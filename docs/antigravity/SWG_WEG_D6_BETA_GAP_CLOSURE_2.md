# SWG WEG D6 Beta Gap Closure 2

Designer: Codex  
Implementer: Antigravity  
Project: SW_MMO_Prototype  
Target: Clone Wars era Star Wars Galaxies-inspired sandbox, powered by WEG D6  
Purpose: second director-level gap closure after reviewing Antigravity's current implementation state and SW_MUSH design references  

## 1. Current Assessment

I checked the project again.

There is now evidence that Antigravity has begun responding to the first gap
closure brief in the correct direction. The latest tree includes:

- `data/resources_clone_wars.json`
- `data/schematics_clone_wars.json`
- `scripts/rules/item_instance.gd`
- `scripts/rules/bazaar_model.gd`
- `scripts/tests/bazaar_model_smoke.gd`
- `scripts/tests/crafting_model_smoke.gd`
- `scripts/tests/survey_model_smoke.gd`
- `scripts/tests/space_travel_wire_smoke.gd`
- new bazaar signals/RPCs in `scripts/net/network_manager.gd`
- persisted `_bazaar_listings` in world state
- some movement toward server-owned space/cargo state

That is the right vector. It shows Antigravity understood the main critique:
the project needs item instances, data-driven resources/schematics, and a
player-to-player economy surface.

However, the implementation is not green yet.

The current `tools/check_project.ps1` gate fails during Godot import:

```
SCRIPT ERROR: Parse Error:
The variable type is being inferred from a Variant value, so it will be typed
as Variant. (Warning treated as error.)
at res://scripts/rules/bazaar_model.gd:12
```

The specific line is:

```
var fee: int = int(max(MIN_LISTING_FEE, price * LISTING_FEE_PCT))
```

This is a small compile-quality issue, not a design disaster. It likely wants
an explicit typed numeric path, such as separating the calculated fee from the
integer max or using the appropriate Godot typed max helper. But the larger
point is procedural: a pass does not count while the project gate is red.

My design assessment is now:

- Antigravity is progressing in the intended direction.
- The current market/item/crafting pass is promising.
- The current pass is incomplete and red.
- The first gap closure is partially acted on, not closed.
- Gap Closure 2 should now harden and connect this work, not restart it.

This document is therefore a stricter design contract for finishing the current
economy loop and proving it through play.

## 2. The Non-Negotiable Product Direction

The game is not SW_MUSH in 3D.

The game is also not a generic Star Wars action prototype.

The target is:

> A Clone Wars era, Star Wars Galaxies-flavored, WEG D6 sandbox MMO prototype
> where players can make a life through combat, crafting, medicine, trade,
> spaceflight, exploration, faction work, social play, and territorial ambition.

The MUSH is reference material. It provides:

- WEG D6 mechanical grounding.
- Economy structures.
- Mission and bounty patterns.
- Smuggling risk/reward.
- Crafting quality and experimentation lessons.
- Space navigation, crew, cargo, salvage, and ship-mod lessons.
- Faction, organization, influence, and city systems.
- Medical and death consequences.
- Director AI world-state concepts.
- Social infrastructure such as places, scenes, plots, and intel.

The MMO version should copy the *good system ideas*, not the MUSH command layer.

In the MMO, those ideas must become:

- Visual world state.
- Spatial traversal.
- Interaction prompts.
- Shared markets.
- Persistent objects.
- Server-owned authority.
- Usable inventories.
- Inspectable logs.
- Multiplayer dependency.

## 3. What Counts As Gameplay

From this point forward, a feature does not count as implemented unless it has
all of the following:

1. Data definition.
2. Server authority.
3. Persistence.
4. Player-facing UI.
5. Gameplay cost or risk.
6. Gameplay reward.
7. Economy, mission, or social linkage.
8. Telemetry or audit visibility.
9. Smoke coverage.
10. A reason another player would care.

If a feature only has UI, it is a toy.

If a feature only has server state, it is a mechanical proof.

If a feature only gives the local player a reward, it is a solo loop.

If a feature creates value another player can use, buy, protect, steal, repair,
heal, transport, tax, or fight over, it becomes MMO gameplay.

## 4. The Gap Antigravity Must Close Next

The current implementation has promising seeds:

- Resource and schematic data files have begun.
- Item instances have begun.
- Bazaar model and RPC wiring have begun.
- Survey gives resources.
- Harvest mutates the sheet.
- Craft can produce item dictionaries for medpacs or power packs.
- Space beacons make travel visible.

But the systems do not yet fully connect, and the project gate is currently red.

The next pass must make these systems depend on each other:

```
survey -> harvest -> resource stack -> schematic -> item instance
item instance -> market/vendor/trade -> another player uses it
space travel -> cargo -> route risk -> market value
combat -> wounds/ammo/damage -> medical/crafting/economy demand
faction missions -> influence -> security/director/territory effects
city/vendor activity -> taxes/upkeep -> organization goals
```

