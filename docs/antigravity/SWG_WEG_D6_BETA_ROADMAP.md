# Star Wars Galaxies WEG D6 Beta Roadmap

Designer: Codex  
Implementer: Antigravity  
Project: SW_MMO_Prototype  
Pivot target: Star Wars Galaxies-scale sandbox MMO, powered by WEG Star Wars D6  
Status: Beta roadmap - 5x to 10x larger than the alpha plan  

2026-07-06 scope update: this document is now historical/aspirational context,
not the active beta critical path. The active roadmap extension is
`docs/antigravity/BETA_ROADMAP_EXTENSION_2026_07_06.md`, which defines beta as a
thin live MMO track and explicitly keeps multiplayer space, sieges, player
cities, runtime LLM work, and broad planet rollout out of the pre-beta lane.

## 1. The Beta Target

The alpha roadmap defined a compact, system-complete prototype. If Antigravity
can burn through that quickly, the next useful target is not "more slice." The
next useful target is a game that people can actually play for weeks.

Beta means:

- Players have multiple viable identities.
- Players have daily and weekly reasons to log in.
- Players can make money in different ways.
- Players can depend on one another.
- Players can own things in the world.
- Players can affect the world.
- Players can travel between places that matter.
- Ground and space are connected.
- Crafting is not decorative.
- Combat is not the only career.
- Social play is useful.
- Factions and territory create conflict.
- WEG D6 consequences are visible.
- The game produces stories without a staff member manually running every scene.

The beta is still not a commercial game. It is a private/friends-scale playable
MMO sandbox with enough systemic depth that the group can find their own fun.

## 2. One-Sentence Product Vision

Build a voxel Star Wars Galaxies-inspired sandbox where players live as WEG D6
characters in a Clone Wars frontier: fighting, crafting, trading, healing,
entertaining, scouting, building, flying, smuggling, hunting bounties, joining
factions, and reshaping a small persistent galaxy.

## 3. What "Gameplay" Means Here

Gameplay is not only combat. This project should treat the following as equal
gameplay pillars:

1. Combat mastery.
2. Resource discovery.
3. Crafting optimization.
4. Market entrepreneurship.
5. Social support.
6. Medical recovery.
7. Exploration and surveying.
8. Vehicle and ship operation.
9. City building.
10. Faction conflict.
11. Bounty and smuggling pressure.
12. Group PvE.
13. Space encounter management.
14. Political/economic control.
15. Character identity and long-term advancement.

If the beta only has combat, it is not a Star Wars Galaxies WEG D6 game. It is
an action prototype with D6 dice.

## 4. Beta Size

The alpha plan was one compact world loop.

Beta should be 5x to 10x larger:

- 4 to 6 ground planets or major regions.
- 4 to 6 connected space sectors.
- 3 hub cities.
- 6 to 10 wilderness/adventure regions.
- 3 lawless or faction-war regions.
- 2 to 3 player city/camp regions.
- 12 to 18 profession tracks.
- 80 to 150 missions.
- 30 to 50 creature/NPC encounter templates.
- 50 to 100 craftable items.
- 8 to 12 resource families with quality variation.
- 6 to 10 player-owned object types.
- 6 to 10 ship/vehicle roles.
- A basic but real player economy.
- A faction conflict layer.
- A city/territory layer.
- A live world Director layer.

This is not "finish the whole dream." This is the minimum size where the dream
starts behaving like a sandbox instead of a demo.

## 5. Beta Definition Of Done

The beta is playable when a small group can play for 30 days and still have
meaningful goals.

Definition of done:

- A new player can play a guided first hour.
- A casual player can play 30 to 60 minutes and make progress.
- A crafter can spend a session gathering, experimenting, crafting, and selling.
- A combat player can hunt, run missions, join group content, and improve.
- A social/medical player can materially help other players.
- A pilot can run space missions, haul cargo, fight, salvage, and repair.
- A trader can operate vendors and profit from resource/crafting differences.
- A faction player can shift local control, earn reputation, and fight over
  territory.
- A builder can place and maintain useful world objects.
- A group can run a dangerous ground or space encounter.
- The world changes over time through Director events, resources, territory, and
  player economy.
- State survives restart.
- The economy has visible faucets and sinks.
- The game has enough data and UI that players do not need developer coaching.

## 6. Core Beta Loops

### 6.1 First-Hour Loop

Goal: the player understands the game and becomes attached to a role.

Flow:

1. Create character.
2. Choose species and starter package.
3. Spawn in hub city.
4. Talk to an in-fiction mentor.
5. Equip starter gear.
6. Learn chat, map, inventory, and wound display.
7. Accept a profession-flavored task.
8. Leave the city.
9. Complete one objective.
10. Return and receive credits/CP.
11. Visit a relevant vendor or trainer.
12. Learn that other players matter.
13. See a preview of space/travel/crafting/factions.

### 6.2 Daily Solo Loop

Goal: the player has satisfying short sessions.

Examples:

- Run a mission terminal job.
- Survey a resource spawn.
- Harvest enough material for a schematic.
- Craft and list a few items.
- Repair gear and restock ammo.
- Patrol faction territory.
- Fly a cargo route.
- Hunt a creature for parts.
- Recover from wounds at a medical/cantina hub.

### 6.3 Daily Social Loop

Goal: players create value for each other.

Examples:

