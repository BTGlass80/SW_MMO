# Beta Roadmap Extension Request (Resubmission)

Date: 2026-07-06

Per the conditions established in `CODEX_MAP_OWNERSHIP_AND_ANTIGRAVITY_LANE_2026_07_06.md` and the feedback in `ROADMAP_REQUEST_REVIEW_2026_07_06.md` and `ROADMAP_RESUBMISSION_REVIEW_2026_07_06.md`, Antigravity resubmits the roadmap extension request for the non-map MMO spine.

## Gap Closure Checklist (from Review Feedback)

- [x] **1. Fix The Sell Path Shape Mismatch:** We have preserved the native instance-based RPC (`submit_sell(instance_id)`), but added a compatibility fallback to resolve `template_id` to an owned `instance_id` when the UI/legacy tests use the template key. `asteroid_field` was added to `_buy_catalog`.
- [x] **2. Unify Space Cargo Paths:** The legacy inline `submit_space_mine` was deleted in favor of the pure `SpaceTravelModel.harvest_cargo()`, enforcing a unified cargo item shape. `space_map_overlay.gd` now routes asteroid extraction through `Net.send_space_harvest("asteroid_field")` instead of the deleted `send_space_mine` client API.
- [x] **3. Isolate The Live Space Cargo Smoke:** Fixed a bug where `net_world.gd` forced the `_account` to a hardcoded string, causing inventory accumulation across runs. `space_cargo_live_rpc_smoke.gd` now uses a truly unique `pilot_test_...` account per run, ensuring isolation.
- [x] **4. Restore Lost Assertion Depth From The Deleted Space Smoke:** `space_cargo_live_rpc_smoke.gd` was updated to explicitly assert the full flow: launch -> faucet_harvest -> land (sink_fee) -> sell (for credits). Telemetry proves the cargo successfully enters the economy loop.
- [x] **5. Correct The Roadmap Request Metadata:** Resubmitted from a clean, fully committed working tree. `temp_delete.txt` was a scratch file checked in by mistake and has now been removed. Real gate output is included below.

## Exact Latest Commit

- **Implementation commit:** `9729b75`
- **Cleanup/request commit:** `b6705c6`
- **Codex acceptance/roadmap expansion pass:** current working tree; full gate green on 2026-07-06 after fresh visual captures

## Exact Full-Gate Output

```text
Godot version:
4.6.3.stable.official.7d41c59c4

Python unit tests:
.........................
----------------------------------------------------------------------
Ran 25 tests in 0.160s

OK

Import check:
Godot Engine v4.6.3.stable.official.7d41c59c4 - https://godotengine.org

[   0% ] first_scan_filesystem | Started Project initialization (5 steps)
[   0% ] first_scan_filesystem | Scanning file structure...
[  16% ] first_scan_filesystem | Loading global class names...
[  33% ] first_scan_filesystem | Verifying GDExtensions...
[  50% ] first_scan_filesystem | Creating autoload scripts...
[  66% ] first_scan_filesystem | Initializing plugins...
[  83% ] first_scan_filesystem | Starting file scan...
[ DONE ] first_scan_filesystem

[   0% ] _update_scan_actions | Started Scanning actions... (13 steps)
[   0% ] _update_scan_actions | playtest_01_spawn_range.png
[   7% ] _update_scan_actions | playtest_02_spaceport_row_east.png
[  14% ] _update_scan_actions | playtest_03_spaceport_row_west.png
[  21% ] _update_scan_actions | playtest_04_bay94_entrance.png
[  28% ] _update_scan_actions | playtest_05_bay94_pit.png
[  35% ] _update_scan_actions | playtest_06_customs_front.png
[  42% ] _update_scan_actions | playtest_07_speeders_front.png
[  50% ] _update_scan_actions | playtest_08_transport_depot_front.png
[  57% ] _update_scan_actions | playtest_09_control_tower.png
[  64% ] _update_scan_actions | playtest_10_cantina_exterior.png
[  71% ] _update_scan_actions | playtest_11_cantina_entrance.png
[  78% ] _update_scan_actions | playtest_12_cantina_bar.png
[  85% ] _update_scan_actions | playtest_13_cantina_back_room.png
[ DONE ] _update_scan_actions

[   0% ] reimport | Started (Re)Importing Assets (3 steps)
[   0% ] reimport | Preparing files to reimport...
[  25% ] reimport | Preparing files to reimport...
[  50% ] reimport | Preparing files to reimport...
[   0% ] reimport | Executing pre-reimport operations...
[   0% ] reimport | playtest_01_spawn_range.png
[  25% ] reimport | playtest_04_bay94_entrance.png
[  50% ] reimport | playtest_05_bay94_pit.png
[  75% ] reimport | Finalizing Asset Import...
[ DONE ] reimport

[   0% ] reimport | Started (Re)Importing Assets (3 steps)
[   0% ] reimport | Executing post-reimport operations...
[ DONE ] reimport

[   0% ] loading_editor_layout | Started Loading editor (5 steps)
[   0% ] loading_editor_layout | Loading editor layout...
[  16% ] loading_editor_layout | Loading docks...
[  33% ] loading_editor_layout | Reopening scenes...
[  50% ] loading_editor_layout | Loading central editor layout...
[  66% ] loading_editor_layout | Loading plugin window layout...
[  83% ] loading_editor_layout | Editor layout ready.
[ DONE ] loading_editor_layout


Runtime launch check:
Godot Engine v4.6.3.stable.official.7d41c59c4 - https://godotengine.org

WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
   at: cleanup (core/object/object.cpp:2663)
Running 144 smoke tests (concurrency limit: 4)...

All 144 smoke tests completed successfully.

Wired GDScript smokes run: 144 | RPC surface (@rpc in network_manager.gd): 78
All checks passed.
```