That dependency graph is the beta spine.

Do not add more disconnected buttons. Do not add more planets before travel
matters. Do not add more schematics in code. Do not add more visual-only beacons.
Fix the red gate, then make the first economy loop real.

## 5. Era And Theme: Clone Wars SWG, Not GCW SWG

The MUSH guides often use Imperial/Rebel language because they are mechanically
derived from a GCW-style reference. For this game, translate the faction layer
into the Clone Wars era:

Primary faction axes:

- Galactic Republic: legitimate authority, clone patrols, Jedi detachments,
  senators, quartermasters, military contracts, lawful security.
- Confederacy of Independent Systems: Separatist cells, droid armies,
  corporate logistics, sabotage, covert factories, convoy interdiction.
- Hutt/Underworld: smuggling, bounties, spice, black markets, slavers,
  protection rackets, neutral ports.
- Independent/Frontier: settlers, miners, traders, scouts, medics, mechanics,
  mercenaries, local militias.
- Professional guilds: medics, shipwrights, mechanics, scouts, entertainers,
  slicers, bounty hunters.

The feel should not be "join a faction and shoot enemies forever." It should be:

- A clone trooper needs a medic and an armorer.
- A pilot needs a shipwright and a fuel/cargo economy.
- A crafter needs scouts and surveyors.
- A smuggler needs false papers, risky routes, and buyers.
- A city needs vendors, security, taxes, and citizens.
- A faction needs supply, influence, and reputation.
- A neutral player can profit from everyone without being a soldier.

Clone Wars flavor should come through systemically:

- Droid forces are cheap, numerous, repairable, and tied to CIS logistics.
- Clone forces are disciplined, supply-hungry, and tied to Republic authority.
- Hutt and neutral ports are where both sides bend rules.
- Jedi are rare and socially disruptive, not a default player power fantasy.
- War creates resource demand, convoy risk, medical demand, black market demand,
  and territorial pressure.

## 6. SW_MUSH Systems To Copy Aggressively

Copy these ideas from SW_MUSH, translated into MMO form.

### 6.1 Economy: Missions, Bounties, Smuggling, Cargo, Sinks

SW_MUSH has a strong economy design:

- Mission boards with 5-8 jobs.
- 14 mission types.
- Pay ranges tied to risk and skill.
- Mission lifecycle: available, accepted, completed, expired, failed.
- Bounty tiers with target difficulty and payout.
- Smuggling cargo tiers with patrol risk and fines.
- Multi-planet routes with risk and reward.
- Credit sinks: repairs, medical costs, travel, upkeep, taxes, guild dues.

MMO translation:

- Mission terminals should be visible objects in hub cities.
- Mission offers should be data-driven and refreshed on server cadence.
- Missions should consume or create demand for goods: medpacs, power packs,
  repair parts, cargo, food, intel, contraband, ship components.
- Bounties should spawn or select actual NPC targets in the world.
- Smuggling should require physical cargo in a ship or backpack.
- Patrol checks should happen at launch, landing, route nodes, and checkpoints.
- The UI should show risk, route, cargo mass, and expected pay.
- Completion should route through WEG D6 rolls, not arbitrary success flags.

The economy must stop being a wallet attached to combat. It must become the
reason many non-combat roles exist.

### 6.2 Crafting: Resources, Schematics, Quality, Experimentation, Teaching

SW_MUSH Guide 7 is close to the exact first MMO economy spine we need:

- Survey for resources.
- Gather materials.
- Learn schematics from trainers.
- Craft items.
- Experiment to improve them.
- Teach schematics to other players.
- Crafted items have quality 1-100.
- Quality determines actual stats.
- Partial success and fumble matter.

MMO translation:

- Resources must be defined in data, not hard-coded.
- Resource spawns must vary by zone, biome, security, and active Director event.
- Survey must use a D6 skill check, probably Search for early proof, with Scout
  and planetary survey skills later.
- Survey margin must affect resource quality/density.
- Harvesting should produce itemized resource stacks with quantity and quality.
- Schematics must live in data files and be learnable.
- Crafted outputs must be item instances.
- Item quality must affect actual gameplay, not just the display name.
- Experimentation should become the crafter's high-skill identity.
- Teaching or licensing schematics should become a player economy path.

The current `medpac_basic` and `power_pack_standard` schematics are useful proof
seeds. They are not sufficient for beta until they are item-instance outputs
that another player can buy and use in combat, medical, ammo, or repair loops.

### 6.3 Space: Routes, Crew, Cargo, Salvage, Ship Mods

SW_MUSH space is rich:

- Zone graph: dock -> orbit -> deep space -> hyperspace lane.
- Ship templates.
- Crew stations.
- Navigation and hyperspace.
- Space combat.
- Power allocation.
- Cargo trading.
- Transponders and countermeasures.
- Anomalies and salvage.
- Ship customization and modifications.
- NPC traffic.

MMO translation:

- A player must have a current server-owned location: ground, dock, ship interior,
  orbit, route, destination, or station.
