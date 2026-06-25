#!/usr/bin/env python3
"""Asset fetch + catalog + curate pipeline for SW_MMO_Prototype.

Flow:  fetch/manual-download zips -> MMO_Assets/ (raw archive, left zipped)
       -> catalog  (inventory + previews + style/theme)  -> docs/ASSET_CATALOG.md
       -> curate   (extract chosen GLB/glTF subset)       -> assets/3d/ (Godot)

Subcommands (mirror tools/durable_loop.py's style):

  kenney    download CC0 Kenney pack zips INTO MMO_Assets/      (NO key needed)
  poly      search + download CC/CC0 models from poly.pizza     (needs POLY_PIZZA_TOKEN)
  tripo     text-to-3D generation via tripo3d.ai                (needs TRIPO_API_KEY)
  catalog   inventory MMO_Assets/ zips + extract previews -> docs/ASSET_CATALOG.md
  curate    extract the chosen subset (GLB/glTF only) into assets/3d/<vendor>/
  all       fetch every available source, then catalog
  manifest  rebuild assets/3d/CREDITS.md from the manifest

Design notes:
- Stdlib only (urllib / zipfile / json), matching the rest of tools/. No pip installs.
- Config-driven from tools/asset_sources.json so the dev session can add packs /
  queries / prompts / curate-picks without touching code.
- MMO_Assets/ is the single raw archive: manual downloads and fetched zips converge
  there and stay zipped. Only curated, on-theme, style-consistent picks get extracted
  into assets/3d/ (and only GLB/glTF, never FBX/OBJ/.blend) to keep the project clean.
- Every curated/generated/downloaded asset is recorded in assets/3d/ASSET_MANIFEST.json
  with its source + license + attribution; CC-BY attributions roll up into
  assets/3d/CREDITS.md. This is the license-provenance trail required by
  docs/ARCHITECTURE.md ("free/open assets only when license is clean").
- Keep everything GENERIC. These are sci-fi stand-ins, never Star Wars trademarks.

Examples:
  python tools/fetch_assets.py kenney      # add CC0 Kenney packs to the archive
  python tools/fetch_assets.py catalog     # inventory the archive -> ASSET_CATALOG.md
  python tools/fetch_assets.py curate      # extract the chosen subset into assets/3d/
  python tools/fetch_assets.py poly        # needs $env:POLY_PIZZA_TOKEN
  python tools/fetch_assets.py tripo       # needs $env:TRIPO_API_KEY
  python tools/fetch_assets.py all
"""
from __future__ import annotations

import argparse
import datetime as _dt
import io
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = PROJECT_ROOT / "MMO_Assets"          # raw .zip archive (manual + fetched), left zipped
ASSET_DIR = PROJECT_ROOT / "assets" / "3d"     # curated, Godot-visible library (extracted)
POLY_DIR = ASSET_DIR / "polypizza"
GEN_DIR = ASSET_DIR / "generated"
MANIFEST_PATH = ASSET_DIR / "ASSET_MANIFEST.json"
CREDITS_PATH = ASSET_DIR / "CREDITS.md"
CATALOG_PATH = ASSET_DIR / "CATALOG.json"
CATALOG_MD = PROJECT_ROOT / "docs" / "ASSET_CATALOG.md"
PREVIEW_DIR = PROJECT_ROOT / "docs" / "asset_previews"
CONFIG_PATH = Path(__file__).resolve().parent / "asset_sources.json"

USER_AGENT = "SW_MMO_Prototype-asset-fetch/1.0 (+local prototype tooling)"

TRIPO_BASE = "https://api.tripo3d.ai/v2/openapi"
POLY_BASE = "https://api.poly.pizza/v1.1"
KENNEY_ASSET_PAGE = "https://kenney.nl/assets/{slug}"

# Set once in main(). On machines with HTTPS-scanning security software (or behind
# a TLS-intercepting proxy), the injected root CA can fail OpenSSL 3.x's strict
# structural checks ("Basic Constraints of CA cert not marked critical"), which
# Python 3.12+ enables by default. We relax ONLY that strict flag — the cert chain,
# hostname, and expiry are still fully verified. --insecure disables verification
# entirely as a last resort.
_SSL_CTX: ssl.SSLContext | None = None


def make_ssl_context(insecure: bool) -> ssl.SSLContext:
	if insecure:
		return ssl._create_unverified_context()
	ctx = ssl.create_default_context()  # loads the OS trust store, incl. Windows roots
	ctx.verify_flags &= ~ssl.VERIFY_X509_STRICT
	return ctx


