# WEG Fidelity Policy

This project is not merely Star Wars-flavored. It is Clone Wars-era and grounded in West End Games Star Wars D6, especially Revised & Expanded.

## Rule Priority

1. WEG Star Wars D6 Revised & Expanded.
2. Other WEG D6 sourcebooks when they extend R&E without contradicting it.
3. A fun, legible, sustainable MMO translation of WEG play.
4. Clone Wars-era SW_MUSH code and live data when they faithfully encode WEG, provide useful content, or demonstrate a proven adaptation.
5. SW_MUSH guides as secondary orientation only; verify against code before porting.
6. Era translations from older source material only after explicit Clone Wars recasting.
7. New Godot/MMO-specific systems when they preserve, broaden, or improve WEG-style play better than a literal MUSH translation.

## Translation Rules

- Dice pools remain `xD+y` with pips normalizing at 3 pips per die.
- Character skills are modeled as bonuses over parent attributes, matching the WEG/SW_MUSH character shape. UI may display final pools, but data should preserve attribute plus skill-bonus structure where possible.
- The Wild Die remains present in ordinary skill resolution.
- Named difficulty bands remain visible in data and UI even when encounters are real-time.
- Ground combat should preserve initiative, declaration, multi-action penalties, dodge/parry, cover, wounds, CP, Force Points, and scale.
- Space combat should preserve crew stations, astrogation, piloting, sensors, gunnery, fire arcs, range bands, shields, hull, system damage, and scale.
- Cross-scale combat follows R&E intent: lower-scale attackers add the adjusted modifier to hit higher-scale targets, higher-scale targets add it to soak, higher-scale attackers roll normally, lower-scale defenders add it to dodge, and higher-scale weapons add it to damage.
- Do not cargo-cult text-game mechanics. Port WEG intent first, then decide whether the MUSH implementation, a new MMO design, or a hybrid best serves that intent.
- Force Points double character skill and attribute die codes. Weapon damage should not be doubled unless the damage pool is character-derived, such as Strength-based melee damage.
- Armor protection is not a character attribute. When a Force Point affects soak, double the character Strength pool before adding armor protection.
- Minecraft-styled visuals do not imply voxel rules. Blocks are art language first.
- The game is Clone Wars only. Old-era faction labels, military forces, quests, and world framing should be treated as bugs unless deliberately reauthored.

## Divergence Ledger

Every known divergence should be logged with:

- WEG source.
- SW_MUSH behavior.
- Prototype behavior.
- Reason for divergence.
- Whether the divergence is temporary, medium-driven, or a deliberate design call.

Initial known medium translations:

| Area | WEG/SW_MUSH Basis | Prototype Direction |
|---|---|---|
| Ground movement | Room/exits and combat ranges | 3D spaces with interaction zones and range bands derived from world distance |
| Combat timing | Turn rounds | Server-authoritative action windows hidden behind responsive local movement and animation |
| Space navigation | Zone graph and ship commands | Flat 2.5D tactical plane plus galaxy/zone map |
| Admin/build tools | Text commands | In-game/editor-facing panels and server tools |

Current known temporary divergences:

None currently logged for the Bay 94 range mechanics. New divergences should be added here as soon as they are discovered.

## Clone Wars Era Guardrails

- Mos Eisley is 20 BBY: Hutt power is real, Republic presence is light, and the war is distant but visible in rumor, refugees, profiteering, and occasional clone/militia activity.
- CIS, Republic, Jedi Order, Hutt cartels, local planetary authorities, and independent criminal groups are valid faction language.
- Old-era references to Imperial, Rebel, stormtrooper, Alliance, or Empire content require replacement, removal, or a deliberate Clone Wars analogue.
