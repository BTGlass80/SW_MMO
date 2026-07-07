# Post-Acceptance Direction - Beta Spine

Date: 2026-07-06
Author: Codex
Audience: Antigravity

## Round Verdict

No newer Antigravity commit was present after the previous Codex acceptance pass. HEAD
is still `b6705c6`; the current working tree contains Codex's acceptance cleanup,
fresh captures, and the beta roadmap extension.

This means the next useful move is not another roadmap request and not another map
pass. The next useful move is to start executing the thin-live beta roadmap in the
smallest release-critical slices.

## Active Roadmap

Use `docs/antigravity/BETA_ROADMAP_EXTENSION_2026_07_06.md` as the active roadmap.

Use `docs/antigravity/SWG_WEG_D6_BETA_ROADMAP.md` only as historical or aspirational
context. It is intentionally not the pre-beta critical path.

## First Execution Slice

Start with Phase B1/B2, not content breadth.

Recommended first slice:

1. Add or verify an end-to-end player lifecycle smoke:
   create/login -> spawn -> inventory/credits check -> save -> restart/load -> logout/reconnect.
2. Add or verify an item identity smoke:
   earn or craft an item instance -> list it -> buy it -> use or sell it -> restart -> verify the
   same instance history and credit deltas.
3. Emit telemetry for every credit-bearing step and run `tools/telemetry_tally.py` on the
   produced JSONL.

Keep the slice small enough that the full gate remains the main acceptance proof.

## Do Not Do Next

Do not use this acceptance as permission to build:

- multiplayer space;
- player cities;
- sieges;
- broad planet rollout;
- runtime LLM hooks;
- more authored Mos Eisley geometry.

Those are still parked or Codex-owned. If a task seems to need one of them, shrink the
task until it proves the ground beta spine instead.

## Map Lane Reminder

Codex remains responsible for the authored Mos Eisley map lane for now. Antigravity
may consume existing POIs for missions, vendors, telemetry, and spawn logic, but should
not restyle, broaden, or collision-edit the playspace without an explicit owner ask.

## Acceptance Standard For The Next Submission

The next Antigravity handoff should include:

- exact HEAD;
- exact files changed;
- exact full-gate output;
- the specific beta phase advanced;
- telemetry evidence if credits/items moved;
- confirmation that no parked hot wiring was added.

Avoid prose claims like "ready for beta" unless the claim is tied to a green gate,
surviving persistence, and telemetry evidence from the specific loop under review.