- Medic stabilizes wounded hunters.
- Entertainer/social character grants recovery or morale buffs.
- Scout finds high-quality resources and sells coordinates.
- Artisan crafts gear from another player's materials.
- Pilot transports players or cargo.
- Bounty hunter tracks a player/NPC target.
- City mayor coordinates defenses/upkeep.
- Group fights an elite creature or droid patrol.

### 6.4 Weekly Sandbox Loop

Goal: the group has medium-term goals.

Examples:

- Found or grow a player town.
- Contest a resource field.
- Run a faction campaign.
- Build a vendor network.
- Craft higher-quality gear from rare resources.
- Upgrade ships.
- Defend a harvester cluster.
- Hunt a named creature.
- Complete a multi-step profession quest.
- Trigger or respond to a Director event.

### 6.5 Monthly Meta Loop

Goal: the world feels alive.

Examples:

- Planet economy shifts from resource availability.
- Faction influence changes security levels.
- Player city becomes a real trade hub.
- A lawless area becomes dangerous or profitable.
- A new rare resource spawn creates a market rush.
- A faction offensive unlocks a battlefield.
- A hidden Force-sensitive path advances for a rare player.

## 7. World Scope

### 7.1 Beta Galaxy Layout

The beta should be a small galaxy, not a whole galaxy.

Recommended beta world:

1. Desert frontier planet.
2. Urban core planet or city-layer region.
3. Forest/plains planet.
4. Industrial/war-torn planet.
5. Optional underworld/moon/outpost region.
6. Connected orbit and hyperspace lanes.

For private Star Wars flavor, this can map emotionally to Tatooine, Coruscant
underlevels, Naboo or Dantooine, Geonosis or Ryloth-like conflict space, and a
Hutt/asteroid outpost. Implementation should keep content data-driven enough to
rename or reframe later.

### 7.2 Region Types

Each planet/major region should contain:

- One safe hub.
- One city fringe.
- One wilderness/resource band.
- One higher-risk area.
- One point of interest.
- One local mission set.
- One travel link.
- One local resource table.
- One local creature/NPC table.

### 7.3 Planet Identity

Each planet needs a gameplay identity, not just a color palette.

Desert frontier:

- Best early hunting.
- Smuggling and Hutt activity.
- Harsh travel.
- Good minerals and creature resources.
- Strong new-player hub.

Urban core:

- Best trade, trainers, bazaar, politics.
- Dense missions.
- Underworld and law enforcement.
- Social play and high vendor traffic.
- Little raw harvesting, but high demand.

Forest/plains:

- Best organic resources.
- Creature handler/scout gameplay.
- Camps, surveying, medicinal components.
- Lower tech, higher wilderness density.

Industrial/war-torn:

- Droid/NPC conflict.
- Salvage, metal, weapon components.
- Faction missions.
- Dangerous battlefields.
- Better ship/mechanical materials.

Underworld/outpost:

- Lawless trade.
- Bounty/smuggling.
- Rare vendors.
- PvP risk.
- High-value black market.

### 7.4 Space Regions

Each major ground region should have orbit.

Space sectors:

- Planetary orbit.
- Trade lane.
- Asteroid/salvage field.
- Pirate interdiction zone.
- Military patrol zone.
- Deep-space jump point.

Each sector should support:

- Sensor contacts.
- Traffic.
- Missions.
- Hazards.
- Resource/salvage opportunity.
- Dock/land transitions.

## 8. Professions And Role Identity

### 8.1 Profession Philosophy

Do not build rigid MMO classes. Build SWG-style identities over WEG skills.

Professions should:

- Guide starting choices.
- Gate certifications.
- Unlock schematics/actions.
- Suggest gameplay loops.
- Allow hybridization.
- Use WEG skills as the mechanical truth.

### 8.2 Beta Profession List

Core combat:

1. Marksman.
2. Brawler/Melee specialist.
3. Commando/heavy weapons.
4. Bounty hunter.

Exploration/wilderness:

5. Scout.
6. Creature handler/tamer.
7. Ranger/survivalist.

Medical/social:

8. Medic.
9. Doctor.
10. Entertainer/social specialist.

Crafting/economy:

11. Artisan.
12. Weaponsmith.
13. Armorsmith.
14. Droid engineer.
15. Shipwright/mechanic.
16. Architect/builder.
17. Merchant.

Space:

18. Pilot.
19. Gunner/crew specialist.
20. Navigator/engineer.

Underworld/faction:

21. Smuggler.
22. Spy/scoundrel.
23. Officer/squad leader.

This list can be implemented as tracks, not full separate classes. Beta does not
need complete parity for every track, but each should have at least:

- Starter package.
- Skill priorities.
- Core action.
- Economic role.
- Mission set.
- Progression unlocks.
- One reason other players care.

### 8.3 Profession Interdependence

The game becomes a sandbox when professions depend on each other.

Examples:

- Marksman needs weapons, armor, ammo, med supplies.
- Scout finds high-quality resources for crafters.
- Medic keeps hunters alive in lawless regions.
- Entertainer/social character accelerates recovery or provides group morale.
- Merchant makes crafted goods discoverable.
- Pilot moves cargo and players.
- Shipwright repairs/upgrades ships.
- Droid engineer creates helper droids for combat/survey/crafting.
- Bounty hunter depends on intel, tracking, and underworld contacts.
- Architect builds camps, harvesters, homes, and city structures.

