# =============================================================================
# tools/soak_test.ps1 -- 20-bot scaling probe (PowerShell 5.1)
# =============================================================================
# Load-tests the server-authoritative net slice: starts one headless server
# with fast windows (--combat-window 1 --director-tick 0.5), launches
# -NumBots headless clients with a deterministic mix of the REAL headless
# affordances parsed by scripts/net/net_world.gd (--account/--secret/--name/
# --species/--quickstart/--autowalk/--autofire/--fire-nearest/--travel),
# samples process memory/CPU + log health every 30s for -DurationMinutes,
# then kills everything and writes a PASS/FAIL report.
#
# There is NO --quit-after client flag: clients run until killed, so this
# script terminates them by process (Win32_Process CommandLine match on
# net_world.tscn) at the end. All output is redirected via cmd /c so PS 5.1
# does not wrap native stderr in ErrorRecords.
#
# FAIL conditions (any one fails the soak):
#   * any SCRIPT ERROR in any server/client log
#   * any client that never logged "connected to server as peer"
#   * server process death before the duration ends
#
# USAGE EXAMPLES:
#   # Default probe: 20 bots, 30 minutes, report to <project>\soak_report.txt
#   .\tools\soak_test.ps1
#
#   # Quick 5-minute sanity pass with 6 bots:
#   .\tools\soak_test.ps1 -NumBots 6 -DurationMinutes 5
#
#   # Custom binary + report location:
#   .\tools\soak_test.ps1 -GodotConsole "D:\Godot\godot_console.exe" -ReportPath "C:\temp\soak_20.txt"
# =============================================================================

[CmdletBinding()]
param(
    [int]$NumBots = 20,
    [int]$DurationMinutes = 30,
    [string]$GodotConsole = "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $projectRoot "soak_report.txt"
}
$runStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$soakDir = Join-Path $projectRoot ("soak_logs\run_{0}" -f $runStamp)
New-Item -ItemType Directory -Force -Path $soakDir | Out-Null

if (-not (Test-Path $GodotConsole)) {
    Write-Error "Godot console binary not found: $GodotConsole"
    exit 1
}

function Get-NetWorldProcesses {
    # Every soak process (server + clients) carries net_world.tscn on its
    # command line; the plain Get-Process name match would also hit editors.
    $procs = @()
    try {
        $procs = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
            $_.Name -like "*Godot*" -and $_.CommandLine -like "*net_world.tscn*"
        })
    } catch {}
    return $procs
}

function Stop-NetWorldProcesses {
    foreach ($p in (Get-NetWorldProcesses)) {
        try { Stop-Process -Id $p.ProcessId -Force -Confirm:$false -ErrorAction Stop } catch {}
    }
}

function Wait-OneSecond {
    # `ping -n 2 127.0.0.1` ~= a 1s sleep that never blocks on input.
    ping -n 2 127.0.0.1 | Out-Null
}

# --- 0. Kill stray net_world Godot processes from earlier runs -------------
Write-Host "[soak] killing stray net_world processes..."
Stop-NetWorldProcesses
Wait-OneSecond