- Launch and land must be server requests, not client-only presentation shifts.
- Ships must be item/vehicle instances with owner, condition, cargo, fuel,
  installed components, and current zone.
- Cargo must exist as physical inventory with mass/volume and legality flags.
- Space salvage and asteroid mining must produce resources used by crafters.
- Ship upgrades must come from crafting, not static unlocks.
- Crew roles can begin as UI toggles but must eventually use different skills:
  pilot, gunner, engineer, navigator, sensors, commander.
- The first version can be single-seat, but the data model must not block crews.

The current beacon jump is visually promising. It is not yet travel. Travel
means server-owned movement of character, ship, cargo, and risk state.

### 6.4 Organizations, Factions, Guilds

SW_MUSH Guide 10 has the right pattern:

- Major factions shape the galaxy.
- Professional guilds shape careers.
- Reputation unlocks rank.
- Rank issues equipment and permissions.
- Faction treasury supports stipends and territory investment.
- Guild dues provide costs.
- Director AI consumes faction activity.

Clone Wars translation:

- Republic, CIS, Hutt/Underworld, Independent, and professional guilds.
- Faction rank should matter, but not erase player crafting value.
- Faction-issued equipment should be useful starter or role gear, not the best
  gear forever.
- Faction gear must be reclaimable or flagged.
- Guild membership should reduce training cost, unlock contracts, or improve
  access to tools.
- Reputation should be earned through missions, crafting deliveries, medical
  service, convoy work, bounties, smuggling, and territory actions.

Do not reduce factions to a badge. Factions are an engine for conflict, supply,
reputation, and world events.

### 6.5 Territory Control

SW_MUSH Guide 11 is a strong endgame structure:

- Influence 0-150 per zone.
- Thresholds: presence, foothold, dominance, control.
- Influence from presence, missions, kills, PvP, and treasury investment.
- Decay when absent.
- Claim rooms after foothold.
- Guards and upkeep.
- Passive resource nodes.
- Visible claim tags and influence display.

MMO translation:

- Regions/zones should track per-faction influence.
- Player activity should shift influence.
- Claimed locations should become visible in the 3D world with banners, guards,
  patrols, resource extractors, vendor rights, or security changes.
- Influence should decay without activity.
- Claimed points should create passive or semi-passive economy output, but only
  with upkeep and vulnerability.
- Conflict should have clear consent/security rules.

This is not an immediate next feature, but early resource/mission/travel data
must be shaped so territory can consume it later.

### 6.6 Player Cities

SW_MUSH Guide 12 is excellent design material:

- Cities are named places owned by organizations.
- They aggregate identity.
- They collect tax.
- They improve security for citizens.
- They provide home/return convenience.
- They create mayor/founder/citizen/guest/outsider/banished roles.
- They expand slowly.
- They produce politics.

MMO translation:

- A city is a placed settlement footprint, not a menu.
- City rooms become districts, lots, interiors, vendors, clinics, cantinas,
  landing pads, workshops, security posts, and housing.
- City tax should apply to commerce within its boundary.
- City services should create convenience but not replace the world.
- Citizen benefits should be meaningful.
- Mayor controls should be visible and political.

Do not build this before the economy exists. But design the economy and vendors
so cities can tax them later.

### 6.7 Medical And Death

SW_MUSH Guide 19 is exactly the kind of non-combat role the MMO needs:

- Wound ladder.
- Healing by other players.
- Medic rates.
- Stims.
- Bacta.
- Death consequences.
- Corpse recovery.
- Wound-state debuff.
- Crafted bacta packs and stims.

MMO translation:

- Wounds should visibly affect player performance.
- Medpacs and stims must be item instances.
- Medics should be paid by patients or mission/faction budgets.
- Combat players should create demand for medics.
- Crafters should create demand for chemicals/organics and produce medical goods.
- Death should be forgiving but costly: time, wound state, recovery, gear risk.

The current crafted medpac must become the first bridge from crafting into real
combat/medical gameplay.

### 6.8 Director AI

SW_MUSH Guide 26 gives the living-world pattern:

- Track faction influence by zone.
- Compute alert levels.
- Trigger world events.
- Refresh ambient text.
- Write news headlines.
- Reward narrative-rich play when provider is active.
- Run a faction turn every 30 minutes.

MMO translation:

- Director is a server-side rules layer, not necessarily an LLM at first.
- It should read telemetry and game state.
- It should produce data: active events, alert levels, spawn modifiers, economy
  modifiers, news entries, and ambient strings.
- The first implementation can be deterministic/procedural.
- Later, AI can help write flavor and summarize events.

The Director should not control players. It should create opportunities and
pressure.

### 6.9 Scenes, Places, Plots, Intel

SW_MUSH has valuable social infrastructure:

- Places allow a busy cantina to support multiple conversations.
- Scenes archive what happened.
- Plots link scenes into arcs.
- Intel turns information into a trade good.
- Espionage gives non-combat players useful things to do.

