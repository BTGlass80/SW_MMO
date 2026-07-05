# Mos Eisley Latest Review - 2026-07-05

Verdict: do not expand the roadmap yet. This pass shows useful cleanup and some encouraging discipline, but the authored Mos Eisley still is not close to release-worthy. The biggest concern is not just that the scene remains visually weak; it is that the current visual validation can report success while failing to produce new screenshots.

## What Improved

- `scripts/world/main.gd` now gates the asset gallery behind `--asset-gallery`, which keeps the normal play scene from becoming a test exhibit.
- `scripts/world/world_builder.gd` now suppresses `WorldBuilder.add_label()` output unless `--debug-world-labels` is passed. That is the right default.
- The new room-data path in `WorldBuilder._build_from_rooms()` is the correct direction for Mos Eisley: authored spaces should come from room/landmark data, not one-off geometry sprawl.
- `LandmarkBuilder` has moved away from CSG nodes, and the smoke test now checks for that.
- The broader project gate is green as of this review: Python tests passed, import passed, runtime launch passed, and the GDScript smoke suite passed.

## Release Blockers

1. Visual proof is currently false-green.

   Running `scripts/tests/visual_playtest_runner.gd` headless produced viewport texture errors and failed to write fresh captures, but still exited successfully. The existing files under `captures/playtest/` are stale, so they cannot be used as evidence of improvement.

   Required fix: capture failure must fail the runner. Either make the runner require a working renderer or move the screenshot job to a non-headless path, but do not allow missing/stale images to count as a pass. Stamp or delete old captures before each run so stale output is obvious.

2. The cantina area still reads as a giant test plaza, not Mos Eisley.

   The main dome is smaller than the previous worst version, but the surrounding authored space still uses an oversized 110m plaza, huge flanking huts, and perimeter walls sized around a massive footprint. This keeps the scene feeling like a blockout arena instead of a cramped desert port neighborhood.

   Required fix: shrink the cantina composition to street scale. The area around the cantina should feel enclosed, dusty, and irregular, with adjacent buildings close enough to create alleys and occlusion. A release candidate should not have a broad empty ceremonial plaza around the cantina.

3. Release-visible labels are still leaking through `LandmarkBuilder`.

   `WorldBuilder.add_label()` is now debug-gated, but `LandmarkBuilder` still creates visible labels such as `Mos Eisley Cantina` and `[NO DROIDS]` directly. Worse, `landmark_builder_smoke.gd` still asserts that the cantina label exists, which trains the test suite to preserve the wrong behavior.

   Required fix: all floating location labels must be debug-only. Update the smoke test to assert that release/default builds do not include those labels, and add an explicit debug-label mode test if that behavior is still useful.

4. Determinism is still at risk.

   `build_cantina_plaza()` creates a seeded local RNG, but `_build_interior()` still uses global `randf_range()` for table offsets and rotations. The existing determinism smoke only checks mesh count, so transform drift can slip through.

   Required fix: route all builder randomness through a local seeded RNG. Extend the determinism smoke to compare relevant transforms/material assignments, not just node counts.

5. The art direction is still accumulation-heavy.

   The latest work removes some obvious debug clutter, but the scene still looks built by adding objects rather than composing playable space. It needs hierarchy: approach streets, compressed alleys, recognizable silhouettes, human-scale doors, shade, grime, props with purpose, and a small number of high-confidence landmarks.

## Immediate Direction For Antigravity

Do not broaden features. Do not expand the roadmap. Finish this Mos Eisley correction pass first.

Recommended order:

1. Make visual capture honest.
   - Fail on screenshot write failure.
   - Clear or timestamp captures before each run.
   - Produce current outside, entrance, bar, and back-room screenshots without gameplay HUD occlusion.

2. Fix release-mode scene hygiene.
   - Gate or remove all `Label3D` location signage from default play.
   - Update tests so default mode proves labels are absent.
   - Keep asset galleries and debug visualization behind explicit flags only.

3. Rebuild the cantina block at believable scale.
   - Remove the 110m plaza.
   - Pull flanking structures closer.
   - Replace broad flat emptiness with alleys, shade breaks, exterior clutter, service doors, crates, pipes, alcoves, and irregular perimeter geometry.
   - Make screenshots demonstrate composition from player height, not aerial/debug angles.

4. Fix deterministic generation.
   - Remove global RNG calls from deterministic builders.
   - Add a transform-level determinism smoke.

5. Re-run the full gate and attach fresh captures.
   - A green `check_project.ps1` is necessary but not sufficient.
   - The visual pass must have current artifacts that a reviewer can inspect.

## Roadmap Position

The roadmap should stay frozen. This project is not ready for a beta roadmap expansion while the authored first impression of Mos Eisley is still weak and visual validation is not trustworthy.

Roadmap expansion becomes appropriate only after:

- Mos Eisley default play no longer exposes debug labels, galleries, or test scaffolding.
- Fresh captures show a coherent, Clone Wars-era Mos Eisley street/cantina experience at player scale.
- The visual runner fails loudly on missing captures.
- Deterministic builder tests check transforms, not only counts.
- The full gate remains green after those fixes.

When those are true, the next roadmap expansion should focus on beta readiness: player onboarding into the ground loop, first-session social goals, admin/moderation tools, telemetry review cadence, economy balance proof, and live-operation recovery playbooks. Until then, the right work is gap closure, not roadmap growth.
