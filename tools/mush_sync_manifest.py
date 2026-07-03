#!/usr/bin/env python3
"""Weekly MUSH -> SW_MMO content sync manifest + drift report.

CLAUDE.md program posture (owner ruling 2026-07-03): "formalize a scheduled
weekly mush-content-porter re-extraction ... with a source-hash manifest
diff, so MUSH content drift is an automated sync report, not a review-time
surprise."

`C:\\SW_MUSH` is STRICTLY READ-ONLY. This tool only ever OPENS files there for
reading (in binary mode, to hash their bytes) -- it never creates, modifies,
or deletes anything under that tree, and it never opens `sw_mush.db` through
sqlite3 (it hashes the file's raw bytes like any other tracked file, so the
db is never queried, let alone opened read-write).

Two subcommands:

    snapshot --note "<why>"
        Hashes every currently-tracked source file under C:\\SW_MUSH and
        writes data/mush_sync_manifest.json -- the stored baseline the next
        `diff` run compares against. Re-running `snapshot` re-baselines
        (accepts current MUSH state as "known", the way updating a lockfile
        does after you've reviewed the diff).

    diff [--json]
        Re-hashes the same tracked sources RIGHT NOW and reports ADDED /
        REMOVED / CHANGED files (with size deltas) versus the stored
        manifest. Exit code 0 = no drift, 1 = drift detected (so a scheduled
        run, e.g. weekly cron/Task Scheduler, can alert on nonzero exit).

TRACKED SOURCES -- what this file watches, and why:

  - `docs/design/Guide_*.md` (glob): the SW_MUSH system design guides that
    orient every curated import (see data/manifests/read_only_sources.md's
    "SW_MUSH System Guides" section).
  - `data/species/*.yaml` (glob): all 9 species files fed
    data/species_clone_wars.json in full.
  - A curated list of specific `data/*.yaml` and
    `data/worlds/clone_wars/**/*.yaml` files that fed a specific curated
    JSON port under this project's `data/` -- see TRACKED_FILES below and
    data/manifests/read_only_sources.md's "Imported" sections for the
    per-file destination mapping. This is a curated allowlist, not a walk of
    all of `data/worlds/clone_wars/` (that tree has 100+ files for
    Coruscant/Nar Shaddaa/Geonosis/quest content this project has not ported
    yet; walking it all would bury real drift signal in irrelevant noise).
  - `sw_mush.db` (single whole-file hash): the live SQLite database, tracked
    as one opaque blob. Never opened via sqlite3; byte-hashed like any other
    file.

When a future re-port draws on a NEW SW_MUSH source file, add its relpath to
TRACKED_FILES (or a new glob entry) here AND to
data/manifests/read_only_sources.md, so the next `diff` run can see it move.
See docs/MUSH_SYNC.md for the weekly cadence and the re-port merge rule.

Usage:
    python tools/mush_sync_manifest.py snapshot --note "baseline 2026-07-03"
    python tools/mush_sync_manifest.py diff
    python tools/mush_sync_manifest.py diff --json
"""

import argparse
import datetime
import fnmatch
import hashlib
import json
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_MUSH_ROOT = r"C:\SW_MUSH"
DEFAULT_MANIFEST_PATH = os.path.join(REPO_ROOT, "data", "mush_sync_manifest.json")

# --- curated source list (production default) -----------------------------

