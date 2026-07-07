# Mos Eisley Slice

## Source Basis

This slice is a compact 3D interpretation of the Clone Wars Mos Eisley data in:

- `C:\SW_MUSH\data\worlds\clone_wars\maps\mos_eisley.yaml`
- `C:\SW_MUSH\data\worlds\clone_wars\planets\tatooine.yaml`

SW_MUSH code and live data are authoritative. Guides are useful orientation, but should be treated as potentially stale until checked against implementation.

The first implemented sub-area is Spaceport Row around Docking Bay 94.

## Included Locations

- Docking Bay 94 / Bay 94 entrance.
- Docking Bay 86.
- Docking Bay 87.
- Spaceport Customs Office.
- Spaceport Speeders.
- Transport Depot.
- Mos Eisley Spaceport Control Tower.
- Spaceport Row street spine.

## Gameplay Loop

The Bay 94 footprint currently hosts the first blaster range prototype. It uses short action windows as the real-time translation of WEG/SW_MUSH rounds; see `REALTIME_D6_TRANSLATION.md`.

- Player pool: Blaster `4D+1`.
- Targets: B1-style training silhouettes.
- Range bands: Point Blank, Short, Medium, Long, Extreme.
- Cover: none, half cargo cover, three-quarter bay-wall cover.
- Aim: right-click stacks +1D per aim step to a maximum of +3D, consumed by the next shot.
- Player cover: `C` toggles half cover at the firing barricade. Per live SW_MUSH combat code, firing from better-than-quarter cover degrades the shooter to quarter cover for return fire.
- Dodge: `Q` declares a normal dodge against the next remote shot. It replaces the base range difficulty and currently applies the extra-action penalty for firing and dodging in the same exchange.
- Full dodge: `F` declares a defense-only action window for the next live remote volley; no player blaster shot is rolled, and the full dodge roll adds to the base range difficulty.
- Multi-remote incoming fire: active remotes now evaluate on a live pressure clock with per-target cadence/phase, near-miss pinning, peeking/tucked, flanking/repositioning, reload/weapon-cycle, morale hesitation, and fallback metadata, so automatic volleys are staggered instead of always firing every armed remote. `V` forces an immediate all-eligible volley for inspection/debug. A declared dodge/full-dodge is rolled once and reused across the incoming shots.
- Peeking remotes: covered B1 remotes can alternate exposed and tucked live ticks. Tucked remotes remain armed, but they do not contribute automatic fire until their next exposed tick; this changes encounter pacing without replacing WEG D6 attack, cover, damage, or soak resolution.
- Flanking remotes: selected B1 remotes can spend configured live ticks repositioning instead of firing. They remain armed, but do not contribute automatic pressure while flanking; this adds NPC behavior texture without changing WEG D6 attack, cover, damage, or soak resolution.
- Reloading remotes: selected B1 remotes can spend configured live ticks cycling weapons instead of firing. They remain armed, but do not contribute automatic pressure while reloading; this gives live fire a readable cadence without changing WEG D6 attack, cover, damage, or soak resolution.
- Covering fire: selected B1 remotes can spend configured live ticks laying down non-damaging pressure instead of resolving a shot. This makes the automatic encounter feel less metronomic while preserving WEG D6 attack, damage, and soak math for actual fire.
- Morale hesitation: selected wounded/stunned B1 remotes can spend configured live ticks hesitating instead of firing. They remain armed, but do not contribute automatic pressure while hesitating; this adds NPC behavior texture without changing WEG D6 wound penalties, attack, cover, damage, or soak resolution.
- Wounded fallback: selected B1 remotes that cross a configured wound threshold briefly fall back from live return-fire pressure. This delays future automatic shots but leaves WEG wound penalties, attack, damage, and soak resolution unchanged.
- Hit suppression: successful non-disabling hits against armed remotes can push that remote off its next configured live-fire tick. This gives player fire real-time counterplay while leaving the WEG D6 attack, damage, and soak result intact.
- Near-miss pinning: configured active remotes can briefly hold fire after a close player miss, making suppressive shots tactically useful without turning a miss into WEG damage. The close-miss threshold is owned by the pure range target model so the same decision can later run server-side.
- Armed return fire: live pressure only includes targets with an attack and damage pool. The walker-scale armor plate remains shootable for scale testing, but it is an inert target and does not fire back.
- Range telemetry: the HUD reports live remote-pressure countdown, armed return-fire source count, next scheduled automatic-fire source count, suppressed remote count, pinned remote count, currently covered/tucked remote count, fallback remote count, flanking remote count, reloading remote count, hesitating remote count, covering-fire count, cover, queued defense, CP/FP state, wound state, automatic-volley count, and latest combat audit summary with hit-location/armor coverage hints so the server-style action window is visible during real-time play.
- In-world remote-state badges: each Bay 94 target displays its current model-derived live behavior state above the target, such as READY, WAIT, TUCKED, COVER, HOLD, FLANK, RELOAD, HESITATE, FALLBACK, SUPPRESSED, PINNED, DOWN, or INERT. These badges are visual-only and mirror `range_target_model.gd` state accounting.
- Moving targets: one B1 remote now sweeps laterally on a sine pattern, while one walker-scale armor plate moves on a sharper patrol/triangle pattern. Shots still resolve through the WEG D6 combat model, but the player must track distinct moving targets in real time, including a cross-scale target. When a moving target is disabled by WEG damage, it stops moving.
- Range target inspection: pressing `E` while looking at a range target reports its data profile, scale, cover, wound state, soak pool, armor coverage/quality, whether it is inert or armed, weapon pool, current and next live behavior state, and source note. This makes the WEG scale/armor setup and real-time encounter behavior legible before the player fires.
- In-world hit feedback: after each shot, the target briefly displays a billboard marker at the resolved WEG hit location with hit/miss/blocked text, armor coverage, armor-quality degradation, and wound result. Successful hits also leave persistent body-part tinting plus small scorch/impact marks on the resolved target location until `R` resets the drill. The feedback is visual-only and uses the same exchange packet as the HUD/audit log.
- Character Points: `P` queues one CP for the next blaster attack. `O` queues one CP for soak if the next remote shot hits. CP dice explode on 6 and do not cause Wild Die mishaps on 1.
- Force Points: `G` queues one FP for the next action window. It doubles the trainee's attack, dodge, and soak pools for that window. CP cannot be queued in the same window.
- Armor: the trainee currently wears a light torso-only training blast vest from `data/prototype_combatants.json`, adding `0D+1` energy soak without a Dexterity penalty when the hit location is covered.
- Armor condition: hit-location-aware partial coverage can decide whether armor soak applies, and damaging hits that penetrate protected armor can reduce that armor's quality pips, so later soak rolls use the chipped protection value while WEG wound and damage bands remain unchanged. The character sheet now shows the vest coverage and live armor-quality pips.
- Damage: training blaster `4D` versus B1 silhouette soak `2D`.
- Scale target: the Bay 94 range includes a walker-scale armor plate. Character-scale shots are easier to land against it, but the target adds the adjusted scale modifier to soak.
- Return fire: active B1 remotes answer with Blaster `3D` and their own `3D+2` stun-blaster damage against trainee Strength `3D` plus armor; per live SW_MUSH stun-mode handling, severe stun damage caps at stunned/unconscious instead of lethal wounds.
- Reset: `R` clears aim, player cover, player wound state, and target wound state.
- Result: HUD line showing target, WEG-style action-window declaration summary, range, cover bonus, attack roll, total difficulty, margin, damage, soak, wound result, and remote response.

The prototype combat values live in `data/prototype_combatants.json` as a small stand-in for future curated SW_MUSH data imports.

The first curated location slice lives in `data/mos_eisley_spaceport_row.json`. It copies a compact, Godot-friendly subset of the live Clone Wars Mos Eisley map and Tatooine room data, with source paths back to SW_MUSH. The Godot scene reads this JSON for inspection names and descriptions instead of loading SW_MUSH directly.

The slice also supports first-pass location and range-target inspection with `E`. Inspectable markers summarize the CW Mos Eisley source cues for the nearby bay, shop, depot, customs office, and tower; range targets summarize their WEG combat profile, scale, armor, and live condition.

See `COMBAT_SOURCE_TRACE.md` for the live SW_MUSH combat code paths used to align the current range mechanics.

## Translation Notes

- This is intentionally not a one-to-one architectural model yet. It is a navigable gameplay compression of the map data.
- The era is 20 BBY Clone Wars. Republic/militia presence is light, Hutt influence is assumed, and old-era military references are invalid unless reauthored.
- The range uses B1 silhouettes as non-living training targets until the round/declaration combat state exists.
