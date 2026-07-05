# SW MMO Prototype

Standalone Godot prototype for a Clone Wars-era, WEG Star Wars D6-grounded successor/spinoff to `C:\SW_MUSH`.

`C:\SW_MUSH` is treated as read-only reference material. This project should not import, mutate, or require the live text-game code at runtime unless a future explicit migration step copies curated data into this folder.

## Current Slice

The repo holds two things (Godot 4.6.x, GDScript, WEG D6 mechanics throughout):

**1. A playable server-authoritative MMO slice** (`scenes/net_world.tscn`) — shared,
persistent, restart-durable Clone Wars Mos Eisley:

- Account auth → character generation (9 species, 76 skills) → dual-track CP progression.
- WEG ~5s action-window combat off the real sheet + equipped gear: CP/FP, cover, dodge,
  Perception initiative, hit-location armor, cumulative wound escalation.
- Full wound/medical loop (natural recovery + First Aid), true death tiering (sev 5 = death,
  sev 3–4 = downed-in-field with bleed-out/yield/medic-revive), death penalty + insurance.
- Economy: WEG-anchored vendors (buy/sell/bargain/reputation), creature loot + harvest,
  armor repair sink, full-loot corpses in lawless zones.
- Persistent player-driven world: multi-zone travel, zone-security Director with alert
  levels + world events, org territory claims + treasuries, faction influence loops,
  ambient + named NPCs with dialogue, quests, hostile creatures that attack unprovoked
  in lawless zones (threat-tiered, alert-banded spawns).
- Chat (say/ooc/org/emote) + a slash-command bar, character sheet + condition/territory
  HUDs, nameplates with wound/status badges, JSONL telemetry.

**2. A deep SOLO tactical sandbox** (`scenes/main.tscn`, the original slice — unchanged):

- The generated low-poly Mos Eisley settlement + the Bay 94 live-pressure blaster range
  vs B1 training remotes (cover, aim, dodge, CP/FP, wounds, armor hit-location, rich
  remote AI behaviors). Detail: `docs/MOS_EISLEY_SLICE.md` + `docs/COMBAT_SOURCE_TRACE.md`.
- A 2.5D space bridge mode: sensors/identification/comms, gunnery + counterfire, shield
  arcs, crew stations + assists, astrogation, hazards, damage control. Detail:
  `docs/SPACE_SLICE.md`. **Space stays SOLO until the ground loop has real players**
  (owner ruling 2026-07-03 — see `CLAUDE.md` program posture).

Design canon: `docs/REALTIME_D6_TRANSLATION.md` (the real-time WEG translation thesis),
`docs/MULTIPLAYER_FOUNDATION.md` (roadmap), `docs/NIGHTLY_HANDOFF.md` (session notes),
`docs/DIVERGENCE_LEDGER.md` (every WEG/MUSH divergence, documented before implementation).

## Open In Godot

1. Install or extract Godot 4.6.3 or newer 4.6.x stable.
2. Open Godot's Project Manager.
3. Import this folder:
   `C:\Users\btgla\Documents\Codex\2026-06-14\i-d-like-you-to-create\outputs\SW_MMO_Prototype`
4. Run the project.

## Networked Mode (Multiplayer Foundation — M1)

The solo experience above is unchanged (`scenes/main.tscn` is still the project's
main scene). A separate server-authoritative networked world lives in
`scenes/net_world.tscn`. See `docs/MULTIPLAYER_FOUNDATION.md` for the architecture.

Run both the server and client concurrently (recommended):

```cmd
.\start_game.bat
```

Or run them individually in separate shells:

Run a dedicated headless server:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . res://scenes/net_world.tscn -- --server
```

Run a client (default host 127.0.0.1, port 24555):

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64.exe" --path . res://scenes/net_world.tscn -- --connect 127.0.0.1
```


Everything after `--` is a user arg. The server owns all positions; clients send
input intents and render authoritative snapshots.

## CLI Checks

The full gate (python tests + import + launch + every wired GDScript smoke + the
not-before-live invariant; it prints the wired smoke + RPC counts):

```powershell
.\tools\check_project.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe"
```

Run a single smoke (any `scripts/tests/*.gd`):

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://scripts/tests/rules_smoke.gd
```

## Controls

- `WASD`: move
- `Mouse`: look
- `Space`: jump
- `E`: inspect a location or range target
- `H`: toggle the character sheet overlay
- `M`: toggle the Mos Eisley approach space map
- `Esc` or `M` while the space map is open: close the space map and return to ground controls
- Left mouse click on a space contact: select the gunnery/damage-control target
- `Tab` or `.` while the space map is open: select the next space contact
- `,` while the space map is open: select the previous space contact
- `N`: open the space map and run a sensors sweep
- `I`: open the space map and identify the selected contact from the current sensor track
- `X`: open the space map and hail the selected contact over comms
- `T`: pause/resume the live space traffic clock
- `;`: open the space map and advance one manual space traffic accounting tick
- `B`: open the space map and resolve a seeded space-gunnery drill
- `J`: open the space map and resolve a seeded shield-reroute station action
- `K`: open the space map and resolve a seeded damage-control repair action
- `Y`: open the space map and resolve a seeded navigator astrogation-plot action
- `L`: open the space map and resolve a seeded piloting maneuver
- `U`: open the space map, then cycle and resolve a seeded crew-station assist for the next matching space action
- Left mouse click on a target: fire a WEG D6 blaster check
- Right mouse click: aim, stacking +1D per click to +3D for the next shot
- `C`: toggle half cover at the firing barricade
- `Q`: declare a normal dodge against the next remote shot
- `F`: declare a defense-only full dodge for the next live remote volley
- `V`: force an immediate multi-remote incoming-fire volley using the current cover/defense/CP/FP state
- `Z`: pause/resume live remote pressure
- `P`: queue one Character Point for the next blaster attack
- `O`: queue one Character Point for soak if the next remote shot hits
- `G`: queue one Force Point for the next action window
- `R`: reset the range drill
- `Esc`: release mouse
- Left mouse click elsewhere: recapture mouse

## Development Stance

The rule hierarchy is:

1. WEG Star Wars D6 Revised & Expanded rules are the mechanics source of truth.
2. Fun, readable MMO translation is the product goal when tabletop timing or text-game affordances do not map directly.
3. Clone Wars-era SW_MUSH code/data is a reference implementation and content source, not a one-to-one port target.
4. Remaining Galactic Civil War references are legacy contamination unless explicitly retranslated to Clone Wars.
5. New Godot/MMO systems are valid when they preserve or extend WEG D6 play better than a literal MUSH translation.

When SW_MUSH and WEG diverge, the divergence should be documented before implementation.
