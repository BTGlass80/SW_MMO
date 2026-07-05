# Star Wars Galaxies WEG D6 Alpha Roadmap

Designer: Codex  
Implementer: Antigravity  
Project: SW_MMO_Prototype  
Pivot target: Star Wars Galaxies-inspired MMO with WEG Star Wars D6 mechanics  
Status: Design roadmap for a playable alpha, not a feature slice  

## 1. Executive Summary

This roadmap assumes a deliberate product pivot:

The project is no longer primarily "SW_MUSH in Godot." Instead, it becomes a
Star Wars Galaxies-inspired sandbox MMO prototype using WEG Star Wars D6 as the
rules engine and using SW_MUSH as reference material for mechanics, data,
faction logic, social texture, D6 edge cases, and Clone Wars-era flavor.

The alpha should not be a vertical slice of one feature. It should be a compact
but complete playable game loop:

1. Create a character using WEG D6 attributes, species, skills, and starting
   profession packages.
2. Spawn into a hub city.
3. Learn the world through in-fiction NPCs, terminals, chat, vendors, and
   inspectable places.
4. Take missions from terminals and NPCs.
5. Buy, equip, repair, and consume gear.
6. Travel on foot, by vehicle/shuttle, and eventually ground-to-space.
7. Survey and harvest resources.
8. Craft usable items from variable-quality resources.
9. Sell to NPCs, player vendors, or a bazaar.
10. Fight creatures, droids, NPCs, and optionally players under WEG D6 rules.
11. Suffer and recover from wounds.
12. Gain Character Points, train skills, and grow horizontally.
13. Own at least one small persistent world object: camp, harvester, vendor,
    ship, or homestead-lite structure.
14. Launch to local space, fly on a 2.5D isometric tactical plane, complete a
    space mission, take ship damage, repair, dock, and return to ground.
15. Reconnect and find the character, inventory, credits, missions, wounds,
    vendors, placed objects, and ship state persisted.

The alpha is system-complete, not content-complete. Every major pillar should
exist in a bounded form. The content footprint can be small.

Recommended alpha footprint:

- One primary planet: Tatooine-style desert frontier.
- One primary city: Mos Eisley-inspired hub.
- One wilderness region outside the city.
- One lawless high-risk region.
- One orbit/approach space zone.
- One asteroid or salvage field.
- One off-world destination or orbital station for travel proof.
- Three to five starter profession packages.
- One player ship class.
- One starter vehicle or mount.
- One resource cycle.
- One crafting chain per profession family.
- One mission terminal set.
- One NPC story/tutorial chain.
- One functioning player economy loop.

This is still ambitious. At the current pace, this is likely multiple weeks of
focused implementation, not a weekend. The project already has enough working
foundation that this is plausible if the team stops adding disconnected
features and instead hardens a complete alpha loop.

## 2. Product Reframe

### 2.1 What The Pivot Means

Old framing:

- SW_MUSH is the product target.
- Godot is the visual/client modernization layer.
- Room descriptions, text commands, MUSH systems, and Clone Wars MUSH content
  are translated into a 3D/2.5D online game.

New framing:

- Star Wars Galaxies is the product model.
- WEG D6 is the mechanical source of truth.
- SW_MUSH is a reference implementation and content archive, not the structure
  of the new game.

This matters because SW_MUSH and SWG produce different design gravity.

SW_MUSH gravity:

- Rooms.
- Commands.
- Staff-mediated scenes.
- Text descriptions.
- Slow social progression.
- Roleplay adjudication.
- MUSH-specific economy and consent assumptions.

SWG gravity:

- World traversal.
- Professions.
- Mission terminals.
- Harvesting.
- Crafting.
- Vendors.
- Player economy.
- Creature hunting.
- Camps and travel.
- Player-owned objects.
- Factional and social identity.
- Ground-to-space continuity.

The alpha should follow SWG gravity while keeping the D6 soul.

### 2.2 What To Keep From SW_MUSH

Keep:

- WEG D6 mechanics references.
- Species, attributes, skills, wound logic, armor, weapons, combat edge cases.
- Clone Wars-era faction ideas and local world flavor.
- Room descriptions as source prompts for locations and props.
- NPC names, roles, job types, and social setups when useful.
- Org/faction/security/territory ideas.
- Economy and vendor lessons.
- Space data, ship roles, and D6 starship handling.
- MUSH discipline around documenting divergences.

Do not keep as product constraints:

- Room-for-room parity.
- Text command parity.
- Staff-dependency as core gameplay.
- Purely narrative travel.
- Text UI as primary interaction model.
- MUSH pacing where it conflicts with an approachable alpha.

### 2.3 What To Keep From The Current Prototype

Strong foundations to preserve:

- Godot 4.6.x project.
- Server-authoritative architecture.
- Existing WEG D6 rules models.
- Character generation with species and skill catalog.
- Wound ladder, First Aid, recovery, death/downed logic.
- Vendors, credits, armor repair, ammo, loot, harvesting models.
- Multi-zone persistence.
- Faction and territory groundwork.
- Space tactical model: sensors, comms, gunnery, shields, damage control,
  astrogation, crew-station assists.
- JSONL telemetry and smoke-test discipline.
- Pixel/voxel deterministic asset pipeline.
- Divergence ledger practice.

Items to harden or retire:

- Any UI flow that edits prototype JSON directly.
- Runtime references to docs-generated assets instead of curated runtime assets.
- Giant orchestration files that now contain UI, gameplay, networking, and
  presentation responsibilities together.
- Solo-only systems that need multiplayer authority before alpha.
- Space as a detached sandbox rather than a travel/combat layer connected to the
  ground economy.

## 3. Alpha Design Pillars

### 3.1 WEG D6 Under The Hood