# --- 1. Start the server (fast windows) ------------------------------------
$serverLog = Join-Path $soakDir "server.log"
$serverCmd = '"{0}" --headless --path "{1}" res://scenes/net_world.tscn -- --server --combat-window 1 --director-tick 0.5 > "{2}" 2>&1' -f $GodotConsole, $projectRoot, $serverLog
Write-Host "[soak] starting server -> $serverLog"
Start-Process -FilePath $env:ComSpec -ArgumentList "/d /c `"$serverCmd`"" -WindowStyle Hidden | Out-Null

# Bounded wait for "server listening" in the server log (max ~60s).
$listening = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    Wait-OneSecond
    if (Test-Path $serverLog) {
        $hit = Select-String -Path $serverLog -Pattern "server listening" -SimpleMatch -ErrorAction SilentlyContinue
        if ($null -ne $hit) { $listening = $true; break }
    }
}
if (-not $listening) {
    Write-Host "[soak] FAIL: server never logged 'server listening' within 60s." -ForegroundColor Red
    Stop-NetWorldProcesses
    "SOAK FAIL: server never reached 'server listening' (see $serverLog)" | Out-File -FilePath $ReportPath -Encoding utf8
    exit 1
}
Write-Host "[soak] server listening."

# --- 2. Launch the bots ------------------------------------------------------
# Deterministic mix built ONLY from flags parsed in scripts/net/net_world.gd:
#   all bots:      --connect --account --secret --name --species --quickstart --autowalk
#   every 2nd bot: --autofire (WEG action-window load)
#   every 4th bot: --fire-nearest (PvP target selection on top of autofire)
#   every 5th bot: --travel <zone> (cross-zone routing load, rotating zones)
$speciesMix = @("human", "rodian", "twilek", "bothan", "duros", "sullustan", "trandoshan", "wookiee", "mon_calamari")
$travelZones = @("tatooine.mos_eisley.port_fringe", "tatooine.mos_eisley.market_district", "tatooine.dune_sea")

$botLogs = @{}
for ($i = 1; $i -le $NumBots; $i++) {
    $tag = "{0:d2}" -f $i
    $botLog = Join-Path $soakDir ("bot{0}.log" -f $tag)
    $botLogs[$tag] = $botLog

    $species = $speciesMix[($i - 1) % $speciesMix.Count]
    $flags = "--connect 127.0.0.1 --account bot$tag --secret soak$tag --name Bot$tag --species $species --quickstart --autowalk"
    if (($i % 2) -eq 0) { $flags = "$flags --autofire" }
    if (($i % 4) -eq 0) { $flags = "$flags --fire-nearest" }
    if (($i % 5) -eq 0) {
        $zone = $travelZones[(($i / 5) - 1) % $travelZones.Count]
        $flags = "$flags --travel $zone"
    }

    $botCmd = '"{0}" --headless --path "{1}" res://scenes/net_world.tscn -- {2} > "{3}" 2>&1' -f $GodotConsole, $projectRoot, $flags, $botLog
    Write-Host "[soak] launching bot$tag ($flags)"
    Start-Process -FilePath $env:ComSpec -ArgumentList "/d /c `"$botCmd`"" -WindowStyle Hidden | Out-Null
    Wait-OneSecond  # stagger registrations by ~1s
}

# --- 3. Sampling loop: every 30s for DurationMinutes ------------------------
$sampleCount = [Math]::Max(1, $DurationMinutes * 2)
$samples = @()
$serverDied = $false

function Get-LogPatternCount {
    param([string]$Pattern)
    $total = 0
    $hits = Select-String -Path (Join-Path $soakDir "*.log") -Pattern $Pattern -SimpleMatch -ErrorAction SilentlyContinue
    if ($null -ne $hits) { $total = @($hits).Count }
    return $total
}

Write-Host "[soak] sampling every 30s for $DurationMinutes minute(s) ($sampleCount samples)..."
for ($s = 1; $s -le $sampleCount; $s++) {
    Start-Sleep -Seconds 30

    # Each launch is a console-wrapper + real win64 process PAIR; measure only the
    # real (non-console) processes or the server row reads the 5MB wrapper and the
    # client count doubles.
    $netProcs = @((Get-NetWorldProcesses) | Where-Object { $_.Name -notlike "*console*" })
    $serverCim = @($netProcs | Where-Object { $_.CommandLine -like "*--server*" })
    $clientCim = @($netProcs | Where-Object { $_.CommandLine -notlike "*--server*" })

    $serverWsMB = 0.0; $serverCpuS = 0.0
    if ($serverCim.Count -gt 0) {
        try {
            $sp = Get-Process -Id $serverCim[0].ProcessId -ErrorAction Stop
            $serverWsMB = [Math]::Round($sp.WorkingSet64 / 1MB, 1)
            $serverCpuS = [Math]::Round($sp.CPU, 1)
        } catch {}
    } else {
        $serverDied = $true
    }

    $clientWsMB = 0.0; $clientCpuS = 0.0
    foreach ($c in $clientCim) {
        try {
            $cp = Get-Process -Id $c.ProcessId -ErrorAction Stop
            $clientWsMB += $cp.WorkingSet64 / 1MB
            $clientCpuS += $cp.CPU
        } catch {}
    }

    $serverLogLines = 0
    if (Test-Path $serverLog) {
        $serverLogLines = (Get-Content $serverLog | Measure-Object -Line).Lines
    }

    $sample = [pscustomobject]@{
        Sample        = $s
        Time          = Get-Date -Format "HH:mm:ss"
        SrvAlive      = ($serverCim.Count -gt 0)
        SrvWS_MB      = $serverWsMB
        SrvCPU_s      = $serverCpuS
        Clients       = $clientCim.Count
        CliWS_MB      = [Math]::Round($clientWsMB, 1)
        CliCPU_s      = [Math]::Round($clientCpuS, 1)
        ScriptErrors  = (Get-LogPatternCount "SCRIPT ERROR")
        InsideTreeErr = (Get-LogPatternCount "is_inside_tree")
        SrvLogLines   = $serverLogLines
    }
    $samples += $sample
    Write-Host ("[soak] sample {0}/{1}: srvAlive={2} srvWS={3}MB clients={4} scriptErr={5}" -f $s, $sampleCount, $sample.SrvAlive, $sample.SrvWS_MB, $sample.Clients, $sample.ScriptErrors)

    if ($serverDied) {
        Write-Host "[soak] server process died -- aborting sampling early." -ForegroundColor Red
        break
    }
}

