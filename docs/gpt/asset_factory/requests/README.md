# Asset Request Queue

Purpose: a simple shared filesystem protocol for Claude, Codex, or a human designer to request asset-factory work without touching runtime game files.

This is not a live API. It is a durable queue in the repo.

## Folder Contract

```text
docs/gpt/asset_factory/requests/
  README.md
  REQUEST_TEMPLATE.md
  ANIMATION_REQUEST_TEMPLATE.md
  FEEDBACK_TEMPLATE.md
  examples/
  inbox/
  in_progress/
  completed/
  rejected/
  feedback/
    inbox/
    reviewed/
    actioned/
```

Claude should create one request file in `inbox/` for each focused asset batch.

Codex should move or copy the request into `in_progress/` while working, generate docs-only artifacts under `docs/gpt/asset_factory/generated/<request_id>/`, then write a response file in `completed/` or `rejected/`.

Claude can create one feedback file in `feedback/inbox/` when the goal is to report how an existing artifact behaved instead of requesting a new asset. Use feedback for:

- this worked well;
- this failed in runtime;
- this imports incorrectly;
- this is visually wrong from the gameplay camera;
- this is too expensive or too heavy;
- this should become the new baseline.

Before selecting a tool lane, Codex should read:

```text
docs/gpt/asset_factory/ASSET_REQUEST_PLAYBOOK.md
```

That playbook defines when to start from in-game descriptions, our own SVG contracts, reference-image lessons, Blockbench, Blender, Godot, Kenney filler, or an API/human lane.

Runtime gameplay/source files remain untouched unless the owner explicitly permits promotion.

## Request Naming

Use:

```text
REQ-YYYYMMDD-short-kebab-name.md
```

Examples:

```text
REQ-20260704-clone-commander-pass.md
REQ-20260704-desert-doorway-kit.md
REQ-20260704-hostile-droid-infantry.md
REQ-20260704-cantina-seated-social-animation.md
```

## Good Request Size

Good:

- one character role;
- one ship family;
- one building kit piece;
- one weapon family of 2 to 3 variants;
- one camera/import proof.

Too broad:

- "make all ships";
- "redo Mos Eisley";
- "make the game look better";
- "replace every character."

The pipeline works best when one variable changes at a time.

## Required Request Fields

Every request should include:

- request id;
- owner priority;
- asset family;
- gameplay role;
- runtime affordances and socket roles, if the request is a room/building/interaction asset;
- target camera;
- desired lane;
- baseline to compare against;
- what may change;
- what must stay fixed;
- reference lessons, if any;
- license/IP boundary;
- requested outputs;
- acceptance checklist.

Use `REQUEST_TEMPLATE.md`.

For animation requests, use `ANIMATION_REQUEST_TEMPLATE.md` instead. Animation requests should state whether they are scene interactions, character action clips, vehicle/tactical motion, or a mixed request that should be split.

For artifact feedback, use `FEEDBACK_TEMPLATE.md` instead. Feedback should name the artifact, context, verdict, what worked, what failed, and the requested follow-up.

## Codex Response Contract

Codex should produce:

- generated source files, preferably `.bbmodel` or a spec;
- generated GLB/Godot review artifact where feasible;
- rendered preview captures;
- validation result;
- keep/reject verdict;
- next one-variable recommendation;
- explicit note if a request was too broad or unsafe.

Suggested completed response path:

```text
docs/gpt/asset_factory/requests/completed/REQ-YYYYMMDD-short-kebab-name_RESPONSE.md
```

## Current Recommended Lanes

Characters/droids/weapons:

```text
request -> original pixel cards or body-part hull proof -> Blockbench only if foreground/hero -> Blender GLB if needed -> Godot/Blender preview -> validation -> verdict
```

Ships:

```text
request -> top/side/isometric pixel card -> Godot token/hull proof -> Blockbench only if hero/rotating -> Godot isometric proof -> validation -> verdict
```

Buildings:

```text
request -> semantic floor/detail JSON cards with seat/stand/use/cover/transition sockets -> Godot geometry/collision/socket proof -> Blockbench identity modules only where needed -> capture -> verdict
```

Space UI/tactical overlays:

```text
request -> Godot procedural review scene -> capture -> verdict
```

Animation:

```text
request -> animation family -> anchors/sockets and clip names -> Godot pose proof or Blender/glTF clip proof -> capture/import validation -> verdict
```

Feedback:

```text
artifact tested in context -> feedback/inbox/FB-* -> reviewed/actioned -> follow-up request only if needed
```

## Boundary

Kenney is filler clay, not the identity layer. A request for a landmark, hero character, ship, or weapon should not ask Codex to simply pick a raw Kenney asset and call it done.

Reference images are allowed as lessons, not source geometry. Fan art should not be traced, sampled, copied, or converted into a model.
