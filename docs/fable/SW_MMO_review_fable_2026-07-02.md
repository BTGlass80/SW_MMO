# SW_MMO Prototype â€” External Review (Fable, 2026-07-02)

**For:** Claude Code / Opus sessions working `SW_MMO_Prototype`.
**Snapshot reviewed:** `SW_MMO_Prototype_review_20260702_221957.zip` (post-Wave-F: S0â€“S19 + DIV-0019 PvP wired).
**Method:** symbol-level reads of all `scripts/rules/*`, `scripts/net/*`, data, and the doc corpus; claims cross-checked against code (phantom-delivery discipline); **the gate was actually executed** â€” Godot 4.6.3-stable (Linux headless): project `--import` clean, **72/72 wired GDScript smokes pass, 7/7 python tests pass**, zero SCRIPT/Parse errors. The green bar is real on this snapshot, not a handoff claim.

---

## 1. Verified at symbol level (credit where due â€” do not re-fix these)

- **F55 FP-damage doubling** â€” present in `ground_combat_model.resolve_exchange` (`damage_pool_fp` branch); the melee nuance (double STR only, not the weapon bonus, precomputed in `combat_arena._pools_from_sheet`) is a genuinely good WEG reading.
- **F60/F64 pip-only parse** â€” `d6_rules.parse_pool_or_pips` exists and is routed through `armor_protection_pool` / `armor_dexterity_penalty_pool`; mirrored guard in `derived_stats_model.melee_damage_pool`.
- **F31/F32 "out" gating** â€” `combat_arena.submit_fire_intent` drops intents at `sev >= DISABLED_SEVERITY`; `world_state.set_input` zeroes movement on `can_act=false`; the resolve loop hoists the disabled guard above the target branch (the DIV-0019 clamp-heal exploit fix is in).
- **Server-owned RNG** â€” no `randomize()` anywhere in `scripts/rules`/`scripts/net` models (comment mentions only); all live rolls flow from `_server_rng` / server-passed seeds.
- **Era-cleanness** â€” every Imperial/Rebel/GCW grep hit is provenance metadata (`source_note`/`era_note`), a schema recast note, or a **negative** test guard (`content_smoke.FORBIDDEN_SHIPS`, `org_model_smoke` bad-axis). The B3 discipline transferred, and it's *test-enforced* â€” better than convention.
- **WEG data fidelity** â€” spot-checked `weapons_clone_wars.json` against R&E list values (blaster pistol 4D/500/[3,10,30,120]; hold-out 3D+1/275; heavy 5D/750; rifle 5D/1000; vibroblade STR+3D/250) â€” all correct.
- **Persistence** â€” `_atomic_write` (tmp â†’ remove â†’ rename) with `.tmp` crash-recovery on load, `has_record` counts a surviving `.tmp`; `world_state.dat` name can't collide with a sanitized character id. Solid.
- **Economy funnel** â€” `_award_credits` is the single credit mutation point; buy/sell/insurance RPCs validate ownership/stock/price server-side; bargain pool comes from the **sheet**, never the client. The faucet/sink discipline carried over.
- **Damage-margin banding** â€” `wound_for_damage_margin` (margin â‰¤0 = no damage, 1â€“3 stunned) exactly matches SW_MUSH `WoundLevel.from_damage_margin` and Guide_03 Â§"1â€“3 Stunned". Parity confirmed; nobody should "fix" this against a raw R&E reading without doing it in both codebases at once.
- **Divergence-ledger-first** is genuinely being followed. 20 rows, mostly accurate. The exceptions are below â€” and they're the review's core.

---

## 2. P0 â€” contradictions/gaps to resolve BEFORE building on Wave F