MMO translation:

- Cantina booths, tables, bars, clinics, and back rooms should have named sockets
  and interaction zones.
- Local chat can eventually support table/say/whisper scopes.
- Scene logs can become lightweight session summaries.
- Intel can become a crafted/traded document item.
- Investigation and scanning can reveal clues, contraband, faction affiliation,
  route data, or bounty hints.

This is not fluff. This is how a social sandbox generates stories between
combat missions.

## 7. Gap Closure 2 Implementation Orders

The next implementation pass should be a single connected economy/travel loop.

### 7.1 Primary Deliverable: The First Real Player Economy Loop

Target player story:

> A scout surveys a mineral deposit outside a settlement, harvests good-quality
> metal, sells it through a market or directly to a crafter. The crafter uses a
> learned schematic and a WEG D6 roll to craft blaster power packs or a basic
> blaster component. Another player buys the crafted item and uses it in combat
> or space. The transaction persists, is visible in telemetry, and creates a
> reason to repeat the loop tomorrow.

Minimum path:

1. Survey resource with server-owned roll.
2. Harvest resource into a resource-stack item.
3. Craft item from schematic data.
4. Create item instance with provenance.
5. List or transfer item.
6. Another character buys or receives it.
7. Another character uses it.
8. Telemetry records the loop.
9. Smoke tests cover the loop.

This is the single most important gap.

### 7.2 Data Files To Add

Complete and harden data definitions before adding more code constants.

The current pass has started resource and schematic data. The next pass should
complete that lane and add the remaining data contracts:

- `data/resources_clone_wars.json`
- `data/resource_spawns_clone_wars.json`
- `data/schematics_clone_wars.json`
- `data/item_templates_clone_wars.json`
- `data/markets_clone_wars.json`
- `data/mission_templates_clone_wars.json`
- `data/space_routes_clone_wars.json`
- `data/factions_clone_wars.json`

These do not need to be huge. They need to be real and expandable.

Initial resources:

- ferrous_metal
- nonferrous_metal
- silicate
- chemical_compound
- organic_tissue
- energy_crystal
- electronic_parts
- rare_alloy
- starship_salvage
- medical_biogel

Initial schematics:

- basic_medpac
- field_stimpack
- blaster_power_pack
- basic_blaster_cell
- blaster_pistol_service_kit
- ship_patch_kit
- sensor_spike
- datapad_intel_report
- ration_pack
- survey_probe

Initial item templates:

- Resource stack.
- Consumable.
- Ammo/power pack.
- Weapon service kit.
- Ship repair kit.
- Intel document.
- Cargo crate.
- Schematic.
- Survey tool.
- Medical stim.

The exact names can change. The point is to establish the taxonomy.

### 7.3 Item Instance Model

Add a real item instance contract.

Every item instance needs:

- `instance_id`
- `template_id`
- `display_name`
- `owner_id`
- `container_id`
- `stack_count`
- `quality`
- `condition`
- `max_condition`
- `created_at`
- `created_by`
- `source_resources`
- `legal_status`
- `mass`
- `volume`
- `tags`
- `stats`
- `tradeable`
- `bound`

Resource stacks need:

- `resource_type`
- `quantity`
- `quality`
- `origin_zone`
- `survey_seed`
- `harvested_by`
- `harvested_at`

Crafted items need:

- `schematic_id`
- `crafter_id`
- `craft_roll`
- `craft_margin`
- `experiment_level`
- `components_used`
- `quality_tier`

This should not be buried in string inventory names.

### 7.4 Crafting Resolution

Crafting must use WEG D6 outcomes.

Recommended outcome table:

| Result | Condition | Resource Consumption | Output |
| --- | --- | --- | --- |
| Critical success | Wild die explosion and success | consumed | high quality, crafter stamped |
| Success | roll >= difficulty | consumed | normal quality, crafter stamped |
| Partial success | miss by 1-4 | consumed | poor quality or damaged output |
| Failure | miss by 5+ | not consumed | no output |
| Fumble | wild die complication | consumed or damaged | no output or flawed item |

Quality calculation:

1. Weighted average input quality.
2. Skill margin multiplier.
3. Schematic difficulty modifier.
4. Optional facility/tool bonus later.
5. Clamp 1-100.

Quality must affect real stats.

Examples:

- Medpac quality affects wound-heal bonus, uses, and failure risk.
- Power pack quality affects shots, misfire chance, or recharge efficiency.
- Repair kit quality affects repair margin bonus and condition restored.
- Ship patch quality affects hull restored and failure complication chance.

### 7.5 Survey And Harvest

Survey should stop being a random faucet.

Minimum implementation:

- Server receives survey request with current zone, selected resource category,
  player skill, and tool state.
- Server rolls Search or Survey skill.
- Zone resource table chooses eligible deposits.
- Roll margin affects quality, distance, and clarity.
- Deposit has a temporary id.
- Deposit can be harvested only if valid and within TTL.
- Harvest adds resource stack item instances.
- Better tools or skills improve yield and reduce failed harvests.