# --------------------------------------------------------------------------- #
# HTTP helpers (stdlib urllib, with a real User-Agent so hosts don't 403)
# --------------------------------------------------------------------------- #
def _request(url: str, *, headers: dict | None = None, data: bytes | None = None, method: str | None = None):
	hdrs = {"User-Agent": USER_AGENT}
	if headers:
		hdrs.update(headers)
	return urllib.request.Request(url, data=data, headers=hdrs, method=method)


def http_bytes(url: str, *, headers: dict | None = None, timeout: int = 60) -> bytes:
	with urllib.request.urlopen(_request(url, headers=headers), timeout=timeout, context=_SSL_CTX) as resp:
		return resp.read()


def http_text(url: str, *, headers: dict | None = None, timeout: int = 60) -> str:
	return http_bytes(url, headers=headers, timeout=timeout).decode("utf-8", errors="replace")


def http_json(url: str, *, headers: dict | None = None, payload: dict | None = None, timeout: int = 60) -> dict:
	data = None
	hdrs = dict(headers or {})
	if payload is not None:
		data = json.dumps(payload).encode("utf-8")
		hdrs["Content-Type"] = "application/json"
	with urllib.request.urlopen(_request(url, headers=hdrs, data=data), timeout=timeout, context=_SSL_CTX) as resp:
		return json.loads(resp.read().decode("utf-8"))


def download_to(url: str, dest: Path, *, headers: dict | None = None, timeout: int = 120) -> int:
	dest.parent.mkdir(parents=True, exist_ok=True)
	with urllib.request.urlopen(_request(url, headers=headers), timeout=timeout, context=_SSL_CTX) as resp:
		total = 0
		with open(dest, "wb") as fh:
			while True:
				chunk = resp.read(65536)
				if not chunk:
					break
				fh.write(chunk)
				total += len(chunk)
	return total


# --------------------------------------------------------------------------- #
# Manifest / credits (license provenance trail)
# --------------------------------------------------------------------------- #
def _now() -> str:
	return _dt.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")


def load_manifest() -> dict:
	if MANIFEST_PATH.is_file():
		try:
			return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
		except json.JSONDecodeError:
			print(f"  ! manifest unreadable, starting fresh: {MANIFEST_PATH}")
	return {"generated_at": _now(), "entries": {}}


def save_manifest(manifest: dict) -> None:
	manifest["generated_at"] = _now()
	ASSET_DIR.mkdir(parents=True, exist_ok=True)
	MANIFEST_PATH.write_text(json.dumps(manifest, indent="\t", ensure_ascii=False), encoding="utf-8")
	write_credits(manifest)


def record(manifest: dict, entry: dict) -> None:
	entry.setdefault("fetched_at", _now())
	# Store path relative to the project root so the manifest is portable.
	lp = entry.get("local_path")
	if lp:
		try:
			entry["local_path"] = str(Path(lp).resolve().relative_to(PROJECT_ROOT)).replace("\\", "/")
		except ValueError:
			pass
	manifest["entries"][entry["id"]] = entry


def write_credits(manifest: dict) -> None:
	"""Rebuild a human-readable credits file. CC0 needs no attribution, but we list
	everything by source so the license posture is auditable at a glance."""
	by_source: dict[str, list[dict]] = {}
	for e in manifest.get("entries", {}).values():
		by_source.setdefault(e.get("source", "unknown"), []).append(e)

	lines = [
		"# Asset Credits & Licenses",
		"",
		"Auto-generated by `tools/fetch_assets.py`. Do not edit by hand.",
		"",
		"All assets here are generic sci-fi stand-ins, not Star Wars trademarks.",
		"CC0 assets require no attribution; CC-BY assets are credited below as the",
		"license legally requires. See docs/ASSET_PIPELINE.md.",
		"",
	]
	for source in sorted(by_source):
		items = by_source[source]
		lines.append(f"## {source} ({len(items)})")
		lines.append("")
		for e in sorted(items, key=lambda x: x.get("name", "")):
			lic = e.get("license", "?")
			attr = e.get("attribution", "").strip()
			if attr:
				lines.append(f"- **{e.get('name', e['id'])}** - {lic} - {attr}")
			else:
				lines.append(f"- {e.get('name', e['id'])} - {lic} (no attribution required)")
		lines.append("")
	CREDITS_PATH.write_text("\n".join(lines), encoding="utf-8")


# --------------------------------------------------------------------------- #
# Kenney.nl  (CC0, no key) — resolve the zip href at runtime (CDN paths rotate)
# --------------------------------------------------------------------------- #
_ZIP_RE = re.compile(r"https://kenney\.nl/media/[^\"'<> ]+?\.zip")