### P0-1. PvP death tiering: docs, model, and wire disagree (pick one, reconcile all three)
- **Model + smoke:** `pvp_rules_model.PVP_DEATH_SEVERITY = 5`, `is_kill(sev>=5)`; `pvp_rules_model_smoke` asserts *"sev 4 (mortally) is 'out', not dead"* and *"sev 3 is 'out', not dead"*.
- **Ledger:** DIV-0019 says *"casualties (sev 3-4 = 'out'/First Aid DIV-0013; sev 5 = dead): the net layer routes sev 5 through â€¦ apply_death"*.
- **Wire (actual):** `combat_arena.resolve_window` records a casualty at `new_def >= DISABLED_SEVERITY (3)`, and `network_manager._resolve_combat_window` routes **every** casualty to `_handle_player_death`. `is_kill` is never called on the live path â€” **dead code whose smoke asserts the opposite of shipped behavior.** A sev-3 PvP hit kills + respawns today.
- **Fork (owner may want a say, but a default is safe):**
  - **(A)** Wire `is_kill`: sev 5 = death; sev 3â€“4 = downed-in-the-field. **Requires** a companion escape hatch â€” DIV-0012 excludes incap/mortal from self-recovery and F32 blocks movement, so a downed player in lawless with no friendly medic is *softlocked*. You'd need the WEG mortal-wound death roll (already built in `recovery_model.death_roll`, unwired) ticking on the Director, plus a "yield/respawn" command for sev 3.
  - **(B, recommended for v1):** declare death-on-incapacitation the v1 rule for PvP too (it already is for PvE per DIV-0006's v1 note) â€” consistent, no softlock. Then: delete or explicitly park `is_kill`/`PVP_DEATH_SEVERITY`, fix the two smoke asserts, and rewrite the DIV-0019 sentence to match the wire. Track (A) as the WEG-fidelity follow-up bundled with the death roll.
- Either way: **the smoke must assert what ships.** A green test encoding unwired semantics is the inverted-narrative phantom with a CI badge.

### P0-2. Cumulative wound escalation is unwired, and lethality just went live
- `wound_ladder_model.escalate()` is complete, correct, tested â€” and **never called on the live path**. Live accumulation everywhere is `maxi(old, new)` (`resolve_exchange`, `_resolve_return_fire`, the PvP defender write-back).
- Consequence, now that S6/S11/DIV-0019 shipped: **attrition cannot kill.** Wounded + Wounded stays Wounded forever; death requires a single margin-16+ hit. That silently reshapes every Wave-F number you just tuned â€” hostile threat, insurance value, PvP TTK, the sparring cap's meaning ("cap 2 because wounded_twice isn't wired" per DIV-0016 is *load-bearing* on this gap).
- DIV-0008 tracks the wiring as a follow-up â€” correct when written, but it graduated to **prerequisite** the moment lethal damage shipped. Recommend: wire `escalate()` into the three accumulation sites now (the ledger already predicted the seeded-smoke churn; re-seed and move on), **or** re-ledger explicitly: "maxi accumulation is the accepted MMO model; one-shot-only death is the intended consequence" â€” and re-tune hostile damage pools knowing it.
- **Trap to avoid while wiring:** severity ints and ladder indices diverge at 3 (`level_for_severity(3)` = incapacitated; `LEVELS[3]` = wounded_twice). Cross the boundary via level strings (`escalate(level, incoming_severity)` â†’ `level_index`), never raw ints. Persist `wound_state` as the level string (it already is) and derive the arena's severity int at the seam.

### P0-3. PvP defenders cannot dodge (the WEG reaction layer is absent exactly and only in PvP)
- `PvpRules.defender_target_pools` maps attack/damage/soak/armor/scale â€” **no dodge pool**. `resolve_exchange`'s primary attack calls `resolve_ranged_attack(shot_pool, distance, cover, rng, {})` â€” empty defense. And a passive victim's cover is read from their **intent** (`_intents.get(target_peer)` â†’ absent â†’ 0), not their persistent state.
- Net effect: against another player's declared attack, your `dodge`/`full_dodge` stance and your cover level do **nothing**; defense = armor + Strength soak only. Full-dodge as a defender is pure downside (you forgo your attack and gain nothing). In a system whose whole defensive identity is the reaction dodge, that's the biggest fidelity hole in the PvP slice â€” and it's not in DIV-0019's follow-up list (positional range and corpse-loot are; this isn't).
- Fix path (mostly plumbing, no new mechanics): in the `is_pvp` branch, build the defender's defense from their declared stance + `player_dodge_pool` (wound- and armor-penalized like `_resolve_return_fire` already does), pass it into `resolve_ranged_attack`; `prepare_ranged_defense` already supports one cached dodge roll reused across multiple incoming attacks in a window â€” it was built for exactly this. Read defender cover from persistent state (`_players[def]["state"].player_cover_level`), falling back to intent. Add smoke: declared-dodge defender raises the attacker's effective difficulty; full-dodge defender skips their own attack AND applies vs incoming.

---

## 3. P1 â€” gaps that will bite the next wave

### P1-1. Hostiles never initiate
Hostile creatures only fire as **return fire inside a player-initiated exchange**. A player who never presses fire can stand beside the Dune Sea spawn indefinitely, unharmed. Lawless zones are currently dangerous only to volunteers â€” which undercuts the death loop, the insurance sink, and the zone fantasy in one stroke. `ground_combat_model.resolve_incoming_fire_window` **already exists**, handles multi-attacker windows and a prepared dodge, and is fully smoked â€” it just has no live caller for hostiles. Add a Director-tick (or per-window when a hostile is engaged and no intent arrived) unprovoked-attack path through it. This also naturally fixes "engagement is symmetric only if the player consents."

### P1-2. One hostile per zone; engagement is forced
`register_hostile_target(zone_id, â€¦)` keys by zone (max one), and `_refresh_peer_hostility` force-targets **every** player in the zone. You can't decline the fight or choose among targets; `pack_size` is loot math only. Acceptable v1 â€” but note it in the ledger/backlog as accepted, and fold multi-spawn + explicit target selection into the already-tracked positional-range follow-up so it's designed once.

### P1-3. Auth hardening bundle (gate this on "before any non-LAN playtest", not now)
- `account_auth_model.check_secret` stores/compares secrets in **plaintext** JSON and they travel over unencrypted ENet. Godot ships `Crypto`/`HashingContext` â€” salted hash at rest is a small slice; DTLS (or an explicit "dev transport" banner) for flight.
- Unsecured accounts are **first-claimer-wins** (documented, but it's an account-squat vector the moment two strangers share a server).
- **Name policy:** there is no reserved-name filter â€” an MMO Q1 analogue is needed before strangers connect (players naming themselves canonical figures). Related nit: `wire_roundtrip_smoke.gd` literally names a test player "Ahsoka" â€” rename the fixture so the canonical-name grep stays clean, then add the chargen-time filter (port the MUSH name-policy list).

### P1-4. Economy arbitrage landmine (one-line structural fix)
`MAX_TOTAL_DISCOUNT = 0.65` â‡’ buy floor = **0.35Ã—list**, while `SELL_RATE = 0.40` â‡’ sell = **0.40Ã—list**. Floor < sell = a buyâ†’sell money printer whenever stacked discounts reach the floor. Unreachable **today** (bargain is 3%/die capped 50% â€” you'd need ~17D bargain), but it's one dial-turn (a deeper Director event, a rep-tier buff) from live. Structural guard: enforce `MAX_TOTAL_DISCOUNT <= 1.0 - SELL_RATE - Îµ` (or compute sell from *paid* price), plus a smoke asserting `buy_floor(list) > sell_price(list)` for all catalog items. Cheap insurance on the whole sink.

### P1-5. `force_sensitive` storage model â€” ledger the deliberate MUSH divergence
In SW_MUSH, `force_sensitive` is **derived state** (reconstructed from control/sense/alter keys; never a stored column) â€” a standing invariant. In the MMO it is a **stored sheet field** flipped by `force_awakening_model.apply_completion`. That's a reasonable choice for this architecture (the awakening queue needs a persisted flag), but it's exactly the kind of cross-repo difference a future MUSH-habituated session will "helpfully fix." One sentence in DIV-0011 ("storage model deliberately differs from SW_MUSH's derived-state invariant because â€¦") immunizes it.

---

## 4. P2 â€” hygiene, doc rot, structure

1. **Stale comment = live phantom:** `ground_combat_model._wound_penalty_dice` comment says *"sev 3->2, 4->2 (the fix)"* â€” the delegate (`penalty_dice_for_severity`) actually returns **0** for 3/4 (out-tiers moot), per its own header. The comment describes a design that was corrected before ship. Fix the comment; it will mislead exactly the session that wires P0-2.
2. **Count drift:** CLAUDE.md says "~66 GDScript smokes", SESSION_HANDOFF says 59, actual wired = **72** (verified: every file in `scripts/tests/` is wired â€” no orphans, good). RPC surface: SESSION_HANDOFF says 21; actual `@rpc` count = 33. Suggestion: have `check_project.ps1` print the smoke count and make that the only authoritative number; docs say "see the gate output," never a literal.
3. **README "Current Slice" is unreadable.** The space paragraph is a single ~600-word comma-chained sentence. It's the first thing a fresh session or human reads; it actively hides information. Rewrite as short bullets; push detail into `SPACE_SLICE.md` (which exists for this).
4. **Monolith watch before SPACE presentation lands:** `space_tactical_model.gd` = 2,597 lines, `space_status_model.gd` = 1,560. The pure/presentation split is right, but these two are becoming un-reviewable. Split by concern (contacts/locks, hazards/maneuver, damage-control/repair, status formatting) while the smokes still map cleanly â€” cheaper now than after the presentation agents start depending on the shape.
5. **Pip-drop inconsistency (harmless today):** `apply_multi_action_penalty`/`apply_wound_penalty` zero the pips whenever dice hit 0 (2D+2 âˆ’ 2D â†’ 0D+0, not 0D+2), while `subtract_pools` preserves them. A 0D actor mostly can't act anyway, but the asymmetry will confuse a future audit â€” pick one convention, note it in `d6_rules` header.
6. **Unledgered house rules in `d6_rules`:** (a) the Wild-Die 1 always applies the *harshest* R&E option (wild counts 0 AND remove highest die) â€” R&E offers GM options; 100%-harshest is a fine server rule but deserves a ledger line. (b) FP doubling is applied **before** MAP and aim are added (penalties/bonuses not doubled) â€” defensible ordering, also worth one sentence. (c) `roll_pool` floors totals at 1. Three lines in the ledger or the file header closes all three.
7. **quest_model (DIV-0020) is pure-only; port the MUSH shape when wiring.** SW_MUSH is now at **35** accessible questlines authored on a fixed no-new-engine pattern (giver â†’ skill checks â†’ combat â†’ return, funnel-routed rewards) and just moved combat-objective completion to **defeat-at-INCAPACITATED** â€” which happens to match the MMO's `DISABLED_SEVERITY=3` convention exactly. When wiring quests: reuse that proven shape and the S-series reward funnels; don't invent a parallel objective grammar. Also note `quests_clone_wars.json` (4 quests) was extracted 06-24 and MUSH has had ~10 heavy content days since â€” schedule a `mush-content-porter` re-extraction pass (quests, any weapons/skills deltas) as a standing cadence item rather than a one-time port.

---

## 5. Strategic direction (for the world-sim / netcode agents)

**The next fidelity cliff is positional truth.** Right now distance is a profile constant (`HOSTILE_DISTANCE`, `PVP_DISTANCE=12`) and cover is intent-supplied, while `WorldState` already owns authoritative positions. Deriving combat distance from server positions and cover from world/zone data retires three follow-ups at once (positional PvP range, defender cover, hostile engagement radius) and is the single biggest step from "action windows bolted to a lobby" toward "real-time MMO with D6 under the hood" â€” exactly the `REALTIME_D6_TRANSLATION.md` thesis. Recommend it as the spine of the next backend wave, ahead of more breadth.

**Persistence scaling:** JSON-per-character + one global `world_state.dat` is right for now; note that org treasuries/claims/influence all funnel through that single global file â€” when zones multiply or a second Director consumer appears, move to per-zone records or the SQLite step already sketched in `PERSISTENCE_DESIGN.md` *before* write contention shows up, not after.

**Add an invariant-auditor agent** (mirror of the MUSH kit): read-only, checks each drop for â€” era grep + `FORBIDDEN_SHIPS`, no `randomize()`/client RNG in models, no trust of `_intents`/client fields in HOT files, divergence-row-exists-before-mechanic-change, smoke asserts match wired behavior (P0-1 is the poster child for why convention alone wasn't enough).

---

## 6. Proposed next backend wave (queue-ready, in house format)

- **G1 [PAR]** Reconcile PvP death tiering per P0-1(B): fix `pvp_rules_model_smoke` asserts + DIV-0019 text to match wire; park `is_kill` with a comment pointing at the death-roll follow-up. (Or escalate fork A/B to owner â€” one line, safe default B.)
- **G2 [PAR]** Wire `wound_ladder_model.escalate()` into the three live accumulation sites (P0-2); severityâ†”level via strings at the seam; re-seed affected smokes; update DIV-0008 status.
- **G3 [HOT]** PvP defender defense (P0-3): stance + dodge pool + persistent-state cover into the `is_pvp` branch; smoke for dodge-raises-difficulty and full-dodge-defender.
- **G4 [HOT]** Hostile initiation (P1-1): Director/window-tick unprovoked attacks via `resolve_incoming_fire_window`; keep lawless+contested gating; two-process check: idle player in dune_sea takes fire and can die.
- **G5 [PAR]** Economy floor guard (P1-4): const assert + catalog-wide smoke.
- **G6 [PAR]** Ledger/doc batch: DIV-0011 storage-model sentence (P1-5), d6_rules house-rule notes (P2-6), `_wound_penalty_dice` comment fix (P2-1), count-drift rule (P2-2), README rewrite (P2-3).
- **G7 [PAR]** Rename the "Ahsoka" test fixture; add reserved/canonical-name filter to chargen (P1-3 name half).
- **G8** (pre-public-playtest, owner-scheduled): secret hashing + transport (P1-3 crypto half).
- **G9** Positional-truth spike (Â§5) â€” design doc first (`world-sim-designer`), then slices.

---

*Reviewed against: WEG R&E semantics as encoded in SW_MUSH Guides 01/03/19 (authoritative per CLAUDE.md), the DIV ledger, and the live SW_MUSH HEAD (2026-07-02 CHANGELOG). Gate re-verified independently on Linux Godot 4.6.3: 72 GD smokes + 7 python, all green.*
