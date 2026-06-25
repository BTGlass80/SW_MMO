# Unattended Durable Loop

`tools/durable_loop.py` is a standalone Windows Task Scheduler wrapper adapted from the durable loop in `C:\SW_MUSH_night`.

It exists because in-session timers are not durable across app closes, reboots, sleep, or compute gaps. Windows Task Scheduler provides the durable pieces:

- persisted task registration
- `MultipleInstancesPolicy=IgnoreNew` so overlapping fires are skipped
- `StartWhenAvailable` so missed fires run when the machine is back
- `ExecutionTimeLimit=PT2H` so a hung unattended run does not block the loop forever
- timestamped run logs under `%USERPROFILE%\.codex\durable_loop\SW_MMO_Prototype`

## Important Limitation

This project version is agent-command agnostic. Codex Desktop is installed on this machine, but the app shim may not behave like a normal headless CLI from PowerShell. Do a dry run or benign test fire before arming a real unattended agent command.

## Safe Commands

Dry-run the generated launcher and task XML:

```powershell
python tools\durable_loop.py arm --in 300 --dry-run
```

Benign self-test that writes a log instead of launching an agent:

```powershell
python tools\durable_loop.py arm --in 60 --test-fire
python tools\durable_loop.py status
python tools\durable_loop.py disarm
```

Real unattended use requires a verified headless command:

```powershell
python tools\durable_loop.py arm --every 30 --agent-command "codex exec -"
```

If that command is not valid on this machine, pass the correct command explicitly with `--agent-command`.

## Resume Contract

The default prompt tells a fresh unattended agent to:

- work only in this prototype folder
- treat `C:\SW_MUSH` as read-only reference
- pursue WEG Star Wars D6 faithfulness and a fun MMO, not a one-to-one MUSH port
- read the core project docs first
- complete one bounded slice
- run `.\tools\check_project.ps1` in the foreground
- stop after a clean checkpoint or a real blocker

## Claude Code Self-Paced Loop (2026-06-24)

A second, simpler unattended mode for **Claude Code** sessions. Instead of Codex's
Windows Task Scheduler wrapper, it uses the Claude Code `/loop` skill in self-paced
(dynamic) mode: the session does one slice, then schedules its own wake-up to do the
next. It keeps developing without the owner prompting.

Mechanism and guardrails:
- **Queue:** `docs/UNATTENDED_BACKLOG.md`, worked strictly top-down, one slice per
  iteration.
- **Safety net (SCOPED — a parallel Codex session shares this repo):** this project
  is now a git repo (baseline `54fa6b8` on `master`). Commit ONLY the files this loop
  changed (`git add <paths>`, NEVER `git add -A`). A RED slice reverts ONLY its own
  files (`git checkout -- <your paths>`) — NEVER a blanket `git checkout -- .`,
  `git reset --hard`, or `git clean`, which would destroy Codex's in-flight asset work.
  Codex owns `tools/fetch_assets.py`, `tools/asset_sources.json`, `MMO_Assets/`,
  `assets/`, `docs/ASSET_CATALOG.md`, `docs/asset_previews/` — never stage or revert those.
- **Green bar:** the GDScript smokes + runtime launch + python tests (run them
  directly). The full `check_project.ps1` `--import` step can fail on Codex's
  half-curated assets — that is an asset-pipeline issue, NOT a code regression.
- **Per-iteration contract:** pick the top unblocked, non-owner-decision backlog item
  → implement → run the green-bar checks → GREEN: `git add <your paths> && git commit`,
  mark the item DONE + hash, append a one-line note to `docs/NIGHTLY_HANDOFF.md` and
  the backlog Log → RED: fix, or revert your own files and mark BLOCKED.
- **Hard stops (leave a status in the backlog, then end the loop):** backlog is dry;
  the top unblocked item needs an owner decision (see the backlog Guardrails list);
  or three consecutive iterations make no progress.
- **Limitation:** local Godot validation needs a live local session. The loop runs
  while this Claude Code session is alive; closing the app stops it (resume by asking
  Claude to continue the loop). The owner can interrupt at any time by sending a
  message. `C:\SW_MUSH` stays read-only throughout.