### 8.4 Skill And Certification Growth

Progression should have three layers:

1. WEG skill dice.
2. Profession unlocks/certifications.
3. Reputation/access.

Example:

- A player with high blaster skill can shoot well.
- A marksman certification allows advanced rifles/heavy mods.
- Republic standing grants access to military contracts.

This avoids flattening everything into a single level number.

## 9. Combat Beta

### 9.1 Ground Combat Expansion

Current WEG action-window combat is the foundation. Beta should make it varied.

Required beta additions:

- Multiple enemy AI behavior families.
- Group enemy tactics.
- Suppression or area denial.
- Stun vs lethal modes.
- Grenades/explosives.
- Melee/brawling pass.
- Creature special attacks.
- Droid immunities/resistances.
- Armor specialization.
- Weapon certifications.
- Cover-rich encounter spaces.
- Group roles: tanking by positioning/cover, medic support, suppression, scout
  pull/mark, officer buffs.

### 9.2 Encounter Families

Ground encounter families:

1. Training enemies.
2. Wild creatures.
3. Pack predators.
4. Humanoid raiders.
5. Droids.
6. Patrol squads.
7. Elite bounty targets.
8. Lair/nest spawns.
9. Battlefield waves.
10. Boss/named encounters.

Each family needs:

- Spawn rules.
- Combat behavior.
- Loot/harvest profile.
- Mission hooks.
- Difficulty band.
- Counterplay.

### 9.3 Group PvE

Beta should have at least three group activities:

1. Creature lair clear.
2. Droid/faction outpost assault.
3. Space convoy/interdiction encounter.

Group content must reward:

- Combat performance.
- Healing/support.
- Scout/utility actions.
- Mission participation.
- Salvage/harvest contribution.

### 9.4 Combat Readability

Players need to understand:

- Why they missed.
- Why they were hit.
- What cover did.
- What armor did.
- What wound penalty did.
- What CP/FP did.
- Why an enemy is dangerous.
- Why a mission is too hard.

Implement compact roll summaries and expanded details.

### 9.5 PvP Combat

Beta PvP should be real but bounded.

Modes:

- Duel/challenge.
- Lawless open PvP.
- Bounty target engagement.
- Faction flag engagement.
- Territory/siege window.

Guardrails:

- Safe zones.
- Lawless warnings.
- Anti-spawn-camping respawn protection.
- Death/corpse logic.
- Reward throttles to prevent farming friends.
- Server-side target legality always.

## 10. Space Beta

### 10.1 Space As A Career

Space cannot remain only a modal combat overlay. Beta should let a player be a
pilot as a meaningful career.

Pilot gameplay:

- Cargo hauling.
- Passenger transport.
- Escort.
- Smuggling.
- Salvage.
- Mining.
- Patrol.
- Pirate hunting.
- Recon/sensors.
- Repair/rescue.
- Faction space missions.

### 10.2 Ship Classes

Beta ship roster:

1. Starter transport.
2. Light fighter.
3. Courier/smuggler ship.
4. Mining/salvage craft.
5. Gunship/group craft.
6. NPC freighter.
7. NPC patrol craft.
8. Pirate/interceptor.

Each ship needs:

- Role.
- Cargo.
- Crew seats.
- Hull/shields.
- Maneuverability.
- Weapons.
- Upgrade slots.
- Repair profile.
- Cost/upkeep.

### 10.3 Ship Ownership

Required:

- Buy or earn starter ship.
- Store ship state.
- Select active ship.
- Dock/land.
- Repair.
- Cargo inventory.
- Equip basic components.
- Insurance or recovery after destruction.

### 10.4 Ship Components

Beta component categories:

- Reactor/power core.
- Engine.
- Hyperdrive.
- Shield generator.
- Sensor package.
- Weapon.
- Armor/hull plating.
- Cargo module.
- Mining/salvage tool.
- Droid socket or crew module.

Crafting should feed ship components.

### 10.5 Space Missions

Mission types:

- Cargo route.
- Scan unknown contacts.
- Patrol route.
- Destroy pirate.
- Disable ship.
- Rescue disabled craft.
- Salvage wreck.
- Mine asteroid.
- Smuggle cargo past patrol.
- Escort convoy.
- Deliver passenger.

### 10.6 Ground-Space Economy

Space should produce and consume ground economy items:

Produces:

- Salvage metal.
- Ship components.
- Rare minerals.
- Contraband.
- Data packages.
- Bounty rewards.

Consumes:

- Fuel/travel fees.
- Repairs.
- Ship components.
- Ammo/ordnance.
- Docking fees.
- Crafted upgrades.

## 11. Harvesting And Resource Simulation

### 11.1 Dynamic Resource Spawns

Resources should rotate over time.

Resource spawn fields:

- Resource family.
- Specific resource name.
- Planet/region.
- Density map.
- Quality stats.
- Start time.
- End time.
- Rarity.
- Survey difficulty.

Beta should have resource churn:

- Common resources always available somewhere.
- Uncommon resources rotate weekly.
- Rare resources trigger market behavior.
- Resource quality creates crafter demand.

### 11.2 Survey Gameplay

Surveying should be a mini-career.

Required:

- Survey tool types.
- Survey action by category.
- Skill-based result fidelity.
- Direction/density hints.
- Survey map pins.
- Share/sell waypoint or resource report.
- Deploy harvester from good location.

