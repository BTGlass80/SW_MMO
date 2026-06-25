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