Players should not need to read the WEG rulebook, but every important outcome
should feel like it came from D6:

- Attributes and skills create dice pools.
- Wounds are states, not HP bars.
- Armor soaks instead of simply adding hit points.
- Multiple actions create pressure.
- Dodging, cover, aiming, range, and wound penalties matter.
- Character Points are both advancement and emergency luck.
- Force Points are rare, powerful, and narratively serious.
- Technical, Mechanical, Knowledge, Perception, Dexterity, and Strength all
  matter outside combat.

### 3.2 SWG-Inspired Sandbox Loops

The alpha should be built around recurring loops:

- Mission loop: terminal/NPC -> travel -> objective -> reward.
- Combat loop: scout target -> engage -> wound/loot -> recover.
- Harvest loop: survey -> harvest -> transport -> sell/craft.
- Craft loop: schematic -> components -> experimentation -> item quality.
- Economy loop: gather/craft/loot -> vendor/bazaar -> credits -> upkeep/sinks.
- Social loop: cantina/med center/group -> buffs/recovery/info -> activity.
- Travel loop: city -> wilderness -> shuttle/starport -> orbit -> destination.
- Space loop: launch -> scan -> engage/avoid -> repair/salvage -> dock.

### 3.3 Voxel Clarity, Not Visual Realism

The alpha should remain visually coherent:

- Deterministic voxel/pixel assets are the default for foreground gameplay.
- Blockbench/manual cleanup is used for hero assets and animation-ready models.
- Meshy is reserve-only for background plates, sky/space ambience, VFX concept,
  or non-foreground reference.
- Every runtime asset must have a stable scale, palette, collision proxy, socket
  metadata if interactable, and provenance note.

### 3.4 Compact Galaxy, Complete Loop

The alpha world should be small but complete. A player should feel like the
world has all the major Star Wars Galaxies categories even if each category is
thin.

Prefer:

- One city that works.
- One wilderness that works.
- One orbit that works.
- One crafting chain that works.
- One player vendor loop that works.
- One ship that works.

Avoid:

- Ten half-empty planets.
- Many disconnected demos.
- Full SW_MUSH import.
- Full space MMO before ground authority is solid.

## 4. Alpha World Topology

### 4.1 Required Zones

Alpha should ship with these authoritative zones:

1. Hub city.
2. City interior/social zone.
3. City fringe.
4. Wilderness.
5. Lawless resource/combat region.
6. Starport/hangar transition.
7. Local orbit.
8. Asteroid/salvage field.
9. Secondary destination: orbital station, small outpost, or second city pad.

Suggested names can be Star Wars-flavored for private play, but implementation
should keep data-driven keys generic enough to refactor later.

### 4.2 Hub City

The city is the alpha's center of gravity.

Required services:

- Starport or landing pad.
- Cantina/social interior.
- Medical center.
- Bazaar terminal.
- Mission terminals.
- Profession trainers or trainer terminals.
- General vendor.
- Weapon/armor vendor.
- Crafting station.
- Survey/harvesting vendor.
- Hangar/ship service NPC.
- Player vendor kiosk area.

Required gameplay:

- New-player spawn.
- First tutorial NPC.
- Inspectable world objects.
- Safe-zone protections.
- Nearby chat.
- Group invite.
- Vendor buy/sell.
- Mission acceptance.
- Training/skill spend.
- Travel departure.

### 4.3 City Fringe

The city fringe is the first place players leave safety.

Required content:

- Low-risk creature spawns.
- Training droids or bandits.
- Resource survey points.
- Delivery drop boxes.
- A small wreck, camp, or cave.
- Cover objects and line-of-sight teaching.
- Return path to city.

Design role:

- Teaches travel, combat, harvesting, and mission completion.
- Mostly secured or contested.
- Death should be rare here.

### 4.4 Wilderness

The wilderness is where the SWG-style loop starts to breathe.

Required content:

- Creature lairs or spawn nests.
- Resource zones with variable quality.
- Scout tracking.
- Camp placement.
- Harvesting sites.
- Patrols or faction skirmishes.
- Environmental hazard such as heat, sandstorm, or visibility penalty.

Design role:

- Primary place for hunting, scouting, harvesting, and camps.
- Risk/reward should be visible.
- Travel time should exist, but not be punishing.

### 4.5 Lawless Region

The lawless region is the alpha's high-risk/high-reward test bed.

Required content:

- Aggressive creature/NPC spawns.
- Better resource quality.
- Higher mission payouts.
- Corpse/loot/death penalty rules.
- PvP enablement according to security rules.
- Territory claim or future territory placeholder.

Design role:

- Tests WEG lethality.
- Tests player choice around danger.
- Tests economy tuning.
- Tests recovery, downed state, and medical roles.

### 4.6 Local Orbit

Local orbit should not feel like a separate minigame. It should be the spatial
continuation of the ground world.

Required content:

- Launch from starport/hangar.
- Dock/land back to ground.
- Local traffic contacts.
- Sensor contacts.
- Communications hails.
- One pirate or hostile encounter.
- One courier/transit route.
- One station or destination marker.

Design role:

- Teaches sensors, movement, comms, and gunnery.
- Provides travel continuity.
- Provides space missions and salvage.

### 4.7 Asteroid Or Salvage Field

Required content:

- Mineable asteroid nodes or salvageable wreckage.
- Hostile or environmental threat.
- Cargo reward.
- Return-to-station or return-to-ground sale point.

Design role:

- Connects space to economy.
- Makes Mechanical/Technical skills matter in space.
- Justifies ships before full space war content.

## 5. Character And Progression

### 5.1 Character Creation

Alpha character creation must produce a useful WEG D6 sheet, not only an avatar.

Required:

