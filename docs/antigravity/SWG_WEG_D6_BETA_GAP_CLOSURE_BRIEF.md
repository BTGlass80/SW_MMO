# SWG WEG D6 Beta Gap Closure Brief

Designer: Codex  
Implementer: Antigravity  
Purpose: clarify why the fast alpha/beta implementation is promising but not
yet meeting the intended gameplay bar  
Validation observed: full `tools/check_project.ps1` passed after the current
implementation pass; 124 wired GDScript smokes, 24 Python tests, RPC surface 63  

## 1. Verdict

The recent work is technically impressive and directionally useful.

It did **not** fully meet the design intent.

That is not because it is broken. It passed the project gate. The issue is that
it implemented the *surface shape* of several roadmap items faster than it
implemented the *gameplay dependencies* that make those items matter.

What it accomplished well:

- Added server-authoritative RPC seams for survey, harvest, and craft.
- Added a client crafting panel.
- Added a small deterministic resource/crafting model.
- Added space beacons and a visible hyperjump-style overlay transition.
- Improved space presentation with isometric orthographic camera framing.
- Added asteroid/resource contacts to the space tactical data.
- Preserved the project test gate.

What it did not yet accomplish:

- It did not create a real SWG-like crafting economy.
- It did not create a data-driven resource simulation.
- It did not create item instances/provenance.
- It did not create player-to-player economic dependency.
- It did not make space travel server-authoritative.
- It did not connect ground-to-space cargo, ship state, docking, or travel costs.
- It did not promote generated assets into runtime asset manifests.
- It did not add focused smoke tests for the new survey/craft/travel systems.

This is the difference between "feature exists" and "gameplay exists."

## 2. Why The Previous Roadmaps Were Too Easy To Misread

The alpha and beta roadmaps said things like:

- Add survey.
- Add crafting.
- Add space travel.
- Add economy.
- Add player vendors.

Antigravity interpreted that as "make the player able to press keys and receive
the named result." That is a reasonable implementation interpretation, but not
the product intent.

For this project, a system only counts when it has all of these:

1. Data definition.
2. Server authority.
3. Persistence.
4. Player-facing UI.
5. Gameplay cost or risk.
6. Gameplay reward.
7. Economic or mission linkage.
8. Telemetry or audit visibility.
9. Smoke coverage.
10. A reason another player would care.

If a feature has only buttons and local feedback, it is a demo.

If a feature has server state but no economy/mission/player dependency, it is a
mechanical proof.

If a feature has persistence, costs, rewards, interdependence, tests, and repeat
value, it is gameplay.

## 3. Observed Implementation Gaps

### 3.1 Crafting

Current shape:

- `scripts/rules/crafting_model.gd` has two hard-coded schematics:
  `medpac` and `power_pack`.
- Inputs are three hard-coded resource types:
  `animal_hide`, `silicate_sand`, `copper_ore`.
- Output is either a string in inventory or an ammo-pack count.
- Average input quality is calculated, but it does not meaningfully alter item
  stats beyond a medpac display name.
- There is no schematic data file.
- There is no item-instance model.
- There is no crafted provenance.
- There is no player vendor or bazaar connection.
- There is no dedicated smoke test for the crafting model or wire flow.

Intent gap:

This is a good "hello world" crafting loop. It is not SWG-style crafting yet.

Crafting must produce items players want, with quality differences that affect
actual gameplay. A crafted medpac should have potency/uses/condition/provenance.
A crafted power pack should be an item stack or inventory commodity, not only a
counter mutation. Weapon, armor, droid, ship, and structure crafting must grow
from the same data-driven contract.

### 3.2 Survey And Harvest

Current shape:

- Survey randomly returns one of three resource types.
- Zone is passed into `roll_survey`, but the zone does not appear to change the
  resource table.
- Survey does not require a tool, skill roll, category choice, or map location.
- Harvest consumes the last survey result and adds three units.
- There is no resource depletion, density, spawn duration, rotation, or harvester
  object.

Intent gap:

Surveying should become a playstyle. Players should search for resource
deposits, compare quality, share coordinates, deploy harvesters, and feed
crafters. The current version is an instant random faucet.

### 3.3 Item Instances

Current shape:

- Some outputs are plain strings or counters.
- Resource stacks live directly on the sheet as aggregate counts/quality.

Intent gap:

Beta economy requires item instances:

- Unique id.
- Template key.
- Name.
- Owner/container.
- Quantity or stack metadata.
- Quality.
- Condition.
- Crafter.
- Resource provenance.
- Modifiers.
- Created timestamp.
- Trade/vendor eligibility.

Without item instances, player vendors, bazaar, crafted quality, repair, and
equipment progression will all become brittle.

### 3.4 Economy

Current shape:

- The project already has strong vendor/economy foundations.
- The new crafting/survey pass does not yet connect to bazaar, player vendor,
  buy orders, sell orders, or meaningful crafted-item demand.

Intent gap:

Economy is not "player receives item." Economy is:

- Players can create value.
- Players can list value.
- Other players can discover and buy value.
- The game destroys credits through upkeep, repairs, taxes, travel, power,
  maintenance, and consumables.
- Telemetry can show whether the economy is inflating or starving.

### 3.5 Space Travel

Current shape:

- Added beacon contacts for Corellia, Nar Shaddaa, Kessel, etc.
- Successful astrogation in the overlay can call `_perform_system_jump`.
- `_perform_system_jump` changes client-side presentation title/system and
  planet positioning.
- This is visually exciting.

Intent gap:

This is not yet ground-to-space travel. It is a client-side space overlay state
change.

True travel needs:

- Server-owned current location.
- Ship ownership or rental.
- Launch permission.
- Docking/landing permission.
- Ship condition.
- Cargo.
- Fuel/travel fee or route cost.
- Mission/cargo validation.
- Persistence across reconnect.
- Arrival in a real ground or station destination.

### 3.6 Asset Runtime Hygiene

Current shape:

- Space presentation loads generated assets from `docs/google/...` and
  `docs/gpt/...`.
- This works for review but is not a clean runtime asset strategy.

Intent gap:

Curated runtime assets need stable paths and manifests. Docs folders are for
generation evidence, not runtime dependencies.

### 3.7 UI And Code Shape

Current shape:

- UI feel improved.
- `net_world.gd` is carrying more responsibilities.
- Some code reaches into `UnifiedHUD` internals such as `_left_panel`.

Intent gap:

The speed is impressive, but this will get hard to maintain. Beta needs services
and controllers, not one growing world script.

### 3.8 Test Coverage

Current shape:

- Full gate passes.
- New systems compile and do not break the existing suite.
- There are no obvious dedicated new smokes for the new crafting/survey wire
  path.

Intent gap:

No new gameplay system should count as accepted until it has:

- Pure model smoke.
- Data smoke.
- Wire/server composition smoke.
- Persistence smoke if it mutates character/world state.
- One happy path and at least two failure/edge paths.

## 4. Updated Acceptance Rule

From this point forward:

> A roadmap checkbox is not complete when a button exists. It is complete when a
> player loop exists.

For each feature, ask:

1. Can a player choose to do this?
2. Does the server own the result?
3. Does it persist?
4. Does it cost something or require skill/risk/time?
5. Does it produce a useful output?
6. Can another player benefit from or interact with that output?
7. Does it feed missions, economy, crafting, combat, travel, or social play?
8. Is it covered by smoke tests?
9. Is it visible in UI?
10. Is it logged enough to tune?

If the answer is no to most of these, the work is a prototype stub.

Prototype stubs are allowed, but they must be labeled as stubs.

## 5. Next Implementation Brief: Interdependence Pass 1

The next pass should not add five new systems. It should make the newly added
systems interlock.

Target:

> A player surveys a resource, harvests it, crafts a real item instance, lists
> it for sale, another player buys it, uses it, and the economy/persistence/tests
> prove the loop.

This is the smallest loop that starts to feel like SWG.

### 5.1 Data-Driven Resources

Add:

- `data/resources_clone_wars.json`
- `data/schematics_clone_wars.json`
- `data/crafting_categories_clone_wars.json` if helpful

Resource fields:

- `key`
- `name`
- `family`
- `subtype`
- `regions`
- `base_value`
- `survey_difficulty`
- `quality_stats`
- `spawn_weight`
- `commonality`

Quality stats:

- `conductivity`
- `durability`
- `malleability`
- `density`
- `potential_energy`
- `purity`
- `medicinal_value`

Acceptance:

- Survey result must come from the current zone/region resource table.
- Data smoke verifies all resource keys and quality stats.
- No hard-coded resource list in `crafting_model.gd`.

### 5.2 Data-Driven Schematics

Schematic fields:

- `key`
- `name`
- `category`
- `required_skill`
- `difficulty`
- `station_type`
- `requires`
- `output`
- `quality_formula`
- `certification`
- `economic_tags`

Minimum schematics:

- `medpac_basic`
- `power_pack_standard`
- `armor_patch_basic`
- `survey_tool_basic`
- `camp_kit_basic`
- `ship_repair_patch_basic`

Acceptance:

- Crafting model reads schematics from data.
- Crafting model has a pure smoke test.
- Unknown schematic fails.
- Insufficient resource fails.
- Failed roll consumes either nothing or a documented partial cost.
- Successful craft creates a real item instance.

### 5.3 Item Instance Model

Add a pure model for item instances.

Required item instance fields:

- `id`
- `template_key`
- `name`
- `kind`
- `quantity`
- `quality`
- `condition`
- `max_condition`
- `crafter_id`
- `resource_inputs`
- `modifiers`
- `created_unix`
- `tradeable`

Acceptance:

- Crafted medpac is not a string.
- Crafted power pack is not only a counter.
- Inventory can hold item instances.
- Vendor/bazaar can list item instances.

### 5.4 Bazaar Or Simple Player Market

Do not wait for full player vendors. Add a simple bazaar first.

Required:

- List item instance.
- Set price.
- Search/list active listings.
- Buy listing.
- Transfer item.
- Transfer credits.
- Charge tax/listing fee.
- Persist listing.

Acceptance:

- Player A crafts item.
- Player A lists item.
- Player B buys item.
- Player B inventory contains the item.
- Player A receives credits minus fee.
- Listing disappears.
- Restart preserves unsold listings.

### 5.5 Usable Crafted Items

At least two crafted outputs must affect gameplay.

Required:

- Crafted medpac works with medical/recovery flow.
- Crafted power pack works with ammo flow.

Better:

- Armor patch works with armor repair.
- Ship repair patch works with space damage-control.

Acceptance:

- Crafted medpac potency or quality changes recovery outcome, uses, or modifier.
- Crafted power pack adds usable ammo/packs.
- Crafted item usage is server-authoritative.

### 5.6 Survey Gameplay Upgrade

Minimum upgrade:

- Survey requires current zone.
- Survey returns resource, quality, density, and approximate direction/distance.
- Better survey roll improves detail.
- Survey result expires or can be replaced.

Better:

- Survey requires survey tool.
- Survey creates a waypoint/pin.
- Survey can be shared as a tradable report item.

Acceptance:

- Same zone and seed are deterministic.
- Different zones have different resource possibilities.
- Survey failure is possible.
- Survey quality matters.

### 5.7 Telemetry

Add telemetry events:

- `survey`
- `manual_harvest`
- `craft_attempt`
- `craft_success`
- `craft_failure`
- `bazaar_list`
- `bazaar_buy`
- `item_use`

Acceptance:

- Economy tally can distinguish credits created, transferred, and destroyed.
- Crafting does not create credits directly unless explicitly designed.

## 6. Next Implementation Brief: Ground-To-Space Authority Pass

After Interdependence Pass 1, fix space travel authority.

Target:

> A player launches from a starport, enters local orbit in a server-owned ship
> state, completes a space action or travel route, docks/lands at a destination,
> and persists location/ship/cargo.

### 6.1 Server-Owned Ship State

Add/persist:

- `active_ship_id`
- `ships`
- `ship.location`
- `ship.condition`
- `ship.cargo`
- `ship.components`
- `ship.docked_at`
- `ship.in_space`

### 6.2 Launch/Dock RPCs

Required RPCs:

- `submit_launch(ship_id, launch_point)`
- `submit_dock(target_id)`
- `submit_land(destination_id)`
- `submit_space_travel(beacon_id)`

Validation:

- Player owns/rents ship.
- Ship is at same location.
- Destination exists.
- Ship is not destroyed.
- Required fee/fuel/cargo state is valid.

