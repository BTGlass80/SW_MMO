# Wave G1 — PvP/PvE death tiering + escape-hatch: code-level execution plan

Companion to `docs/WAVE_G_BACKLOG.md` G1 (the *what/why*). This is the *where/how* — the exact
seam map found by reading the live path, so G1 can be executed as one clean, verified slice. Written
after G2 landed (commits 3d0a4a8 / 46cf510): cumulative wound escalation is now live on the PvP
defender, so most PvP "outs" now arrive as **incapacitated-by-accumulation** (sev 3) — exactly the
"downed, medic-relevant" state G1 keys on.

## Owner ruling (2026-07-03, via the parallel session)
True tiering (fork A): **sev 5 = death; sev 3–4 = downed-in-the-field** (medic-relevant, not an instant
kill). Mandatory escape-hatch bundle so a downed lawless player with no friendly medic is NOT
softlocked: (a) a Director-ticked `recovery_model.death_roll` for `mortally_wounded`; (b) a yield/
respawn command for a downed player. Applies to BOTH PvP (DIV-0019) and PvE (DIV-0006).

## Why this MUST be one unit (the softlock trap)
Today `_handle_player_death` fires for **every** casualty (sev ≥ DISABLED_SEVERITY = 3) and does the
full death penalty + **instant respawn** at the spaceport. That is crude but softlock-SAFE. G1's
tiering makes sev 3–4 "stay down in the field" instead of respawning — which INTRODUCES a softlock
unless the escape hatch ships in the same slice. So tiering-without-escape-hatch is a regression; do
both together or neither.

## The exact seam (files + lines as of this writing)

### 1. Casualty classification — `scripts/net/combat_arena.gd` `resolve_window` (~L406–416, L900+ casualties)
The arena already emits tiered `casualties` `[{peer, severity, killer}]` and, post-G2, sets each
victim's `player_wound_level`. **No arena change needed** — the tier decision lives in the net layer.

### 2. The routing split — `scripts/net/network_manager.gd` `_resolve_combat_window` (~L1900–1914)
Currently:
```
for victim in deaths:  # deaths collected from lethal-shooter + casualties, sev>=3
    _handle_player_death(victim, name, killer)
```
Change to classify by severity via `PvpRules.is_kill(sev)` (already exists: `sev >= PVP_DEATH_SEVERITY=5`):
- `is_kill(sev)` (sev 5) → `_handle_player_death(...)` — UNCHANGED full death + respawn.
- else (sev 3–4) → `_handle_player_downed(victim, killer, sev)` — NEW: no penalty, no respawn, in place.
Keep the dedup (a victim both casualty + return-fire death) and keep crediting the killer either way
(the kill/down both reward the attacker — see `_handle_player_death`'s killer block, reuse it).

### 3. NEW `_handle_player_downed(peer_id, killer_peer, severity)` — network_manager
- Do NOT apply DeathPenalty, do NOT move zone, do NOT respawn. The player stays where they fell.
- Mark a server-side downed state: `_downed[peer_id] = {severity, killer, since_tick}` (new dict).
- The arena already treats sev ≥ DISABLED_SEVERITY as "out" (the initiative disabled-guard at
  combat_arena L338), so a downed player already can't act — no arena change.
- Credit the killer (reuse the killer block from `_handle_player_death`).
- Broadcast a NEW `downed_notice.rpc_id(peer_id, {severity, killer, can_yield:true, ...})` +
  a zone-scoped broadcast so others see them down (for First Aid / looting).
- First Aid (DIV-0013, already wired: `submit_heal` → lowers wound severity) is the REVIVE path — when
  a downed player's severity drops below DISABLED_SEVERITY, clear `_downed[peer]`. Add that clear to the
  heal path.

### 4. Escape hatch (a): Director-tick death_roll for mortally_wounded — network_manager `_advance_*`
- On the Director tick (or a dedicated downed-tick), for each `_downed` player with severity == 4
  (mortally_wounded): call `recovery_model.death_roll(...)` (VERIFY its exact signature/inputs — it
  takes the character's STR/stamina + a server-owned seed and returns stabilize | worsen | die).
  - stabilize → severity drops to incapacitated (3) or a recovering tier; update arena + record.
  - die → route to `_handle_player_death` (full penalty + respawn). This is the "bleed out" resolution
    so a medic-less downed player is not stuck forever.
- Server owns the seed (never client). This is the only NEW RNG on the path — seed from `_server_rng`.

### 5. Escape hatch (b): yield/respawn command — network_manager RPC + net_world affordance
- NEW `@rpc("any_peer") submit_yield()` — a downed player (must be in `_downed`) voluntarily gives up:
  route to `_handle_player_death` (accept the penalty + respawn) OR a lighter yield-respawn (owner
  tunable; simplest = reuse `_handle_player_death` so yield == accept death). Reject if not downed.
- `net_world.gd`: when `downed_notice` arrives, show a "You are down — press Y to yield/respawn, or wait
  for a medic" panel; bind Y → `Net.send_yield()`. Headless affordance `--yield` for two-process tests.

### 6. Presentation — net_world.gd
- `downed_notice` handler: distinct HUD state (downed vs dead card), the yield prompt, and a toast when
  First-Aided back up. A downed OTHER player renders prone (optional polish).

## Divergence
Extends DIV-0006 (death penalty) + DIV-0019 (PvP death) — the tiering + downed state + death_roll +
yield are new behavior on those rows. Add a note/row (DIV-0026) before implementing: "sev 5 = death;
sev 3–4 = downed-in-field with Director-tick death_roll (mortally) + player yield; First Aid revives."

## Verification (the seam Fable warned about — do ALL of these)
1. **Pure/logic smoke**: classify sev 3/4 → downed, sev 5 → death; death_roll transitions are
   deterministic for a seed; a heal below DISABLED clears downed.
2. **Arena/flow smoke**: extend `pvp_flow_smoke` — a sev-3 casualty produces a DOWNED outcome (victim
   NOT respawned, still at their position, `_downed` set), a sev-5 produces a death+respawn.
3. **Softlock guard smoke**: a mortally_wounded (sev 4) downed player with NO medic, ticked N times,
   RESOLVES (stabilizes or dies) — asserts the escape hatch prevents an infinite downed state.
4. **Two-process**: two clients in lawless; A downs B (sev 3) → B gets a downed_notice + can `--yield`
   → respawns; separately, a sev-5 → immediate death. Confirm no SCRIPT ERROR + the notices fire.
5. Full `check_project.ps1` green; re-run `tools/balance_probe.gd` (G2+G1 change the TTK/downed mix).

## Suggested build order (one slice)
model/decision → routing split + `_handle_player_downed` → death_roll tick → yield RPC → net_world
presentation → smokes → two-process. Land as ONE commit (or two: server-truth, then presentation) so
tiering + escape hatch are never in the tree apart.

## Status
NOT STARTED (plan only). G2 foundation is in. Owner may take G1 directly (offered) or a focused
continuation executes this plan; either way the seam-audit review the owner proposed should run after.