- Species selection.
- Attribute allocation or species-based starter arrays.
- Starting profession package.
- Skill dice assignment.
- Starting credits.
- Starting equipment.
- Starting wound state healthy.
- Starting home city/respawn location.
- Optional tutorial preference.

Species should have meaningful but readable differences:

- Attribute min/max.
- Move.
- Starting language/cultural flags if implemented.
- Social/medical/equipment restrictions only when gameplay-worthy.

### 5.2 Profession Packages

Professions are not rigid classes. They are SWG-style starter identities mapped
onto WEG D6 skill priorities.

Alpha starter packages:

1. Marksman.
2. Scout.
3. Medic.
4. Artisan/Mechanic.
5. Pilot/Spacer.
6. Entertainer/Social optional but highly recommended.

Each package grants:

- Suggested attributes.
- Skill dice distribution.
- Starter gear.
- Tutorial mission chain.
- Early certification tags.
- Recommended first CP spends.

The player can cross-train. The alpha should support hybridization.

### 5.3 Skill Advancement

Use Character Points as the main advancement currency.

Required:

- CP earned from missions, discovery, combat, crafting orders, harvesting
  milestones, social support, and space missions.
- CP spend UI.
- Skill increase validation.
- Cost increases by current skill level.
- Training location or trainer requirement for meaningful increases.
- Log of CP grants and spends.

Do not implement SWG's exact skill-box grid unless it helps presentation.
Instead, use profession tracks as guided wrappers around WEG skills.

### 5.4 Certifications

Certifications solve a common MMO problem: a player may own a weapon/ship/tool
but not yet be competent or authorized to use it well.

Alpha certifications:

- Blaster pistol.
- Blaster rifle.
- Heavy weapon.
- Basic armor.
- Medpac.
- Survey tool.
- Crafting station.
- Speeder/vehicle.
- Starter ship.
- Ship weapon operation.

Certification should never replace WEG skill rolls. It gates equipment access,
reduces penalties, or allows advanced actions.

## 6. Ground Combat

### 6.1 Combat Contract

Ground combat is server-authoritative and WEG D6-led.

Server owns:

- Target legality.
- Range band.
- Cover.
- Dice rolls.
- Wild Die behavior if/when fully implemented.
- CP/FP spends.
- Multiple action penalty.
- Attack roll.
- Defense roll.
- Damage roll.
- Soak roll.
- Armor contribution.
- Wound escalation.
- Death/downed state.
- Loot eligibility.
- Telemetry.

Client owns:

- Camera.
- Animation.
- Reticle.
- Impact presentation.
- Combat log display.
- Local input intent.

### 6.2 Action Windows

Keep explicit action windows under the real-time presentation.

Alpha model:

- A short server action window, currently around 5 seconds.
- Player submits intents: attack, aim, dodge, full defense, move, use medpac,
  interact, reload if manual reload is implemented, or assist.
- Multiple actions in a window apply WEG-style penalties.
- The server resolves the window in deterministic order.
- Presentation smooths the result but never changes it.

### 6.3 Required Ground Combat Actions

Alpha actions:

- Basic ranged attack.
- Aim.
- Dodge.
- Full dodge/defense.
- Cover use.
- Melee/brawling placeholder or first pass.
- Use medpac.
- Assist ally.
- Flee/disengage.
- Yield while downed.

Recommended second-pass actions:

- Suppressive fire.
- Called shot.
- Stun setting.
- Throw grenade.
- Drag downed ally.
- Repair droid.
- Creature special handling.

### 6.4 Wounds And Recovery

Wounds must be central. This is a WEG game, not an HP game.

Required wound states:

- Healthy.
- Stunned.
- Wounded.
- Wounded twice.
- Incapacitated.
- Mortally wounded.
- Dead.

Required recovery:

- Natural recovery for actable wound states.
- First Aid by another player.
- Medpac usage.
- Medical center recovery.
- Downed-state UI.
- Yield option.
- Respawn/insurance/death penalty.

Alpha should make Medic meaningful without making solo play impossible.

### 6.5 Armor, Durability, Ammo, And Gear

Required:

- Armor soak.
- Hit location if current systems already support it.
- Armor condition/durability.
- Broken armor penalty.
- Armor repair vendor or player repair path.
- Weapon ammo counts.
- Power packs as recurring sink.
- Reload/auto-reload behavior.
- Weapon condition optional for alpha, but desirable.

### 6.6 Encounter Types

Ground alpha needs multiple encounter templates:

1. Training target.
2. Weak creature.
3. Pack creature.
4. Armored humanoid/droid.
5. Dangerous elite.
6. Mission target.
7. Lawless ambush.
8. Optional player-versus-player duel or lawless PvP encounter.

Each template should validate a different part of the system.

## 7. Space Gameplay

### 7.1 Space Design Direction

Space should be 2.5D tactical, not full six-axis simulation.

The target:

- Flat x/y tactical positions.
- Isometric or cinematic camera.
- 3D voxel/low-poly ships on the plane.
- WEG starship rules under the hood.
- Readable crew-station actions.
- Smooth enough to feel alive.
- Deterministic enough to test.

### 7.2 Ground-To-Space Transition

Required transition:

1. Player enters starport or hangar.
2. Player chooses ship or rents starter transport.
3. Server validates ship, cargo, mission, and launch permission.
4. Client enters space presentation.
5. Ground avatar is no longer active in the ground zone.
6. Player ship exists in local orbit.
7. Player can dock/land back to a ground destination.

State to persist:

- Ship location.
- Ship condition.
- Cargo.
- Fuel or travel charge if implemented.
- Active space mission.
- Crew/NPC assignment if implemented.
- Last docked location.

### 7.3 Starter Ship

Alpha needs one player ship class.

Required ship stats:

- Hull.
- Shields/arcs.
- Maneuverability.
- Move/speed.
- Sensors.
- Comms.
- Hyperdrive flag.
- Cargo capacity.
- Weapon hardpoint.
- Crew/station mapping.
- Repairable systems.
- Docking/landing compatibility.

The ship should support:

- Travel.
- Light combat.
- Cargo mission.
- Salvage/asteroid field interaction.
- Repair loop.

### 7.4 Space Actions

Required:

- Sensors sweep.
- Contact identification.
- Hail/communications.
- Maneuver.
- Evasive maneuver/break lock.
- Gunnery attack.
- Shield reroute.
- Damage control repair.
- Astrogation plot.
- Dock/land.
- Mine/salvage.

Each action should map to WEG skills:

- Sensors: sensors/search family.
- Piloting: space transports/starfighter piloting as appropriate.
- Gunnery: starship gunnery.
- Shields: starship shields.
- Repair: space transports repair or relevant Technical skill.
- Astrogation: astrogation.
- Comms: communications.

### 7.5 Space Encounter Templates

Alpha templates:

1. Tutorial traffic contact.
2. Unknown sensor contact.
3. Friendly courier.
4. Pirate skirmisher.
5. Disabled freighter rescue.
6. Asteroid hazard.
7. Salvage wreck.
8. Docking approach.

The first alpha does not need capital ship warfare.

### 7.6 Space Economy Links

Space must feed the economy.

Required links:

- Cargo delivery missions.
- Salvage goods.
- Asteroid mining goods.
- Ship repair costs.
- Docking or launch fees.
- Fuel/travel fee optional but desirable.
- Space loot sold at ground vendors or bazaar.

## 8. Travel

### 8.1 Travel Philosophy

Travel should create world scale without becoming dead time.

Modes:

- Walking in local zones.
- Speeder/vehicle for wilderness.
- Shuttle/starport for city-to-city or planet-to-station travel.
- Player ship for local orbit and selected destinations.
- Hyperspace as route selection and transition, not a long real-time wait.

### 8.2 Ground Travel

Required:

- Zone exits.
- Starport entry.
- Vehicle or mount spawn/despawn.
- Travel costs or access conditions.
- Travel UI.
- Arrival safe point.

Recommended:

- Vehicle damage/condition later.
- Terrain speed modifiers.
- Camps as temporary recovery/travel anchors.

### 8.3 Shuttle And Starport Travel

Required:

- Ticket/vendor or terminal.
- Destination list.
- Credit cost.
- Travel confirmation.
- Server-side state update.
- Arrival location.

For alpha, shuttles may be instant after confirmation. Timed departures can come
later.

### 8.4 Ship Travel

Required:

- Launch to orbit.
- Dock at station.
- Land back at city.
- Plot route to secondary destination.
- Failure cases: damaged hyperdrive, destroyed ship, insufficient access.

The first version can represent hyperspace as a successful astrogation/travel
transition rather than a full space corridor.

## 9. Harvesting And Resources

### 9.1 Resource Philosophy

Resources are the heart of SWG-style crafting. Even in alpha, resources should
not be generic "iron."

Each resource should have:

- Type.
- Subtype.
- Quality stats.
- Spawn region.
- Current availability.
- Decay/replacement schedule.
- Economy base value.

Suggested quality stats:

- Conductivity.
- Durability.
- Malleability.
- Density.
- Potential energy.
- Purity.
- Flavor or medicinal potency for organic resources.

### 9.2 Surveying

Required:

- Survey tool item.
- Survey action.
- WEG skill roll.
- Resource map/result.
- Direction/density readout.
- Better roll gives better information.

Player experience:

- Equip survey tool.
- Select resource category.
- Survey.
- Move toward better density.
- Deploy harvester or manually harvest.

### 9.3 Manual Harvesting

Required:

- Harvest action on resource point.
- Skill check.
- Yield result.
- Inventory item.
- Tool durability or time cost.
- Encumbrance/cargo consideration optional.

Manual harvesting should be lower yield but immediate.

### 9.4 Harvesters

Alpha should include one placeable harvester type if possible.

Required:

- Place harvester in valid region.
- Server validates placement.
- Harvester stores owner, resource type, rate, maintenance, power.
- Harvester accrues resource over time.
- Player returns to collect.
- Harvester can run out of maintenance/power.
- Harvester persists across restart.

Simplify visuals. The important alpha proof is persistence and economy.

### 9.5 Creature Harvesting

Required:

- Disabled creature has harvestable tags.
- Scout/Survival/appropriate skill roll.
- Yield: hide, bone, meat, venom, organ, etc.
- Quality or tier affects crafting/economy.
- Failure/partial/success tiers.

This connects combat and crafting.

## 10. Crafting

### 10.1 Crafting Philosophy

Crafting should be useful before it is deep. The alpha needs working crafting
chains, not every SWG crafting profession.

Core loop:

1. Learn or own schematic.
2. Gather resources.
3. Use crafting station/tool.
4. Select resource inputs.
5. Roll or resolve crafting quality.
6. Produce item.
7. Use, sell, repair, or place item.

### 10.2 Crafting Data Model

Schematic fields:

- Key.
- Name.
- Category.
- Required skill.
- Required certification if any.
- Components.
- Resource stat weights.
- Crafting difficulty.
- Station/tool requirement.
- Output item.
- Output condition/durability.
- Optional experimentation fields.

Item instance fields:

- Template key.
- Crafter.
- Serial/id.
- Quality.
- Condition.
- Durability.
- Resource provenance.
- Modifiers.
- Owner if bound, preferably avoid binding for economy items.

### 10.3 Alpha Crafting Chains

Minimum chains:

1. Power pack or ammo pack.
2. Medpac.
3. Basic blaster component or complete hold-out blaster.
4. Armor patch/repair kit.
5. Survey tool or harvester part.
6. Ship repair patch or salvage component.
7. Camp kit.

These cover combat, medical, harvesting, space, and social travel.

### 10.4 Experimentation

Alpha experimentation can be simple:

- Player spends optional effort/roll.
- Better Technical/crafting roll improves one chosen stat.
- Failure lowers condition or wastes some input.
- Critical failure can produce flawed item.

Do not overbuild SWG's full experimentation graph at alpha. Build the contract
that resource quality matters.

### 10.5 Crafting Stations

Required station types:

- General crafting station.
- Medical station.
- Weapon/armor station.
- Ship/mechanical station.

For alpha these can be terminals in the hub, plus optional player-placeable
portable station later.

## 11. Economy

### 11.1 Economy Philosophy

The economy must have faucets, sinks, and player agency.

Faucets:

- Mission payouts.
- Creature loot.
- Harvested resource sales.
- Crafted item sales.
- Space salvage.
- Bounty payouts.
- Territory/resource income later.

Sinks:

- Travel fees.
- Repair.
- Ammo/power packs.
- Med supplies.
- Harvester maintenance.
- Harvester power.
- Vendor listing fees.
- Bazaar tax.
- Insurance.
- Ship repair.
- Docking/launch fees.
- Training fees optional.

### 11.2 Currencies And Ledgers

Required:

- Character credits.
- Vendor transaction log.
- Mission reward log.
- Crafting cost log.
- Harvester maintenance log.
- Repair log.
- Admin/economy telemetry tally.

Do not tune by feel only. Log faucets and sinks from the start.

### 11.3 NPC Vendors

Vendor types:

- General goods.
- Weapons.
- Armor.
- Medical.
- Survey/harvesting.
- Crafting.
- Ship services.
- Junk/salvage buyer.

NPC vendors should:

- Sell baseline goods.
- Buy common goods at lower rate.
- Apply reputation/skill/bargain modifiers.
- Reflect zone/event multipliers.
- Never outperform player crafters on high-quality goods.

### 11.4 Bazaar

Alpha bazaar:

- List item for sale.
- Search/list by category.
- Buy item.
- Charge listing fee/tax.
- Persist listing.
- Remove sold item from seller inventory.
- Deposit credits to seller.

It can be local to the alpha city at first.

### 11.5 Player Vendors

Player vendors are extremely SWG-flavored and worth including in alpha if the
economy foundation is stable.

Minimum implementation:

- Player places/rents a vendor kiosk in the bazaar area or homestead/camp.
- Vendor has owner.
- Owner stocks inventory.
- Owner sets prices.
- Other players buy while owner is offline.
- Vendor stores credits until owner collects.
- Vendor charges upkeep.

This single feature makes crafting and harvesting feel real.

## 12. Missions And Content

### 12.1 Mission Types

Alpha mission terminal templates:

- Kill creature.
- Clear lair.
- Deliver package.
- Recover salvage.
- Survey resource.
- Craft order.
- Escort/protect optional.
- Patrol route.
- Space courier.
- Space pirate interdiction.
- Asteroid salvage.

NPC story/tutorial missions:

- Welcome to the hub.
- Buy gear.
- Visit medical center.
- Take first mission.
- Survey a resource.
- Craft a medpac or power pack.
- Launch to orbit.
- Complete space scan/comms task.
- Return and spend CP.

### 12.2 Mission Structure

Mission fields:

- Key.
- Title.
- Giver/source.
- Required zone.
- Objective type.
- Target key or generated target spec.
- Reward credits.
- Reward CP.
- Faction/reputation changes.
- Required skill/certification if any.
- Failure conditions.
- Expiration if any.
- Follow-up mission key.

### 12.3 Dynamic Mission Generation

Alpha should support both authored and generated missions.

Generated mission inputs:

- Zone.
- Security tier.
- Player level/skill band.
- Profession package.
- Faction status.
- Available spawn tables.
- Current resource table.
- Economy faucet budget.

Start with deterministic templates and seeded random selection. Avoid LLM runtime
dependency.

## 13. Social, Medical, And Cantina Gameplay

### 13.1 Social Systems

Required:

- Nearby chat.
- OOC/global channel.
- Group chat.
- Emotes.
- Player inspect.
- Basic friend list or local player list.
- Group invite/leave.

Recommended:

- Guild/org chat.
- Player bio.
- Looking-for-group marker.

### 13.2 Cantina Role

The cantina should not be decorative only.

Alpha cantina functions:

- Social spawn point.
- Mission rumors.
- Entertainer/social support action.
- Wound/stress recovery bonus if implemented.
- NPC contacts.
- Bounty/gossip hooks.
- Player vendor or market notices.

Entertainer/social package can provide:

- Recovery acceleration.
- Temporary morale bonus.
- Rumor reveal.
- Negotiation/bargain bonus.
- Group support.

Keep it simple but real.

### 13.3 Medical Gameplay

Medical center functions:

- Treat wounds.
- Sell med supplies.
- Revive/downed recovery path.
- Clone/respawn registration if desired.
- Medical missions.

Medic role:

- First Aid in field.
- Medpac crafting/use.
- Stabilize downed players.
- Improve recovery.
- Sell crafted medical supplies.

## 14. Factions, Reputation, PvP, And Territory

### 14.1 Faction Model

Alpha factions:

- Republic.
- Separatist/CIS.
- Hutt/Underworld.
- Independent.
- Bounty Hunter guild/standing as a special overlay if desired.

Faction data:

- Standing per character.
- Reputation thresholds.
- Vendor discounts/access.
- Mission availability.
- Guard hostility.
- Security effects.
- PvP legality interactions.

### 14.2 Security Tiers

