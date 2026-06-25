# Asset Pipeline (handoff)

> Hand this file to the Codex dev session. It explains how 3D art enters the
> project so gameplay work and asset work can run in parallel without colliding.

## TL;DR

A second AI session (Claude Code) built an automated, license-clean 3D-asset
pipeline. **You (Codex) do not make art.** Assets arrive as game-ready GLB files
under `res://assets/3d/`. To get more, run one Python tool; to use them, instance
the GLBs. Everything is CC0/generic — no Star Wars trademarks ever enter the repo.

## The one tool

`tools/fetch_assets.py` — stdlib-only (urllib/zipfile/json, no pip), config-driven
from `tools/asset_sources.json`, same argparse-subcommand style as `durable_loop.py`.

```
fetch ─► MMO_Assets/ (raw .zip archive, left zipped) ─► catalog ─► curate ─► assets/3d/
```

| Command | Does | Needs |
|---|---|---|
| `python tools/fetch_assets.py kenney` | download CC0 Kenney pack zips into `MMO_Assets/` | nothing |
| `python tools/fetch_assets.py poly` | search + download CC0 models from poly.pizza | `POLY_PIZZA_TOKEN` (free) |
| `python tools/fetch_assets.py tripo` | text-to-3D generation | `TRIPO_API_KEY` (~$0.10–0.20/model) |
| `python tools/fetch_assets.py catalog` | inventory the archive, extract previews, classify style/theme | nothing |
| `python tools/fetch_assets.py curate` | extract the chosen GLB/glTF subset into `assets/3d/` | nothing |
| `python tools/fetch_assets.py all` | every available fetch source, then catalog | optional keys |

## Folder layout

```
MMO_Assets/                     raw .zip archive (manual + fetched). STAYS ZIPPED. ~34 packs.
assets/3d/
  kenney/<pack>/Models/...      curated, extracted, GLB-only (Godot-visible)
  polypizza/<name>__<id>.glb    individual CC/CC0 models (when used)
  generated/<name>.glb          Tripo text-to-3D output (when used)
  CATALOG.json                  machine-readable inventory of MMO_Assets
  ASSET_MANIFEST.json           provenance: source + license + attribution per curated asset
  CREDITS.md                    auto-generated; CC-BY attributions live here
docs/
  ASSET_CATALOG.md              human catalog w/ embedded preview images + keep/skip verdicts
  asset_previews/               extracted pack preview thumbnails
```

`MMO_Assets/` is the single source of truth for raw assets; manual downloads and
`fetch` output both land there. Only `curate` writes into `assets/3d/`.

## House style (consistency rule — important)

The archive has two vendors with **different looks**:

- **Kenney** — flat ultra-low-poly, one shared palette, GLB-native. Maximally consistent. Strong on environment/buildings/props; weak on animated characters.
- **Quaternius** — smoother low-poly, baked AO, a notch more detail; ships glTF/FBX/.blend. Has rigged/animated characters, creatures, mechs, ships that Kenney lacks.

**Current `house_style` = `Kenney`** (set in `asset_sources.json`). The curated
`assets/3d/kenney/` set is the environment palette for the Mos Eisley spaceport
slice. Rule of thumb: **build from the house-style vendor first; only mix the other
vendor where it reads as the same family.** Mixing flat Kenney buildings with
smooth Quaternius props in the same shot will look off — keep them in separate
visual zones or restyle. If the owner switches `house_style`, update the `curate`
list and re-run `curate`.

## Using assets in Godot 4.6

- GLBs under `res://assets/3d/` **auto-import** when the editor opens (or run
  `godot --headless --import` in CI). The `.godot/` import cache is gitignored.
- Instance a model: `preload("res://assets/3d/kenney/space-kit/Models/GLB format/barrel.glb").instantiate()`,
  or drag the `.glb` into a scene. They come in as `Node3D` with `MeshInstance3D` children.
- Kenney GLBs embed their texture; no extra material setup needed for greyboxing.
- For server-authoritative logic, remember these are **presentation only** — keep
  meshes on the client; the server owns position/interaction truth (per ARCHITECTURE.md).

## Extending it (edit `tools/asset_sources.json`, then run a command)

- **More Kenney packs:** add `{ "slug": "<kenney-asset-slug>" }` to `kenney_packs`, run `kenney` then `catalog`. URLs resolve at runtime (Kenney's CDN paths carry version hashes, so don't hardcode old ones).
- **Specific models from poly.pizza:** add `{ "q": "crate", "license": "cc0", "limit": 4 }` to `polypizza_queries`, set `POLY_PIZZA_TOKEN`, run `poly`. (`license: cc0` avoids attribution; the tool still records `Attribution` for any CC-BY.)
- **Custom AI models:** add `{ "name": "x", "prompt": "low-poly ... game asset" }` to `tripo_prompts`, set `TRIPO_API_KEY`, run `tripo`. Keep prompts GENERIC.
- **Change what's extracted:** edit the `curate` list (`{ "match": "<zip substring>", "vendor": "Kenney" }`), run `curate`.

## License / IP rules (do not break)

- Everything is **CC0** (Kenney, Quaternius) or filtered to CC0 (poly.pizza) or
  owned paid-API output (Tripo). Provenance is logged to `ASSET_MANIFEST.json`.
- **Generic sci-fi only.** Never search for, generate, or commit anything named or
  shaped as Star Wars IP (X-Wing, stormtrooper, landspeeder, moisture vaporator,
  astromech, Tatooine, etc.). poly.pizza is user-uploaded — vet titles before use.
- This protects the project's "public distribution avoids copyrighted assets"
  posture in `docs/ARCHITECTURE.md`.

## Known rough edges (low priority)

- The `kenney` present-check matches loosely (e.g. `space-kit` substring also hits
  `modular-space-kit`); harmless because both are already archived, but tighten if
  you add a pack whose slug is a substring of another.
- Several Quaternius packs are **FBX-only** (no glTF): `Ultimate Modular Sci-Fi`,
  `Spaceships by @Quaternius`, `Alien Animated`, `Animated FPS Guns`. `curate` skips
  FBX, so those need Godot's FBX import (FBX2glTF) or manual conversion first.
- `MMO_Assets/` has a **duplicate** `Ultimate Modular Men- Feb 2022` zip — delete one.
