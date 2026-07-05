# Two-Week SW_MUSH / SWG / WEG D6 Roadmap

## Purpose

This document captures Codex's assessment-driven roadmap for the current
SW_MMO_Prototype after the Antigravity handoff. The goal is not to broaden the
prototype indefinitely, but to harden one playable MMO spine:

> A friend can create a WEG D6 character, spawn in a Mos Eisley-style hub, talk
> to NPCs, accept a mission, buy gear, travel to a danger area, fight, loot or
> harvest, return for rewards, spend Character Points, reconnect, and see the
> state persist.

The target flavor is:

- SW_MUSH as content memory, social density, room flavor, factions, and weird
  local detail.
- Star Wars Galaxies as the MMO loop model: professions, surveys, vendors,
  player identity, mission terminals, travel, and creature/NPC economy.
- WEG D6 as the mechanical truth: attributes, skills, dice pools, wounds,
  Character Points, Force Points, multiple-action pressure, armor/soak, and
  lethal consequences softened only where an MMO needs it.

## Current Assessment

Antigravity's current direction is strong. The project now has the outline of a
real online RPG instead of only a tech demo. The server-authoritative slice,
character generation, WEG action-window combat, wounds, inventory/economy,
quests, vendors, harvesting, persistence, factions, territory, chat, HUD, and
telemetry are all meaningful foundations.

The recent presentation work is especially important. Unified HUD, dialogue and
trade overlay, target highlighting, quest/shop panels, muzzle/tracer/damage
feedback, and the isometric space overlay make the game much more legible. The
space view is finally close to the original "flat x/y space with an isometric
presentation" target.

The visual pipeline should now default to deterministic voxel/pixel-generated
assets, with Blockbench/manual cleanup for hero assets. Meshy is not the default
foreground asset source for a strict voxel game. It remains useful for
background plates, space ambience, visual effects reference, posterized
backdrops, and high-entropy concept inspiration.

## Main Risks

1. The playable MMO spine can get buried under breadth.
2. `net_world.gd` has accumulated too many responsibilities.
3. Some UI/demo flows still read or write prototype JSON directly instead of
   going through server-authoritative state.
4. Generated assets are partly referenced from docs folders; curated runtime
   assets need proper manifests and stable runtime paths.
5. Voxel scale, palette, lighting, collision, sockets, and asset provenance need
   to become formal acceptance criteria.
6. Space is promising, but ground MMO play should remain the priority until the
   first friend-tested loop is fun.

## Two-Week Target

By the end of this roadmap, the project should support a small but convincing
multiplayer vertical slice:

- Character creation using the WEG D6 attribute/skill foundation.
- Mos Eisley-style hub with at least one dense social interior.
- One mission board or NPC mission giver.
- One vendor/equipment loop.
- One creature/NPC combat loop.
- One harvest/loot/sell loop.
- Wound/recovery/medical consequence.
- Character Point reward/spend loop.
- Two-client multiplayer smoke test.
- Persistent reconnect test.
- Visual pass using curated voxel assets for the most visible pieces.

## Days 1-2: Freeze Baseline And Harden Authority

Create a named baseline for Antigravity's current state.

Deliverables:

- Capture screenshots and short videos of the current hub, HUD, dialogue,
  combat, space overlay, and generated voxel assets.
- Record a passing full project check.
- Identify which features are production foundation versus demo scaffolding.
- Create a short "known seams" list for server authority, persistence, assets,
  UI, and generated content.

Implementation focus:

- Move dialogue/shop/inventory/credit mutations out of direct prototype JSON
  writes and behind server-authoritative calls.
- Keep the current UI behavior, but make the client a view over server state.
- Begin splitting overloaded world orchestration into smaller controllers:
  HUD, dialogue/shop, targeting, combat feedback, quests, world interaction,
  and net-state display.

Acceptance:

- Existing checks still pass.
- A vendor transaction is represented by server state, not a local UI-only file
  mutation.
- The code clearly marks any remaining prototype-only local data writes.

## Days 3-4: SW_MUSH-Inspired Playable Hub

Choose one hub slice and make it feel intentional.

Recommended hub:

- Mos Eisley / Cantina / Bay 94 / Jundland edge.

Content translation rules:

- SW_MUSH descriptions drive affordances, mood, factions, NPC roles, exits,
  hazards, and social density.
- Do not preserve one-room-to-one-room topology unless it improves play.
- Convert text-room affordances into MMO sockets: sit, stand, vendor, mission,
  inspect, exit, cover, spawn, harvest, and travel.

Deliverables:

- One connected hub area.
- One social interior with named sockets.
- One travel edge to a danger/outskirts area.
- One vendor or shopkeeper.
- One mission giver or mission board.
- One inspectable lore/world-detail chain.

Acceptance:

- A new player can orient visually without reading docs.
- The hub feels like a place, not a debug room.
- At least five SW_MUSH-inspired details are translated into playable or
  inspectable affordances.

## Days 5-6: SWG-Style Starter Loop