Advanced:

- Deeper scan consumes time or tool charge.
- Better surveyors reveal quality estimates.
- Environmental hazards affect survey rolls.

### 11.3 Harvester Network

Harvester gameplay:

- Place in valid resource area.
- Choose resource.
- Maintenance pool.
- Power pool.
- Extraction rate from density and harvester quality.
- Storage capacity.
- Collect output.
- Repair/pack up.
- Permissions.
- Visible world object.
- Vulnerable in lawless/territory areas.

Harvester types:

- Mineral.
- Chemical.
- Flora/organic.
- Gas/moisture.
- Asteroid/space mining.

### 11.4 Creature Harvesting

Creature harvesting should matter to multiple crafts.

Outputs:

- Hide.
- Bone.
- Meat.
- Venom.
- Glands/organs.
- Chitin/shell.
- Exotic tissue.

Uses:

- Armor.
- Medicine.
- Food/buffs.
- Creature handling.
- Decorative/social items.
- Specialty components.

## 12. Crafting Beta

### 12.1 Crafting As A Pillar

Crafting must create items players actually prefer over vendor defaults.

Beta rules:

- Vendor goods are baseline.
- Crafted goods can exceed baseline.
- Resource quality affects output.
- Crafter skill affects experimentation and reliability.
- Item condition/durability matters.
- Components feed higher-tier items.
- Player economy makes crafted items available.

### 12.2 Crafting Professions

Crafting tracks:

- Artisan/general.
- Weaponsmith.
- Armorsmith.
- Droid engineer.
- Shipwright/mechanic.
- Medic/pharmaceutical.
- Architect.
- Chef/entertainer support optional.
- Merchant.

### 12.3 Schematic Depth

Beta schematic categories:

Weapons:

- Hold-out blaster.
- Blaster pistol.
- Blaster rifle.
- Power packs.
- Weapon mods.
- Grenade/explosive.

Armor:

- Light armor.
- Medium armor.
- Armor patch.
- Environmental gear.
- Utility belt.

Medical:

- Medpac.
- Stim.
- Wound treatment kit.
- Poison/venom treatment.

Harvesting:

- Survey tool.
- Harvester component.
- Camp kit.
- Resource container.

Droids:

- Utility droid.
- Survey droid.
- Repair droid.
- Combat assistant droid.
- Droid modules.

Ships:

- Repair patch.
- Shield component.
- Engine component.
- Sensor upgrade.
- Weapon mount.
- Cargo module.

Structures:

- Camp.
- Harvester.
- Vendor kiosk.
- Small house/homestead.
- City service module.

### 12.4 Experimentation And Quality

Implement a beta-level experimentation pass.

Inputs:

- Resource stats.
- Component quality.
- Crafter skill.
- Station quality.
- Tool quality.
- Optional CP spend.

Outputs:

- Damage.
- Accuracy.
- Durability.
- Encumbrance.
- Soak.
- Capacity.
- Extraction rate.
- Repair efficiency.
- Medical potency.

Failure:

- Lower condition.
- Wasted component.
- Flawed item tag.
- Catastrophic failure rare.

### 12.5 Factories

Factories are a major SWG-like system. Beta should include a simplified version.

Factory loop:

1. Craft prototype item.
2. Save manufacturing schematic.
3. Load resources.
4. Run factory over time.
5. Produce identical item batch.
6. Pay maintenance/power.

This gives merchants inventory and makes resource stockpiling meaningful.

## 13. Economy Beta

### 13.1 Economy Goal

Players should eventually buy from each other because player goods are better,
more specialized, or more convenient than NPC goods.

### 13.2 Market Layers

NPC economy:

- Baseline goods.
- Credit sinks.
- Emergency availability.

Bazaar:

- Searchable player listings.
- Regional/local market.
- Fees and taxes.

Player vendors:

- Persistent shops.
- Offline sales.
- Owner pricing.
- Vendor maintenance.

Direct trade:

- Player-to-player exchange.
- Credits/items confirmation.

Contracts/orders:

- Crafting order request.
- Resource buy order.
- Delivery/courier contract.

### 13.3 Economic Roles

Merchant gameplay:

- Buy low/sell high.
- Run vendors.
- Place vendors in player city.
- Track price history.
- Fulfill orders.
- Move goods between planets.
- Speculate on rare resources.
- Coordinate with crafters/harvesters.

### 13.4 Sinks And Inflation Control

Mandatory sinks:

- Travel.
- Repairs.
- Ammo.
- Medical supplies.
- Crafting station use.
- Harvester maintenance.
- Harvester power.
- Factory maintenance.
- Vendor maintenance.
- Listing taxes.
- Housing/city upkeep.
- Ship repairs.
- Ship component degradation.
- Insurance.

Telemetry must show:

- Credits generated per day.
- Credits destroyed per day.
- Top faucets.
- Top sinks.
- Average player balance.
- Market volume.
- Resource prices.
- Item sales.

## 14. Player Cities And Housing

### 14.1 Why Player Cities Matter

Player cities turn the game from a theme park into a world.

Beta does not need full metropolis complexity, but it should support meaningful
settlements.

### 14.2 Settlement Stages

Stage 1: Camp

- Temporary.
- Recovery/social/crafting utility.

Stage 2: Homestead

- Persistent small structure.
- Storage.
- Vendor slot.
- Crafting station.
- Upkeep.