def kenney_resolve_zip(slug: str, fallback_url: str) -> str | None:
	page_url = KENNEY_ASSET_PAGE.format(slug=slug)
	try:
		html = http_text(page_url)
	except urllib.error.HTTPError as exc:
		print(f"  ! {slug}: asset page returned HTTP {exc.code}")
		return fallback_url or None
	except urllib.error.URLError as exc:
		print(f"  ! {slug}: could not load asset page ({exc.reason})")
		return fallback_url or None
	matches = _ZIP_RE.findall(html)
	# Prefer a zip whose URL mentions this slug, else first match, else fallback.
	for m in matches:
		if slug.replace("-", "") in m.replace("-", "").lower():
			return m
	if matches:
		return matches[0]
	if fallback_url:
		print(f"  . {slug}: no zip href on page, using configured fallback URL")
		return fallback_url
	print(f"  ! {slug}: no download zip found and no fallback URL")
	return None


def kenney_pack_present(slug: str) -> Path | None:
	"""Find an already-archived zip for this slug in MMO_Assets, tolerating the
	version suffixes Kenney adds (kenney_blaster-kit_2.1.zip vs slug 'blaster-kit')."""
	if not RAW_DIR.is_dir():
		return None
	key = slug.replace("-", "").lower()
	for p in RAW_DIR.glob("*.zip"):
		if key in p.stem.replace("-", "").replace("_", "").lower():
			return p
	return None


def cmd_kenney(args, config: dict, manifest: dict) -> int:
	"""Download Kenney pack zips into the MMO_Assets archive (no extraction).
	Manual downloads and fetched packs converge here; 'catalog' then inventories
	the archive and 'curate' extracts the chosen subset into assets/3d/."""
	packs = config.get("kenney_packs", [])
	RAW_DIR.mkdir(parents=True, exist_ok=True)
	print(f"== Kenney.nl (CC0) -> MMO_Assets/ - {len(packs)} packs ==")
	ok = 0
	for pack in packs:
		slug = pack["slug"]
		existing = kenney_pack_present(slug)
		if existing and not args.force:
			print(f"  = {slug}: already archived ({existing.name})")
			ok += 1
			continue
		url = kenney_resolve_zip(slug, pack.get("url", ""))
		if not url:
			continue
		fname = url.split("/")[-1].split("?")[0] or f"kenney_{slug}.zip"
		dest = RAW_DIR / fname
		print(f"  > {slug}: downloading {fname}")
		try:
			blob = http_bytes(url, timeout=240)
			zipfile.ZipFile(io.BytesIO(blob))  # validate it's a real zip
			dest.write_bytes(blob)
		except (urllib.error.URLError, zipfile.BadZipFile, OSError) as exc:
			print(f"  ! {slug}: download failed: {exc}")
			continue
		print(f"    archived {len(blob) // 1024} KB -> MMO_Assets/{fname}")
		ok += 1
	print(f"== Kenney done: {ok}/{len(packs)} packs in archive. Run 'catalog' next. ==")
	return 0


# --------------------------------------------------------------------------- #
# Poly Pizza  (needs free POLY_PIZZA_TOKEN; mixed CC0 / CC-BY)
# --------------------------------------------------------------------------- #
# License query param polarity is counterintuitive: 1 = CC0 only, 0 = CC-BY only,
# omit for both. (Verified against the official OpenAPI spec.)
_POLY_LICENSE = {"cc0": "1", "ccby": "0", "any": None}


def poly_search(token: str, keyword: str, license_key: str, limit: int) -> list[dict]:
	params = {"Limit": str(min(max(limit, 1), 32)), "Page": "0"}
	lic = _POLY_LICENSE.get(license_key, "1")
	if lic is not None:
		params["License"] = lic
	url = f"{POLY_BASE}/search/{urllib.parse.quote(keyword)}?{urllib.parse.urlencode(params)}"
	data = http_json(url, headers={"x-auth-token": token})
	return data.get("results", [])[:limit]