# --- 4. Teardown: kill everything (no --quit-after flag exists) -------------
Write-Host "[soak] tearing down all net_world processes..."
Stop-NetWorldProcesses
Wait-OneSecond

# --- 5. Connection audit + totals -------------------------------------------
$neverConnected = @()
foreach ($tag in ($botLogs.Keys | Sort-Object)) {
    $log = $botLogs[$tag]
    $connected = $false
    if (Test-Path $log) {
        $hit = Select-String -Path $log -Pattern "connected to server as peer" -SimpleMatch -ErrorAction SilentlyContinue
        if ($null -ne $hit) { $connected = $true }
    }
    if (-not $connected) { $neverConnected += "bot$tag" }
}

$totalScriptErrors = (Get-LogPatternCount "SCRIPT ERROR")
$totalInsideTree = (Get-LogPatternCount "is_inside_tree")
$maxSrvWs = 0.0
$maxCliWs = 0.0
foreach ($smp in $samples) {
    if ($smp.SrvWS_MB -gt $maxSrvWs) { $maxSrvWs = $smp.SrvWS_MB }
    if ($smp.CliWS_MB -gt $maxCliWs) { $maxCliWs = $smp.CliWS_MB }
}

$failReasons = @()
if ($totalScriptErrors -gt 0) { $failReasons += "SCRIPT ERROR x$totalScriptErrors in logs" }
if ($neverConnected.Count -gt 0) { $failReasons += ("clients never connected: " + ($neverConnected -join ", ")) }
if ($serverDied) { $failReasons += "server process died before the duration ended" }
$verdict = "PASS"
if ($failReasons.Count -gt 0) { $verdict = "FAIL" }

# --- 6. Report ----------------------------------------------------------------
$report = @()
$report += "SW_MMO soak test report -- $runStamp"
$report += "  bots=$NumBots durationMinutes=$DurationMinutes samples=$($samples.Count)"
$report += "  logs: $soakDir"
$report += ""
$report += ($samples | Format-Table -AutoSize | Out-String).TrimEnd()
$report += ""
$report += "TOTALS:"
$report += "  peak server WorkingSet:  $maxSrvWs MB"
$report += "  peak client WorkingSet (sum): $maxCliWs MB"
$report += "  SCRIPT ERROR count:      $totalScriptErrors"
$report += "  is_inside_tree count:    $totalInsideTree"
$report += "  clients connected:       $($NumBots - $neverConnected.Count)/$NumBots"
$report += "  server survived:         $(-not $serverDied)"
$report += ""
if ($failReasons.Count -gt 0) {
    $report += "FAIL REASONS:"
    foreach ($r in $failReasons) { $report += "  - $r" }
    $report += ""
}
$report += "VERDICT: $verdict"

$report -join [Environment]::NewLine | Out-File -FilePath $ReportPath -Encoding utf8
Write-Host ""
Write-Host ($report -join [Environment]::NewLine)
Write-Host ""
Write-Host "[soak] report written to $ReportPath"

if ($verdict -eq "FAIL") { exit 1 }
exit 0

