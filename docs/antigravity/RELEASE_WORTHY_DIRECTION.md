# Release-Worthy Direction For Antigravity

Reviewer: Codex  
Date: 2026-07-05  
Audience: Antigravity / Pro 3.1 driver  
Purpose: convert the current beta momentum into a release-worthy private MMO build.

## 1. Current Verdict

The latest Antigravity work is moving in the right direction. The full gate is
green:

- 24 Python tests.
- Godot import check.
- Godot runtime launch check.
- 132 wired GDScript smokes.
- 82 RPCs in `network_manager.gd`.

The work now includes the beta systems the prior roadmap/gap docs asked for:
data-driven resources, schematics, item templates, resource spawns, markets,
mission/faction/space route data, item instances, crafting, bazaar, item use,
server-owned space-state seeds, cargo, runtime asset manifest, and focused
smokes.

That is progress. But release-worthy is a different bar from beta momentum.

Release-worthy does not mean "more systems exist." It means a small private
group can install, connect, play, recover from normal failures, understand what
to do, and trust that the game will remember their progress.

From this point forward, Antigravity should stop widening the checklist and
start locking the game.

## 2. The Release-Worthy Standard

A private release build is acceptable when:

1. A new player can start without developer coaching.
2. Two to five players can play together for a full evening.
3. The main loop survives restart/reconnect.
4. Credits, inventory, wounds, ships, cargo, markets, and territory do not
   corrupt under normal play.
5. The economy telemetry correctly counts faucets, sinks, and transfers.
6. The UI exposes the systems players need without debug-only knowledge.
7. The server never trusts client-owned truth for credits, items, travel, combat,
   or dice.
8. The release has a known-issues list, admin recovery tools, and a playtest
   script.
9. The build is Clone Wars era and WEG D6-led.
10. The owner can hand it to friends and say: "log in and play this loop."

## 3. Immediate Direction

### Stop Adding Broad New Systems

Do not add:

- more planets;
- more professions;
- more combat families;
- more city/siege scope;
- more Force/Jedi scope;
- more space destinations;
- more visual asset dumps;
- more UI panels that do not close a release-blocking loop.

The current project has enough surface area. The release problem is cohesion,
not imagination.

### Lock Three Player Stories

Release work should target exactly these stories first:

1. New player first hour:
   create character -> spawn -> learn chat/HUD -> buy/equip/restock -> take a
   simple mission -> fight or survey -> return -> get reward -> spend CP.

2. Player economy:
   survey -> harvest -> craft item instance -> list -> buy -> use -> telemetry
   proves the credit/item flow.

3. Space cargo:
   launch owned/rented ship -> harvest/salvage cargo -> land/dock -> cargo moves
   into inventory or market -> pay docking/travel/repair sink -> persist.

Everything else is secondary until these are playable end to end.

## 4. Latest Review Findings

### 4.1 The Economy Loop Smoke Is Useful But Too Synthetic

`scripts/tests/economy_loop_smoke.gd` is the right kind of test, but it still
patches in resources and directly manipulates sheets. It proves model
compatibility more than live server behavior.

Release direction:

- Add a live composition test that mirrors the server flow, not only pure model
  calls.
- It should use the same inventory keys and RPC-facing item ids as the real
  client.
- It must prove a crafted `instance_id` can be listed, bought, persisted, and
  used.

### 4.2 First Aid Still Has A Legacy Item-Key Path

The generic `submit_use_item` path accepts item instances by `instance_id` and
uses `item_usage_model.gd`, which is good. But `submit_heal` still searches
only for dictionary items with `template_key == "medpac"` plus legacy string
items.

Crafted medpacs use `template_id == "medpac"`.

Release direction:

- Make First Aid accept the item-instance contract (`template_id`) or route it
  through the shared item-use model.
- Add a test proving a crafted medpac can be used by the live First Aid path.

### 4.3 Telemetry Tally Is Not Yet Release-Safe

`tools/telemetry_tally.py` now knows about bazaar transfer events and
`space_sell_cargo`, but the live event fields do not fully match:

- `space_sell_cargo` logs `credits_earned`, while the tally reads `price`.
- docking fees log `sink_fee` with `amount`, but the tally does not count
  `sink_fee`.
- `amount` is not in `CREDITY_FIELDS`, so an uncounted sink can avoid the loud
  unknown-credit warning.

That makes economy telemetry undercount live flows.

Release direction:

- Normalize credit event fields (`price`, `cost`, `amount`, or a documented
  schema) and update the tally.
- Count `sink_fee` as outflow.
- Either log `space_sell_cargo.price` or make the tally read `credits_earned`.
- Add a telemetry-tally unit test with bazaar fee, bazaar buy/sell transfer,
  space cargo sale, and docking fee.

### 4.4 Space Cargo Is Still A Release Seed, Not A Finished Loop

`scripts/tests/space_cargo_smoke.gd` proves the desired state mutation shape,
but it simulates launch/cargo/land locally. It does not prove the live RPC
lifecycle.

Release direction:

- Add a server composition smoke for launch -> space harvest -> land -> cargo
  transfer -> docking fee -> persistence.
- Validate ship ownership/rental and current location.
- Treat cargo as item instances, not only ad hoc dictionaries.
- Make cargo usable by crafting or market, not only sold for credits.

### 4.5 Asset Promotion Is Too Noisy For Release

`data/runtime_asset_manifest.json` exists, which is good. But it includes many
repeated ids such as `contact_sheet_all`, and the repo still contains a large
docs-generated asset mirror alongside runtime assets.

Release direction:

- Runtime manifests must use unique stable ids.
- Release runtime should load from `assets/`, not `docs/`.
- Docs-generated assets should be evidence/reference, not active runtime
  import churn.
- Add a data smoke that checks manifest id uniqueness and path existence.

### 4.6 Hot Files Are Too Large For Ongoing Feature Expansion

`network_manager.gd` and `net_world.gd` are carrying too much. Do not pause
release for broad refactors, but also do not keep adding feature scope into
them.

Release direction:

- Only extract where it directly reduces release risk.
- Good candidates: item lookup helpers, telemetry event helpers, travel-state
  helpers, and market/crafting UI view-model formatting.

## 5. Release Work Order

### R0: Release Freeze

Declare a feature freeze for the private release candidate.

Allowed:

- bug fixes;
- release-blocking tests;
- first-hour onboarding;
- persistence/reconnect fixes;
- telemetry correctness;
- admin/recovery tools;
- small UI clarity changes;
- asset manifest hygiene.

Not allowed:

- new major systems;
- new planets;
- new player-city/siege scope;
- new Force/Jedi powers;
- new runtime LLM;
- broad visual churn.

### R1: Telemetry And Economy Correctness

Fix telemetry before tuning. Bad telemetry creates false confidence.

Required:

- `telemetry_tally.py` counts all current credit-bearing events.
- Unknown credit-bearing events cannot slip through because they use `amount`
  or `credits_earned` instead of `price`.
- Bazaar transfers net to zero except listing fees.
- Space cargo faucets are visible.
- Docking/travel/repair/insurance fees are visible sinks.

Exit:

- A telemetry fixture test proves the tally table.
- A sample play log can be tallied without unknown credit warnings.

### R2: Item Contract Lock

Normalize item instance semantics.

Required:

- `instance_id` is the primary identity.
- `template_id` is the primary template key.
- Legacy `id`/`template_key` compatibility is read-only migration support.
- Bazaar, item use, First Aid, ammo, cargo, inventory UI, and tests agree.

Exit:

- A crafted medpac can be listed, bought, and used.
- A crafted power pack can be listed, bought, and consumed into ammo/reload
  state.
- Item provenance survives transfer.

### R3: Live Two-Player Economy Proof

Upgrade the current economy loop smoke from model-synthetic to server-composed.

Required story:

1. Character A gets resource stacks.
2. Character A crafts an item instance.
3. Character A lists it by `instance_id`.
4. Character B buys it.
5. Credits move A/B correctly.
6. Character B uses it.
7. Listing disappears.
8. State persists.
9. Telemetry records craft/list/fee/buy/sell/use.

