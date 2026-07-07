# Antigravity Quick Scope Guidance - 2026-07-05

## Read

This latest pass looks more like release hardening than uncontrolled feature broadening. The newest work is pointed at the right targets: corrected release playtest instructions, known-issues capture, admin recovery commands, asset hygiene, telemetry coverage, and multi-process economy/space-cargo smokes.

Do not widen the feature set from here. Stay in release freeze and make the existing three player stories boringly reliable:

1. new player first hour,
2. player economy craft/list/buy/use,
3. space cargo launch/harvest/land/persist.

No beta roadmap extension yet. We are still closing release-readiness gaps, not planning the next wave.

## Keep

- The release playtest script now uses the right scene and port shape (`net_world.tscn`, port `24555`). Keep it as the manual truth source.
- The admin commands now go through a `network_manager.gd` admin API instead of directly depending on stale internal maps. Good correction.
- The new live RPC smoke tests are the right kind of proof. Keep pushing toward real process/RPC/persistence validation over mirror-composition tests.
- The known-issues doc is useful and should be maintained as a release triage artifact, not a dumping ground for blockers.

## Fix Before Beta Claims

1. **Admin authorization is not a beta-safe surface yet.** `/admin ...` is routed distinctly now, but any authenticated player appears able to invoke it. Gate it behind an explicit operator allowlist, dev flag, local-only test mode, or account role before a beta label.
2. **Make multi-process smokes deterministic under the parallel runner.** `tools/run_smoke_tests.py` runs smokes concurrently, while `economy_live_rpc_smoke.gd` and `space_cargo_live_rpc_smoke.gd` both start a server on the default port. Give these tests unique ports or mark server-starting smokes for serial execution.
3. **Add cleanup protection around spawned server processes.** If a client hangs or the smoke times out, a child server can survive and poison later runs. Use per-test ports plus best-effort kill/finalization paths.
4. **Treat test affordances as test-only.** The `--economy-test-*` and `--space-cargo-test-*` hooks are acceptable for gate proof, but they should not become production UX or hidden release features.
5. **Do not add more content systems until the release script passes manually.** New markets/resources/assets are fine only where they directly support the three frozen stories and remain covered by data/asset smokes.

## Direction

Antigravity should spend the next pass on reliability, not breadth:

- admin permission gate,
- serial/unique-port multi-process smoke stability,
- manual release script dry run with notes,
- telemetry tally from that dry run,
- known-issues cleanup with each issue classified as blocker, workaround, or accepted private-alpha limitation.

When those are done and the manual script passes cleanly twice, revisit beta language. Until then, call this a private alpha/release-candidate hardening pass.
