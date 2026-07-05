param(
  [string]$BlenderExe = "$env:LOCALAPPDATA\CodexTools\blender-5.1.2\blender-5.1.2-windows-x64\blender.exe",
  [string]$BbmodelDir = "docs\gpt\asset_factory\generated\blockbench_cubecraft_v0\blockbench",
  [string]$OutDir = "docs\gpt\asset_factory\generated\blockbench_cubecraft_v0\glb"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BlenderExe)) {
  throw "Blender executable not found: $BlenderExe"
}

& $BlenderExe `
  --background `
  --python "docs\gpt\asset_factory\adapters\blender_bbmodel_to_glb.py" `
  -- `
  $BbmodelDir `
  $OutDir
