# API Adapter Contract

This document defines how paid/free AI 3D services should plug into the asset factory.

The pipeline should not be tied to any one provider. Meshy, Tripo, or another service should implement this contract.

## Inputs

Each adapter receives one asset spec:

```json
{
  "id": "mos_eisley_droid_vendor_01",
  "display_name": "Droid Vendor Stall",
  "category": "vendor",
  "style_lane": "chunky_low_poly",
  "prompt": "generic low-poly sci-fi desert market droid vendor stall...",
  "negative_prompt": "no logos, no text, no recognizable Star Wars ships or characters",
  "target_format": "glb",
  "max_cost_usd": 0.25,
  "palette": ["sand_plaster", "dark_metal", "cyan_light"],
  "scale_hint_meters": [4.0, 2.5, 3.0],
  "review_required": true
}
```

## Outputs

An adapter should write:

```text
generated/api/<provider>/<asset_id>/<asset_id>.glb
generated/api/<provider>/<asset_id>/provider_response.json
generated/api/<provider>/<asset_id>/preview.png
generated/api/<provider>/<asset_id>/license_note.md
```

## Required Metadata

Every provider output must record:

- provider name;
- provider URL;
- account used, if applicable;
- timestamp;
- prompt;
- negative prompt;
- input images, if any;
- cost/credits consumed;
- license/terms snapshot or link;
- generated file path;
- review status.

## Provider Rules

Do not call a paid provider unless:

- API key is present;
- per-asset max cost is set;
- provider terms are acceptable;
- asset source remains generic;
- output is placed in a review folder, not runtime.

## Review Rules

Generated API models must be rejected if:

- they contain recognizable protected franchise silhouettes;
- topology is unusable;
- material style clashes badly;
- asset scale/origin is wrong and cannot be fixed cheaply;
- generated license/terms are unclear;
- output has text/logos/watermarks.

## Recommended Providers To Test

1. Meshy
   - Good API docs.
   - Text/image-to-3D.
   - Premium account is now available for bounded testing.
   - Use preview-first geometry evaluation; do not auto-refine.
   - Adapter: `meshy_text_to_3d.py`.
   - Potentially useful for special props, creatures, hard silhouettes, and texture-reference drafts.

2. Tripo
   - Already anticipated by existing `tools/fetch_assets.py`.
   - Text-to-3D and image-to-3D style workflows.
   - Needs cost/quality testing.

3. Future/local generators
   - Only if they export GLB/glTF and can be normalized.
