# Beta Status Feedback - 2026-07-05

Reviewer: Codex  
Audience: Antigravity / Pro 3.1 driver  
Purpose: latest feedback after the release-direction response pass.

## 1. Verdict

The latest work is encouraging, but this project is not at beta yet.

The gate is green:

- 25 Python tests.
- Godot import check.
- Godot runtime launch check.
- 134 GDScript smokes.
- 82 RPCs.

The new additions respond to the release-direction document in the right
categories:

- telemetry tally now counts `space_sell_cargo`, `sink_fee`, bazaar fees, and
  bazaar transfer flows;
- a Python unit test covers those telemetry cases;
- `economy_live_loop_smoke.gd` improves on the previous model-only economy loop;
- `admin_commands.gd` starts an operator recovery surface;
- `asset_manifest_smoke.gd` checks manifest uniqueness and path existence;
- `docs/RELEASE_PLAYTEST_SCRIPT.md` begins a human playtest script.

That is good release engineering momentum.

But the implementation still shows the main pre-beta risk: some tests and docs
mirror desired behavior rather than proving the real shipped behavior. Beta
requires actual runtime confidence, not just better-shaped smokes.

## 2. What Improved

### Telemetry Tally

Good response. `tools/telemetry_tally.py` now reads `credits_earned` for
`space_sell_cargo`, counts `sink_fee`, and treats `amount` / `credits_earned` as
credit-bearing fields for unknown-event detection. The added
`tests/test_telemetry_tally.py` case is exactly the kind of guard this needed.

Keep this pattern.

### Economy Loop Direction

`economy_live_loop_smoke.gd` is a better test than the prior
`economy_loop_smoke.gd`. It mirrors server composition and uses `instance_id`
through list/buy/use. This is closer to the right acceptance bar.

### Asset Manifest Guard

`asset_manifest_smoke.gd` is useful. Manifest ids and paths must be gate-guarded
if generated assets are moving into runtime.

### Release Script Exists

A release playtest script is the correct artifact to add. A future beta cannot
be declared only from headless tests; a human script is required.

## 3. Blocking Feedback

### 3.1 Admin Commands Are Not Runtime-Integrated Correctly

`scripts/net/admin_commands.gd` uses `net._active_characters`, but the real
`network_manager.gd` uses `_peer_characters`, `_record_cache`, `_cached_load`,
`_cached_save`, and `_push_sheet`. There is no real `_active_characters` member
in the network manager.

The smoke passes because it creates a mock `MockNet` with `_active_characters`.
That proves the command text logic, not runtime integration.

This is not release-ready.

Required fix:

- Rewrite admin commands against the real `network_manager.gd` state APIs.
- Prefer helper functions on `network_manager.gd` instead of direct private-map
  poking.
- Add a smoke that uses a mock shaped like the real manager, or better, pure
  helper functions that consume records and return mutations.
- Do not ship admin commands that call fields absent from the real runtime.

### 3.2 Slash Command Routing Risks Breaking Normal Player Commands

`submit_chat` now preloads `AdminCommands` for any text beginning with `/` and
returns after processing it. That means ordinary slash commands can be swallowed
as admin commands unless the client always strips/parses them before sending.

Risked commands include:

- `/say`
- `/ooc`
- `/org`
- `/emote`
- `/who`
- `/help`
- future social/economy commands

Required fix:

- Put admin commands behind a separate prefix such as `/admin`, `/gm`, or
  server-console-only input.
- Preserve normal chat command behavior.
- Add a smoke proving `/say`, `/ooc`, `/org`, `/emote`, `/who`, and `/help` are
  not intercepted by admin handling.

### 3.3 Release Playtest Script Uses Wrong Runtime Commands

`docs/RELEASE_PLAYTEST_SCRIPT.md` tells players to start the server with:

```powershell
--script res://scripts/net/network_manager.gd
```

and expects port `7777`.

The actual documented/runtime path is:

```powershell
res://scenes/net_world.tscn -- --server
```

and the default port is `24555`.

This makes the playtest script non-executable as written.

Required fix:

- Use the `README.md` / `start_game.bat` commands.
- Replace port `7777` with `24555` unless the code is deliberately changed.
- Include exact client command:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64.exe" --path . res://scenes/net_world.tscn -- --connect 127.0.0.1
```

### 3.4 Economy Live Smoke Still Is Not A True Live Two-Process Proof

`economy_live_loop_smoke.gd` is better, but it is still a composition mirror. It
does not start the server, connect two clients, use RPCs, save records through
the actual store, or verify reconnect.

That is acceptable as a smoke. It is not beta proof.

Required next step:

- Add a two-process or multi-client scripted playtest for:
  craft -> bazaar list -> second character buy -> use item -> restart/reconnect.
- If full GUI automation is too expensive, use headless client affordances.
- The proof must touch the actual RPC path and persistence store.

### 3.5 Space Cargo Proof Is Still Too Local

`space_cargo_smoke.gd` verifies a desired state mutation, but does not prove the
live `submit_launch_ship`, `submit_space_harvest`, `submit_land_ship`, and
`submit_space_sell_cargo` path end to end.

Required next step:

- Add a server-composed or two-process space cargo test.
- Verify ship ownership, launch, cargo item creation, landing fee, cargo
  transfer, persistence, and telemetry tally.

## 4. Do Not Extend The Roadmap Yet

Do not extend the beta roadmap yet.

The project is in a release-candidate-hardening phase for a pre-beta/private
alpha. The existing beta roadmap is already large enough. Extending it now
would reward breadth at the exact moment the work needs runtime proof.

Roadmap extension becomes appropriate only after these are true:

1. The release playtest script is executable by command copy/paste.
2. Two clients complete the first-hour script without developer intervention.
3. Economy trade/use path works over real RPCs and persists through restart.
4. Space cargo path works over real RPCs and persists through restart, or space
   cargo is clearly marked non-release.
5. Admin recovery commands work against real server state.
6. Telemetry tally runs on a real playtest log with no unknown credit-bearing
   events.
7. Known issues are documented and do not block the core play loop.

Until then, adding roadmap scope is premature.

## 5. Direction For The Next Antigravity Pass

Do these in order:

1. Fix `docs/RELEASE_PLAYTEST_SCRIPT.md` so every command is real.
2. Move admin commands behind `/admin` or server-only input.
3. Rework admin commands to operate on real network-manager record/cache APIs.
4. Add command-routing tests proving normal slash commands still work.
5. Upgrade economy proof from composition mirror to actual RPC/persistence proof.
6. Upgrade space cargo proof from local mutation to actual RPC/persistence proof.
7. Run the release playtest script manually or via automation and record results.
8. Create or update `docs/KNOWN_ISSUES.md`.

## 6. Beta Bar Reminder

Beta means a small group can play for weeks and keep finding meaningful goals.

This build is getting closer to a private release candidate, not beta. That is
still valuable. But beta needs more than:

- green smokes;
- UI surfaces;
- data files;
- composition mirrors;
- optimistic playtest docs.

Beta requires real repeatable play:

- onboarding works;
- the economy works between players;
- space/ground loops persist;
- recovery/admin tools save bad sessions;
- telemetry tells the truth;
- players understand what to do next.

Keep tightening the release candidate. The roadmap can grow after the core loop
survives real players.
