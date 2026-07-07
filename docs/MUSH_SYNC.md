# MUSH Sync Manifest â€” weekly drift report

Owner posture (2026-07-03, from the Fable review), quoted in `CLAUDE.md`:

> Formalize a scheduled weekly `mush-content-porter` re-extraction
> (quests/NPCs/creatures/skill deltas) with a source-hash manifest diff, so
> MUSH content drift is an automated sync report, not a review-time surprise.

`tools/mush_sync_manifest.py` is that manifest + diff tool. It hashes the
specific `C:\SW_MUSH` files that fed a curated import under this project's
`data/`, so a **weekly re-run tells you exactly which upstream sources moved
since the last baseline** â€” before a human has to eyeball anything.

`C:\SW_MUSH` remains STRICTLY READ-ONLY. This tool only ever opens files
there to read bytes (including `sw_mush.db`, hashed as one opaque
whole-file blob, never opened via `sqlite3`). It never creates, edits, or
deletes anything under that tree.

## What is tracked

See the header comment and `TRACKED_FILES` / `TRACKED_DIR_GLOBS` /
`TRACKED_ALWAYS_FILES` in `tools/mush_sync_manifest.py` for the exact list.
Summary:

- `docs/design/Guide_*.md` (glob, 24 files as of this writing) â€” the SW_MUSH
  system design guides that orient every curated import.
- `data/species/*.yaml` (glob, 9 files) â€” fed `data/species_clone_wars.json`
  in full.
- A curated allowlist of specific `data/*.yaml` and
  `data/worlds/clone_wars/**/*.yaml` files, each of which fed one or more
  specific curated JSON snapshots under this project's `data/` (see
  `data/manifests/read_only_sources.md`'s "Imported" sections for the
  per-file destination mapping). This is deliberately NOT a full walk of
  `data/worlds/clone_wars/` â€” that tree has 100+ files for content
  (Coruscant, Nar Shaddaa, Geonosis, generalized questlines, etc.) this
  project has not ported and isn't tracking yet; walking all of it would
  bury real drift signal in noise.
- `sw_mush.db` â€” the live SQLite database, tracked as a single whole-file
  hash.

**When a future re-port draws on a new SW_MUSH source file**, add its
relpath to `tools/mush_sync_manifest.py`'s tracked-source config AND to
`data/manifests/read_only_sources.md`, so the next `diff` run can see it
move too.

## Running it

From the repo root, with the read-only `C:\SW_MUSH` checkout present:

```powershell
# Baseline (or re-baseline after reviewing a drift report):
python tools\mush_sync_manifest.py snapshot --note "why/when this baseline was taken"

# Weekly check â€” compares the CURRENT hash of every tracked file against the
# stored baseline in data/mush_sync_manifest.json:
python tools\mush_sync_manifest.py diff

# Machine-readable form, e.g. for a scheduled task to parse:
python tools\mush_sync_manifest.py diff --json
```

Exit codes (so a scheduled run, e.g. Windows Task Scheduler, can alert):

- `0` â€” no drift; every tracked file's hash matches the stored baseline.
- `1` â€” drift detected; see the ADDED / REMOVED / CHANGED sections of the
  report (CHANGED entries include old/new size and the size delta).
- `2` â€” setup problem: `C:\SW_MUSH` not found at the given `--mush-root`, or
  (for `diff`) no stored manifest exists yet at `--manifest-path` (run
  `snapshot` first).

A file that exists but can't be read (locked, permission-denied, etc.) is
recorded as `UNREADABLE` and reported, but does not by itself set exit code
1 unless its readable/unreadable status just *changed* since the last
baseline â€” a persistently-locked file shouldn't spam the same "drift" alert
every week.

## What a drift report means

- **ADDED** â€” a file now exists under a tracked glob (e.g. a new
  `docs/design/Guide_27_*.md`, or a new file dropped into `data/species/`)
  that wasn't in the stored baseline. This is a candidate for the NEXT
  curated import, not something to port automatically.
- **REMOVED** â€” a previously-tracked file is gone (renamed or deleted
  upstream). Check whether this project's existing curated JSON that came
  from it is now stale/orphaned.
- **CHANGED** â€” a tracked file's content hash differs from the baseline.
  This is the important case: it means the curated JSON `data/*.json` file(s)
  this source previously fed **may now be out of date** with upstream MUSH
  content and should be reviewed for a re-port.

None of this is auto-applied. `mush-content-porter` (or whoever reviews the
report) decides what, if anything, to re-import.

## The re-port merge rule (read before re-porting anything)

**A re-port MERGES around prototype-added fields â€” it never overwrites
them.** Several curated `data/*.json` snapshots have gained fields that do
not exist in the SW_MUSH source and must survive any re-extraction, e.g.
(non-exhaustive, check each file's own `source_note`/`source_policy` before
touching it):

- `threat_tier`, `boss` â€” creature/NPC balance tags added in this project.
- `loot_mult` â€” per-creature loot multiplier tuning (`data/creatures_clone_wars.json`).
- `stun_return_fire` â€” combat behavior flag added for hostile NPCs.
- Harvest-value tweaks in `data/harvest_values_clone_wars.json` (server-side
  pricing deliberately deferred/tuned here, not sourced from MUSH at all).
- `vendor_stocked` curation flags and any `curation_note` /
  `faction_axis` recasts documented per-entry in a file's own provenance
  block (e.g. Djas Puhr's `bounty_hunters_guild` axis, Pell Darro's
  `republic` axis).

A safe re-port is a three-way merge: (1) re-extract the CW-legal subset from
the changed MUSH source the same way the original curation did, (2) diff
against the existing `data/*.json` by stable id/key, (3) overlay step (1)'s
raw fields onto each existing entry while PRESERVING every
prototype-added field already on it, adding new entries as new IDs and
flagging (not silently dropping) any entry whose MUSH source disappeared.
This is out of scope for `tools/mush_sync_manifest.py` itself â€” it only
tells you *that* something changed, never *what* to do about it.

## Tests

`tests/test_mush_sync_manifest.py` builds a small fake source tree under a
tmp dir (never touches the real `C:\SW_MUSH`) and covers: clean
snapshot-then-diff, a changed file, an added + a removed file, the
UNREADABLE non-fatal path, and all three exit codes. It's auto-discovered by
the project gate's `python -m unittest discover -s tests` step in
`tools/check_project.ps1` â€” no changes were needed there.