def cmd_poly(args, config: dict, manifest: dict) -> int:
	token = os.environ.get("POLY_PIZZA_TOKEN", "").strip()
	if not token:
		print("POLY_PIZZA_TOKEN is not set — skipping poly.pizza.")
		print("  Get a free key at https://poly.pizza/settings/api, then:")
		print('  PowerShell:  $env:POLY_PIZZA_TOKEN = "your_key"')
		return 0 if args.soft else 2
	queries = config.get("polypizza_queries", [])
	print(f"== Poly Pizza - {len(queries)} queries ==")
	ok = 0
	for q in queries:
		keyword = q["q"]
		lic_key = q.get("license", "cc0")
		limit = int(q.get("limit", 4))
		try:
			results = poly_search(token, keyword, lic_key, limit)
		except urllib.error.HTTPError as exc:
			body = exc.read().decode("utf-8", errors="replace")[:200]
			print(f"  ! '{keyword}': HTTP {exc.code} {body}")
			continue
		print(f"  > '{keyword}' ({lic_key}): {len(results)} models")
		for r in results:
			model_id = r.get("ID", "")
			dl = r.get("Download", "")
			if not dl:
				continue
			title = r.get("Title", model_id)
			slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-") or "model"
			dest = POLY_DIR / f"{slug}__{model_id}.glb"
			if dest.is_file() and not args.force:
				ok += 1
				continue
			try:
				download_to(dl, dest)  # static CDN — no auth header needed
			except urllib.error.URLError as exc:
				print(f"    ! {title}: download failed: {exc}")
				continue
			record(manifest, {
				"id": f"poly:{model_id}",
				"name": title,
				"source": "poly.pizza",
				"license": r.get("Licence", "?"),
				"attribution": r.get("Attribution", ""),
				"source_url": f"https://poly.pizza/m/{model_id}",
				"local_path": str(dest),
				"tri_count": r.get("Tri Count"),
				"query": keyword,
			})
			ok += 1
			print(f"    + {title} [{r.get('Licence', '?')}]")
	save_manifest(manifest)
	print(f"== Poly Pizza done: {ok} models ==")
	return 0


# --------------------------------------------------------------------------- #
# Tripo  (text-to-3D; needs TRIPO_API_KEY = tsk_...)
# --------------------------------------------------------------------------- #
_TRIPO_TERMINAL = {"success", "failed", "cancelled", "banned", "expired", "unknown"}


def tripo_create(key: str, prompt: dict) -> str:
	body = {
		"type": "text_to_model",
		"prompt": prompt["prompt"],
		"model_version": prompt.get("model_version", "v2.5-20250123"),
		"texture": prompt.get("texture", True),
		"pbr": prompt.get("pbr", True),
		"texture_quality": prompt.get("texture_quality", "standard"),
		"face_limit": prompt.get("face_limit", 10000),
	}
	resp = http_json(f"{TRIPO_BASE}/task", headers={"Authorization": f"Bearer {key}"}, payload=body)
	if resp.get("code") != 0:
		raise RuntimeError(f"create rejected: code={resp.get('code')} {resp.get('message', '')}")
	return resp["data"]["task_id"]


def tripo_poll(key: str, task_id: str, *, timeout: int = 600, interval: int = 4) -> dict:
	headers = {"Authorization": f"Bearer {key}"}
	waited = 0
	while True:
		resp = http_json(f"{TRIPO_BASE}/task/{task_id}", headers=headers)
		data = resp.get("data", {})
		status = data.get("status", "unknown")
		progress = data.get("progress", 0)
		if status in _TRIPO_TERMINAL:
			return data
		if waited >= timeout:
			raise TimeoutError(f"task {task_id} still '{status}' after {timeout}s")
		print(f"      ...{status} {progress}% (queue {data.get('queuing_num', 0)})", flush=True)
		time.sleep(interval)
		waited += interval


def cmd_tripo(args, config: dict, manifest: dict) -> int:
	key = os.environ.get("TRIPO_API_KEY", "").strip()
	if not key:
		print("TRIPO_API_KEY is not set — skipping Tripo generation.")
		print("  Get a key at https://platform.tripo3d.ai/api-keys (300 free trial credits), then:")
		print('  PowerShell:  $env:TRIPO_API_KEY = "tsk_..."')
		return 0 if args.soft else 2
	if not key.startswith("tsk_"):
		print(f"  ! warning: TRIPO_API_KEY does not start with 'tsk_' (got '{key[:6]}…') — continuing anyway")
	prompts = config.get("tripo_prompts", [])
	print(f"== Tripo text-to-3D - {len(prompts)} prompts ==")
	ok = 0
	for p in prompts:
		name = p["name"]
		dest = GEN_DIR / f"{name}.glb"
		if dest.is_file() and not args.force:
			print(f"  = {name}: already generated (use --force to regenerate)")
			ok += 1
			continue
		print(f"  > {name}: submitting…")
		try:
			task_id = tripo_create(key, p)
			data = tripo_poll(key, task_id, timeout=args.timeout)
		except (urllib.error.URLError, RuntimeError, TimeoutError, KeyError) as exc:
			print(f"  ! {name}: {exc}")
			continue
		if data.get("status") != "success":
			print(f"  ! {name}: ended '{data.get('status')}' ({data.get('error_msg', '')})")
			continue
		out = data.get("output", {})
		glb = out.get("pbr_model") or out.get("model") or out.get("base_model")
		if not glb:
			print(f"  ! {name}: success but no GLB URL in output")
			continue
		try:
			download_to(glb, dest)  # signed URL expires in ~24h — grab it now
		except urllib.error.URLError as exc:
			print(f"  ! {name}: GLB download failed: {exc}")
			continue
		record(manifest, {
			"id": f"tripo:{task_id}",
			"name": name,
			"source": "tripo3d",
			"license": "Tripo paid-API output (commercial use per Tripo ToS)",
			"attribution": "",
			"source_url": f"https://platform.tripo3d.ai (task {task_id})",
			"local_path": str(dest),
			"prompt": p["prompt"],
			"consumed_credit": data.get("consumed_credit"),
		})
		ok += 1
		print(f"    + {name}.glb (credits: {data.get('consumed_credit', '?')})")
	save_manifest(manifest)
	print(f"== Tripo done: {ok}/{len(prompts)} models ==")
	return 0