Exit:

- Full gate green.
- Test name should make the story obvious, e.g.
  `economy_live_loop_smoke.gd`.

### R4: Space Cargo Release Proof

Space does not need full MMO combat for release, but if space cargo is in the
release, it must be honest.

Required story:

1. Character owns or rents a starter ship.
2. Server approves launch.
3. Server creates/updates ship space state.
4. Space harvest/salvage creates itemized cargo.
5. Server approves landing/docking.
6. Docking/travel fee is charged.
7. Cargo moves into inventory or market.
8. State persists after restart.

Exit:

- One live composition smoke covers the story.
- Telemetry tally sees both faucet and sink.

### R5: First-Hour Playtest Script

Write and maintain a release playtest script.

Required:

- exact install/run steps;
- server start;
- first client join;
- second client join;
- character creation;
- chat;
- buy/equip/restock;
- combat or survey;
- craft/list/buy/use;
- launch/cargo/land if space is included;
- reconnect/restart check;
- telemetry tally command;
- known expected messages.

Exit:

- A non-developer can follow it.
- Any failure becomes a release blocker or a documented known issue.

### R6: Admin And Recovery Tools

Release-worthy private servers need operator escape hatches.

Minimum admin actions:

- list online players;
- inspect character summary;
- grant credits/CP/item for recovery;
- teleport unstuck;
- kick player;
- clear broken listing;
- clear stuck travel/space state;
- export latest telemetry and persistence summary.

These can be command-line or debug-admin only. They do not need polished UI.

### R7: Packaging And Runtime Hygiene

Required:

- `README.md` has current release run instructions.
- `start_game.bat` works from a clean checkout.
- No runtime code loads from `docs/` asset generation folders.
- Runtime asset manifest ids are unique.
- Known warnings are documented; avoid normalizing red/noisy launch output.
- Full gate remains green.

## 6. Release Candidate Definition

Call it an RC only when all of these are true:

- Full gate green.
- Release playtest script completed once solo.
- Release playtest script completed once with two clients.
- Server restarted during/after play and persisted the important state.
- Telemetry tally ran cleanly on the play log.
- Known issues are documented and do not block the three locked player stories.
- No new owner-gated scope was added.

## 7. Priority List For Antigravity

Do these in order:

1. ~~Fix telemetry tally/event schema mismatch.~~ (DONE)
2. ~~Normalize item instance/template ids across live paths.~~ (DONE)
3. ~~Make crafted medpac work through live First Aid or shared item-use path.~~ (DONE)
4. ~~Make crafted power pack work as an item-instance consumable, with legacy ammo migration only as a shim.~~ (DONE)
5. ~~Upgrade economy loop test to live/server-composed.~~ (DONE)
6. ~~Upgrade space cargo test to live/server-composed.~~ (DONE)
7. ~~Add manifest uniqueness/path validation.~~ (DONE)
8. ~~Write `docs/RELEASE_PLAYTEST_SCRIPT.md`.~~ (DONE)
9. ~~Add minimal admin recovery commands.~~ (DONE)
10. Run two-client playtest, restart, tally telemetry, then document known
    issues.

## 8. Design Intent To Preserve

Release-worthy does not mean sanding off the identity. Preserve these:

- Clone Wars frontier, not GCW nostalgia.
- WEG D6 under the hood.
- Server-authoritative truth.
- Player interdependence.
- Visible wounds and recovery.
- Economy faucets paired with sinks.
- Private/friends-scale balance.
- Deterministic Director, no runtime LLM.
- SW_MUSH as read-only reference, not runtime dependency.

## 9. Final Instruction

Antigravity should now behave like a release engineer, not a feature explorer.

The next impressive milestone is not "140 smokes" or "90 RPCs." It is:

> Two players can play the first evening loop, trade a crafted useful item,
> recover from wounds, move cargo or credits through the economy, restart the
> server, and keep going.

Ship that loop. Then expand.