Resource tables should vary by zone:

- city/industrial: chemical, electronic, energy
- desert/frontier: silicate, metal, organic
- battlefield: scrap, droid parts, rare alloy
- space asteroid: ore, ice, rare alloy
- salvage field: starship_salvage, electronic_parts
- clinic/cantina economy: demand for medical goods, not raw resources

Do not require a full planetary ecology yet. Require enough variation that
players choose where to go.

### 7.6 Market And Trade

The loop needs a way for one player to benefit from another.

Minimum market:

- Local market terminal in one hub.
- List item for price.
- Buy listed item.
- Cancel listing.
- Persist listings.
- Transfer item ownership.
- Charge small listing fee or sales tax.
- Telemetry: listed, sold, canceled, price, template, quality.

Do not overbuild auction houses yet.

But do design the market so future player vendors and city taxes can use it.

Market listing fields:

- listing_id
- seller_id
- item_instance_id
- price
- location_id
- created_at
- expires_at
- status
- tax_context

Market UI must show:

- item name
- quality
- quantity
- condition
- crafter
- price
- location

### 7.7 Crafted Item Use

At least three crafted item types must be usable in real loops:

1. Medpac or field stim.
2. Blaster power pack or ammo cell.
3. Ship patch kit or sensor spike.

Usage must:

- Consume or decrement the item instance.
- Be server-authoritative.
- Apply WEG roll if appropriate.
- Affect real gameplay state.
- Persist state.
- Emit telemetry.
- Have a smoke test.

This is the bridge from "crafting exists" to "crafting matters."

### 7.8 Server-Owned Travel

The current space beacon work should be preserved as visual presentation, but
travel authority must move server-side.

Minimum travel state:

- character current_world_state: ground, dock, ship, orbit, route, space_zone
- current_planet
- current_location_id
- active_ship_id
- destination
- travel_started_at
- travel_arrives_at
- cargo_manifest

Launch flow:

1. Player at starport/dock.
2. Server checks ship ownership/rental/boarding.
3. Server checks ship condition and cargo legality if relevant.
4. Server moves player to ship/orbit state.
5. Client renders orbit/space view.

Hyperspace flow:

1. Player selects destination.
2. Server checks route.
3. Server rolls Astrogation.
4. Success sets travel state and arrival timer.
5. Failure may misjump, delay, damage, or attract encounter.
6. Arrival moves ship to destination orbit.

Landing flow:

1. Player requests landing.
2. Server checks orbit/dock permission/security.
3. Server runs patrol/customs if needed.
4. Server moves player/cargo to dock/ground state.

Do not keep adding destinations until this state exists.

### 7.9 Ship Cargo And Space Resource Loop

Space must feed the economy.

Minimum:

- Ship has cargo capacity.
- Cargo crates and resource stacks have mass/volume.
- Asteroid/salvage contacts can produce resource stack items.
- Ship cargo persists.
- Dock markets can buy/sell cargo.
- Smuggling cargo has legality risk.
- Route risk varies by faction/security/Director state.

First playable story:

> A pilot mines or salvages starship scrap, lands at a frontier port, sells it to
> a crafter, and that crafter builds a ship patch kit used by another pilot.

That is SWG. That is WEG D6. That is better than a hundred visual beacons.

### 7.10 Medical Demand Loop

Make medics matter early.

Minimum:

- Wound levels visible in HUD/sheet.
- Medpac item instance can heal one step or provide a roll bonus.
- Field stim can grant a temporary dice bonus with risk.
- Medic skill affects healing.
- Patient can pay a medic.
- Crafted medpacs/stims are superior to generic vendor items.
- Death or severe wounds create real demand for medical goods.

Do not make all healing free and instant. The game needs recovery friction.

### 7.11 Faction And Director Hooks

Add small hooks now, full systems later.

Every mission, market sale, smuggling delivery, bounty, medical service, and
space salvage should be capable of emitting:

- faction_id
- zone_id
- influence_delta
- economy_delta
- event_tags

This can initially be telemetry only. But the data shape should prepare for:

- Republic/CIS/Hutt influence.
- Director events.
- alert levels.
- resource spawn modifiers.
- mission board modifiers.
- patrol risk modifiers.
- city tax and territory claims.

Do not bolt this on later if the data model can carry it now.

## 8. Antigravity Acceptance Checklist

For Gap Closure 2 to count, Antigravity should deliver:

### Required Data

- Resource definitions in data files.
- Resource spawn tables in data files.
- Schematic definitions in data files.
- Item template definitions in data files.
- At least one local market definition.
- At least one server-owned route/travel definition if travel is touched.

### Required Code

- Item instance creation and ownership transfer.
- Resource stack item instances.
- Crafting from data-driven schematics.
- Survey from data-driven resource tables.
- Market list/buy/cancel.
- Crafted item use for at least medpac and power pack.
- Server-owned travel state if travel is touched.
- Telemetry events for survey, harvest, craft, listing, sale, item use.

