# Next Decisions

> **ARCHIVED (2026-06-25).** This is an early-prototype artifact; all three questions
> below are long-resolved and the project has moved well past them. Kept for history
> only â€” it is NOT a live decision queue. The current queue is
> `docs/UNATTENDED_BACKLOG.md` (Wave E); open owner-gated forks live in
> `docs/SESSION_HANDOFF.md` Â§5.
>
> **Resolutions:** (1) First sub-area â†’ Spaceport Row / Docking Bay 94 (built; the
> shared `world_builder.gd` Mos Eisley). (2) First combat target â†’ training targets
> first, then live targets (the combat arena + action-window model shipped). (3) Data
> import policy â†’ scripted one-way extraction from read-only `C:\SW_MUSH` into `data/`
> (the established pipeline; the `mush-content-porter` agent).

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