# --------------------------------------------------------------------------- #
# Catalog  (inventory the MMO_Assets archive; capture style + theme for curation)
# --------------------------------------------------------------------------- #
MODEL_EXTS = (".glb", ".gltf", ".fbx", ".obj")

STYLE_PROFILE = {
	"Kenney": (
		"Ultra-low-poly, flat-shaded, single shared low-res texture atlas, bright "
		"minimalist palette, ~1-unit modular grid. Extremely self-consistent. GLB is "
		"self-contained (textures embedded)."
	),
	"Quaternius": (
		"Low-poly with smooth/gradient shading and baked ambient occlusion; a notch "
		"more detail than Kenney. Per-pack textures. Many packs include rigged & "
		"animated characters/creatures. Ships glTF (+.bin+Textures), FBX, .blend."
	),
	"Unknown": "Unclassified - inspect the preview before mixing with the house style.",
}

# Theme verdicts for a Clone Wars-era desert spaceport. Heuristic; tune in the doc.
THEME_SKIP = ("dungeon", "pirate", "fantasy", "arcade", "cyberpunk", "rpg", "cube-pet", "cubepets", "nature", "arena")
THEME_KEEP = ("space", "sci-fi", "scifi", "modular", "building", "city", "station", "blaster",
	"factory", "market", "food", "prototype", "survival", "spaceship", "rover", "mech")
THEME_MAYBE = ("character", "men", "women", "monster", "animated", "gun", "fps", "alien", "robot", "pet", "mini")


def _png_dims(data: bytes) -> str:
	import struct
	if data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR":
		w, h = struct.unpack(">II", data[16:24])
		return f"{w}x{h}"
	return "?"


def guess_vendor(zip_name: str, names: list[str]) -> str:
	low = zip_name.lower()
	if low.startswith("kenney") or "/kenney" in low:
		return "Kenney"
	if "quaternius" in low or any("quaternius" in n.lower() for n in names):
		return "Quaternius"
	# Fallback: Kenney zips always carry "Visit Kenney.url"; otherwise assume Quaternius.
	if any("visit kenney" in n.lower() for n in names):
		return "Kenney"
	return "Quaternius" if not low.startswith("kenney") else "Kenney"


def clean_pack_name(zip_name: str, vendor: str) -> str:
	stem = Path(zip_name).stem
	# Strip Google-Takeout-style timestamp suffixes: "...-20260625T000414Z-3-001"
	stem = re.sub(r"-\d{8}T\d{6}Z(-\d+)*$", "", stem)
	if vendor == "Kenney":
		stem = re.sub(r"^kenney_", "", stem)
		stem = re.sub(r"_[0-9.]+$", "", stem)  # trailing version
	return stem.strip(" -_") or zip_name


def classify_theme(pack: str) -> tuple[str, str]:
	low = pack.lower()
	for kw in THEME_SKIP:
		if kw in low:
			return "skip", f"off-theme ('{kw}') for a desert spaceport"
	for kw in THEME_KEEP:
		if kw in low:
			return "keep", f"on-theme ('{kw}')"
	for kw in THEME_MAYBE:
		if kw in low:
			return "maybe", f"situational ('{kw}') - usable if it matches the house style"
	return "maybe", "unclassified - judge from the preview"


def find_preview(names: list[str]) -> str | None:
	imgs = [n for n in names if n.lower().endswith((".png", ".jpg", ".jpeg"))]
	if not imgs:
		return None
	def base(n: str) -> str:
		return n.rsplit("/", 1)[-1].lower()
	master = [n for n in imgs if base(n) in ("preview.png", "preview.jpg", "preview_1.jpg", "preview (variation a).png")]
	if master:
		return master[0]
	named = [n for n in imgs if "preview" in n.lower() or "sample" in n.lower()]
	pool = named or imgs
	pool.sort(key=lambda n: (n.count("/"), len(n)))  # prefer top-level, shortest
	return pool[0]


