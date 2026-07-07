# Antigravity Post-Completion Review - 2026-07-05

## Verdict

Good progress. This pass closed most of the previous reliability guidance:

- full gate is green,
- live economy/space-cargo smokes now use distinct ports,
- spawned server cleanup was strengthened,
- `/admin` routing no longer swallows normal slash chat,
- admin commands use a real `network_manager.gd` admin API,
- the release playtest script points at the real `net_world.tscn` server flow.

This is still **private alpha / release-candidate hardening**, not beta. The remaining beta blocker is narrow but important: admin authorization is still too easy to accidentally expose.

## Verified

Full gate run on 2026-07-05:

- Python unit tests: 25 passed
- Godot import check: passed
- runtime launch check: passed
- GDScript smokes: 137 passed
- RPC surface: 82

The new live RPC smokes are materially better than the earlier mirror tests. `economy_live_rpc_smoke.gd` and `space_cargo_live_rpc_smoke.gd` now start real server/client processes on separate ports (`24556`, `24557`) and validate telemetry output.

No forbidden hot `scripts/net/space_*`, `scripts/net/siege_*`, or `scripts/net/city_*` wiring files showed up.

## Remaining Blocker

`network_manager.gd` gates `/admin` with:

```gdscript
var _admin_allowlist: Array = ["admin", "operator", "pilot_1"]
```

That is better than no gate, but it is not beta-safe as written. Account records are first-claim/open unless already secured by a secret. If a deployment has not preclaimed and secret-locked `admin`, `operator`, and `pilot_1`, an ordinary client can attempt to register one of those IDs and then pass the character-ID allowlist.

`pilot_1` is especially risky because it is also a test account used by the space cargo smoke.

## Direction

Before beta language:

1. Replace the hardcoded character-ID allowlist with one of:
   - a server-only operator secret/config file outside normal player creation,
   - an account role persisted on an already-secret-bound account,
   - a dev-only command flag that is off by default and never enabled for playtest builds.
2. Remove `pilot_1` from any production-capable admin path. Keep it test-only.
3. Add a smoke that proves a normal authenticated character receives `Permission denied` for `/admin list`.
4. Add a smoke or setup check that proves every allowlisted admin identity is secret-bound before server start, if the hardcoded list remains temporarily.

After that, the next review should focus on the manual release playtest: run the three frozen stories twice, tally telemetry, and decide which known issues are accepted private-alpha limitations versus true release blockers.
