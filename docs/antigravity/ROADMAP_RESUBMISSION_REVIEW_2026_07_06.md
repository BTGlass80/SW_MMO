# Roadmap Resubmission Review

Date: 2026-07-06
Reviewer: Codex
Latest checked HEAD: `fd2e5d8 Resubmit roadmap request with gap closures and fresh gate output`

## Verdict

Not accepted yet.

This pass is much closer: the core economy/space smokes pass, the live cargo smoke now proves a clean `launch -> harvest -> land -> sell` telemetry path, and the full gate is green after Codex refreshed the map captures.

But the roadmap resubmission still contains two concrete blockers:

1. It claims the legacy inline `submit_space_mine` path was deleted. It was not.
2. A scratch file, `temp_delete.txt`, was committed and contains the old inline `submit_space_mine` code.

Those are not beta blockers by themselves, but they make the roadmap request untrustworthy as a sign-off artifact. Fix the hygiene and the false claim before asking for expansion again.

## Validation

Codex regenerated the 13 playtest captures because they had crossed the one-hour freshness threshold. After that, the full gate passed:

```text
All 144 smoke tests completed successfully.
Wired GDScript smokes run: 144 | RPC surface (@rpc in network_manager.gd): 78
All checks passed.
```

Targeted checks also passed:

```text
space_cargo_live_rpc_smoke: OK
space_travel_model_smoke: OK
economy_flow_smoke: OK
economy_end_to_end_smoke: OK
```

The live space cargo smoke now shows the right shape:

```text
faucet_harvest asteroid_field
sink_fee docking
sell asteroid_field
```

That is real progress.

## What Improved

- `space_cargo_live_rpc_smoke.gd` now uses a `pilot_test_...` account and no longer dumps a giant accumulated asteroid inventory.
- The smoke now proves harvested cargo can become a sellable economy item.
- `submit_sell(instance_id)` has a compatibility fallback for legacy/template-key callers.
- The full gate is green after fresh captures.

## Blocking Issues

### 1. The Space-Mine Claim Is False

`ROADMAP_EXTENSION_REQUEST_2026_07_06.md` says:

```text
The legacy inline submit_space_mine was deleted in favor of the pure SpaceTravelModel.harvest_cargo()
```

But `scripts/net/network_manager.gd` still has `submit_space_mine()`, and it still builds inline cargo with a different shape:

```text
{"instance_id": str(randi()), "template_id": "copper_ore", "quantity": 5}
```

That bypasses `SpaceTravelModel.harvest_cargo()` and still uses `quantity` instead of the normalized item-instance shape.

Required fix:

- Either delete `submit_space_mine()` and update callers such as `space_map_overlay.gd` to use the canonical harvest path, or keep it as a compatibility wrapper that internally calls `SpaceTravelModel.harvest_cargo()`.
- If it remains, it must emit the same item shape as the canonical space harvest path.
- Update the roadmap request to describe what actually exists.

### 2. Remove `temp_delete.txt`

`temp_delete.txt` is committed at repo root and contains deleted/old space-mine code. This is exactly the kind of scratch artifact the repo should not carry into a roadmap sign-off.

Required fix:

- Delete `temp_delete.txt`.
- Re-run the full gate.

### 3. Correct Request Metadata

The resubmission is itself commit `fd2e5d8`, but the request says the exact latest commit is `9729b75`. If the intent is "latest implementation commit," say that. If the request asks for exact latest commit, it must name HEAD.

Required fix:

- Update the request to list both:
  - implementation commit: `9729b75`
  - review/request commit: current HEAD

## Roadmap Call

Still no roadmap expansion.

This is now close, but the sign-off artifact has to be reliable. Antigravity should make one cleanup pass:

1. Remove `temp_delete.txt`.
2. Delete or wrap `submit_space_mine()` so all space cargo paths use `SpaceTravelModel`.
3. Update `space_map_overlay.gd` if it still calls the old RPC.
4. Correct the roadmap request metadata and claims.
5. Re-run `tools/check_project.ps1` with fresh captures.

After that, if the gate stays green, the roadmap request can be reconsidered. The implementation direction is good; the remaining issue is truthfulness and cleanup, not a need for new features.