Stage 3: Outpost

- Multiple player structures in a region.
- Shared services.
- Shuttle marker maybe.
- Local tax/upkeep.

Stage 4: Player City

- Mayor.
- Citizens.
- City treasury.
- Placed services.
- Vendor district.
- Medical/cantina services.
- Militia/security.
- City specialization.

Beta should reach Stage 3 or early Stage 4.

### 14.3 City Services

Services:

- Shuttleport.
- Bazaar terminal.
- Medical center.
- Cantina/social stage.
- Crafting hall.
- Mission terminal.
- Garage/hangar.
- Guard post.
- Resource depot.

Each service needs:

- Construction cost.
- Upkeep.
- Permission rules.
- Gameplay value.

### 14.4 Governance

Governance beta:

- Mayor/founder.
- Citizen list.
- Treasury.
- Tax rate.
- Building placement permission.
- Service placement permission.
- Militia/guard permission.

Do not overbuild elections before the first city works.

## 15. Factions, War, And Territory

### 15.1 Faction Gameplay Goal

Factions should create a living map.

The player should see:

- Who controls a region.
- What that changes.
- How to help or hurt.
- What rewards exist.
- What risks exist.

### 15.2 Faction Axes

Beta axes:

- Republic.
- CIS/Separatist.
- Hutt/Underworld.
- Independent/local.
- Bounty Hunter standing as special professional overlay.

### 15.3 Influence System

Influence changes from:

- Missions.
- NPC kills.
- PvP.
- Smuggling.
- Trade.
- Patrols.
- Player city allegiance.
- Territory control.
- Director events.

Influence affects:

- Patrol spawns.
- Vendor access.
- Mission availability.
- Security tier overlays.
- Bounties.
- Prices.
- World events.

### 15.4 Territory Nodes

Beta territory:

- Claimable resource fields.
- Claimable outposts.
- Claimable city-adjacent service nodes.
- Claimable space beacon or mining field.

Each node:

- Owner org.
- Upkeep.
- Guard slot.
- Passive yield.
- Vulnerability window.
- Map visibility.

### 15.5 Siege/Contest Beta

Implement a simplified but real contest loop:

1. Org declares contest.
2. Defender receives warning.
3. Contest window opens.
4. PvP and PvE objectives generate score.
5. Winner takes or defends node.
6. Lockout begins.

Scoring:

- Player presence.
- Defeated guards.
- Completed sabotage/repair objectives.
- PvP wins.
- Delivered supplies.
- Held control points.

This gives warriors, crafters, medics, pilots, and smugglers roles.

### 15.6 Battlefield Events

Beta event types:

- Droid incursion.
- Republic checkpoint.
- Hutt enforcement sweep.
- Smuggler convoy.
- Resource rush.
- Pirate blockade.
- City defense.

These can be Director-triggered or player-triggered.

## 16. Bounty, Smuggling, Crime, And Underworld

### 16.1 Crime System

Beta should support an underworld career.

Crime/heat sources:

- Smuggling contraband.
- Attacking faction NPCs.
- Entering restricted areas.
- Killing players in lawless areas.
- Failing scans.
- Theft/sabotage if implemented.

Heat effects:

- Patrol hostility.
- Bounty generation.
- Vendor restrictions.
- Underworld access.
- Scan difficulty.

### 16.2 Smuggling

Smuggling loop:

1. Accept contraband job.
2. Acquire cargo.
3. Travel through controlled route.
4. Avoid or beat scans.
5. Deliver cargo.
6. Gain credits/Hutt/underworld rep.

Counterplay:

- Republic scans.
- Player bounty hunters.
- Informants.
- Riskier route pays more.

### 16.3 Bounty Hunting

Bounty types:

- NPC bounty.
- Player bounty from crime/heat.
- Faction bounty.
- Creature bounty.

Bounty hunter tools:

- Tracking terminal.
- Last-known region.
- Probe/sensor action.
- Informant contacts.
- Capture/kill objective.

Player bounty must be carefully bounded to avoid griefing.

## 17. Droids, Pets, Mounts, And Companions

### 17.1 Droids

Droids are perfect for WEG/SWG interdependence.

Droid types:

- Utility droid.
- Survey droid.
- Medical assistant.
- Repair droid.
- Combat droid.
- Astromech/ship support droid.

Droid systems:

- Crafting.
- Modules.
- Maintenance.
- Damage/repair.
- Commands.
- Skill bonuses.
- Ship crew assistance.

### 17.2 Creature Handler

Creature handler/tamer beta:

- Tame eligible creatures.
- Train simple commands.
- Feed/maintain.
- Use in combat or scouting.
- Harvest/non-lethal ethical tension optional.
- Stable/storage.

Keep scope modest. One pet class can prove the loop.

### 17.3 Mounts And Vehicles

Beta vehicles:

- Speeder bike.
- Landspeeder.
- Pack/mount creature optional.

Systems:

- Spawn/despawn.
- Speed difference.
- Damage/repair.
- Fuel/maintenance optional.
- Cargo slot optional.

Vehicles make world scale feel real.

## 18. Social And Noncombat Careers

### 18.1 Entertainer/Social Specialist

Social gameplay should produce mechanical value.

Actions:

- Perform.
- Inspire/morale buff.
- Recovery acceleration.
- Rumor gathering.
- Negotiation support.
- Cantina mission unlocks.
- Group cohesion bonus.