def read_license(zf: zipfile.ZipFile, names: list[str]) -> str:
	for n in names:
		if "licen" in n.lower() and n.lower().endswith(".txt"):
			try:
				txt = zf.read(n).decode("utf-8", errors="replace").lower()
			except Exception:
				continue
			if "cc0" in txt or "public domain" in txt or "creative commons zero" in txt:
				return "CC0 1.0"
			if "creative commons" in txt and "by" in txt:
				return "CC-BY (check License.txt)"
			return "see License.txt"
	return "CC0 1.0 (assumed)"


def catalog_zip(zip_path: Path) -> dict:
	with zipfile.ZipFile(zip_path) as zf:
		names = [n for n in zf.namelist() if not n.endswith("/")]
		vendor = guess_vendor(zip_path.name, names)
		pack = clean_pack_name(zip_path.name, vendor)
		exts = {}
		for n in names:
			e = Path(n).suffix.lower()
			if e:
				exts[e] = exts.get(e, 0) + 1
		model_fmts = [e[1:] for e in MODEL_EXTS if e in exts]
		godot_fmt = "glb" if "glb" in model_fmts else ("gltf" if "gltf" in model_fmts else (model_fmts[0] if model_fmts else "none"))
		model_count = max((exts.get(e, 0) for e in MODEL_EXTS), default=0)
		theme, reason = classify_theme(pack)

		# Extract the preview image for visual style comparison.
		preview_rel = None
		prev = find_preview(names)
		if prev:
			PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
			out = PREVIEW_DIR / f"{vendor}_{re.sub(r'[^A-Za-z0-9._-]+', '-', pack)}{Path(prev).suffix.lower()}"
			try:
				out.write_bytes(zf.read(prev))
				preview_rel = out.relative_to(CATALOG_MD.parent).as_posix()
			except Exception:
				preview_rel = None

		# Texture resolution signal (PNG only).
		tex_res = "?"
		for n in names:
			low = n.lower()
			if low.endswith(".png") and not any(k in low for k in ("preview", "sample", "thumb")):
				try:
					tex_res = _png_dims(zf.read(n)[:64])
				except Exception:
					tex_res = "?"
				break

		sample = sorted({Path(n).stem for n in names if Path(n).suffix.lower() in MODEL_EXTS})[:8]
		license_str = read_license(zf, names)

	return {
		"zip": zip_path.name,
		"vendor": vendor,
		"pack": pack,
		"license": license_str,
		"size_mb": round(zip_path.stat().st_size / 1_048_576, 1),
		"model_count": model_count,
		"formats": model_fmts,
		"godot_format": godot_fmt,
		"texture_res": tex_res,
		"preview": preview_rel,
		"style": STYLE_PROFILE.get(vendor, STYLE_PROFILE["Unknown"]),
		"theme": theme,
		"theme_reason": reason,
		"sample_models": sample,
	}


def write_catalog_md(entries: list[dict]) -> None:
	order = {"keep": 0, "maybe": 1, "skip": 2}
	entries = sorted(entries, key=lambda e: (order.get(e["theme"], 3), e["vendor"], e["pack"]))
	n_keep = sum(1 for e in entries if e["theme"] == "keep")
	n_maybe = sum(1 for e in entries if e["theme"] == "maybe")
	n_skip = sum(1 for e in entries if e["theme"] == "skip")
	L = [
		"# Asset Catalog",
		"",
		"Auto-generated by `python tools/fetch_assets.py catalog`. Do not edit by hand.",
		"",
		f"Inventory of the `MMO_Assets/` raw archive: **{len(entries)} packs** "
		f"(keep {n_keep} / maybe {n_maybe} / skip {n_skip}). Zips stay zipped; "
		"`curate` extracts the chosen subset into `assets/3d/`.",
		"",
		"## Style consistency",
		"",
		"All packs here are **CC0** generic sci-fi (no Star Wars trademarks). The two",
		"vendors do NOT share an identical look:",
		"",
		f"- **Kenney** - {STYLE_PROFILE['Kenney']}",
		f"- **Quaternius** - {STYLE_PROFILE['Quaternius']}",
		"",
		"Pick ONE as the primary house style and use the other only where it reads as",
		"the same family. Preview thumbnails below let you eyeball the match. The chosen",
		"style is recorded in `tools/asset_sources.json` under `house_style`.",
		"",
		"## Format guidance",
		"",
		"Prefer **GLB** (Kenney) and **glTF** (Quaternius) for Godot 4.6 - `curate`",
		"extracts only those and drops FBX/OBJ/.blend to keep imports clean.",
		"",
	]
	headers = {"keep": "## ✅ Keep (on-theme)", "maybe": "## 🟡 Maybe (situational)", "skip": "## ⛔ Skip (off-theme)"}
	current = None
	for e in entries:
		if e["theme"] != current:
			current = e["theme"]
			L += ["", headers.get(current, f"## {current}"), ""]
		L.append(f"### {e['vendor']} - {e['pack']}")
		if e["preview"]:
			L.append(f"![{e['pack']}]({e['preview']})")
		L += [
			"",
			f"- zip: `{e['zip']}` ({e['size_mb']} MB)",
			f"- license: {e['license']}",
			f"- models: {e['model_count']} | formats: {', '.join(e['formats']) or 'none'} | Godot import: **{e['godot_format']}** | texture: {e['texture_res']}",
			f"- theme: **{e['theme']}** - {e['theme_reason']}",
			f"- sample: {', '.join(e['sample_models'])}",
			"",
		]
	CATALOG_MD.parent.mkdir(parents=True, exist_ok=True)
	CATALOG_MD.write_text("\n".join(L), encoding="utf-8")


