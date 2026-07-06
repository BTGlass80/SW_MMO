# Roadmap Resubmission Follow-Up

Date: 2026-07-06
Reviewer: Codex
Latest checked HEAD: `b6705c6 Update roadmap request to clarify submit_space_mine deletion and exact commits`

## Verdict

Still not accepted for roadmap expansion.

The cleanup moved in the right direction:

- `temp_delete.txt` is gone.
- `network_manager.gd` no longer contains `submit_space_mine()`.
- The live space cargo smoke proves a clean fresh-character path:

```text
faucet_harvest asteroid_field
sink_fee docking
sell asteroid_field
```

After Codex refreshed the 13 map captures, the full gate passed:

```text
All 144 smoke tests completed successfully.
Wired GDScript smokes run: 144 | RPC surface (@rpc in network_manager.gd): 78
All checks passed.
```

But one live client reference remains broken, and the roadmap request metadata is stale again.

## Remaining Blockers

### 1. `space_map_overlay.gd` Still Calls The Deleted API

The old server RPC was removed, but the asteroid action path still calls it:

```text
scripts/world/space_map_overlay.gd: Net.send_space_mine(target_id)
```

`Net.send_space_mine()` no longer exists. That means selecting an asteroid and using the gunnery/mining action can hit a missing method at runtime even though the smoke suite is green.

Required fix:

- Update the overlay asteroid action to call the canonical `Net.send_space_harvest(...)` path, or route through whatever the accepted client API is for `SpaceTravelModel.harvest_cargo()`.
- Add a focused smoke or model/composition test that covers asteroid overlay action routing so this does not regress.
- If the overlay action is intentionally deprecated, remove or disable the button/path visibly instead of leaving a dead call.

### 2. Roadmap Request Metadata Is Still Not Exact

`ROADMAP_EXTENSION_REQUEST_2026_07_06.md` now says:

```text
Implementation commit: 9729b75
Review/request commit: 80a8385 (current HEAD)
```

But the current HEAD for this review is:

```text
b6705c6 Update roadmap request to clarify submit_space_mine deletion and exact commits
```

Required fix:

- Update the request so it no longer says `80a8385` is current HEAD.
- If the request is expected to be a sign-off artifact, it must name the actual current HEAD or explicitly state that the request commit is historical and has been superseded.

## Roadmap Call

No roadmap expansion yet.

This should now be a small cleanup pass, not a new feature pass:

1. Replace or remove the stale `Net.send_space_mine` overlay call.
2. Add a guard for the asteroid overlay action route.
3. Correct the roadmap request metadata.
4. Re-run the full gate with fresh captures.

Once that is done and green, the roadmap expansion request is close enough to reconsider.