Resources:

- Instruments/props.
- Clothing/cosmetics.
- Venue/stage.

Progression:

- Larger audience.
- Better recovery effects.
- Better rumor quality.
- More social actions.

### 18.2 Doctor/Medic

Medical gameplay:

- Field stabilize.
- Heal wound levels.
- Treat poison/restraint.
- Craft medicine.
- Operate medical center.
- Revive downed ally.
- Reduce death penalty.

Economy:

- Sell med supplies.
- Charge for treatment.
- Supply cities/groups.

### 18.3 Officer/Squad Leader

Officer role:

- Group tactical buffs.
- Coordinate fire.
- Rally from suppression/wounds.
- Improve mission payouts for group.
- Call target.
- Territory/siege utility.

Officer is useful because WEG action windows make coordination meaningful.

## 19. Mission And Quest Content

### 19.1 Content Volume

Beta mission target:

- 20 tutorial/onboarding missions.
- 30 terminal combat missions.
- 20 delivery/courier missions.
- 15 harvest/survey missions.
- 15 crafting/order missions.
- 20 space missions.
- 10 faction missions per major faction.
- 5 to 10 group missions.
- 5 profession quest chains.

### 19.2 Mission Variety

Mission templates:

- Kill target.
- Disable target.
- Harvest quantity.
- Survey location.
- Craft item.
- Deliver cargo.
- Escort.
- Patrol.
- Scan space contact.
- Hail/contact.
- Salvage.
- Smuggle.
- Bounty.
- Defend object.
- Repair object.
- Place harvester.
- Supply city.
- Recover lost item.
- Investigate rumor.

### 19.3 Story Arcs

Beta needs light story arcs, not a full theme park.

Recommended arcs:

1. Frontier newcomer.
2. Hutt debt/smuggling.
3. Republic security crackdown.
4. CIS droid cell.
5. Resource rush.
6. Pirate blockade.
7. Player city founding.
8. Hidden Force rumor chain, not full Jedi unlock.

Each arc should cross systems.

Example:

Resource rush arc:

- Survey rare resource.
- Fight local threat.
- Place harvester.
- Craft component.
- Deliver to faction/vendor.
- Other faction tries to sabotage.
- Market price changes.

## 20. Live World Director

### 20.1 Director Goal

The Director creates conditions, not cutscenes.

It changes:

- Alert levels.
- Patrol intensity.
- Event availability.
- Resource pressure.
- Local market modifiers.
- Mission weights.
- Spawns.
- News/rumors.

It should not:

- Narrate player actions.
- Force specific outcomes.
- Depend on LLM runtime.
- Invent mechanics that code cannot support.

### 20.2 Director Event Types

Beta event list:

- Republic crackdown.
- CIS probe/droid incursion.
- Hutt auction.
- Smuggler convoy.
- Pirate surge.
- Sandstorm/environmental hazard.
- Merchant arrival.
- Medical emergency.
- Resource boom.
- Creature migration.
- Bounty surge.
- City festival.
- Space distress signal.
- Hyperspace lane disruption.
- Faction battlefield.

### 20.3 News And Rumors

Players need to perceive world changes.

Channels:

- News terminal.
- Cantina rumors.
- Mission terminal modifiers.
- Space traffic alerts.
- NPC chatter.
- Map overlays.
- Player mail/message optional.

## 21. UI Beta

### 21.1 Required Screens

Main HUD:

- Vitals/wounds.
- Target.
- Action window.
- Mission tracker.
- Chat.
- Mini-map or region map.
- Notifications.

Character:

- Attributes.
- Skills.
- Profession tracks.
- Certifications.
- CP/FP.
- Faction standings.

Inventory/equipment:

- Gear.
- Containers.
- Item condition.
- Ammo.
- Resource stacks.
- Crafted provenance.

Economy:

- Vendor.
- Bazaar search/listing.
- Player vendor management.
- Trade window.

Crafting:

- Schematics.
- Resource selection.
- Experimentation.
- Output preview.
- Factory batch if implemented.

Harvest:

- Survey.
- Resource map.
- Harvester management.

Travel:

- Ground map.
- Shuttle/starport.
- Ship selection.
- Launch/dock.

Space:

- Tactical map.
- Contact details.
- Crew/station strip.
- Ship condition.
- Cargo.
- Space mission tracker.

Social:

- Group.
- Friends/list.
- Player inspect.
- City/org panel.

### 21.2 Gamepad/Keyboard Priority

Do not chase full controller support before beta, but avoid UI that only works
with precise debug clicking. Mouse/keyboard should be comfortable.

### 21.3 Explain The Dice

Every major action should optionally expose:

- Skill.
- Attribute.
- Dice.
- Difficulty.
- Modifiers.
- Result.
- Consequence.

This is a key differentiator.

## 22. AI And NPC Behavior

### 22.1 NPC Categories

NPC types:

- Static service NPC.
- Ambient social NPC.
- Patrol NPC.
- Mission target.
- Enemy combatant.
- Faction guard.
- Vendor.
- Trainer.
- Event NPC.
- Companion/droid/pet.

### 22.2 AI Behavior Families

Combat AI:

- Aggressive melee.
- Ranged cover user.
- Skirmisher/kiter.
- Pack swarm.
- Defensive guard.
- Droid direct-fire.
- Elite tactical.
- Fleeing civilian/merchant.

