param(
    [string]$GodotConsole = "godot-console"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:smokeCount = 0  # counted at runtime so docs can say "see the gate output" (kills count drift)

function Invoke-GodotStep {
    param(
        [string]$Label,
        [string[]]$Arguments
    )

    if ($Arguments -contains "--script") { $script:smokeCount++ }
    Write-Host "`n$Label"
    $oldAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $GodotConsole @Arguments 2>&1
    $ErrorActionPreference = $oldAction
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }


    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode."
    }

    $joined = $output -join "`n"
    if ($joined -match "SCRIPT ERROR|SCRIPT ERROR:|Parse Error|Parser Error|ERROR:|!is_inside_tree") {
        throw "$Label emitted a Godot script or engine error."
    }
}

Write-Host "Godot version:"
& $GodotConsole --version

Write-Host "`nPython unit tests:"
$pythonOutput = & cmd /c "python -m unittest discover -s `"$projectRoot\tests`" 2>&1"
$pythonExitCode = $LASTEXITCODE
$pythonOutput | ForEach-Object { Write-Host $_ }
if ($pythonExitCode -ne 0) {
    throw "Python unit tests failed with exit code $pythonExitCode."
}

Invoke-GodotStep "Import check:" @("--headless", "--path", $projectRoot, "--import", "--quit")

Invoke-GodotStep "Runtime launch check:" @("--headless", "--path", $projectRoot, "--quit-after", "2")

$smokeOutput = & python "$projectRoot\tools\run_smoke_tests.py" 2>&1
$smokeExitCode = $LASTEXITCODE
$smokeOutput | ForEach-Object {
    if ($_ -match "SMOKE_COUNT:(\d+)") {
        $script:smokeCount = [int]$Matches[1]
    } else {
        Write-Host $_
    }
}
if ($smokeExitCode -ne 0) {
    throw "Smoke tests failed."
}


# Not-before-live invariant (owner ruling 2026-07-03): pure models + design docs for
# siege / player-cities / server-space are PERMITTED (they live in scripts/rules + docs);
# their HOT wiring (files or preloads in scripts/net) is PARKED until the ground loop
# has real players. A new siege_*/city_*/space_* file in scripts/net, or a HOT-file
# preload of one, fails the gate until the CLAUDE.md list changes.
$parkedFiles = Get-ChildItem "$projectRoot\scripts\net" -File | Where-Object { $_.Name -match '^(siege_|city_|space_)' }
if ($parkedFiles) {
    throw "Not-before-live invariant: parked wiring in scripts/net: $(($parkedFiles | ForEach-Object { $_.Name }) -join ', ')"
}
$hotFiles = @("$projectRoot\scripts\net\network_manager.gd", "$projectRoot\scripts\net\net_world.gd")
$parkedPreloads = Select-String -Path $hotFiles -Pattern 'preload\(.*(siege_|city_)' -ErrorAction SilentlyContinue
if ($parkedPreloads) {
    throw "Not-before-live invariant: HOT file preloads a parked model: $(($parkedPreloads | ForEach-Object { "$($_.Filename):$($_.LineNumber)" }) -join ', ')"
}

$rpcCount = (Select-String -Path "$projectRoot\scripts\net\network_manager.gd" -Pattern '@rpc\(').Count
Write-Host "`nWired GDScript smokes run: $script:smokeCount | RPC surface (@rpc in network_manager.gd): $rpcCount"
Write-Host "All checks passed."
