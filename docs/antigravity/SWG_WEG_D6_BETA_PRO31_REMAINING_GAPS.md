# SWG WEG D6 Beta - Pro 3.1 Gap Review

Reviewer: Codex  
Implementer under review: Antigravity  
Date: 2026-07-05  
Context: owner switched Antigravity driving model from Flash 3.5 to Pro 3.1  
Validation observed: full `tools/check_project.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe"` passed with 24 Python tests, import, launch, 130 wired GDScript smokes, and 79 RPCs.

## 1. Short Verdict

The Pro 3.1-driven work is paying closer attention to the beta roadmap and the
gap-closure docs than the earlier surface-feature pass.

The strongest evidence is that the newest tree does not merely add UI buttons.
It adds the specific connective pieces called out in the first two beta gap
closure briefs:

- data-driven resources, resource spawns, schematics, markets, item templates,
  missions, factions, and space routes;
- a pure item-instance model with quality, condition, provenance, owner-ready
  fields, and source resources;
- a data-driven crafting model that consumes resource-stack item instances and
  outputs crafted item instances;
- focused smokes for crafting, survey/harvest, bazaar, item usage, and space
  travel wire behavior;
- server RPC seams for survey, harvest, craft, bazaar list/buy, launch/travel,
  space mining, cargo sale, and related client feedback;
- persisted bazaar listings in the server world state;
- telemetry hooks for survey, manual harvest, craft success/failure, bazaar
  list/buy, item use, and space cargo actions.

That is a meaningful shift. The work is now aimed at the beta spine:

```
resource -> crafted item -> player trade -> player use -> economy/world effect
```

It is not done yet. The remaining gaps are mostly integration depth, wire-level
proof, and product intent. The project has crossed from "feature nouns exist"
to "early dependency loops exist," but it has not yet proven the loops at the
same standard expected of a beta.

## 2. What Pro 3.1 Seems To Have Improved

### 2.1 It Followed The Gap Docs Literally

The prior gap docs asked for data-driven resources/schematics, item instances,
a bazaar/market, usable crafted items, survey upgrade, telemetry, and a
server-owned travel direction. Those exact artifacts now exist or have a first
implementation.

This suggests the model is reading the docs as implementation contracts rather
than general inspiration.

### 2.2 It Added Tests Beside Systems

The current gate runs 130 GDScript smokes. The new beta-facing systems are not
only compiling; they have focused smokes. That is a sharp improvement over the
earlier pattern where broad existing tests stayed green while new features were
only lightly exercised.

### 2.3 It Preserved The Green Bar

The earlier `bazaar_model.gd` typed warning called out in Gap Closure 2 has
been fixed. The full project gate is green. That matters because this repo's
standing discipline is that design momentum does not count if the baseline is
red.

### 2.4 It Is Moving Toward Player Interdependence

Survey, resource stacks, crafting, market listing, buying, crafted item use,
and cargo sale now point toward players needing one another. The design vector
is correct.

## 3. Remaining Gaps

### 3.1 Wire-Level Item Identity Is Still Fragile

The item-instance contract uses `instance_id` and `template_id`. Some older
live paths still search for `id` or `template_key`.

Observed risks:

- Bazaar listing in `network_manager.gd` looks for `item.get("id", "")`, but
  crafted item instances are created with `instance_id`.
- First Aid searches inventory dictionaries for `template_key == "medpac"`,
  while crafted medpacs are stored with `template_id == "medpac"`.
- The pure `item_usage_model.gd` correctly accepts either `template_key` or
  `template_id`, but the live First Aid path does not appear to use that shared
  helper.

Implication: the model-level smoke tests can pass while the live story "craft a
medpac, list it, buy it, and use it for First Aid" still fails or depends on
legacy item shapes.

Beta closure requirement:

- Normalize item identity across inventory, ammo, First Aid, bazaar, vendor,
  crafted outputs, and tests.
- Add one wire/composition smoke that uses a crafted `instance_id` item through
  the live list/buy/use path.

### 3.2 The Complete Economy Loop Is Not Yet Proven In One Test