Use the existing secured/contested/lawless model.

Secured:

- No open PvP.
- NPC aggression limited.
- Tutorial and trade safe.

Contested:

- PvE active.
- PvP by consent, bounty, faction flag, or event.

Lawless:

- Open PvP.
- Higher rewards.
- Corpse/loot/death penalties.

All combat initiation should route through one server legality function.

### 14.3 PvP Alpha Scope

Alpha should include a controlled PvP proof but not build the full war.

Required:

- Duel/challenge or lawless PvP.
- PvP wound/death handling.
- PvP reward/penalty guardrails.
- Anti-grief safe-zone rules.
- Clear UI warning before lawless entry.

Optional:

- Bounty mission.
- Faction flag.
- Small territory claim proof.

### 14.4 Territory Alpha Scope

Full player cities and multi-week sieges are post-alpha unless already close.

Alpha territory-lite:

- One claimable lawless resource node.
- Org/guild ownership.
- Passive resource/credit accrual.
- Guard NPC placeholder.
- Upkeep cost.
- Visible world tag.

This gives the project a path toward SWG player cities and SW_MUSH Drop 6D
territory without making alpha depend on a giant PvP state machine.

## 15. Player-Owned Objects

Alpha should include at least one persistent player-owned world object.

Priority order:

1. Harvester.
2. Player vendor.
3. Camp.
4. Ship.
5. Homestead-lite structure.

### 15.1 Camps

Camp alpha:

- Crafted or purchased camp kit.
- Place in valid wilderness area.
- Temporary object persists for a limited duration.
- Provides recovery bonus and social anchor.
- Allows group regrouping.
- Maybe supports field crafting/medical.

### 15.2 Homestead-Lite

If included:

- One small placed structure in a valid region.
- Owner only or group access.
- Storage box.
- Player vendor slot.
- Decoration optional.
- Upkeep.

Do not build full cities before alpha.

## 16. UI And Player Experience

### 16.1 UI Goals

The UI must translate D6 into readable MMO feedback.

Required panels:

- Character/vitals/wounds.
- Target.
- Combat log.
- Mission tracker.
- Inventory.
- Equipment.
- Vendor/bazaar.
- Crafting.
- Survey/harvest.
- Travel.
- Space tactical.
- Chat.
- Group.
- Notifications.

### 16.2 WEG Roll Transparency

Players need readable roll summaries:

- Skill used.
- Dice pool.
- Difficulty.
- Modifiers.
- CP/FP spends.
- Outcome.
- Consequence.

Do not spam raw math constantly. Use expandable details or compact log entries.

### 16.3 New Player Flow

The alpha must have a guided first hour:

1. Create character.
2. Spawn in city.
3. Learn movement/chat.
4. Talk to tutorial NPC.
5. Open inventory/equip weapon.
6. Visit vendor.
7. Accept mission.
8. Leave city.
9. Fight and recover.
10. Survey/harvest.
11. Craft simple item.
12. Sell or list item.
13. Launch to orbit.
14. Complete space task.
15. Return and spend CP.

## 17. Asset And Visual Roadmap

### 17.1 Runtime Asset Policy

All runtime assets must live in curated runtime folders, not docs output folders.

Recommended structure:

- `assets/voxel/characters`
- `assets/voxel/droids`
- `assets/voxel/creatures`
- `assets/voxel/buildings`
- `assets/voxel/props`
- `assets/voxel/weapons`
- `assets/voxel/ships`
- `assets/materials`
- `assets/backgrounds`
- `assets/vfx`

Each promoted asset gets a manifest:

- Key.
- Source/generator.
- License/provenance.
- Scale.
- Collision proxy.
- Sockets.
- Palette/material notes.
- Status: prototype, alpha, replaced, rejected.

### 17.2 Alpha Asset Needs

Characters:

- Player base body.
- Marksman variation.
- Scout variation.
- Medic variation.
- Artisan/mechanic variation.
- Pilot variation.
- Vendor NPC.
- Trainer NPC.
- Guard NPC.
- Cantina patron.

Droids/Enemies:

- B1-style battle droid.
- Training remote.
- Small hostile droid.
- Humanoid bandit/raider.

Creatures:

- Small starter creature.
- Pack creature.
- Harvest-rich creature.
- Dangerous lawless creature.

Buildings/Props:

- Starport/hangar.
- Cantina kit.
- Medical center kit.
- Bazaar/vendor kiosks.
- Mission terminal.
- Crafting station.
- Survey marker.
- Harvester.
- Camp kit.
- Resource crates.
- Cover pieces.

Ships:

- Starter transport.
- Pirate/light fighter.
- Freighter contact.
- Space station/docking marker.
- Asteroids/salvage chunks.

### 17.3 Meshy Usage

Meshy should not be used for foreground voxel assets by default.

Allowed alpha uses:

- Space background plates.
- Planet/orbit backdrop concept.
- Nebula/asteroid ambience references.
- VFX or material reference.
- Posterized skybox experiments.
- Non-runtime inspiration to rebuild as voxel.

Avoid spending Meshy credits on:

- Player characters.
- Nearby NPCs.
- Weapons/equipment.
- Modular buildings.
- Ships intended to sit beside strict voxel assets.

## 18. Technical Architecture Roadmap

### 18.1 Authority Boundaries

Server owns:

- Account/session.
- Character state.
- Position truth.
- Zone truth.
- Dice.
- Combat.
- Economy.
- Inventory.
- Missions.
- Crafting.
- Harvesters.
- Player vendors.
- Ships.
- Space encounters.
- Faction/security.
- Persistence.

Client owns:

- Presentation.
- Camera.
- Input intent.
- UI.
- Animation.
- Audio.
- Local effects.

