# Beta Runbook - Thin Live MMO Track

Date: 2026-07-06
Scope: private trusted PT1 / beta rehearsal only

This runbook is for operating the thin live MMO slice: ground Mos Eisley,
server-authoritative play, persistence, telemetry, and recovery. It does not unlock
multiplayer space, sieges, player cities, broad planet rollout, or runtime LLM.

## 1. Required Tools

- Godot 4.6.3 console binary:
  `C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe`
- Repository root:
  `C:\Users\btgla\Documents\Codex\2026-06-14\i-d-like-you-to-create\outputs\SW_MMO_Prototype`
- Private LAN or trusted VPN only. ENet traffic is not encrypted.

Before any PT1 session, open the session bundle and run the full project gate into
that bundle:

```powershell
$SessionId = "PT1_2026_07_06_2000"
.\tools\pt1_bundle.ps1 -Action Start -SessionId $SessionId
$SessionDir = Join-Path (Get-Location) "sessions\$SessionId"
.\tools\check_project.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" *>&1 | Tee-Object -FilePath (Join-Path $SessionDir "gate.txt")
```

Do not run a human session from a tree with a red gate.

## 2. Session Folder

Create one folder per session under `sessions\` and copy every artifact there. If
you did the gate step above, this already exists.

Example:

```powershell
$SessionId = "PT1_2026_07_06_2000"
.\tools\pt1_bundle.ps1 -Action Start -SessionId $SessionId
$SessionDir = Join-Path (Get-Location) "sessions\$SessionId"
```

The final bundle should contain:

- `gate.txt` from the pre-session full gate.
- `server.log` and watchdog journal/log files.
- Telemetry JSONL for the session.
- A zipped persistence backup from before launch.
- A zipped persistence backup from after shutdown.
- Filled player feedback templates.
- `triage.md` filled from `docs/PT1_TRIAGE_TEMPLATE.md`.
- A short operator note listing blockers and admin interventions.

## 3. Persistence Backups

Godot user data lives at:

```powershell
$SaveDir = "$env:APPDATA\Godot\app_userdata\SW MMO Prototype"
```

The watchdog does not create backups automatically. Take explicit backups before and
after each session. The session bundle helper does this for normal PT1 operation:

```powershell
.\tools\pt1_bundle.ps1 -Action Start -SessionId $SessionId
```

After shutdown:

```powershell
.\tools\pt1_bundle.ps1 -Action Close -SessionId $SessionId
.\tools\pt1_bundle.ps1 -Action Audit -SessionId $SessionId -RequireFeedback
```

The audit fails if required artifacts are missing, if `gate.txt` does not contain
`All checks passed.`, or if `telemetry_tally.txt` reports unknown credit-bearing
events.

To restore:

1. Stop the server.
2. Run the restore action against the selected bundle backup.
3. Restart the server and verify reconnect/persistence.

```powershell
.\tools\pt1_bundle.ps1 -Action Restore -SessionId <SESSION_ID> -BackupName persistence_before.zip
```

The restore action moves the current save folder aside as
`*.restore_hold_<timestamp>` before expanding the selected backup. Do not delete that
hold folder until the restored world has been verified.

## 4. Launch

For PT1, use a deliberate port and telemetry file so logs are easy to archive. The
server defaults to its built-in port if no `--port` is passed; PT1 uses `24560` by
convention.

```powershell
$Telemetry = "user://telemetry/pt1_events.jsonl"
.\tools\run_server_watchdog.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" -ServerArgs "--port 24560 --telemetry-file $Telemetry"
```

If `24560` is unavailable, choose another port and write it in the session folder's
operator note. Players must connect to the same port.

## 5. Stop

Use `Ctrl+C` in the watchdog terminal. Wait for the Godot server process to exit, then
check that no old server remains:

```powershell
Get-Process Godot_v4.6.3-stable_win64_console -ErrorAction SilentlyContinue
```

If a process remains after a clean stop, record it as a blocker, capture the log, and
terminate only the stale process for this session.

## 6. Operator Commands

Admin commands are hardcoded to the current allowlist in `network_manager.gd`
(`admin`, `operator`, `pilot_1` at the time this runbook was written). Use them only
for recovery and record every use in the operator note.

Expected commands:

- `/admin list`
- `/admin inspect <char_id>`
- `/admin teleport <char_id> <zone_id>`
- `/admin unstuck <char_id>`
- `/admin grant <char_id> credits <amount>`
- `/admin grant <char_id> cp <amount>`
- `/admin grant <char_id> item <template_id>`
- `/admin force_save <char_id>`
- `/admin clear_space <char_id>`
- `/admin kick <char_id>`
- `/admin clear_listing <listing_id>`
- `/admin export_telemetry`

Default safe ground zone:

```text
tatooine.mos_eisley.spaceport
```

## 7. Telemetry

After the session, copy telemetry into the session folder and run the economy tally.
Use the actual telemetry path from the launch command or server log. The session
bundle helper copies the file and runs the tally by default:

```powershell
.\tools\pt1_bundle.ps1 -Action Close -SessionId $SessionId -TelemetryPath "$env:APPDATA\Godot\app_userdata\SW MMO Prototype\telemetry\pt1_events.jsonl"
```

Unknown credit-bearing events are blockers until classified or fixed. Faucets and
sinks must remain paired.

## 8. Stop-The-Test Thresholds

Stop the session and preserve logs if any of these happen:

- Server crash, repeated disconnect wave, or unrecoverable client login failure.
- Save corruption, missing character, missing inventory, or duplicated credits/items.
- More than one player requires admin unstuck/teleport for the same defect.
- A player is downed/dead with no recovery path.
- A PvP/consent/lawless-zone outcome surprises the target player.
- A credit or item exploit would require a wipe if repeated.

## 9. Weekly Triage

After each PT1 or beta window:

1. Archive the session bundle.
2. Run the bundle audit:
   `.\tools\pt1_bundle.ps1 -Action Audit -SessionId <SESSION_ID> -RequireFeedback`
3. Update `docs/KNOWN_ISSUES.md`.
4. Fill `triage.md`: P0 blockers, P1 release risks, P2 polish, content requests,
   and parked/post-live ideas.
5. Add focused smokes for reproducible blockers where practical.
6. Run the full gate before any next live window.