### Required UI

- Resource inventory view.
- Schematic/crafting view that reads data, not code constants.
- Item inspection view showing quality, condition, crafter, and stats.
- Market view with list/buy/cancel.
- Clear success/failure feedback for D6 craft and use rolls.
- If travel is touched: route status and server-owned destination display.

### Required Tests

Add focused smokes. Suggested names:

- `scripts/tests/item_instance_model_smoke.gd`
- `scripts/tests/resource_survey_harvest_smoke.gd`
- `scripts/tests/crafting_data_schematic_smoke.gd`
- `scripts/tests/crafted_item_use_smoke.gd`
- `scripts/tests/player_market_smoke.gd`
- `scripts/tests/economy_loop_smoke.gd`
- `scripts/tests/server_travel_state_smoke.gd` if travel is touched
- `scripts/tests/ship_cargo_salvage_smoke.gd` if space economy is touched

Do not rely only on broad data smoke.

### Required Telemetry

At minimum:

- survey_requested
- survey_completed
- harvest_completed
- craft_attempted
- craft_completed
- item_instance_created
- market_listing_created
- market_listing_sold
- item_used
- travel_requested
- travel_completed
- cargo_loaded
- cargo_unloaded

Telemetry should allow us to answer:

- What are players producing?
- What are players buying?
- Which resources are valuable?
- Which schematics are used?
- Are credits inflating?
- Are crafted items entering combat/medical/space loops?

## 9. Playtest Scripts

Antigravity should prove systems through playtest scripts, not screenshots.

### 9.1 Two-Player Crafting Economy Test

Actors:

- Player A: scout/surveyor.
- Player B: crafter.
- Optional Player C: combat or medical consumer.

Flow:

1. Player A surveys a frontier zone.
2. Player A finds a metal or organic deposit.
3. Player A harvests resource stack items.
4. Player A lists resources on market.
5. Player B buys resources.
6. Player B crafts medpac or power pack from schematic.
7. Player B lists crafted item.
8. Player C buys crafted item.
9. Player C uses it in combat/medical loop.
10. Telemetry shows full chain.

Pass condition:

- The item used by Player C has provenance back to Player A's resource stack and
  Player B's crafting roll.

### 9.2 Space Cargo Economy Test

Actors:

- Pilot.
- Crafter.

Flow:

1. Pilot launches from a dock.
2. Pilot travels to an asteroid/salvage contact.
3. Pilot extracts salvage into ship cargo.
4. Pilot travels to a port.
5. Pilot lands.
6. Pilot sells salvage to market or crafter.
7. Crafter builds ship patch kit.
8. Pilot buys and uses patch kit on ship condition.

Pass condition:

- Ship cargo, location, salvage, sale, crafted kit, and repair all persist.

### 9.3 Medic Economy Test

Actors:

- Combat player.
- Medic/crafter.

Flow:

1. Combat player gets Wounded.
2. Medic crafts medpac/stim.
3. Combat player buys or pays for treatment.
4. Medic uses item and skill roll.
5. Wound state changes.
6. Credits transfer.
7. Item use is consumed/decremented.

Pass condition:

- The medic can earn money without killing anything.

### 9.4 Smuggling Seed Test

Actors:

- Smuggler/pilot.

Flow:

1. Player accepts contraband cargo job.
2. Cargo crate is created and loaded.
3. Player launches.
4. Patrol risk is checked.
5. Player rolls Con/Sneak/Astrogation as appropriate.
6. Player lands at destination.
7. Delivery completes or cargo is confiscated/fined.

Pass condition:

- Cargo exists as an item, not a flag.
- Fine/reward and faction influence hooks fire.

### 9.5 Faction Influence Seed Test

Actors:

- Republic player.
- CIS or Hutt-aligned activity.

Flow:

1. Player completes faction mission in a zone.
2. Influence telemetry records zone/faction delta.
3. A dashboard or debug view shows influence changed.
4. Director seed logic can read the changed value.

Pass condition:

- The game can later turn this into alert levels, patrols, and news without
  rewriting mission completion.

## 10. What Antigravity Should Not Do Next

Do not:

- Add ten more resource names to `crafting_model.gd`.
- Add more destinations while travel is client-owned.
- Add more UI panels that mutate local state only.
- Treat generated/doc asset paths as production runtime dependencies.
- Add new planet content before the economy loop works.
- Add faction badges without influence and reputation hooks.
- Add player cities before markets/vendors/taxes exist.
- Add more combat encounters without medical/equipment demand.
- Add another "press key, receive reward" system.
- Replace WEG D6 rolls with arbitrary success chances.
- Let credits, item ownership, cargo, or travel be client-authoritative.

## 11. How To Use SW_MUSH Without Becoming SW_MUSH

Copy:

- Tables.
- Thresholds.
- Pay ranges.
- Risk tiers.
- Wound ladders.
- Influence thresholds.
- City roles.
- Mission lifecycle.
- Crafting outcome logic.
- Space route structures.
- Director event categories.

Do not copy:

- Text-command UX as the primary player experience.
- GCW faction labels without CW translation.
- Room-only assumptions that ignore 3D space.
- Staff-run workflows that should become UI or simulation.
- Systems that require prose RP to function before the game has mechanical play.

Translation examples:

- `survey` command becomes survey tool mode, world interaction, and result panel.
- `faction claim` becomes a placed beacon/terminal/structure claim interaction.
- `+city tax set` becomes mayor terminal UI.
- `bounty claim` becomes terminal contract plus tracked target marker.
- `eavesdrop` becomes proximity/listen/sensor action with risk feedback.
- `+intel` becomes a sealed datapad item that can be traded.
- `hyperspace <destination>` becomes server-owned route selection and transit.

## 12. Design Expectations By System

### Combat

Combat should remain WEG D6:

- Initiative from Perception.
- Actions with multi-action penalty.
- Dodge/parry/cover.
- Damage vs soak.
- Wound ladder.
- CP and Force Point hooks.
- Stun mode.

For beta, combat must also create economy demand:

- Ammo/power packs.
- Weapon degradation.
- Armor condition.
- Medical goods.
- Repair services.
- Bounty contracts.
- Faction reputation.
- Loot/salvage.

Combat without logistics is not SWG.

### Crafting

Crafting should become a career:

- Surveyors find resources.
- Crafters learn schematics.
- Skill and resource quality matter.
- Experiments can improve or damage output.
- Crafted items carry creator identity.
- Best items come from player effort, not vendors.
- Markets make quality legible.

Crafting must not be reduced to "click medpac."

### Harvesting

Harvesting should be a scouting/exploration profession:

- Different zones have different resources.
- Resource quality varies.
- Survey margin matters.
- Deposits have distance/density.
- Travel to good deposits matters.
- Dangerous zones have better resources.
- Resource rushes and Director events can create temporary hotspots.

Harvesting must not remain a random resource button.

### Economy

Economy should be legible:

- Players know where to buy and sell.
- Quality affects price.
- Credits have sinks.
- NPC vendors establish baseline, not best-in-slot.
- Player vendors/markets are better for quality.
- Taxes/upkeep remove credits.
- Missions inject credits.
- Repair, travel, medical, guild dues, and city upkeep consume credits.

The economy should be tuned for private/friends scale, not thousands of users.
Small-player economy needs NPC demand and market seeding, but not so much that
players become irrelevant.

### Space

Space should be a career, not a loading screen:

- Pilot transports cargo.
- Pilot mines/salvages.
- Pilot fights or flees.
- Navigator/engineer/gunner roles can grow later.
- Ships need repair and parts.
- Space resources feed ground crafters.
- Ground missions can send players to space.
- Space missions can require ground delivery.

The first version can be simple, but the data model must point toward full
space careers.

### Medical And Social

Medical and social play must matter:

- Wounds need treatment.
- Medics can earn credits.
- Cantinas are recovery, hiring, rumor, and mission spaces.
- Entertainers can eventually buff recovery, morale, or CP gain.
- Places/booths let groups talk privately in public spaces.
- Social play feeds Director and faction stories.

The cantina should become a gameplay hub, not just a pretty room.

### Faction And Territory

Faction play should be layered:

- Reputation unlocks ranks.
- Ranks unlock permissions and equipment.
- Actions shift influence.
- Influence shifts security, events, patrols, and opportunities.
- Territory claims create visible power.
- Cities become long-term faction artifacts.

Factions should create civic and economic gameplay, not just PvP flags.

### Director

The Director should start as deterministic simulation:

- Observe events.
- Update influence.
- Trigger occasional world events.
- Publish news.
- Modify spawn/resource/mission/economy parameters.

Later it can use AI for summaries or ambient flavor. The first useful version is
not an LLM. It is a server rules loop that makes player actions echo.

## 13. Prioritized Next Work

If Antigravity asks "what exactly should I do next?", the answer is:

### Priority 1: Item Instance Foundation

Build the item instance model, resource stacks, and ownership transfer.

No more serious economy work should happen before this.

### Priority 2: Data-Driven Resources And Schematics

Move resource and schematic definitions out of code into data.

Start small but real:

- 8-10 resource types.
- 8-10 schematics.
- 3 item categories: medical, ammo, repair.

### Priority 3: Crafting Quality Affects Use

Make crafted medpacs, stims, power packs, and repair kits usable.

Quality must alter actual effect.

### Priority 4: Local Market

Let one player sell to another.

Do this before adding player vendors. Market first, vendors later.

### Priority 5: Server-Owned Space Travel State

Replace client-only beacon jump with server-owned travel state.

Keep the visual transition. Move truth to the server.

### Priority 6: Ship Cargo And Salvage

Make space produce resources that crafting consumes.

### Priority 7: Medical Economy