### 6.3 Space Overlay Becomes View Over Server State

Current overlay state can remain, but it should receive authoritative state:

- Current system.
- Current ship.
- Contacts.
- Ship condition.
- Route/destination.

Client-side `_perform_system_jump` should become presentation only after server
approval.

### 6.4 Space Economy Link

Add one space economic loop:

- Asteroid mine/salvage -> cargo resource -> dock -> sell/list/craft.

Acceptance:

- Space-produced resource enters inventory/cargo.
- Cargo persists.
- Ground vendor/bazaar can sell it.
- Ship repair or travel fee creates a sink.

## 7. Specific Tests To Add

### 7.1 Crafting Model Smoke

File suggestion:

- `scripts/tests/crafting_model_smoke.gd`

Coverage:

- Loads resource data.
- Loads schematic data.
- Unknown schematic fails.
- Missing resources fail.
- Failed roll handled.
- Successful craft creates item instance.
- Quality affects output.
- Deterministic seed produces deterministic result.

### 7.2 Crafting Wire Smoke

File suggestion:

- `scripts/tests/crafting_wire_smoke.gd`

Coverage:

- Mirrors server flow: sheet + resources -> craft -> saved sheet.
- Inventory instance is present.
- Resources consumed.
- Ammo/med usage compatible with existing systems.

### 7.3 Survey Model Smoke

File suggestion:

- `scripts/tests/survey_model_smoke.gd`

Coverage:

- Zone-specific resources.
- Survey failure/success.
- Quality/density/direction.
- Determinism by seed.

### 7.4 Bazaar Model Smoke

File suggestion:

- `scripts/tests/bazaar_model_smoke.gd`

Coverage:

- List.
- Buy.
- Tax.
- Insufficient credits.
- Missing listing.
- Ownership transfer.

### 7.5 Space Travel Wire Smoke

File suggestion:

- `scripts/tests/space_travel_wire_smoke.gd`

Coverage:

- Launch valid.
- Launch invalid without ship.
- Travel valid.
- Dock/land valid.
- Destroyed ship cannot travel.
- Cargo persists.

## 8. What To Stop Doing

Stop treating roadmap nouns as completion criteria.

Bad:

- "Added crafting panel."
- "Added Corellia beacon."
- "Added resource scan."
- "Added bazaar button."

Good:

- "A crafted medpac is an item instance with quality, can be listed, bought by
  another player, used by the server recovery path, and survives restart."
- "A player ship launches from a real starport, travels to a server-approved
  beacon, consumes a cost, preserves cargo/condition, docks at destination, and
  reconnects there."
- "Survey results come from zone resource tables, require skill/tool validation,
  and feed harvesting/crafting/economy."

## 9. What To Keep Doing

Keep:

- Moving fast.
- Preserving server authority.
- Running the full gate.
- Improving presentation.
- Adding small playable loops.
- Keeping WEG D6 mechanics under the hood.
- Using voxel assets for foregrounds.
- Using space as isometric tactical, not full 6DOF sim.

Just add sharper acceptance gates so the speed creates game depth instead of a
larger checklist.

## 10. Immediate Priority Order

Do these in order:

1. Add data-driven resources and schematics.
2. Add item instance model.
3. Convert medpac/power_pack crafting to item instances.
4. Add crafting/survey smoke tests.
5. Add simple bazaar/player market.
6. Make crafted medpac/power pack usable by existing systems.
7. Add telemetry for survey/craft/list/buy/use.
8. Convert space hyperjump from client-side overlay state to server-approved
   ship travel.
9. Add ship cargo and one space salvage/mining resource loop.
10. Promote any runtime-used generated assets out of docs folders.

If those ten land, the game will cross an important threshold: players will be
able to create value for one another.

That is the missing ingredient.

## 11. Bottom Line

The recent work is good engineering momentum. It is not yet beta gameplay.

The next pass should be less about adding more named features and more about
closing loops:

- survey -> harvest -> craft -> list -> buy -> use
- launch -> travel -> salvage -> dock -> sell/craft -> repair
- mission -> consume crafted gear -> earn resources/credits -> buy from players

When those loops work, the project stops being a feature showcase and starts
becoming a sandbox.

