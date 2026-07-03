# =============================================================================
# tools/run_server_watchdog.ps1 -- PT1 evening server watchdog (PowerShell 5.1)
# =============================================================================
# Keeps the headless authoritative server alive for a full playtest evening.
# Starts `net_world.tscn -- --server`, redirects all output to a timestamped
# log (via cmd /c so PS 5.1 does not wrap native stderr in ErrorRecords),
# waits for exit, appends a crash record (timestamp, exit code, last 20 log
# lines) to the watchdog journal, and restarts after a 3s backoff.
#
# A restart is SAFE: persistence is crash-safe (atomic .tmp -> rename onto
# world_state.dat), so a restarted server resumes the persisted world --
# accounts, characters, inventory, economy, and zone state all survive.
# In-flight action windows at the moment of the crash are lost; nothing else.
#
# STOP conditions:
#   * Sentinel file:  create <LogDir>\stop.flag  -> watchdog exits 0 between
#     restarts (it does NOT kill a healthy running server; stop the server
#     process yourself if you want it down immediately).
#   * Crash-loop:     more than -MaxRestartsPerHour restarts inside a rolling
#     60-minute window -> watchdog exits 1 loudly (something is truly broken;
#     read the journal + the last server log).
#
# USAGE EXAMPLES:
#   # Defaults: known Godot console binary, 10 restarts/hour, logs under
#   # <project>\watchdog_logs\
#   .\tools\run_server_watchdog.ps1
#
#   # PT1 fast-combat evening (extra server args are appended after --server):
#   .\tools\run_server_watchdog.ps1 -ServerArgs "--combat-window 5 --director-tick 2"
#
#   # Custom binary + tighter crash-loop guard:
#   .\tools\run_server_watchdog.ps1 -GodotConsole "D:\Godot\godot_console.exe" -MaxRestartsPerHour 5
#
#   # Stop it (from another shell):
#   New-Item -ItemType File "watchdog_logs\stop.flag"
# =============================================================================

[CmdletBinding()]
param(
    [string]$GodotConsole = "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe",
    [string]$ServerArgs = "",
    [int]$MaxRestartsPerHour = 10,
    [string]$LogDir = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $LogDir = Join-Path $projectRoot "watchdog_logs"
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

$stopFlag = Join-Path $LogDir "stop.flag"
$journalPath = Join-Path $LogDir "watchdog_journal.log"

function Write-Journal {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -Path $journalPath -Value $line -Encoding UTF8
}

if (-not (Test-Path $GodotConsole)) {
    Write-Error "Godot console binary not found: $GodotConsole"
    exit 1
}
if (Test-Path $stopFlag) {
    Write-Journal "stop.flag already present at $stopFlag -- remove it to arm the watchdog. Exiting."
    exit 0
}

Write-Journal "watchdog armed: project=$projectRoot maxRestartsPerHour=$MaxRestartsPerHour serverArgs='$ServerArgs'"
Write-Journal "stop sentinel: $stopFlag (create this file to stop the watchdog between restarts)"

# Rolling list of restart timestamps (starts after the first) for the crash-loop guard.
$restartTimes = @()
$firstStart = $true

while ($true) {
    if (Test-Path $stopFlag) {
        Write-Journal "stop.flag detected -- watchdog exiting cleanly (server stays down)."
        exit 0
    }

    if (-not $firstStart) {
        # Prune restarts older than a rolling hour, then check the guard.
        $cutoff = (Get-Date).AddHours(-1)
        $restartTimes = @($restartTimes | Where-Object { $_ -gt $cutoff })
        if ($restartTimes.Count -ge $MaxRestartsPerHour) {
            Write-Journal "FATAL: $($restartTimes.Count) restarts in the last hour (limit $MaxRestartsPerHour). CRASH LOOP -- watchdog giving up."
            Write-Host ""
            Write-Host "############################################################" -ForegroundColor Red
            Write-Host "# WATCHDOG ABORT: server is crash-looping.                #" -ForegroundColor Red
            Write-Host "# Read $journalPath" -ForegroundColor Red
            Write-Host "# and the newest server_*.log in $LogDir" -ForegroundColor Red
            Write-Host "############################################################" -ForegroundColor Red
            exit 1
        }
        $restartTimes += Get-Date
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $serverLog = Join-Path $LogDir ("server_{0}.log" -f $stamp)

    # cmd /c pattern: PowerShell 5.1 wraps a native command's stderr in
    # ErrorRecords when redirected in-process; routing the redirect through
    # cmd.exe keeps the log clean and the exit code honest.
    $cmdLine = '"{0}" --headless --path "{1}" res://scenes/net_world.tscn -- --server {2} > "{3}" 2>&1' -f $GodotConsole, $projectRoot, $ServerArgs, $serverLog
    Write-Journal "starting server -> $serverLog"
    $firstStart = $false

    $proc = Start-Process -FilePath $env:ComSpec -ArgumentList "/d /c `"$cmdLine`"" -NoNewWindow -PassThru -Wait
    $exitCode = $proc.ExitCode

    # Crash record: timestamp, exit code, last 20 log lines.
    $tailLines = @()
    if (Test-Path $serverLog) {
        try { $tailLines = @(Get-Content -Path $serverLog -Tail 20 -ErrorAction Stop) } catch {}
    }
    Write-Journal "server exited with code $exitCode -- last $($tailLines.Count) log lines follow:"
    foreach ($l in $tailLines) {
        Add-Content -Path $journalPath -Value ("    | " + $l) -Encoding UTF8
    }

    if (Test-Path $stopFlag) {
        Write-Journal "stop.flag detected after server exit -- watchdog exiting cleanly."
        exit 0
    }

    Write-Journal "restarting in 3s (crash-safe persistence: the world resumes from world_state.dat)..."
    Start-Sleep -Seconds 3
}
