# GPT Project Audit and Backend Feedback

Date: 2026-07-03  
Author: GPT/Codex read-only audit  
Scope: `SW_MMO_Prototype` plus read-only comparison against `C:\SW_MUSH`

## Purpose

This document captures strategic feedback for continued development of the standalone Clone Wars MMO prototype. It is intended for a developer, game designer, or future Codex/Claude agent picking up the work.

The main conclusions are:

- The project has evolved from a small prototype into a server-authoritative WEG D6 MMO systems lab.
- The backend/game-simulation layer is more advanced than the player-facing experience.
- The next phase should prioritize clarity, embodied gameplay, and playtest readiness over adding more systems.
- A canned MMO backend should be investigated, especially Nakama, but as surrounding infrastructure rather than an immediate replacement for the custom WEG gameplay server.

## Executive Summary

This project is no longer just "a Godot Star Wars prototype." It is now a custom rules-driven MMO foundation with a significant amount of WEG D6 logic already implemented: dice pools, Wild Die behavior, CP/FP spending, wound escalation, action-window combat, First Aid, downed/death states, equipment, vendors, quests, bounties, hostile NPCs, security zones, organizations, telemetry, and persistence.

That is both promising and risky.

The promising part is that the project has a real identity: a Clone Wars MMO where the MUSH and WEG books provide the rules/canon spine, but the MMO turns those rules into embodied tactical play.

The risky part is that the backend knows far more than the player can currently understand. A first-time player can easily miss the richness because the client does not yet make targets, danger, quests, progression, economy, wounds, and consequences obvious enough.

The highest-value next work is not more breadth. It is making the existing 30-minute loop legible, satisfying, and repeatable.

## Current Project Shape

The project currently contains two major gameplay branches:

1. `scenes/main.tscn`
   - The default scene in `project.godot`.
   - Functions as a solo tactical sandbox.
   - Contains the older/deeper 2.5D space bridge work.

2. `scenes/net_world.tscn`
   - The actual server-authoritative MMO slice.
   - Launched through explicit server/client commands.
   - Contains the meaningful online loop: movement, combat, progression, vendors, quests, chat, zones, death/downed, etc.

This split has caused real player confusion. Earlier playtest feedback described entering space while ground UI remained visible, mouse input still controlling the ground camera, and the space window feeling like an overlay rather than a true location transition. That feedback points to the same architectural truth: solo space and MMO ground are currently separate prototypes sharing conceptual space.

Recommendation: do not try to make space work in the MMO yet. Keep multiplayer space parked until the ground MMO is fun, understandable, and testable. When space returns, it should be a full mode transition with clear ownership of input, camera, HUD, scene state, and physical location.

## The Core Design Opportunity

The strongest version of this project is not a generic MMO, and it is not a one-to-one SW MUSH port.

The strongest version is:

> A Clone Wars-era, WEG D6-authentic, semi-tactical MMO where players inhabit a dangerous living frontier, make risky choices, suffer meaningful wounds, spend scarce heroic resources, join organizations, travel across security zones, and gradually uncover deeper faction/Force/war systems.

The special sauce is not voxel destruction, not raw scale, and not a giant feature checklist. It is the combination of:

- WEG dice uncertainty.
- Action-window tactics.
- Persistent wounds and recovery.
- CP/FP choice pressure.
- Security-zone danger gradient.
- Faction and organization stakes.
- MUSH-derived world texture.
- Clone Wars wartime instability.

The game should lean into being dangerous, readable, and systemic.

## Gameplay Strengths

The prototype already has a strong MMO spine:

- Spawn in Mos Eisley.
- Learn basic movement and interaction.
- Fight training targets or hostile NPCs.
- Earn credits and CP.
- Raise skills.
- Buy, equip, repair, and insure gear.
- Accept quests and bounties.
- Travel into more dangerous zones.
- Take wounds or go down.
- Recover, retreat, or die.
- Repeat with better knowledge and higher stakes.

This is the right core loop for a WEG-inspired MMO. It gives progression without requiring huge content volume.

The better the game gets at communicating that loop, the more the backend work will pay off.

## Gameplay Weaknesses and Friction

The major gameplay friction is not that systems are missing. It is that the player cannot yet reliably perceive what the systems are doing.

High-priority issues:

- The project launches into the solo scene by default, while the MMO requires special launch commands.
- The player-facing onboarding does not yet match the actual MMO path strongly enough.
- Target selection and targeting feedback are underdeveloped.
- Combat can feel server-chosen or abstract rather than spatial and intentional.
- Zone security, faction pressure, and danger bands need stronger visual language.
- Inventory, equipment, ammo, repair, insurance, and vendor loops need to become first-class UI.
- Wounds, downed state, recovery, and death need strong feedback because they are central to WEG identity.
- Many backend systems are live or partial but not discoverable by a normal player.

The game should answer four questions at all times:

1. Where am I?
2. What can I do here?
3. What am I working toward?
4. What changed because of my last action?

That principle also appears aligned with the SW MUSH documentation culture.

## SW MUSH Faithfulness

The MMO is faithful to SW MUSH in philosophy and increasingly faithful to WEG mechanics, but it is not and should not be a literal MUSH port.

Strong alignments:

- Clone Wars-only era posture.
- WEG D6 as the rules foundation.
- Dice pools, pips, Wild Die, CP, FP, wounds, armor, scale, and reactions.
- Security zones and lawfulness/danger gradients.
- Faction and organization concepts.
- Force rarity and gated progression.
- Creature, weapon, armor, quest, and world data influenced by the MUSH reference.
- Divergence tracking through `docs/DIVERGENCE_LEDGER.md`.
- One-way read-only use of `C:\SW_MUSH`.

Partial or missing areas compared to SW MUSH:

- Rich RP command surface.
- Social/admin/moderation tooling.
- Crafting depth.
- Player shops.
- Player cities.
- Espionage.
- Sabacc/entertainer-style social play.
- Mature spaceflight and ship ownership.
- Crew play.
- Plot/scenes infrastructure.
- Mail/channels/news depth.
- Tutorial chains.
- Full content breadth across Clone Wars worlds.

This is not a failure. These are scope boundaries.

Recommendation: keep SW MUSH as the canon/rules/content source of truth, but let the MMO be the embodied tactical layer. Track divergences explicitly. Do not chase one-to-one parity.

## WEG D6 Faithfulness

The project appears unusually committed to WEG D6, and that is one of its best qualities.

Important preserved concepts:

- Dice pool parsing.
- Pips.
- Wild Die behavior.
- Character Points.
- Force Points.
- Multi-action/action-window thinking.
- Dodge/full dodge.
- Cover.
- Armor soak/degradation.
- Wound ladder.
- Wound penalties.
- First Aid and recovery.
- Scale.
- Weapon ranges.
- Lethality tiers.

This should remain a design pillar. The MMO does not need to expose every die roll as tabletop UI, but it should let players feel the consequences:

- Spending CP should feel costly and heroic.
- Spending FP should feel rare and dramatic.
- Wounds should change behavior.
- Armor damage should create maintenance pressure.
- Dangerous zones should create real fear.

## Implementation Assessment

The pure model layer is the project's strongest engineering asset. It creates testable rules separate from presentation.

Examples of strong areas:

- `scripts/d6_rules.gd`
- `scripts/ground_combat_model.gd`
- `scripts/wound_ladder_model.gd`
- `scripts/action_window_model.gd`
- `scripts/combat_arena.gd`

These files represent the heart of the game and should be protected from UI/network churn.

The main engineering risk is concentration of responsibility in `scripts/network_manager.gd`.

That file currently acts as:

- network server
- RPC registry
- snapshot builder
- persistence coordinator
- combat coordinator
- vendor/economy coordinator
- quest coordinator
- death/downed coordinator
- PvP coordinator
- Force awakening coordinator
- telemetry bridge
- zone state coordinator

That is acceptable for prototype velocity, but not for beta.

Recommendation: gradually extract service-style modules while preserving behavior. Do not do a giant rewrite. Pull one bounded responsibility at a time behind tests.

Good candidates for extraction:

- session/account adapter
- persistence adapter
- chat/presence service
- vendor/economy service
- quest service
- combat service facade
- death/downed service
- telemetry service
- zone/shard registry

## Positional Truth Risk

The biggest gameplay/engineering mismatch is positional truth.

The game has positions and movement, but much of the combat sophistication still comes from staged WEG-style rules. That is fine, but the MMO must make range, cover, line of sight, facing, elevation, threat, and target intent feel real.

For beta, combat should not feel like "press fire and the server picks a target." It should feel like:

- I selected that target.
- I understand why I can or cannot hit.
- I understand what cover is helping me.
- I understand why the enemy hit me.
- I understand when I should dodge, retreat, heal, or spend CP/FP.

Recommendation: prioritize targeting, range bands, cover truth, and combat feedback before adding new combat subsystems.

## Backend Question

The question was:

> Should we be using a canned MMO networking backend? Does such a thing exist? Free is key. Or like $20. If there is a "Godot for the backend," does it make sense to develop it ourselves?

Short answer:

There is no free "Godot for MMO backends" that gives this project a finished open-world MMO server. However, there are open-source game backend frameworks that can replace a lot of boring infrastructure.

The right question is not:

> Custom backend or canned backend?

The right question is:

> Which layers are game-specific, and which layers are commodity infrastructure?

## Backend Options

### Nakama

Nakama is the closest fit to "free/open-source game backend." It supports Godot and includes accounts, sessions, storage, social features, realtime multiplayer, matchmaking, chat, groups, leaderboards, and server-authoritative matches.

Why it is attractive:

- Open-source and self-hostable.
- Official Godot client support.
- Designed for game backends rather than generic web apps.
- Handles many commodity MMO services.
- Server runtime can be extended with Go, TypeScript, or Lua.
- Supports both server-authoritative and server-relayed multiplayer.

Why it should not be adopted blindly:

- It will not understand WEG D6, wounds, CP/FP, Clone Wars zones, or MUSH data.
- Authoritative match logic still has to be written.
- Migration could distract from playtest readiness.
- Scaling/open-source/commercial boundaries should be understood before committing.

Recommended use:

Use Nakama as an identity/meta/persistence/social backend around the current Godot gameplay server, not as an immediate replacement for the WEG simulation.

### Colyseus

Colyseus is an open-source Node/TypeScript authoritative multiplayer framework with matchmaking and automatic state sync.

Why it is attractive:

- MIT licensed.
- TypeScript server logic.
- Good for room-based authoritative games.
- Built-in matchmaking and state synchronization.
- Godot support now exists.

Risks:

- Godot support is marked beta/experimental in current docs.
- A TypeScript server would mean porting or bridging the existing GDScript WEG models.
- Better fit for room/session games than a custom persistent WEG MMO unless carefully architected.

Recommended use:

Worth watching, but less immediately compelling than Nakama for this project unless the team strongly prefers TypeScript and room-based state sync.

### Godot Dedicated Server + ENet

This is closest to what the project already uses.

Why it is attractive:

- Keeps gameplay code in Godot/GDScript.
- Preserves current rules implementation.
- Simple local development.
- No vendor lock-in.
- Good for early authoritative prototype work.

Risks:

- Does not provide accounts, moderation, chat ops, persistence DB, shard discovery, admin tooling, or deployment orchestration.
- Custom infrastructure burden grows over time.
- `network_manager.gd` can become an unmaintainable monolith.

Recommended use:

Keep it for authoritative zone simulation in the near term.

### Agones

Agones is an open-source platform for orchestrating dedicated game servers on Kubernetes.

Why it is attractive:

- Useful for scaling fleets of dedicated servers.
- Engine-agnostic.
- Open-source.

Risks:

- Not a gameplay backend.
- Requires Kubernetes/devops complexity.
- Too heavy for the current phase.

Recommended use:

Do not use now. Revisit when the game needs automated server fleet orchestration.

### Photon Fusion

Photon Fusion is polished and has a free tier, but it is not the best philosophical fit for this project right now.

Why it is attractive:

- Mature hosted multiplayer product.
- Free tier can support early experiments.
- Less ops burden.

Risks:

- Vendor lock-in.
- Cost can grow.
- Less ownership.
- Not naturally aligned with a custom fan MMO stack.
- More attractive for match/session action multiplayer than a deeply custom WEG persistent world.

Recommended use:

Do not adopt unless the project pivots away from ownable custom MMO infrastructure.

## Recommended Backend Architecture

The recommended architecture is a hybrid:

```text
Godot Client
  |
  | login / account / chat / presence / character metadata
  v
Nakama or equivalent backend
  |
  | session validation / shard discovery / durable records
  v
Godot Authoritative Zone Server
  |
  | WEG D6 simulation / movement / combat / NPCs / quests / vendors
  v
Persistent game state
```

The Godot server remains the authority for moment-to-moment gameplay.

Nakama, if adopted, handles the boring and risky infrastructure:

- account creation
- login/session tokens
- character records
- chat channels
- presence
- groups/org metadata
- storage
- friend/social systems
- shard discovery
- basic telemetry hooks
- admin/moderation hooks

The custom Godot server keeps:

- WEG D6 rules
- movement
- targeting
- action windows
- combat
- wounds
- NPC AI
- zones
- vendors
- quests
- bounties
- death/downed behavior
- MUSH-specific translation logic

## Backend Recommendation To Include In Planning

Use this wording directly if helpful:

```text
Investigate Nakama as a surrounding platform, not as an immediate replacement for the Godot authoritative server.

The current prototype already has a custom WEG D6 combat engine, zone logic, persistence model, quests, vendors, death/downed handling, PvP consent, org systems, and telemetry. Replacing that wholesale with Nakama or Colyseus would mean reimplementing a large amount of game-specific logic.

The more practical path is:
1. Keep Godot as the authoritative zone/gameplay server for now.
2. Use Nakama or a similar backend for accounts, sessions, character records, chat, presence, groups/org metadata, storage, and possibly matchmaking/shard discovery.
3. Let the Godot zone server validate player sessions with Nakama and report durable state back to it.
4. Revisit full migration only after a thin integration spike proves value.

Do not adopt a backend merely because it exists. Adopt it only where it removes boring, risky, non-game-specific code.
```

## Proposed Nakama Spike

Timebox this spike. It should not derail playtest readiness.

Goal:

Prove whether Nakama improves the project without forcing a rewrite.

Spike requirements:

1. Godot client logs into Nakama.
2. Nakama returns a session token.
3. A minimal character record is stored in Nakama.
4. Client receives an active Godot zone server address.
5. Client connects to the existing Godot MMO server.
6. Godot server validates the Nakama session.
7. Godot server loads basic character state.
8. On logout, death, or zone transfer, Godot writes durable state back.
9. Local development remains easy.
10. Existing tests and prototype flow are not broken.

Success criteria:

- Less custom auth/session code.
- Cleaner persistence boundary.
- Better future path for chat/presence/groups.
- No meaningful harm to local iteration speed.

Failure criteria:

- Integration requires invasive rewrite.
- WEG rules need to be ported prematurely.
- Local testing becomes painful.
- The team spends more time fighting backend tooling than improving gameplay.

## What Not To Outsource

Do not outsource the soul of the game.

Keep these custom:

- WEG D6 resolution.
- CP/FP logic.
- wound ladder.
- death/downed tiers.
- Clone Wars zone simulation.
- faction/security logic.
- MUSH-derived content interpretation.
- target/range/cover logic.
- NPC/director behavior.
- economy tuning.
- quest semantics.

A backend can store and route things. It should not define what a blaster shot means.

## What To Stop Hand-Rolling Eventually

These are commodity enough that a mature backend should be considered:

- password handling
- account/session security
- character list
- long-term storage
- chat channels
- presence
- friend/group systems
- org metadata
- bans/moderation records
- server browser/shard discovery
- logs/analytics ingestion
- admin dashboards

Every custom line here is a line not spent on making WEG combat fun.

## Playtest Readiness Feedback

The project appears close to a controlled private playtest, but not a public beta.

Before PT1, prioritize:

1. Clear launch path into MMO mode.
2. Onboarding overlay for the actual MMO loop.
3. Target selection and target feedback.
4. Combat result feedback.
5. Visible health/wound/downed/death state.
6. Inventory/equipment/vendor/repair UX.
7. Quest board or quest tracker.
8. Zone-entry danger/security/faction banners.
9. Minimap or spatial orientation aid.
10. Basic GM/admin observation tools.

Do not let backend investigation block PT1 unless current auth/persistence makes PT1 impossible.

## Suggested Development Trajectory

### Immediate

Make the current MMO slice understandable.

Priority:

- launcher/default scene clarity
- onboarding
- targeting
- visible combat consequences
- vendor/equipment/repair loop
- quest readability
- zone danger cues

### Short Term

Run a human playtest and collect friction.

Measure:

- time to first quest
- time to first combat
- time to first wound
- time to first death/downed state
- time to understand CP/FP
- time to buy/equip/repair
- percentage of players who know where to go next
- disconnect/crash rates
- common stuck points

### Medium Term

Stabilize architecture.

Work:

- split `network_manager.gd`
- introduce backend adapter boundary
- consider Nakama spike
- improve persistence format
- add admin/mod tools
- add telemetry dashboards
- deepen content only after the loop is clear

### Longer Term

Expand toward true MMO breadth.

Possible later systems:

- crafting
- player shops
- richer organizations
- player cities
- espionage
- space
- crew play
- broader Clone Wars worlds
- live events
- MUSH-to-MMO content pipeline

## Beta Trajectory

Current state is closer to controlled playtest than beta.

Rough estimate:

- Private PT1/friends test: days to 1-2 weeks if UI/onboarding blockers are handled.
- Closed alpha with a coherent repeatable loop: 4-8 focused weeks.
- Public beta: likely 6-12+ months, depending on art, content, ops, security, moderation, and expected scale.

The fastest path to beta is not adding all planned systems. It is proving one slice:

> Mos Eisley starter loop -> danger-zone travel -> WEG combat -> wounds/death/recovery -> economy maintenance -> faction/quest motivation -> return with a story.

## Concrete Backlog Recommendations

Recommended high-priority backlog:

1. Add launcher scene or make MMO path explicit from boot.
2. Make solo sandbox and MMO mode visually/structurally distinct.
3. Keep space out of MMO mode until it owns input/camera/HUD fully.
4. Add targeting reticle and target cycling/selection.
5. Add combat log summaries that explain WEG outcomes in player language.
6. Add clear wound state UI.
7. Add clear downed/death overlay.
8. Add quest tracker and "nearest available opportunity" hinting.
9. Add equipment/inventory panel.
10. Add vendor affordances for buy/sell/repair/ammo.
11. Add zone-entry security/danger banners.
12. Add minimap or compass.
13. Add telemetry events for combat, death, repair, travel, quest completion, and player confusion points.
14. Extract persistence boundary from `network_manager.gd`.
15. Extract chat/presence boundary from `network_manager.gd`.
16. Spike Nakama for auth/session/storage/shard discovery.
17. Add a MUSH content sync review checklist.
18. Keep `DIVERGENCE_LEDGER.md` mandatory.
19. Add human playtest script and survey.
20. Avoid major new systems until PT1 has been observed.

## Designer Notes

The game should not feel like "a UI over dice." It should feel like a dangerous world whose rules happen to be WEG.

Design language to emphasize:

- Danger is local and readable.
- Heroism is scarce and expensive.
- Wounds matter.
- Equipment maintenance matters.
- Retreat is valid.
- Lawless zones are scary.
- Factions change opportunity.
- The Clone Wars are present even when Jedi are rare.
- A normal blaster fight can create a story.

Do not over-explain tabletop mechanics in the main HUD. Instead, surface them when they matter:

- "You spent 2 CP to turn a miss into a hit."
- "Your armor absorbed the shot, but its plating degraded."
- "You are Wounded: -1D until treated."
- "Full dodge protected you, but you gave up your attack."
- "This zone is lawless. PvE death can be permanent."

## Developer Notes

Protect the pure models.

The pure rules modules are the project's foundation. They make it possible to test WEG behavior without a running client. New systems should follow that pattern:

- pure model first
- tests second
- server integration third
- UI feedback fourth

Do not bury new rules directly in networking code.

When adding features, prefer this shape:

```text
data file -> pure model -> server coordinator -> snapshot/RPC -> UI
```

This keeps the project understandable to both Codex and human developers.

## Final Recommendation

Continue the current project, but tighten its identity:

- Godot remains the client and immediate authoritative zone server.
- WEG D6 remains the rules soul.
- SW MUSH remains the read-only canon/design/content reference.
- Nakama should be investigated as commodity backend infrastructure.
- Space remains parked until the ground MMO is fun.
- The next milestone is a clear, human-playtestable Mos Eisley MMO slice.

The project has enough systems to start becoming a game. The next work is to make players feel those systems without needing to read the code.

## External Backend References Checked

- Nakama: https://heroiclabs.com/nakama/
- Nakama Godot client docs: https://heroiclabs.com/docs/nakama/client-libraries/godot/
- Nakama authoritative multiplayer docs: https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/
- Colyseus: https://colyseus.io/
- Colyseus Godot docs: https://docs.colyseus.io/getting-started/godot
- Godot high-level multiplayer docs: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- Agones: https://agones.dev/
- Photon Fusion pricing: https://www.photonengine.com/fusion/pricing
