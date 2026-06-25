# SW_MUSH System Map For Visual Translation

Initial Clone Wars-only map from `C:\SW_MUSH` inspection.

## Core Rule/Data Sources

| System | SW_MUSH Reference | Visual Translation |
|---|---|---|
| Dice and checks | `engine/dice.py`, `engine/skill_checks.py`, Guide 01 | `D6Rules` singleton, later server rules module |
| Character attributes/skills | `engine/character.py`, `data/skills.yaml`, species YAML | Character resource plus server-owned progression |
| Ground combat | `engine/combat.py`, `parser/combat_commands.py`, Guide 03 | Round-based resolver with 3D range/cover queries |
| Space systems | `engine/starships.py`, `engine/npc_space_traffic.py`, Clone Wars space YAML, Guide 05 | 2.5D ship scene and zone graph |
| Economy/trading | `engine/trading.py`, Guide 06 | Planet markets, cargo, dynamic supply pools |
| Crafting | `engine/crafting.py`, `data/schematics.yaml`, Guide 07 | Workbenches/vendors/resources with WEG checks |
| Factions/guilds | `engine/organizations.py`, Guide 10 | Faction state, rank, reputation, mission access |
| Force | `engine/force_powers.py`, Guide 08 | Strictly gated abilities, server-side checks |
| Director/events | `engine/director.py`, world events docs | Server event director, admin-tunable |
| Player cities/housing | `engine/player_cities.py`, housing docs | Later settlement ownership/build placement |

## First Slice Choice

The first playable slice is Mos Eisley because it validates:

- 3D scale and movement.
- Interaction ranges.
- NPC/vendor/terminal placement.
- WEG blaster range and cover checks in context.
- The future transition point to ships and space.

Space follows as the second visual slice because the SW_MUSH space system is large and benefits from having the shared rules/data core in place first.

See `MOS_EISLEY_SLICE.md` for the current Spaceport Row / Docking Bay 94 translation.

## Era Decision

Clone Wars only. Remaining GCW references in SW_MUSH are legacy contamination unless already translated by Clone Wars data or explicitly reauthored.
