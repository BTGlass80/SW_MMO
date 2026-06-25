# Next Decisions

Resolved:

- First settlement: Mos Eisley.
- Era: Clone Wars only.
- First WEG interaction loop: blaster range and cover.

## 1. First Mos Eisley Sub-Area

The current scaffold is a compressed visual stand-in. Next, choose which Mos Eisley sub-area to model from the Clone Wars data first:

- Spaceport Row / Docking Bay 94.
- Market District / Kayson's Weapon Shop.
- Outskirts Checkpoint / Jundland edge.

Recommendation: Spaceport Row plus Docking Bay 94 because it naturally connects ships, customs, vendors, cover, and starter movement.

## 2. First Combat Target Type

The prototype currently uses non-living B1-style training targets for the blaster loop.

Recommendation: keep the first iteration as training targets, then add live B1/CIS or criminal NPCs only after the round/declaration/combat-state model exists.

## 3. Data Import Policy

Decide when curated SW_MUSH data can be copied into this standalone project:

- Manual snapshots only.
- Scripted import from read-only source paths.
- No import yet; re-author minimal test data.

Recommendation: scripted import that reads Clone Wars data from `C:\SW_MUSH` and writes snapshots into this project, never the reverse.