Any alpha feature that violates this boundary should be marked prototype-only
and scheduled for migration.

### 18.2 Persistence

Required persisted tables/files:

- Accounts.
- Characters.
- Character skills/progression.
- Inventory item instances.
- Equipped gear.
- Credits.
- Wounds.
- Missions.
- Vendors/listings.
- Harvester objects.
- Resources.
- Crafted item provenance.
- Ships and ship condition.
- Player location.
- Faction standings.
- Org/guild membership if included.
- Telemetry/audit logs.

Alpha can stay JSON/resource-backed if reliable, but interfaces should be shaped
so a database migration is not a rewrite.

### 18.3 Data Validation

Every data file needs smoke coverage:

- Skills.
- Species.
- Weapons.
- Armor.
- Items.
- Schematics.
- Resources.
- Missions.
- Vendors.
- NPCs.
- Creatures.
- Ships.
- Zones.
- Assets/manifests.

Validation should check:

- Required fields.
- Unique keys.
- Referenced keys exist.
- Economy values present.
- No invalid era labels.
- No runtime references to docs-generated paths.

### 18.4 Refactor Targets

High-priority refactors:

- Split net world orchestration.
- Extract vendor/economy service.
- Extract mission service.
- Extract crafting service.
- Extract travel service.
- Extract ship/space service.
- Extract UI controllers.
- Promote generated assets to curated runtime assets.

Refactor only when it supports the alpha path. Avoid architecture gardening.

## 19. Implementation Milestones

### Milestone 0: Pivot Lock

Goal: Make the project explicitly SWG WEG D6, with SW_MUSH as reference.

Tasks:

- Add this roadmap to Antigravity docs.
- Add a short product-pivot note to active handoff docs.
- Mark SW_MUSH as reference, not target.
- Define alpha acceptance checklist.
- Inventory existing systems to reuse.
- Inventory local JSON/UI authority seams.
- Inventory docs-generated runtime asset references.

Exit criteria:

- Antigravity knows the product target.
- The project has one alpha definition.
- Existing tests pass.

### Milestone 1: Authoritative Ground Core

Goal: Make ground play authoritative, persisted, and friend-testable.

Tasks:

- Harden character login/spawn/reconnect.
- Move vendor/dialogue/local JSON edits behind server state.
- Stabilize inventory/equipment.
- Stabilize credits.
- Stabilize mission state.
- Stabilize wound/death/recovery state.
- Ensure two-client consistency.

Exit criteria:

- Two clients can play in the same city/wilderness.
- Vendor transaction persists.
- Mission persists.
- Wound persists.
- Reconnect is reliable.

### Milestone 2: Complete Ground Loop

Goal: Player can do a full SWG-style ground session.

Tasks:

- Build hub city services.
- Build first mission terminal.
- Build first NPC mission chain.
- Build city fringe.
- Build wilderness hunting area.
- Build survey/manual harvest.
- Build sell/repair loop.
- Build CP spend loop.

Exit criteria:

- Character can accept mission, leave city, fight, loot/harvest, return, sell,
  complete, spend CP, and reconnect.

### Milestone 3: Crafting And Economy

Goal: Player economy exists, not only NPC loot.

Tasks:

- Add resource qualities.
- Add schematics.
- Add crafting station UI.
- Add item instance provenance.
- Add medpac/power pack/basic tool crafting.
- Add bazaar listing/buying.
- Add player vendor if feasible.
- Add economy telemetry.

Exit criteria:

- A player can harvest a resource, craft a useful item, list or sell it, and
  another player can buy/use it.

### Milestone 4: Travel And Space Integration

Goal: Space becomes part of the world loop.

Tasks:

- Add starport/hangar flow.
- Add starter ship ownership/rental.
- Persist ship state.
- Launch to orbit.
- Dock/land back to ground.
- Add orbit contacts.
- Add space mission terminal/NPC.
- Add cargo/salvage/asteroid mission.
- Add ship repair path.

Exit criteria:

- A player can launch from ground, complete a space action mission, take or
  repair ship damage, dock/land, and receive ground economy reward.

### Milestone 5: Social, Medical, And Group Play

Goal: The game feels online and cooperative.

Tasks:

- Nearby/OOC/group chat.
- Group invites.
- Group mission sharing or simple group credit.
- Medic revive/stabilize flow.
- Cantina recovery/support.
- Player inspect.
- Social tutorial hooks.

Exit criteria:

- Two players can group, travel, fight, heal, and complete a mission together.

### Milestone 6: Faction/Security/PvP Proof

Goal: Risk and faction identity matter.

Tasks:

- Implement or harden secured/contested/lawless gates.
- Add lawless warning.
- Add faction standing display.
- Add faction mission deltas.
- Add guard hostility rules.
- Add duel or lawless PvP proof.
- Add death/corpse/loot rules for lawless.
- Optional territory-lite claim.

Exit criteria:

- Players understand where they are safe.
- Lawless rewards are better and riskier.
- PvP cannot bypass security rules.

### Milestone 7: Visual Cohesion And Asset Promotion

Goal: The alpha no longer looks like a stitched-together lab.

Tasks:

- Promote top generated assets into runtime folders.
- Create manifests.
- Replace docs-path asset loading.
- Standardize scale and palette.
- Standardize lighting and shadows.
- Add collision/socket metadata.
- Replace most visible placeholders.
- Capture alpha screenshots.

Exit criteria:

- The first 10 minutes are visually coherent.
- Foreground assets share a voxel language.
- Asset provenance is documented.

### Milestone 8: Alpha Lock And Playtest

Goal: Produce a playable alpha build.

Tasks:

- Write first-hour playtest script.
- Run solo playtest.
- Run two-client playtest.
- Run economy balance tally.
- Run combat balance probe.
- Run persistence/restart test.
- Run space travel/reconnect test.
- Fix blockers.
- Document known issues.

