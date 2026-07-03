# Read-Only Reference Sources

The new project is standalone. These paths are references only and must not be modified by prototype work.

## Primary Local Source

- `C:\SW_MUSH`

Use Clone Wars-era files from this tree for setting and content. Remaining old-era references are legacy material unless a Clone Wars data file or design note has explicitly reauthored them.

## WEG Source Material

- `C:\SW_MUSH\docs\sourcebooks\WEG40120.pdf`
- `C:\SW_MUSH\docs\sourcebooks\WEG40120.txt`

Treat WEG Star Wars D6 Revised & Expanded as the source of truth for rule resolution, not era framing. The local text extraction is useful for search, but page images/PDF should be checked when precision matters.

## Source Authority

- SW_MUSH code and live data are the source of truth for implemented behavior.
- System guides are useful orientation material, but may lag behind implementation and must be checked against code before porting mechanics.
- WEG R&E remains the mechanics source of truth when deciding whether SW_MUSH behavior is faithful or intentionally divergent.

## SW_MUSH System Guides

- `C:\SW_MUSH\docs\design\Guide_01_WEG_D6_Core_Mechanics.md`
- `C:\SW_MUSH\docs\design\Guide_02_Character_Creation.md`
- `C:\SW_MUSH\docs\design\Guide_03_Ground_Combat.md`
- `C:\SW_MUSH\docs\design\Guide_05_Space_Systems.md`
- `C:\SW_MUSH\docs\design\Guide_06_Economy.md`
- `C:\SW_MUSH\docs\design\Guide_07_Crafting.md`
- `C:\SW_MUSH\docs\design\Guide_08_Force_Powers.md`
- `C:\SW_MUSH\docs\design\Guide_10_Organizations_Factions.md`
- `C:\SW_MUSH\sw_d6_mush_architecture_v51.md`

## SW_MUSH Data Candidates For Future Curated Import

- `C:\SW_MUSH\data\skill_descriptions.yaml`
- `C:\SW_MUSH\data\starships.yaml`
- `C:\SW_MUSH\data\schematics.yaml`
- `C:\SW_MUSH\data\npcs_*.yaml`
- `C:\SW_MUSH\data\worlds\clone_wars\*.yaml`
- `C:\SW_MUSH\data\worlds\clone_wars\maps\mos_eisley.yaml`
- `C:\SW_MUSH\data\worlds\clone_wars\planets\tatooine.yaml`
- `C:\SW_MUSH\data\worlds\clone_wars\npcs_drop_h_combat.yaml` for the B1 `2D` strength/soak baseline used by the first training silhouettes.

## Imported — Clone Wars Content Drop 1 (2026-06-24)

The following SW_MUSH sources were read (READ-ONLY) and their curated content
extracted into standalone JSON snapshots under `data/`. All four files carry
`source_policy` provenance blocks noting SW_MUSH read-only status.

### Sources consumed

| Source file | Destination |
|---|---|
| `C:\SW_MUSH\data\skills.yaml` | `data/weg_skill_catalog.json` |
| `C:\SW_MUSH\docs\design\Guide_01_WEG_D6_Core_Mechanics.md` | `data/weg_skill_catalog.json`, `data/weapons_clone_wars.json` |
| `C:\SW_MUSH\docs\design\Guide_02_Character_Creation.md` | `data/species_clone_wars.json` |
| `C:\SW_MUSH\data\species\human.yaml` | `data/species_clone_wars.json` |
| `C:\SW_MUSH\data\species\bothan.yaml` | `data/species_clone_wars.json` |
| `C:\SW_MUSH\data\species\duros.yaml` | `data/species_clone_wars.json` |
| `C:\SW_MUSH\data\species\mon_calamari.yaml` | `data/species_clone_wars.json` |
| `C:\SW_MUSH\data\species\rodian.yaml` | `data/species_clone_wars.json` |
| `C:\SW_MUSH\data\species\sullustan.yaml` | `data/species_clone_wars.json` |
| `C:\SW_MUSH\data\species\trandoshan.yaml` | `data/species_clone_wars.json` |
| `C:\SW_MUSH\data\species\twilek.yaml` | `data/species_clone_wars.json` |
| `C:\SW_MUSH\data\species\wookiee.yaml` | `data/species_clone_wars.json` |
| `C:\SW_MUSH\data\weapons.yaml` | `data/weapons_clone_wars.json`, `data/armor_clone_wars.json` |

### Destination files created

| File | Contents |
|---|---|
| `data/weg_skill_catalog.json` | 76 WEG D6 R&E skills across 6 attributes (75 core + Powersuit Operation per MUSH design note 2026-06-13) |
| `data/species_clone_wars.json` | 9 playable Clone Wars-era species with attribute dice ranges and special abilities |
| `data/weapons_clone_wars.json` | 32 Clone Wars-era weapons (19 blasters, 8 melee, 2 bowcaster/auto, 1 lightsaber, 2 grenades) |
| `data/armor_clone_wars.json` | 23 Clone Wars-era armors (commercial, faction-issued, powered exo-frame) |

### Curation decisions

- **Excluded from weapons**: Heavy Repeating Blaster (E-Web) — Imperial doctrine
  framing in notes.
