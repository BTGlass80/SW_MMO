# Phased Development Plan

## Phase 0: Reference Baseline

Goal: make the Clone Wars-only project safe to evolve while SW_MUSH continues separately.

- Keep `C:\SW_MUSH` read-only.
- Maintain a source manifest for WEG and SW_MUSH references.
- Build a divergence ledger before changing any WEG-derived mechanic.
- Decide which Clone Wars SW_MUSH YAML/data can be copied into this project as curated snapshots.

## Phase 1: Playable Ground Slice

Goal: walk around a recognizable settlement and exercise WEG checks in-world.

- 3D blocky settlement scene.
- Player movement, camera, collision, jump.
- Interaction prompts for doors, vendors, NPCs, terminals, ships, and combat targets.
- D6 dice singleton with Wild Die.
- Basic character sheet resource: attributes, skills, CP, FP, wound state.
- First translated loop: blaster range and cover in Mos Eisley.

## Phase 2: Rules Core

Goal: extract the rules from UI so multiplayer and tests can trust them.

- Authoritative rules service in GDScript initially.
- Unit tests for dice pools, Wild Die, difficulty checks, advancement cost, wound penalties, multi-action penalties.
- Data-driven skills/species/weapons/starships copied from curated Clone Wars SW_MUSH snapshots.
- WEG/SW_MUSH divergence ledger maintained as docs plus machine-readable entries.

## Phase 3: 2.5D Space Slice

Goal: flat movement plane with 3D ships/camera and WEG space mechanics.

- Space scene with zone map and tactical plane.
- Ship controller with speed, heading, range bands, and target locks.
- Crew station model: pilot, copilot, gunner, engineer, navigator, commander, sensors.
- Astrogation and hyperspace transitions.
- Gunnery, shields, hull, and system damage.

## Phase 4: Server-Authoritative Multiplayer

Goal: build toward a larger community without overbuying infrastructure early.

- Dedicated headless Godot server for simulation.
- Client prediction only for movement/camera; rules resolved server-side.
- Accounts, characters, persistence, shard/zone boundaries.
- PostgreSQL for durable state when SQLite stops being enough.
- Observability from day one: structured logs, admin audit log, metrics.

## Phase 5: MMO Systems

Goal: port the gameplay breadth of SW_MUSH into visual form.

- Economy, trading, smuggling, bounty board.
- Crafting with resources, schematics, experimentation, durability.
- Factions, guilds, rank, reputation, payroll.
- Missions, quests, scenes/plots, mail/channels/news.
- Territory, player cities, housing, shops.
- Force systems with strict WEG and era handling.

## Phase 6: Tools And Operations

Goal: support builders/admins without text-MUSH assumptions.

- Admin web panel or Godot tool scenes.
- Live spawn/event controls.
- Player support tools.
- Content validation.
- Data migration/import tooling from curated SW_MUSH snapshots.
