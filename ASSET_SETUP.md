# Getting 3D Assets — Plain-Language Setup

You don't need any art skill. One tool pulls free 3D models into the game. This
page is the "what do I actually type" guide. (For the technical handoff to the
Codex session, see `docs/ASSET_PIPELINE.md`.)

## The idea in one picture

```
free 3D model packs (.zip)  →  MMO_Assets/   →  catalog (a browsable list)  →  curate (pick the good ones)  →  game uses them
        you download              archive          you/we review                  one command                  automatic
```

- **MMO_Assets/** = a shelf of zipped packs. We leave them zipped.
- **catalog** = builds `docs/ASSET_CATALOG.md`, a page with a picture of every pack and a keep/maybe/skip tag.
- **curate** = unzips only the packs you want into the game, and only the clean files.

## What's already done (you don't need to redo this)

- 34 packs you downloaded (Kenney + Quaternius) are catalogued.
- A consistent **Kenney environment set (11 packs, ~1,050 models)** is already
  unzipped into the game at `assets/3d/kenney/` — buildings, space kit, crates,
  market, factory props, a greybox kit, etc.
- Open `docs/ASSET_CATALOG.md` (in VS Code, hit the preview button) to **see every
  pack with a thumbnail** and decide what else to pull in.

## How to see them in the game

1. Open the project in Godot 4.6.
2. The models appear in the FileSystem panel under `assets/3d/`. Godot imports them automatically the first time.
3. Drag any `.glb` into a scene, or tell the Codex session "use the barrel from `assets/3d/kenney/survival-kit`".

## Things you can do — copy/paste commands

Run these from a terminal in the project folder. (PowerShell is fine.)

### 1. Pull more free Kenney packs — no signup, free
Open `tools/asset_sources.json`, add the pack's slug to the `kenney_packs` list
(the slug is the end of its kenney.nl URL, e.g. `city-kit-commercial`). Then:
```powershell
python tools/fetch_assets.py kenney      # downloads new packs into MMO_Assets/
python tools/fetch_assets.py catalog     # refreshes the catalog page
```

### 2. Change which packs are actually in the game
Edit the `curate` list in `tools/asset_sources.json` (add/remove
`{ "match": "pack-name", "vendor": "Kenney" }` lines), then:
```powershell
python tools/fetch_assets.py curate
```

### 3. Grab specific models from Poly Pizza — free, one-time signup
1. Go to **https://poly.pizza/settings/api**, sign up, and create an "app" to get a key.
2. In your terminal, set the key for this session:
   ```powershell
   $env:POLY_PIZZA_TOKEN = "paste-your-key-here"
   ```
3. Edit the `polypizza_queries` list in `tools/asset_sources.json` (e.g. add
   `{ "q": "lantern", "license": "cc0", "limit": 4 }`), then:
   ```powershell
   python tools/fetch_assets.py poly
   ```

### 4. Generate a custom model with AI (Tripo) — costs a little
Use this only for one-off props the free packs don't have. ~$0.10–0.20 per model;
**new accounts get 300 free credits**, enough for ~15–30 models.
1. Go to **https://platform.tripo3d.ai/api-keys**, sign in, create a key (starts with `tsk_`).
2. Set it for this session:
   ```powershell
   $env:TRIPO_API_KEY = "tsk_paste-your-key-here"
   ```
3. Edit the `tripo_prompts` list in `tools/asset_sources.json` (keep descriptions
   GENERIC — no Star Wars names), then:
   ```powershell
   python tools/fetch_assets.py tripo
   ```

### Make a key stick (optional)
The `$env:` lines above only last for the current terminal window. To save a key
permanently for your user account:
```powershell
setx POLY_PIZZA_TOKEN "your-key"     # then open a NEW terminal
```

## Keeping it consistent (the one rule)

The two free vendors look slightly different. **Kenney** = flat, blocky, super
clean. **Quaternius** = a bit smoother and more detailed, and has the animated
characters/creatures Kenney doesn't. We've set **Kenney as the primary style** for
now. Stick to one look per area so it doesn't feel mismatched; bring in Quaternius
mainly for characters/enemies later.

## Two housekeeping notes

- You have a **duplicate** zip: `Ultimate Modular Men- Feb 2022` appears twice in `MMO_Assets/` — delete one copy.
- A few Quaternius packs are **FBX-only** and were skipped by curate (they need a conversion step). The catalog marks each pack's usable format.

## Cheat sheet

```powershell
python tools/fetch_assets.py catalog   # rebuild the browsable catalog page
python tools/fetch_assets.py curate    # (re)extract your chosen packs into the game
python tools/fetch_assets.py kenney     # add more free Kenney packs
python tools/fetch_assets.py all        # do everything available at once
```