There are focused smokes for the pieces, but the beta acceptance bar is one
complete loop:

```
survey -> harvest -> craft -> list -> buy -> use -> telemetry/persistence
```

The current tests prove important slices. They do not yet prove the whole loop
with two simulated characters and a real crafted item moving through ownership.

Beta closure requirement:

- Add `economy_loop_smoke.gd` or equivalent.
- It should create or simulate two characters, harvest a resource stack, craft
  a medpac or power pack, list by `instance_id`, buy it, transfer credits, then
  use the bought item.
- The pass condition should include item provenance surviving through the sale.

### 3.3 Crafted Power Packs Still Bridge Through Legacy Ammo Counts

Crafting creates an item instance, but the crafting model also increments
legacy `ammo.packs` for compatibility. That is practical, but it blurs the
beta direction.

Beta intent:

- A power pack should be an item instance first.
- Reload/use should consume an item instance.
- Legacy counters can remain as migration state, but they should not be the
  product truth for crafted ammo.

Beta closure requirement:

- Route crafted power packs through the same item-use contract as medpacs and
  repair patches.
- Keep a migration shim only where old character records require it.

### 3.4 Space Travel Is Better, But Still Not The Beta Travel Model

The new work adds server-side `space_state`, launch, destination changes, cargo,
mining, landing, and selling cargo. That is a real improvement over purely
client-side beacon visuals.

Remaining gap:

- There is still no full ship ownership/rental validation.
- Cargo appears as a simple dictionary, not itemized cargo/resource instances.
- Route costs, route risk, launch/dock permissions, customs/security checks,
  and ship condition constraints are still shallow.
- The smoke test simulates the state shape more than it proves a live RPC
  travel lifecycle.

Beta closure requirement:

- Treat space travel as server-owned character + ship + cargo state, not only
  a `space_state` block on the sheet.
- Itemize cargo so space salvage can move into the same market/crafting system.
- Add a live/server composition smoke for launch -> mine/salvage -> land ->
  sell/list/craft.

### 3.5 The UI Has Grown Faster Than Service Boundaries

The new `net_world.gd`, `unified_hud.gd`, dialogue overlay, map/space UI, and
market/crafting surfaces are useful for playability. The risk is that UI,
network orchestration, and feature logic are still concentrating in hot files.

Beta closure requirement:

- Do not stop feature work for architecture gardening, but extract when a
  beta loop needs reuse.
- Good next extraction targets are item inventory helpers, market view-model
  formatting, crafted item inspection, and travel state presentation.

### 3.6 Runtime Asset Hygiene Is Still Noisy

The full import passes, but Godot reports many UID duplicate warnings between
docs-generated assets and promoted runtime assets under `assets/3d/generated`.
This does not fail the gate today, but it confirms the asset pipeline still
needs a cleanup pass.

Beta closure requirement:

- Curated runtime assets should live in stable runtime folders.
- Docs folders should remain evidence/reference, not active duplicate import
  sources.
- Add or preserve an asset manifest that identifies which generated assets are
  actually runtime-approved.

### 3.7 Telemetry Names Need To Match The Economy Tally Contract

The telemetry hooks are good, but beta tuning depends on consistent event
semantics. Credit creation, destruction, and transfer must remain distinct.

Beta closure requirement:

- `bazaar_buy` should be treated as transfer, not faucet.
- Listing fee should be a sink.
- Space cargo sale should be classified as a faucet unless paired with travel,
  repair, docking, fuel, or market fees.
- Unknown credit-bearing event types must remain loud in
  `tools/telemetry_tally.py`.

## 4. What A Beta Means Under Pro 3.1

For Pro 3.1, "beta" should not mean "build the whole huge roadmap faster."
That would reward breadth over dependency.

Beta means the game can support a private group for weeks because the systems
create repeatable reasons to cooperate.

The Pro 3.1 beta intent is:

1. Build fewer loops, but make each loop complete.
2. Prefer one end-to-end player economy chain over five isolated panels.
3. Treat item instances as the backbone of crafting, markets, medical play,
   ammo, cargo, repair, and mission demand.