- **Era-recast in skills**: `bureaucracy` specializations changed from
  Imperial/Rebel Alliance to Republic Senate/Separatist Council; `capital_ship_piloting`,
  `starfighter_piloting`, `starship_gunnery`, `space_transports`, `starfighter_repair`,
  `walker_operation` specializations updated to Clone Wars-era vessels.
- **Contraband included**: Disruptor pistol, predator rifle, anti-vehicle grenade
  exist in-universe in the Clone Wars era and are flagged `contraband: true`.
- **Faction-issued gear**: All Clone Wars military/chain-reward weapons and armors
  included with `vendor_stocked: false`.
- **Powersuit Operation**: 76th skill (mechanical) — added by MUSH design note
  CRAFT.powered_suit_design 2026-06-13; documented in `era_note` field.

## Imported — Clone Wars Content Drop 2 (2026-06-24)

Vehicles/starships, droids, and creatures extracted READ-ONLY into standalone JSON.
All three files carry `source_policy` provenance.

### Sources consumed

| Source file | Destination |
|---|---|
| `C:\SW_MUSH\data\starships.yaml` | `data/starships_clone_wars.json` |
| `C:\SW_MUSH\data\vendor_droids.yaml` | `data/droids_clone_wars.json` |
| `C:\SW_MUSH\data\npcs_creatures.yaml` | `data/creatures_clone_wars.json` |

### Destination files created

| File | Contents |
|---|---|
| `data/starships_clone_wars.json` | 6 era-appropriate civilian craft (YT-1300, YT-2400, Ghtroc 720, Z-95 Headhunter, Firespray, Corellian Corvette) |
| `data/droids_clone_wars.json` | 3 commerce/vendor droids (GN-4/GN-7/GN-12) for the player-vendor economy |
| `data/creatures_clone_wars.json` | 22 era-neutral wildlife creatures (worrt, krayt fauna, etc.) |

### Curation decisions

- **Excluded GCW/Imperial-era starships**: X/A/B-wing, all TIE variants, Lambda &
  Sentinel shuttles, Nebulon-B, Imperial Star Destroyer — not Clone Wars-appropriate.
  (`content_smoke` asserts none of these leak into the roster.)
- **CW-specific military starfighters** (V-19 Torrent, ARC-170, Eta-2, Delta-7,
  Vulture droid, Tri-fighter) are NOT in the SW_MUSH source; authoring them from WEG
  sourcebook stats is a future drop, noted in the file's `source_note`.

## Imported — World-Depth NPC & Vendor Drop (2026-07-02)

Named NPCs and per-zone vendor stock variety extracted READ-ONLY into standalone
JSON. Both files carry `source_policy` provenance.

### Sources consumed

| Source file | Destination |
|---|---|
| `C:\SW_MUSH\data\worlds\clone_wars\npcs_drop_b_mos_eisley.yaml` | `data/npcs_clone_wars.json` |
| `C:\SW_MUSH\data\worlds\clone_wars\npcs_mos_eisley_population_p1.yaml` | `data/npcs_clone_wars.json` |
| `C:\SW_MUSH\data\worlds\clone_wars\npcs_drop_ambient_tatooine_spaceport_civic.yaml` | `data/npcs_clone_wars.json` |
| `C:\SW_MUSH\data\worlds\clone_wars\npcs_drop_mob_grind_tatooine.yaml` | `data/npcs_clone_wars.json` |
| This repo's own `data/weapons_clone_wars.json` + `data/armor_clone_wars.json` (`vendor_stocked:true` subset only) | `data/vendor_stock_by_zone.json` |

### Destination files created

| File | Contents |
|---|---|
| `data/npcs_clone_wars.json` | 15 named Clone Wars-era (20 BBY) Mos Eisley NPCs spread across the 4 zones in `data/zones_clone_wars.json`, with role/faction_axis/description/dialogue_lines |
| `data/vendor_stock_by_zone.json` | Per-zone curated vendor item lists (existing `vendor_stocked:true` weapons/armor only) for the same 4 zones |

### Curation decisions

- **Zone mapping is a curation call**: SW_MUSH rooms are far more granular than
  this project's four broad `zone_id`s, so each NPC's MUSH room was mapped to the
  nearest loaded zone by in-fiction fit (documented per-entry via `source_room`).
- **Djas Puhr's `faction_axis` recast** from the MUSH source's generic
  `independent` tag to this project's dedicated `bounty_hunters_guild` axis (the
  MUSH schema has no bounty-hunter-specific faction; ours does, and his profession
  is explicit in the source text). Documented per-entry via `curation_note`.
- **No CIS-affiliated named NPC**: none exists anywhere in SW_MUSH's
  Tatooine/Mos Eisley content — lore-consistent (the CIS has no meaningful
  presence in Hutt-controlled Outer Rim space during the war) — reflected
  honestly rather than invented.
- **Canonical film characters** (Wuher, Chalmun, Djas Puhr) are carried over ONLY
  because `npcs_mos_eisley_population_p1.yaml` itself already re-skinned them for
  the Clone Wars era per its own header policy (original descriptions/dialogue,
  WEG-only stats, no copied sourcebook text); no new canonical cameo is
  introduced by this drop.
- **Vendor stock is a strict subset**: every `item_keys` entry in
  `vendor_stock_by_zone.json` is drawn only from weapons/armor already marked
  `vendor_stocked:true` in the existing catalogs (12 items total); no
  `vendor_stocked:false` or contraband item is unlocked for any zone.