Build the first "live in the world" loop.

Core loop:

1. Get a mission.
2. Buy or equip starter gear.
3. Travel to the edge zone.
4. Fight or interact with a target.
5. Loot or harvest.
6. Return to sell/complete.
7. Gain Character Points or faction/economy progress.

Starter roles should be skill-forward, not class-locked:

- Marksman: safer combat, blaster competence.
- Scout: tracking, harvesting, outdoor survival.
- Medic: wound treatment, recovery utility.
- Mechanic/artisan: repair, devices, droid/terminal hooks.
- Social/smuggler-leaning role: negotiation, contacts, contraband hooks.

Deliverables:

- Mission terminal or NPC job board.
- At least three starter mission templates.
- Creature/NPC hunting contract.
- Harvestable resource node.
- Vendor sell/buy loop.
- Character Point reward and spend loop.

Acceptance:

- A player has a reason to leave town and return.
- Non-combat value exists, even if simple.
- The loop feels closer to SWG than to a linear action game.

## Days 7-8: WEG D6 Combat Readability

The mechanics need to be visible to the player.

Improve UI/feedback for:

- Attribute/skill dice pools.
- Action windows.
- Multiple-action penalties.
- Dodge, parry, cover, and range pressure.
- Armor soak.
- Wound states.
- Downed state.
- First Aid / medpac recovery.
- Character Points and Force Points.

Encounter ladder:

- Training target.
- Weak creature or droid.
- Armored target.
- Dangerous target that teaches retreat/recovery.
- Small group encounter.

Deliverables:

- Combat feedback panel or log that explains the WEG result in readable terms.
- Visible wound state changes.
- Medical/recovery interaction.
- At least one cover-aware combat space.

Acceptance:

- The player can understand why an attack hit, missed, soaked, wounded, or
  escalated.
- The D6 table logic is felt without forcing the player to read a rulebook.

## Days 9-10: Runtime Visual Cohesion

Promote the best generated voxel assets into runtime-ready curated assets.

Asset lanes:

- Deterministic pixel/voxel: default for props, rooms, terrain, ships, vehicles,
  low-detail actors, droids, and equipment.
- Blockbench/manual cleanup: hero characters, hero props, animation-ready
  actors, and polish passes.
- Meshy: background plates, space ambience, visual effects reference, skybox or
  posterized scene inspiration.

Curated first-pass assets:

- Player archetype.
- B1/droid enemy.
- Guard/trooper NPC.
- Vendor NPC.
- Mission terminal.
- Blaster.
- Medpac.
- Cantina table/chair/bar props.
- One small ship or vehicle token.
- One creature silhouette.

Acceptance checklist for runtime assets:

- Grid-aligned voxel or intentionally marked non-voxel.
- Stable scale.
- Known palette/material family.
- Screenshot proof.
- Godot import proof.
- Collision or interaction proxy.
- Socket metadata if interactable.
- Provenance note.

## Days 11-12: Multiplayer And Social Proof

Run the slice with multiple clients and harden the social layer.

Deliverables:

- Two-client local test script/checklist.
- Nearby chat.
- Basic channels or clear channel plan.
- `/who` or player list.
- Group/party stub or explicit deferral.
- Faction visibility.
- Org/territory status display if already wired.
- Persistent reconnect smoke test.

Acceptance:

- Two players can take part in the same local world without state divergence.
- Combat, rewards, credits, inventory, and wounds remain authoritative.
- Reconnect preserves meaningful state.

## Days 13-14: Friend-Test Vertical Slice

Turn the work into a 30-minute playtest path.

Required path:

1. Create character.
2. Spawn in hub.
3. Talk to NPC.
4. Buy or equip gear.
5. Accept mission.
6. Travel to edge zone.
7. Fight target.
8. Take or heal a wound.
9. Loot or harvest.
10. Return to hub.
11. Sell or complete mission.
12. Spend Character Points.
13. Reconnect and confirm persistence.

Deliverables:

- Playtest script.
- Known issues ranked by severity.
- Updated docs/handoff.
- Fresh screenshots.
- Passing full project check.

Acceptance:

- A non-developer friend can complete the loop with minimal coaching.
- The experience feels like WEG D6 under an SWG-inspired MMO wrapper.
- The next bottleneck is clear.

## Explicit Non-Goals For This Sprint

These should not be prioritized until the core loop is friend-testable:

- Full Jedi/Force progression.
- Full space multiplayer.
- Player cities.
- Deep crafting factories.
- Complete SW_MUSH room parity.
- Large planet count.
- Large enemy catalog.
- Polishing every generated asset.
- Meshy foreground asset replacement.

## Definition Of Success

This roadmap succeeds if the project stops feeling like many impressive
subsystems and starts feeling like one small online world.

The right first milestone is not "all of SW_MUSH in 3D." It is:

> One playable SW_MUSH-inspired corner of the galaxy, with SWG-style reasons to
> live there and WEG D6 consequences under every meaningful action.

