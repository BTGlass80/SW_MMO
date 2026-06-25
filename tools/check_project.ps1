param(
    [string]$GodotConsole = "godot-console"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Invoke-GodotStep {
    param(
        [string]$Label,
        [string[]]$Arguments
    )

    Write-Host "`n$Label"
    $output = & $GodotConsole @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }

    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode."
    }

    $joined = $output -join "`n"
    if ($joined -match "SCRIPT ERROR|SCRIPT ERROR:|Parse Error|Parser Error") {
        throw "$Label emitted a Godot script error."
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

Invoke-GodotStep "Rules smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/rules_smoke.gd")

Invoke-GodotStep "Ground combat model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/ground_combat_model_smoke.gd")

Invoke-GodotStep "Armor condition model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/armor_condition_model_smoke.gd")

Invoke-GodotStep "Action window model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/action_window_model_smoke.gd")

Invoke-GodotStep "Range action window model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_action_window_model_smoke.gd")

Invoke-GodotStep "Combat event envelope model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/combat_event_envelope_model_smoke.gd")

Invoke-GodotStep "Combat event log model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/combat_event_log_model_smoke.gd")

Invoke-GodotStep "Character sheet model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/character_sheet_model_smoke.gd")

Invoke-GodotStep "Range controller smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_controller_smoke.gd")

Invoke-GodotStep "Range status model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_status_model_smoke.gd")

Invoke-GodotStep "Range inspection model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_inspection_model_smoke.gd")

Invoke-GodotStep "Range hit feedback model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_hit_feedback_model_smoke.gd")

Invoke-GodotStep "Range state badge model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_state_badge_model_smoke.gd")

Invoke-GodotStep "Range target model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/range_target_model_smoke.gd")

Invoke-GodotStep "Moving target model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/moving_target_model_smoke.gd")

Invoke-GodotStep "Modal overlay model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/modal_overlay_model_smoke.gd")

Invoke-GodotStep "Space overlay layout model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_overlay_layout_model_smoke.gd")

Invoke-GodotStep "Space overlay mode model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_overlay_mode_model_smoke.gd")

Invoke-GodotStep "Space station strip model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_station_strip_model_smoke.gd")

Invoke-GodotStep "Space contact selection model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_contact_selection_model_smoke.gd")

Invoke-GodotStep "Space action log model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_action_log_model_smoke.gd")

Invoke-GodotStep "Space tactical model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_tactical_model_smoke.gd")

Invoke-GodotStep "Space overlay live clock smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_overlay_live_clock_smoke.gd")

Invoke-GodotStep "Space status model smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/space_status_model_smoke.gd")

Invoke-GodotStep "Data smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/data_smoke.gd")

Invoke-GodotStep "Net smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/net_smoke.gd")

Invoke-GodotStep "World builder smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/world_builder_smoke.gd")

Invoke-GodotStep "Content smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/content_smoke.gd")

Invoke-GodotStep "Combat arena smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/combat_arena_smoke.gd")

Invoke-GodotStep "Persistence smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/persistence_smoke.gd")

Invoke-GodotStep "Zone state smoke:" @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/zone_state_smoke.gd")

Write-Host "`nAll checks passed."