Exit criteria:

- A friend can complete the first-hour loop without developer intervention.
- Core systems persist.
- Full check passes.
- Known issues are ranked.
- Next phase is content expansion, not foundation rescue.

## 20. Alpha Acceptance Checklist

### Character

- Character creation works.
- Species affects sheet.
- Profession package affects skills/gear.
- CP spend works.
- Reconnect restores sheet.

### Ground

- Hub city exists.
- City fringe exists.
- Wilderness exists.
- Lawless region exists.
- Travel between them works.
- Ground movement feels acceptable.

### Combat

- WEG dice resolve attacks.
- Cover/dodge/aim matter.
- Wounds matter.
- Armor matters.
- Ammo matters.
- Recovery matters.
- Combat logs explain outcomes.

### Harvesting

- Survey works.
- Manual harvest works.
- Creature harvest works.
- Resource quality exists.
- Harvested goods persist.

### Crafting

- Schematics exist.
- Crafting station works.
- Crafted item instances persist.
- Resource quality affects output.
- Crafted items can be used or sold.

### Economy

- Credits persist.
- NPC vendors work.
- Bazaar or player vendor works.
- Repairs cost credits.
- Ammo/consumables cost credits.
- Economy telemetry records faucets/sinks.

### Missions

- Mission terminal works.
- NPC tutorial chain works.
- Ground combat mission works.
- Harvest/craft mission works.
- Space mission works.
- Rewards persist.

### Space

- Launch works.
- Orbit view works.
- Sensors/comms/gunnery/maneuver work.
- Ship damage persists.
- Repair works.
- Dock/land works.
- Space rewards connect to ground economy.

### Social

- Chat works.
- Grouping works.
- Medic/social support has at least one real use.
- Player inspect or player list works.

### Persistence

- Character state persists.
- Inventory persists.
- Credits persist.
- Wounds persist.
- Missions persist.
- Vendor/listings persist.
- Harvester/camp/vendor/ship state persists as implemented.

### Admin/Test

- Full project check passes.
- Data smoke tests pass.
- Two-client test passes.
- Restart/reconnect test passes.
- Telemetry can answer economy/combat questions.

## 21. What Not To Build Before Alpha

Do not block alpha on:

- Full planet roster.
- Full SWG crafting complexity.
- Full player cities.
- Full territory siege.
- Full Jedi/Force unlock.
- Full capital ship combat.
- Full space multiplayer fleet warfare.
- Full SW_MUSH content import.
- Full animation library.
- Perfect asset polish.
- Public-release IP cleanup.

These matter later. The alpha needs all major systems present, but each system
can be narrow.

## 22. Force/Jedi Policy For Alpha

Force sensitivity should remain hidden and rare.

Alpha scope:

- Track hidden prerequisites if the model already exists.
- Include rumors/lore hints.
- Do not allow Jedi as starter profession.
- Do not let Force powers dominate alpha combat.
- Do not let Force implementation delay crafting, economy, space, or travel.

Post-alpha:

- Earned awakening questline.
- Scarcity controls.
- Dark Side/temptation rules.
- Force skill training.
- Social/faction consequences.

## 23. Designer Notes To Antigravity

### 23.1 The Main Product Bet

The most promising version of this project is not a visual MUSH port. It is a
small, playable SWG-like world where WEG D6 is the invisible machinery.

If a choice arises between:

- room parity and playable traversal, choose playable traversal;
- exact SWG recreation and WEG integrity, choose WEG integrity;
- realism and voxel clarity, choose voxel clarity;
- content breadth and complete loop, choose complete loop;
- a clever isolated demo and alpha cohesion, choose alpha cohesion.

### 23.2 The Main Technical Bet

Preserve server authority at all costs.

The prototype can tolerate ugly UI, incomplete art, and thin content. It cannot
tolerate client-owned credits, inventory, combat, or mission truth if it is
serious about becoming an MMO alpha.

### 23.3 The Main Design Trap

The project is now strong enough to attract too many good ideas.

Do not add ten planets. Do not add ten professions. Do not add twenty enemy
families. Do not build Jedi. Do not chase Meshy. Do not import all of SW_MUSH.

Build one complete life loop:

City -> mission -> travel -> combat/harvest -> craft/sell -> social/recover ->
space -> return -> progress -> persist.

Then expand.

## 24. Suggested Immediate Next Tasks

If Antigravity starts from this document, the next concrete tasks should be:

1. Add a short pivot note to the active handoff.
2. Create an alpha acceptance checklist file from Section 20.
3. Inventory every feature that currently bypasses server authority.
4. Move dialogue/vendor credit and inventory changes behind server calls.
5. Promote the best voxel assets from docs-generated folders into runtime
   curated asset folders.
6. Define the alpha city/wilderness/orbit zone keys.
7. Implement or harden one mission terminal that can issue combat, delivery,
   harvest, craft, and space missions from data templates.
8. Build resource quality data and one survey/harvest/craft chain.
9. Connect launch/dock/land space travel to persistent character/ship state.
10. Run the first "complete life loop" playtest and log every break.

## 25. Final Alpha Vision

The alpha is successful when it feels like this:

A new player logs in as a WEG D6 character, not a class avatar. They step into a
voxel Mos Eisley-style hub, hear chatter, see terminals, vendors, ships, and
other players. They buy a cheap blaster and a survey tool, take a mission, leave
the city, get into a dangerous fight where a wound matters, harvest something
valuable, limp back, sell part of it, craft a useful item from the rest, recover
in a social space, spend Character Points, launch into orbit, scan an unknown
contact, survive a pirate exchange, dock, and log out. When they return, the
world remembers.

That is the alpha.

