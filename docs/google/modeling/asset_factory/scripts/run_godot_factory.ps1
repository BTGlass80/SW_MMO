param(
    [string]$GodotConsole = "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe",
    [string]$Spec = "res://docs/gpt/asset_factory/specs/mos_eisley_chunky_v0.json"
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")

if (-not (Test-Path $GodotConsole)) {
    throw "Godot console binary not found: $GodotConsole"
}

& $GodotConsole --path $projectRoot --script res://docs/gpt/asset_factory/scripts/godot_asset_factory.gd -- --spec $Spec