4. Treat server authority as the product boundary: no client-owned credits,
   inventory, travel truth, dice, or combat consequences.
5. Treat WEG D6 as the resolution layer: skills, difficulty, margin, Wild Die
   consequences, wounds, CP/FP, and tradeoffs should be visible where they
   matter.
6. Treat Clone Wars frontier pressure as the content lens: Republic supply,
   CIS droid logistics, Hutt black markets, neutral scouts/crafters/medics, and
   pilots moving goods through risky space.
7. Treat telemetry as design instrumentation, not merely logging.

The model should be rewarded for closing one player story:

> A scout finds useful resources. A crafter makes a quality item. Another
> player buys it. The item changes combat, medical, travel, or repair outcomes.
> Credits and items move through server-owned state. The world remembers.

That is a beta unit.

## 5. Next Pro 3.1 Acceptance Target

The next Antigravity pass should be named something like:

`BETA-P31-1: First Real Economy Loop`

Scope:

- Normalize item fields (`instance_id`, `template_id`) across live inventory,
  bazaar, ammo, First Aid, item use, and UI.
- Add one composition smoke for crafted item list/buy/use.
- Make crafted medpac use route through the same item-use model or equivalent
  shared semantics.
- Make crafted power packs consumable as item instances, with legacy ammo count
  compatibility clearly labeled.
- Add telemetry assertions for list fee sink, buyer/seller transfer, craft
  success, and item use.
- Add a short playtest checklist proving the user story.

Exit:

- Player A can harvest and craft.
- Player A can list a crafted item.
- Player B can buy it.
- Player B can use it in a real gameplay path.
- The item's provenance remains visible.
- The full gate is green.

## 6. Then Do The Space/Cargo Loop

Only after the economy item loop is truly closed, Pro 3.1 should take the next
beta unit:

`BETA-P31-2: Server-Owned Space Cargo Loop`

Scope:

- Ship ownership or rental proof.
- Launch/dock/land validation.
- Itemized cargo/resource stacks.
- One salvage/mining action producing cargo.
- Dock/land and move cargo into market/crafting.
- One repair/travel/docking sink paired with the cargo faucet.
- Composition smoke and telemetry.

Exit:

- Pilot can produce a useful economy input from space.
- Crafter can buy or use that input.
- Ship/cargo/location survive restart.

## 7. Review Rubric For Future Pro 3.1 Work

Use this before accepting any "done" claim:

| Question | Passing standard |
| --- | --- |
| Is truth server-owned? | Result, costs, dice, ownership, and persistence are server-side. |
| Is it data-driven? | Content lives in JSON/data definitions, not hard-coded lists. |
| Does it use item instances? | Tradeable/useful objects have ids, templates, quality, condition, owner, provenance. |
| Does it create interdependence? | Another player can buy, use, protect, repair, transport, or need the output. |
| Does quality matter? | Resource/craft quality changes real gameplay, not only display text. |
| Is there a sink with the faucet? | New credits/resources/items are paired with recurring costs or risk. |
| Is it covered end to end? | At least one smoke follows the loop across models/wire/persistence. |
| Is it Clone Wars? | Republic/CIS/Hutt/frontier framing, not old GCW defaults. |
| Is it beta, not demo? | The player gets a repeatable reason to do it tomorrow. |

## 8. Bottom Line

The model switch appears beneficial. Pro 3.1 is responding to the beta roadmap
and gap-closure docs with more structurally relevant work: item instances,
data-driven crafting, markets, smokes, telemetry, and early server-owned travel.

The remaining risk is that it will declare victory at "all parts exist" rather
than "the player dependency loop is real." Keep the beta bar strict:

```
not feature exists -> loop works
not UI exists -> server truth persists
not item created -> item traded and used
not space visual -> ship/cargo/travel economy
not green pieces -> green end-to-end story
```

If Pro 3.1 keeps closing the loop instead of widening the checklist, it is the
right driver for the beta push.