Make wounds and healing create repeat demand.

### Priority 8: Mission Board Consumes Economy

Mission terminals should create demand for goods and routes.

Examples:

- Republic needs 5 field stims at outpost.
- Hutt broker needs contraband delivered to Nar Shaddaa.
- CIS agent pays for sensor spikes.
- Clinic pays premium for medical biogel.
- Shipyard buys starship salvage.

### Priority 9: Faction Influence Hooks

Add influence telemetry and minimal dashboard.

### Priority 10: Director Seed

Run a deterministic faction/economy turn that can publish one news item and one
temporary modifier.

## 14. Suggested Data-Driven Vertical Slice

Build this exact slice:

### "Supply The Frontier Clinic"

Setting:

- A frontier settlement clinic in a contested Clone Wars zone.
- Republic patrols need medical supplies.
- Hutts profit from black market medpacs.
- CIS droids occasionally raid supply lines.

Roles:

- Scout surveys organic/chemical resources.
- Crafter makes field medpacs.
- Medic uses or sells medpacs.
- Pilot can haul a clinic supply crate.
- Combat player gets wounded and buys treatment.
- Faction player earns Republic or Hutt reputation by supplying the clinic or
  diverting supplies.

Loop:

1. Clinic mission board posts a supply contract.
2. Scout finds organic/chemical resource.
3. Crafter produces field medpacs.
4. Market or direct trade moves medpacs to medic/clinic.
5. Delivery pays credits and faction rep.
6. Clinic stock increases.
7. Wounded players can pay for treatment.
8. Director sees clinic supplied and reduces local medical scarcity.

Why this is strong:

- It uses survey.
- It uses crafting.
- It uses item instances.
- It uses market/trade.
- It uses medical gameplay.
- It uses faction rep.
- It creates a visible world effect.
- It is Clone Wars flavored.
- It is not just combat.

This should be the next "complete" playable beta loop.

## 15. Documentation Expectations For Antigravity

When Antigravity completes the next pass, it should write or update:

- A short implementation summary in `docs/antigravity`.
- A data contract note for resources/items/schematics.
- A playtest transcript or checklist for the economy loop.
- A known gaps section.
- A "designer questions" section if it made judgment calls.

It should explicitly say:

- What is server-authoritative.
- What is persisted.
- What is still temporary.
- What tests were added.
- What user story is now playable.
- Which prior gap closure items are actually closed.

## 16. Designer Review Rubric

I will judge the next pass using this rubric:

| Area | Passing Standard |
| --- | --- |
| Item model | Items are instances with ownership, quality, condition, provenance |
| Crafting | Data-driven schematics, WEG outcomes, quality affects use |
| Resources | Data-driven spawns, zone variation, D6 survey effect |
| Economy | One player can sell useful crafted goods to another |
| Medical | Crafted medical item can affect wound/recovery loop |
| Space | If touched, travel truth is server-owned |
| Cargo | If touched, cargo is itemized and persists |
| Factions | Actions can emit faction/influence hooks |
| UI | Player can understand quality, price, and use |
| Tests | Focused smokes cover the loop |
| Telemetry | Loop can be audited |
| Design feel | Feels like CW-era SWG/WEG, not a generic survival game |

## 17. Signs The Next Pass Is Going Wrong

Stop and correct if:

- Craft outputs are still plain strings.
- Market listings sell template names instead of item instances.
- Quality still does not affect gameplay.
- Survey still ignores zone tables.
- Space jumps still only change client visuals.
- Travel changes location without ship/cargo state.
- Medical items heal without skill or consequence.
- New data is hard-coded into model scripts.
- UI grows while persistence stays shallow.
- Tests only check file load, not loop behavior.
- Antigravity declares "crafting done" after adding more schematics.

This project has enough surfaces. It needs connective tissue.

## 18. The Desired Player Feeling

After Gap Closure 2, a player should be able to say:

- "I found a good deposit and my friend wanted it."
- "This medpac is better because another player made it well."
- "I bought power packs from a crafter before a fight."
- "The market has prices I can understand."
- "Space salvage is worth doing because crafters buy it."
- "I need to go back to town because I am wounded."
- "The clinic feels supplied because players supplied it."
- "The war economy is starting to show."

Those sentences matter more than feature names.

## 19. Final Instruction To Antigravity

Build fewer systems, but make them touch.

The next milestone is not "more beta roadmap checkboxes." It is the first
complete sandbox dependency loop:

> resource -> crafted item -> player trade -> player use -> world/economy effect

Everything else in the beta roadmap becomes easier once that loop exists.

If there is a design ambiguity, choose the option that makes players need each
other more.

If there is an implementation ambiguity, choose the option that keeps truth on
the server and data out of hard-coded scripts.

If there is a content ambiguity, choose Clone Wars frontier sandbox over
nostalgia-only SWG imitation.

If there is a scope ambiguity, prefer one deeply playable loop over five shallow
panels.

That is the gap to close.
