# WEG / SW_MUSH / Prototype Divergence Ledger

Use this file whenever a mechanic differs across WEG, SW_MUSH, and this Godot prototype.

## Format

| ID | Area | WEG Source | SW_MUSH Behavior | Prototype Behavior | Reason | Status |
|---|---|---|---|---|---|---|

## Entries

| ID | Area | WEG Source | SW_MUSH Behavior | Prototype Behavior | Reason | Status |
|---|---|---|---|---|---|---|
| DIV-0001 | Ground location model | R&E assumes cinematic scenes and range/difficulty context | Rooms, exits, maps, zones | Continuous 3D settlement with interaction zones | Medium translation from text rooms to spatial play | Accepted translation |
| DIV-0002 | Combat presentation | Turn-based tabletop rounds | Turn-based command rounds | Server-authoritative rounds with real-time camera/animation wrapper | Preserve rules while making visual play responsive | Planned |
| DIV-0003 | Building/destruction | Not a voxel construction game | Text rooms, housing, cities, structures | Minecraft-styled visuals without general destructible voxels | User direction: visual style, not full voxel simulation | Accepted |
| DIV-0004 | Space map | WEG tactical/range bands and astrogation | Clone Wars zone graph plus tactical combat grid | Flat 2.5D plane with 3D ships/camera and zone graph overlay | Medium translation while preserving ship mechanics | Planned |
| DIV-0005 | Era handling | WEG R&E book framing is older-era by default, but mechanics are era portable | SW_MUSH still has some legacy old-era references | Prototype is Clone Wars only; old-era labels are invalid unless retranslated | User direction and current SW_MUSH launch direction | Accepted |
| DIV-0006 | Death / loot penalty | R&E: GM-discretion lethality, no loot rules | SW_MUSH: full-loot decaying corpse in unsafe zones, credits kept | Partial loss + durability damage + insurance, credits kept | Owner direction 2026-06-24: mainstream MMO retention over hardcore full-loot | Accepted |
| DIV-0007 | CP progression source/pace | R&E: CP awarded per session, spent to raise skills | SW_MUSH: kudos + optional LLM pose-grading, deliberately slow (~months/+2D) | Dual-track: fast gameplay-driven CP (quests/kills/exploration) + slow RP-prestige CP | Owner direction 2026-06-24: broad audience with an RP layer | Accepted |