# Specific files, relative to the MUSH root, forward-slash style. Each one
# fed a specific curated JSON port -- see data/manifests/read_only_sources.md.
TRACKED_FILES = [
    # Top-level data/*.yaml sources that fed a specific curated JSON port.
    "data/skills.yaml",                # -> data/weg_skill_catalog.json
    "data/weapons.yaml",               # -> data/weapons_clone_wars.json, data/armor_clone_wars.json
    "data/starships.yaml",             # -> data/starships_clone_wars.json
    "data/vendor_droids.yaml",         # -> data/droids_clone_wars.json
    "data/npcs_creatures.yaml",        # -> data/creatures_clone_wars.json

    # data/worlds/clone_wars/* sources used by the World-Depth NPC/vendor
    # drop and the space tactical slice.
    "data/worlds/clone_wars/npcs_drop_b_mos_eisley.yaml",
    "data/worlds/clone_wars/npcs_mos_eisley_population_p1.yaml",
    "data/worlds/clone_wars/npcs_mos_eisley_population_p2.yaml",
    "data/worlds/clone_wars/npcs_drop_ambient_tatooine_spaceport_civic.yaml",
    "data/worlds/clone_wars/npcs_drop_ambient_mos_eisley_service_sector.yaml",
    "data/worlds/clone_wars/npcs_drop_mob_grind_tatooine.yaml",
    "data/worlds/clone_wars/npcs_drop_mob_grind_hutt_territory.yaml",
    "data/worlds/clone_wars/maps/mos_eisley.yaml",       # -> data/mos_eisley_spaceport_row.json
    "data/worlds/clone_wars/planets/tatooine.yaml",      # -> data/mos_eisley_spaceport_row.json
    "data/worlds/clone_wars/traffic_archetypes.yaml",    # -> data/space_tactical_slice.json
    "data/worlds/clone_wars/ships.yaml",                 # -> data/space_tactical_slice.json
]

# (directory relative to MUSH root, fnmatch pattern) -- every matching file
# in the directory is tracked, since the whole directory fed a prior port
# (or, for the design guides, orients every port).
TRACKED_DIR_GLOBS = [
    ("data/species", "*.yaml"),        # -> data/species_clone_wars.json (all 9 files)
    ("docs/design", "Guide_*.md"),     # SW_MUSH system design guides
]

# Single files always tracked as an opaque whole-file hash.
TRACKED_ALWAYS_FILES = [
    "sw_mush.db",                      # never opened via sqlite3; byte-hash only
]

DEFAULT_SOURCE_SPEC = {
    "files": TRACKED_FILES,
    "dir_globs": TRACKED_DIR_GLOBS,
    "always_files": TRACKED_ALWAYS_FILES,
}

_HASH_CHUNK_SIZE = 1024 * 1024


def _to_posix(relpath):
    return relpath.replace(os.sep, "/")


def discover_source_paths(mush_root, spec=None):
    """Returns a sorted list of forward-slash relpaths (relative to
    mush_root) for every tracked source file that currently EXISTS.

    A tracked-but-missing fixed file is simply omitted here (not an error at
    this stage) -- if it was present in a previously stored manifest, the
    `diff` comparison naturally reports it as REMOVED, which is the correct
    drift signal. Directory globs behave the same way: a file that no longer
    matches (renamed/deleted) just won't appear.
    """
    spec = spec or DEFAULT_SOURCE_SPEC
    found = set()

    for rel in spec.get("files", []):
        abspath = os.path.join(mush_root, *rel.split("/"))
        if os.path.isfile(abspath):
            found.add(_to_posix(rel))

    for dir_rel, pattern in spec.get("dir_globs", []):
        dir_abspath = os.path.join(mush_root, *dir_rel.split("/"))
        if os.path.isdir(dir_abspath):
            for name in sorted(os.listdir(dir_abspath)):
                if fnmatch.fnmatch(name, pattern):
                    full = os.path.join(dir_abspath, name)
                    if os.path.isfile(full):
                        found.add(_to_posix(dir_rel + "/" + name))

    for rel in spec.get("always_files", []):
        abspath = os.path.join(mush_root, *rel.split("/"))
        if os.path.isfile(abspath):
            found.add(_to_posix(rel))

    return sorted(found)


def hash_file(path):
    """Returns (sha256_hex, size_bytes) for a file, reading it read-only in
    binary chunks. Raises OSError if the file cannot be read (caller decides
    how to record that, non-fatally)."""
    digest = hashlib.sha256()
    size = 0
    with open(path, "rb") as handle:
        while True:
            chunk = handle.read(_HASH_CHUNK_SIZE)
            if not chunk:
                break
            digest.update(chunk)
            size += len(chunk)
    return digest.hexdigest(), size