def cmd_catalog(args, config: dict, manifest: dict) -> int:
	if not RAW_DIR.is_dir():
		print(f"no archive folder: {RAW_DIR}")
		return 2
	zips = sorted(RAW_DIR.glob("*.zip"))
	if not zips:
		print(f"no zips in {RAW_DIR}")
		return 0
	print(f"== Catalog - {len(zips)} zips in MMO_Assets/ ==")
	entries = []
	for z in zips:
		try:
			entry = catalog_zip(z)
		except (zipfile.BadZipFile, OSError) as exc:
			print(f"  ! {z.name}: {exc}")
			continue
		entries.append(entry)
		mark = {"keep": "+", "maybe": "~", "skip": "-"}.get(entry["theme"], "?")
		print(f"  {mark} {entry['vendor']:<11} {entry['pack']:<28} {entry['model_count']:>4} models  [{entry['godot_format']}]")
	CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
	CATALOG_PATH.write_text(json.dumps({"generated_at": _now(), "packs": entries}, indent="\t", ensure_ascii=False), encoding="utf-8")
	write_catalog_md(entries)
	print(f"== Catalog done -> {CATALOG_PATH.relative_to(PROJECT_ROOT)} + {CATALOG_MD.relative_to(PROJECT_ROOT)} ==")
	print(f"   previews -> {PREVIEW_DIR.relative_to(PROJECT_ROOT)}")
	return 0


# --------------------------------------------------------------------------- #
# Curate  (extract a chosen, style-consistent subset into assets/3d/)
# --------------------------------------------------------------------------- #
def _curated_members(names: list[str]) -> list[str]:
	"""Pick the cleanest Godot-ready files: prefer self-contained GLB; else glTF +
	its .bin buffers + textures. Always drop FBX/OBJ/MTL/.blend and preview images.

	Kenney 'GLB format' models are NOT fully self-contained: their GLB references an
	external Textures/colormap.png by relative path, so when we take the GLBs we must
	also bring along their sibling textures (but not the duplicate FBX/OBJ-format ones,
	which would just be wasted imports)."""
	has_glb = any(n.lower().endswith(".glb") for n in names)

	def is_preview(low: str) -> bool:
		return any(k in low for k in ("preview", "sample", "thumb", "overview"))

	def is_other_format(low: str) -> bool:
		return ("fbx format" in low) or ("obj format" in low) or low.endswith(".blend")

	chosen = []
	for n in names:
		low = n.lower()
		if has_glb:
			if low.endswith(".glb"):
				chosen.append(n)
			elif low.endswith((".png", ".jpg", ".jpeg")) and not is_preview(low) and not is_other_format(low):
				chosen.append(n)  # GLB-format textures (e.g. colormap.png) the GLB needs
		else:
			if low.endswith((".gltf", ".bin")):
				chosen.append(n)
			elif low.endswith((".png", ".jpg", ".jpeg")) and not is_preview(low):
				chosen.append(n)
	return chosen