Ambient AI:

- Walk route.
- Work/social/rest schedule.
- React to event.
- Chatter.
- Vendor/service idle.

Space AI:

- Patrol.
- Hold range.
- Close and attack.
- Flee.
- Escort.
- Mine/salvage.
- Docking route.

### 22.3 NPC Persistence

Important NPCs persist:

- Location.
- Wound/death status if relevant.
- Respawn timer.
- Event affiliation.
- Vendor stock modifiers.

Ambient disposable NPCs can be generated.

## 23. Technical Beta Architecture

### 23.1 Service Boundaries

Split runtime systems into clear services:

- Account/session service.
- Character service.
- World/zone service.
- Combat service.
- Inventory service.
- Economy service.
- Vendor/bazaar service.
- Crafting service.
- Resource/harvester service.
- Mission service.
- Travel service.
- Space service.
- Faction/security service.
- City/territory service.
- Social/chat service.
- Asset registry.
- Telemetry/admin service.

This does not require a microservice architecture. It requires code boundaries.

### 23.2 Database Direction

JSON can survive alpha. Beta needs stronger persistence boundaries.

Recommended:

- Keep data definitions as JSON/resources.
- Move mutable player/world state behind a storage interface.
- Start with file-backed store if needed.
- Shape interfaces for SQLite/PostgreSQL migration.

Beta mutable state:

- Accounts.
- Characters.
- Inventory instances.
- Crafted item instances.
- Vendors/listings.
- Harvester objects.
- Factories.
- Player structures.
- Ships.
- Missions.
- Faction standings.
- Territory.
- Resource spawns.
- Economy logs.

### 23.3 Admin Tools

Beta needs admin tooling.

Required:

- Spawn item.
- Grant credits/CP.
- Teleport player.
- Inspect player.
- Inspect economy.
- Inspect world objects.
- Force event.
- Reset stuck mission.
- Ban/kick if needed.
- Export logs.

Admin tools prevent playtests from dying.

### 23.4 Telemetry

Track:

- Session length.
- Mission completion.
- Death/wound rates.
- Credits faucet/sink.
- Item sales.
- Crafting attempts.
- Resource harvesting.
- Travel usage.
- Space actions.
- PvP kills.
- Harvester output.
- City upkeep.
- Error rates.

Use telemetry to tune, not vibes only.

## 24. Content Production Pipeline

### 24.1 Asset Pipeline

Foreground assets:

- Pixel/voxel deterministic source.
- Godot proof.
- Blockbench/manual cleanup for hero assets.
- Runtime manifest.
- Collision/socket pass.

Background/ambience:

- Meshy or image generation allowed as reference or backdrop when not jarring.
- Posterize/pixelate as needed.
- Never mix organic Meshy foreground models with strict voxel characters unless
  deliberately framed as distant/background.

### 24.2 Content Data Pipeline

Every content category should be data-driven:

- NPCs.
- Creatures.
- Missions.
- Vendors.
- Items.
- Schematics.
- Resources.
- Ships.
- Zones.
- Factions.
- Events.
- Assets.

Build validation early. Antigravity moves fast enough that bad data will become
the limiting factor if validation lags.

### 24.3 "Request From Designer" Protocol

For each asset or system request, include:

- Gameplay purpose.
- Scale/importance.
- Runtime path.
- Required sockets.
- Collision needs.
- Visual references/mood.
- WEG mechanics involved.
- Data keys.
- Acceptance test.

## 25. Beta Milestones

### Milestone B0: Beta Pivot Lock

Goal: replace alpha thinking with beta product thinking.

Tasks:

- Add this roadmap.
- Create beta acceptance checklist.
- Mark old alpha roadmap as foundational, not final.
- Create product pillar doc.
- Identify all current systems that already satisfy beta needs.
- Identify all systems that are only demo/prototype.

Exit:

- Antigravity has a beta target and can prioritize.

### Milestone B1: Playable City And First Professions

Goal: the hub becomes a real home base.

Build:

- Full hub city service layout.
- Cantina, medical center, bazaar, starport, crafting hall.
- Profession trainer flow.
- Six starter packages.
- First-hour tutorial.
- Social/medical functions.

Exit:

- A new player knows what the game is.

### Milestone B2: Wilderness, Resources, And Crafting

Goal: the world outside the city supports economic life.

Build:

- Wilderness region.
- Resource survey.
- Manual harvesting.
- Harvester placement.
- Resource quality.
- Schematics.
- Crafting station.
- First useful crafted items.

Exit:

- A player can gather, craft, and sell something another player wants.

### Milestone B3: Economy And Vendors

Goal: players can trade asynchronously.

Build:

- Bazaar.
- Player vendor.
- Direct trade.
- Vendor upkeep.
- Listing fees.
- Economy telemetry.
- Better NPC vendor stock.

Exit:

- A crafter/merchant can log off and still sell goods.

### Milestone B4: Ground Combat And Group PvE

Goal: combat has variety and consequences.

Build:

- Encounter families.
- Group mission.
- Lair/outpost.
- Enemy AI families.
- Medical role support.
- Loot/harvest variety.
- Armor/ammo/repair loop.

Exit:

- A group has a real night of PvE gameplay.

### Milestone B5: Space Career

Goal: space becomes a second career, not a side screen.

Build:

- Ship ownership.
- Launch/dock/land.
- Cargo.
- Space missions.
- Salvage/mining.
- Ship repair.
- Components.
- Pirate/escort encounters.

Exit:

- A pilot can spend a whole session in space and affect the ground economy.

### Milestone B6: Multi-Region Galaxy

Goal: travel and regional identity matter.

Build:

- Second and third major regions.
- Resource differences.
- Regional vendors.
- Regional missions.
- Shuttle travel.
- Space lanes.
- Market differences.

Exit:

- Moving goods/players between regions is meaningful.

### Milestone B7: Player Ownership And Cities

Goal: players can build persistent economic/social anchors.

Build:

- Camps.
- Homesteads.
- Harvester fields.
- Player vendor clusters.
- Outpost/player city stage.
- City services.
- Upkeep.

Exit:

- Players can create a place other players visit.

### Milestone B8: Faction And Territory War

Goal: the map can change.

Build:

- Influence.
- Security overlays.
- Faction missions.
- Claimable nodes.
- Guards.
- Contest windows.
- Territory rewards.
- PvP legality.

Exit:

- Faction players can fight over something that persists.

### Milestone B9: Underworld, Bounty, Smuggling

Goal: the criminal layer becomes playable.

Build:

- Contraband.
- Scans.
- Heat.
- Smuggling missions.
- Bounty generation.
- Tracking tools.
- Underworld vendors.

Exit:

- Smugglers and bounty hunters have a real loop.

### Milestone B10: Live World Director

Goal: the world changes without manual staff.

Build:

- Event scheduler.
- News/rumor output.
- Resource churn.
- Patrol/security shifts.
- Dynamic mission weights.
- Economy modifiers.

Exit:

- Players can log in to changed conditions.

### Milestone B11: Beta Hardening

Goal: play for weeks without foundation collapse.

Build:

- Storage reliability.
- Admin tools.
- Balance telemetry.
- Crash/restart recovery.
- Content validation.
- Bug triage.
- Performance pass.
- Two-to-five player playtest.

Exit:

- A small group can play for 30 days.

## 26. Beta Acceptance Checklist

### Player Identity

- 12+ profession tracks have meaningful actions.
- 6+ starter packages are viable.
- Hybridization works.
- CP/skill progression matters.
- Certifications matter.

### World

- 4+ major regions.
- 3+ hubs.
- 6+ wilderness/adventure regions.
- 4+ space sectors.
- Regional resources and markets differ.

### Combat

- Ground solo content works.
- Ground group content works.
- Wounds/recovery matter.
- Gear condition/ammo matter.
- PvP is legal only where intended.

### Economy

- Bazaar works.
- Player vendors work.
- Crafting produces useful goods.
- Resource quality affects goods.
- Economy has measured faucets/sinks.

### Crafting/Harvesting

- Surveying works.
- Harvesters work.
- Factories or batch production work.
- At least 50 craftables.
- At least 8 resource families.

### Space

- Ship ownership works.
- Launch/dock/land works.
- Space missions work.
- Salvage/mining work.
- Ship repair/components matter.
- Space connects to economy.

### Social

- Groups work.
- Medical support matters.
- Social/cantina support matters.
- Player cities/outposts matter.
- Chat and player discovery work.

### Factions

- Influence changes.
- Security changes.
- Faction missions exist.
- Territory nodes exist.
- Contest loop exists.

### Persistence

- Player state persists.
- World objects persist.
- Vendors persist.
- Harvesters persist.
- Ships persist.
- Cities/territory persist.
- Resource spawns persist.

### Operations

- Admin tools exist.
- Telemetry exists.
- Full checks pass.
- Content validation exists.
- Playtest script exists.

## 27. Things To Still Avoid

Even for beta, avoid:

- Full commercial polish.
- Full planet count.
- Full Jedi game.
- Full capital-ship warfare.
- Fully simulated politics.
- Large NPC voice/dialogue systems.
- Perfect animation.
- Procedural everything.
- Public release/legal packaging.

Dream big, but spend implementation on gameplay systems that interlock.

## 28. The Beta Fantasy

A player logs in on Friday night. They are not asking, "What demo should I try?"
They are asking, "What should I do tonight?"

They might:

- Join a group hunting a dangerous creature for rare hide.
- Escort a merchant shipment through a pirate-heavy space lane.
- Survey a newly spawned high-quality mineral and race to place harvesters.
- Craft armor from last week's rare resource and list it on their vendor.
- Heal wounded friends after a lawless-region fight.
- Smuggle contraband past a Republic checkpoint.
- Hunt a bounty target who has been raiding harvesters.
- Help defend a player outpost during a contest window.
- Fly salvage runs after a battle in orbit.
- Spend the night in a cantina gathering rumors, healing fatigue, and recruiting
  for tomorrow's faction push.

That is beta.

## 29. Designer's Final Instruction To Antigravity

The alpha plan was about proving the pillars exist. This beta plan is about
making those pillars produce a world.

Do not merely add features. Add dependencies between playstyles.

The magic of a Star Wars Galaxies WEG D6 game is not that a player can shoot a
droid. It is that the player shooting the droid needs ammo made by a crafter,
armor repaired by a smith, medicine from a doctor, coordinates from a scout, a
ship flown by a pilot, a city maintained by builders, a market run by merchants,
and a faction war that gives the whole mess a reason to matter.

Build that web.