def build_file_records(mush_root, relpaths):
    """relpath -> {"sha256":.., "size":..} or {"error": "UNREADABLE"}.

    Unreadable files are recorded, not raised -- one locked/permission-denied
    file must not abort the whole snapshot/diff run.
    """
    records = {}
    for rel in relpaths:
        abspath = os.path.join(mush_root, *rel.split("/"))
        try:
            sha256, size = hash_file(abspath)
        except OSError:
            records[rel] = {"error": "UNREADABLE"}
        else:
            records[rel] = {"sha256": sha256, "size": size}
    return records


def build_manifest(mush_root, note, spec=None):
    relpaths = discover_source_paths(mush_root, spec)
    files = build_file_records(mush_root, relpaths)
    return {
        "schema_version": 1,
        "generated_at": datetime.datetime.now().isoformat(timespec="seconds"),
        "generated_note": note,
        "mush_root": mush_root,
        "file_count": len(files),
        "files": files,
    }


def write_manifest(manifest, manifest_path):
    out_dir = os.path.dirname(os.path.abspath(manifest_path))
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")


def load_manifest(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as handle:
        return json.load(handle)


# --- drift computation ------------------------------------------------------

def compute_drift(old_files, new_files):
    """Compares two {relpath: record} dicts and returns a drift report dict."""
    old_keys = set(old_files)
    new_keys = set(new_files)

    added = sorted(new_keys - old_keys)
    removed = sorted(old_keys - new_keys)
    changed = []
    unreadable_now = []
    unchanged_count = 0

    for rel in sorted(old_keys & new_keys):
        old_rec = old_files[rel]
        new_rec = new_files[rel]
        old_error = old_rec.get("error")
        new_error = new_rec.get("error")

        if new_error:
            unreadable_now.append(rel)

        if old_error or new_error:
            # Only a transition (readable<->unreadable, or the sha changed
            # while somehow still tagged readable both times) counts as
            # CHANGED. A file that stays UNREADABLE on both sides carries no
            # new information -- report it, but don't call it drift.
            if old_error != new_error:
                changed.append({
                    "path": rel,
                    "old_sha256": old_rec.get("sha256"),
                    "new_sha256": new_rec.get("sha256"),
                    "old_size": old_rec.get("size"),
                    "new_size": new_rec.get("size"),
                    "size_delta": None,
                    "note": "became %s" % ("UNREADABLE" if new_error else "readable"),
                })
            else:
                unchanged_count += 1
            continue

        if old_rec.get("sha256") != new_rec.get("sha256"):
            old_size = old_rec.get("size", 0) or 0
            new_size = new_rec.get("size", 0) or 0
            changed.append({
                "path": rel,
                "old_sha256": old_rec.get("sha256"),
                "new_sha256": new_rec.get("sha256"),
                "old_size": old_size,
                "new_size": new_size,
                "size_delta": new_size - old_size,
                "note": None,
            })
        else:
            unchanged_count += 1

    has_drift = bool(added or removed or changed)

    return {
        "added": added,
        "removed": removed,
        "changed": changed,
        "unreadable": sorted(unreadable_now),
        "unchanged_count": unchanged_count,
        "has_drift": has_drift,
        "summary": {
            "added": len(added),
            "removed": len(removed),
            "changed": len(changed),
            "unreadable": len(unreadable_now),
            "unchanged": unchanged_count,
        },
    }


def render_report(report, stored_manifest, mush_root, manifest_path):
    lines = []
    lines.append("MUSH sync drift report")
    lines.append("  mush root:      %s" % mush_root)
    lines.append("  stored manifest: %s" % manifest_path)
    lines.append("  baseline note:  %s" % stored_manifest.get("generated_note", ""))
    lines.append("  baseline at:    %s" % stored_manifest.get("generated_at", ""))
    lines.append("")

    if report["added"]:
        lines.append("ADDED (%d):" % len(report["added"]))
        for rel in report["added"]:
            lines.append("  + %s" % rel)
        lines.append("")

    if report["removed"]:
        lines.append("REMOVED (%d):" % len(report["removed"]))
        for rel in report["removed"]:
            lines.append("  - %s" % rel)
        lines.append("")

    if report["changed"]:
        lines.append("CHANGED (%d):" % len(report["changed"]))
        for entry in report["changed"]:
            if entry["size_delta"] is None:
                lines.append("  * %s (%s)" % (entry["path"], entry["note"]))
            else:
                sign = "+" if entry["size_delta"] >= 0 else ""
                lines.append("  * %s  size %s -> %s (%s%d bytes)" % (
                    entry["path"], entry["old_size"], entry["new_size"],
                    sign, entry["size_delta"]))
        lines.append("")

    if report["unreadable"]:
        lines.append("UNREADABLE right now (informational, non-fatal, %d):" % len(report["unreadable"]))
        for rel in report["unreadable"]:
            lines.append("  ? %s" % rel)
        lines.append("")

    summary = report["summary"]
    lines.append("summary: added=%d removed=%d changed=%d unreadable=%d unchanged=%d" % (
        summary["added"], summary["removed"], summary["changed"],
        summary["unreadable"], summary["unchanged"]))
    lines.append("DRIFT DETECTED" if report["has_drift"] else "NO DRIFT")
    return "\n".join(lines)


# --- CLI ---------------------------------------------------------------------

def cmd_snapshot(args, spec=None):
    if not os.path.isdir(args.mush_root):
        print(
            "error: SW_MUSH root not found at %r -- this tool only reads from "
            "it, never writes; check the path and try again." % args.mush_root,
            file=sys.stderr,
        )
        return 2

    manifest = build_manifest(args.mush_root, args.note, spec)
    write_manifest(manifest, args.manifest_path)

    unreadable = sorted(rel for rel, rec in manifest["files"].items() if "error" in rec)
    print("wrote %s: %d files tracked%s" % (
        args.manifest_path, manifest["file_count"],
        (", %d UNREADABLE" % len(unreadable)) if unreadable else ""))
    for rel in unreadable:
        print("  UNREADABLE: %s" % rel)
    return 0


def cmd_diff(args, spec=None):
    if not os.path.isdir(args.mush_root):
        print(
            "error: SW_MUSH root not found at %r -- this tool only reads from "
            "it, never writes; check the path and try again." % args.mush_root,
            file=sys.stderr,
        )
        return 2

    if not os.path.isfile(args.manifest_path):
        print(
            "error: no stored manifest at %r -- run the `snapshot` subcommand "
            "first to baseline." % args.manifest_path,
            file=sys.stderr,
        )
        return 2

    stored = load_manifest(args.manifest_path)
    stored_files = stored.get("files", {})

    relpaths = discover_source_paths(args.mush_root, spec)
    current_files = build_file_records(args.mush_root, relpaths)

    report = compute_drift(stored_files, current_files)

    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(render_report(report, stored, args.mush_root, args.manifest_path))

    return 1 if report["has_drift"] else 0


def build_arg_parser():
    parser = argparse.ArgumentParser(
        description="Weekly MUSH -> SW_MMO content sync manifest + drift report "
                    "(source-hash based; SW_MUSH is read-only reference).")
    parser.add_argument("--mush-root", default=DEFAULT_MUSH_ROOT,
                         help="path to the read-only SW_MUSH checkout (default: %(default)s)")
    parser.add_argument("--manifest-path", default=DEFAULT_MANIFEST_PATH,
                         help="path to the stored manifest JSON (default: %(default)s)")

    subparsers = parser.add_subparsers(dest="command", required=True)

    snap = subparsers.add_parser("snapshot", help="hash tracked MUSH sources and write the baseline manifest")
    snap.add_argument("--note", default="(no note provided)",
                       help="caller-supplied context for this baseline (why/when it was taken)")
    snap.set_defaults(func=cmd_snapshot)

    diff = subparsers.add_parser("diff", help="re-hash tracked MUSH sources and report drift vs the stored manifest")
    diff.add_argument("--json", action="store_true", help="emit machine-readable JSON instead of the text report")
    diff.set_defaults(func=cmd_diff)

    return parser


def main(argv=None):
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