def cmd_curate(args, config: dict, manifest: dict) -> int:
	picks = config.get("curate", [])
	if not picks:
		print("Nothing in the 'curate' list of asset_sources.json yet.")
		print("Add entries like { \"match\": \"space-station-kit\", \"vendor\": \"Kenney\" } then re-run.")
		return 0
	zips = sorted(RAW_DIR.glob("*.zip")) if RAW_DIR.is_dir() else []
	print(f"== Curate - {len(picks)} picks -> assets/3d/ ==")
	ok = 0
	for pick in picks:
		match = pick["match"].lower()
		hits = sorted((z for z in zips if match in z.name.lower()), key=lambda z: len(z.name))
		if not hits:
			print(f"  ! no archived zip matches '{pick['match']}'")
			continue
		if len(hits) > 1:
			print(f"  ~ '{pick['match']}' matched {len(hits)} zips; using {hits[0].name}")
		zip_path = hits[0]  # most specific (shortest filename) wins
		with zipfile.ZipFile(zip_path) as zf:
			names = [n for n in zf.namelist() if not n.endswith("/")]
			vendor = pick.get("vendor") or guess_vendor(zip_path.name, names)
			pack = clean_pack_name(zip_path.name, vendor)
			dest = ASSET_DIR / vendor.lower() / pack
			members = _curated_members(names)
			if dest.is_dir() and any(dest.iterdir()) and not args.force:
				print(f"  = {vendor}/{pack}: already curated")
				ok += 1
				continue
			count = 0
			dest_root = dest.resolve()
			for m in members:
				target = (dest / m).resolve()
				if not str(target).startswith(str(dest_root)):
					continue
				target.parent.mkdir(parents=True, exist_ok=True)
				with zf.open(m) as src, open(target, "wb") as out:
					out.write(src.read())
				count += 1
			license_str = read_license(zf, names)
		print(f"  + {vendor}/{pack}: {count} files -> assets/3d/{vendor.lower()}/{pack}")
		record(manifest, {
			"id": f"{vendor.lower()}:{pack}",
			"name": f"{vendor} {pack}",
			"source": vendor,
			"license": license_str,
			"attribution": "" if "CC0" in license_str else f"{pack} by {vendor} (CC-BY - verify License.txt)",
			"source_url": "MMO_Assets/" + zip_path.name,
			"local_path": str(dest),
		})
		ok += 1
	save_manifest(manifest)
	print(f"== Curate done: {ok}/{len(picks)} packs in assets/3d/ ==")
	return 0


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #
def cmd_all(args, config: dict, manifest: dict) -> int:
	args.soft = True  # don't hard-fail 'all' just because an optional key is missing
	cmd_kenney(args, config, manifest)
	cmd_poly(args, config, manifest)
	cmd_tripo(args, config, manifest)
	cmd_catalog(args, config, manifest)
	print("\nNext: review docs/ASSET_CATALOG.md, set 'curate' in asset_sources.json, then run 'curate'.")
	return 0


def cmd_manifest(args, config: dict, manifest: dict) -> int:
	write_credits(manifest)
	n = len(manifest.get("entries", {}))
	print(f"rebuilt {CREDITS_PATH.relative_to(PROJECT_ROOT)} from {n} manifest entries")
	return 0


def load_config(path: Path) -> dict:
	if not path.is_file():
		print(f"error: config not found: {path}", file=sys.stderr)
		sys.exit(2)
	return json.loads(path.read_text(encoding="utf-8"))


def build_parser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser(description="Asset fetch + generate pipeline for SW_MMO_Prototype.")
	parser.add_argument("--config", default=str(CONFIG_PATH), help="path to asset_sources.json")
	parser.add_argument("--force", action="store_true", help="refetch/regenerate even if a file already exists")
	parser.add_argument("--soft", action="store_true", help="treat a missing API key as a skip (exit 0), not an error")
	parser.add_argument("--timeout", type=int, default=600, help="per-model Tripo generation timeout in seconds")
	parser.add_argument("--insecure", action="store_true", help="LAST RESORT: disable TLS verification entirely (default already relaxes only the strict X.509 structural check for HTTPS-scanning antivirus/proxies)")
	sub = parser.add_subparsers(dest="cmd", required=True)
	for name, fn, help_text in (
		("kenney", cmd_kenney, "download CC0 Kenney pack zips into MMO_Assets/ (no key)"),
		("poly", cmd_poly, "search + download from poly.pizza (POLY_PIZZA_TOKEN)"),
		("tripo", cmd_tripo, "text-to-3D generation via tripo3d.ai (TRIPO_API_KEY)"),
		("catalog", cmd_catalog, "inventory MMO_Assets/ zips + previews -> docs/ASSET_CATALOG.md"),
		("curate", cmd_curate, "extract the chosen subset (GLB/glTF) into assets/3d/"),
		("all", cmd_all, "fetch every available source, then catalog"),
		("manifest", cmd_manifest, "rebuild assets/3d/CREDITS.md from the manifest"),
	):
		sp = sub.add_parser(name, help=help_text)
		sp.set_defaults(func=fn)
	return parser


def main(argv: list[str] | None = None) -> int:
	try:
		sys.stdout.reconfigure(encoding="utf-8")  # avoid mojibake on the Windows console
	except Exception:
		pass
	args = build_parser().parse_args(argv)
	global _SSL_CTX
	_SSL_CTX = make_ssl_context(args.insecure)
	if args.insecure:
		print("! TLS verification DISABLED (--insecure)")
	config = load_config(Path(args.config))
	manifest = load_manifest()
	return args.func(args, config, manifest)


if __name__ == "__main__":
	sys.exit(main())
