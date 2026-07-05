param(
  [ValidateSet("dry-run", "run-preview", "run-refine", "get")]
  [string]$Command = "dry-run",
  [string]$Spec,
  [string]$AssetId,
  [string]$OutDir,
  [string]$TaskId,
  [string]$PreviewTaskId,
  [string]$RefineOutId,
  [int]$PollSeconds = 10,
  [int]$TimeoutSeconds = 900,
  [switch]$Download
)

$ErrorActionPreference = "Stop"
$ApiRoot = "https://api.meshy.ai/openapi/v2/text-to-3d"

function New-Directory {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Get-AssetSpec {
  param([string]$SpecPath, [string]$WantedId)
  $data = Get-Content -Raw -LiteralPath $SpecPath | ConvertFrom-Json
  foreach ($asset in $data.assets) {
    if ($asset.id -eq $WantedId) {
      return $asset
    }
  }
  throw "Asset id not found in spec: $WantedId"
}

function Convert-ObjectToHashtable {
  param($Value)
  if ($null -eq $Value) {
    return $null
  }
  if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string] -and $Value -isnot [System.Management.Automation.PSCustomObject]) {
    $items = @()
    foreach ($item in $Value) {
      $items += Convert-ObjectToHashtable $item
    }
    return $items
  }
  if ($Value -is [System.Management.Automation.PSCustomObject]) {
    $hash = [ordered]@{}
    foreach ($prop in $Value.PSObject.Properties) {
      $hash[$prop.Name] = Convert-ObjectToHashtable $prop.Value
    }
    return $hash
  }
  return $Value
}

function New-PreviewBody {
  param($Asset)
  $body = Convert-ObjectToHashtable $Asset.api_body
  if (-not $body) {
    $body = [ordered]@{}
  }
  $body["mode"] = "preview"
  $body["prompt"] = $Asset.prompt
  if ($body["prompt"].Length -gt 600) {
    throw "Meshy prompt exceeds 600 characters"
  }
  if (-not $body.Contains("target_formats")) {
    $body["target_formats"] = @("glb")
  }
  if ($body["target_formats"] -is [string]) {
    $body["target_formats"] = @($body["target_formats"])
  }
  return $body
}

function New-RefineBody {
  param($Asset, [string]$PreviewId)
  $body = Convert-ObjectToHashtable $Asset.refine_body
  if (-not $body) {
    $body = [ordered]@{}
  }
  $body["mode"] = "refine"
  $body["preview_task_id"] = $PreviewId
  if ($body.Contains("texture_prompt") -and $body["texture_prompt"].Length -gt 600) {
    throw "Meshy texture_prompt exceeds 600 characters"
  }
  if (-not $body.Contains("target_formats")) {
    $body["target_formats"] = @("glb")
  }
  if ($body["target_formats"] -is [string]) {
    $body["target_formats"] = @($body["target_formats"])
  }
  return $body
}

function Get-Headers {
  if (-not $env:MESHY_API_KEY) {
    throw "MESHY_API_KEY is not set"
  }
  return @{
    "Authorization" = "Bearer $env:MESHY_API_KEY"
    "Content-Type" = "application/json"
  }
}

function Invoke-MeshyJson {
  param([string]$Method, [string]$Uri, $Body)
  $params = @{
    Method = $Method
    Uri = $Uri
    Headers = Get-Headers
  }
  if ($null -ne $Body) {
    $params["Body"] = ($Body | ConvertTo-Json -Depth 20)
    $params["ContentType"] = "application/json"
  }
  return Invoke-RestMethod @params
}

function Redact-Url {
  param([string]$Url)
  if (-not $Url) {
    return $Url
  }
  try {
    $uri = [Uri]$Url
    return $uri.GetLeftPart([System.UriPartial]::Path)
  } catch {
    return "<redacted-url>"
  }
}

function Write-RedactedResponse {
  param($Task, [string]$Path)
  $summary = [ordered]@{
    id = $Task.id
    mode = $Task.mode
    type = $Task.type
    status = $Task.status
    progress = $Task.progress
    task_error = $Task.task_error
    consumed_credits = $Task.consumed_credits
    created_at = $Task.created_at
    finished_at = $Task.finished_at
    thumbnail_url = (Redact-Url $Task.thumbnail_url)
    alpha_thumbnail_url = (Redact-Url $Task.alpha_thumbnail_url)
    model_urls = [ordered]@{}
    texture_urls = @()
  }
  if ($Task.model_urls) {
    foreach ($prop in $Task.model_urls.PSObject.Properties) {
      $summary.model_urls[$prop.Name] = Redact-Url $prop.Value
    }
  }
  if ($Task.texture_urls) {
    foreach ($texture in $Task.texture_urls) {
      $texSummary = [ordered]@{}
      foreach ($prop in $texture.PSObject.Properties) {
        $texSummary[$prop.Name] = Redact-Url $prop.Value
      }
      $summary.texture_urls += $texSummary
    }
  }
  $summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Save-TaskStatus {
  param($Task, [string]$Folder)
  $lines = @(
    "# Meshy Task Status",
    "",
    "Task id: ``$($Task.id)``",
    "Type: ``$($Task.type)``",
    "Status: ``$($Task.status)``",
    "Progress: ``$($Task.progress)``",
    "Consumed credits: ``$($Task.consumed_credits)``",
    "",
    "Downloaded files, if available:",
    "",
    "- ``model.glb``",
    "- ``thumbnail.png``",
    "- ``alpha_thumbnail.png``",
    "",
    "Provider response is saved as ``provider_response_redacted.json``; signed URLs are stripped."
  )
  $lines -join "`n" | Set-Content -LiteralPath (Join-Path $Folder "STATUS.md") -Encoding UTF8
}

function Save-Readme {
  param($Asset, $RequestBody, [string]$Folder, [bool]$Submitted)
  $lines = @(
    "# Meshy Preview Request",
    "",
    "Asset id: ``$($Asset.id)``",
    "Display name: $($Asset.display_name)",
    "Submitted: ``$Submitted``",
    "",
    "## Prompt",
    "",
    $RequestBody.prompt,
    "",
    "## Safety",
    "",
    "The API key is read from ``MESHY_API_KEY`` and is not written to this folder."
  )
  $lines -join "`n" | Set-Content -LiteralPath (Join-Path $Folder "README.md") -Encoding UTF8
}

function Save-RefineReadme {
  param($Asset, $RequestBody, [string]$Folder, [bool]$Submitted)
  $texturePrompt = ""
  if ($RequestBody.Contains("texture_prompt")) {
    $texturePrompt = $RequestBody["texture_prompt"]
  }
  $lines = @(
    "# Meshy Refine Request",
    "",
    "Asset id: ``$($Asset.id)``",
    "Display name: $($Asset.display_name)",
    "Submitted: ``$Submitted``",
    "Preview task id: ``$($RequestBody.preview_task_id)``",
    "",
    "## Texture Prompt",
    "",
    $texturePrompt,
    "",
    "## Safety",
    "",
    "The API key is read from ``MESHY_API_KEY`` and is not written to this folder."
  )
  $lines -join "`n" | Set-Content -LiteralPath (Join-Path $Folder "README.md") -Encoding UTF8
}

function Save-Downloads {
  param($Task, [string]$Folder)
  if ($Task.status -ne "SUCCEEDED") {
    return
  }
  if ($Task.model_urls.glb) {
    Invoke-WebRequest -Uri $Task.model_urls.glb -OutFile (Join-Path $Folder "model.glb") -UseBasicParsing
  }
  if ($Task.thumbnail_url) {
    Invoke-WebRequest -Uri $Task.thumbnail_url -OutFile (Join-Path $Folder "thumbnail.png") -UseBasicParsing
  }
  if ($Task.alpha_thumbnail_url) {
    Invoke-WebRequest -Uri $Task.alpha_thumbnail_url -OutFile (Join-Path $Folder "alpha_thumbnail.png") -UseBasicParsing
  }
}

function Wait-Task {
  param([string]$Id, [int]$Poll, [int]$Timeout)
  $deadline = (Get-Date).AddSeconds($Timeout)
  $lastStatus = ""
  while ($true) {
    $task = Invoke-MeshyJson -Method "GET" -Uri "$ApiRoot/$Id"
    if ($task.status -ne $lastStatus) {
      Write-Host "Meshy task $Id`: $($task.status) $($task.progress)%"
      $lastStatus = $task.status
    }
    if ($task.status -in @("SUCCEEDED", "FAILED", "CANCELED")) {
      return $task
    }
    if ((Get-Date) -gt $deadline) {
      throw "Timed out waiting for Meshy task $Id"
    }
    Start-Sleep -Seconds ([Math]::Max(1, $Poll))
  }
}

if ($Command -in @("dry-run", "run-preview")) {
  if (-not $Spec -or -not $AssetId -or -not $OutDir) {
    throw "--spec, --asset-id, and --out-dir are required"
  }
  $asset = Get-AssetSpec -SpecPath $Spec -WantedId $AssetId
  $folder = Join-Path $OutDir $AssetId
  New-Directory $folder
  $body = New-PreviewBody -Asset $asset
  $body | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $folder "request_body.json") -Encoding UTF8
  Save-Readme -Asset $asset -RequestBody $body -Folder $folder -Submitted:($Command -eq "run-preview")
  if ($Command -eq "dry-run") {
    Write-Host "Dry run wrote $(Join-Path $folder "request_body.json")"
    exit 0
  }
  $created = Invoke-MeshyJson -Method "POST" -Uri $ApiRoot -Body $body
  $created.result | Set-Content -LiteralPath (Join-Path $folder "task_id.txt") -Encoding UTF8
  $task = Wait-Task -Id $created.result -Poll $PollSeconds -Timeout $TimeoutSeconds
  Write-RedactedResponse -Task $task -Path (Join-Path $folder "provider_response_redacted.json")
  Save-Downloads -Task $task -Folder $folder
  Save-TaskStatus -Task $task -Folder $folder
  Write-Host "Meshy preview complete: $($created.result) -> $folder"
  exit 0
}

if ($Command -eq "run-refine") {
  if (-not $Spec -or -not $AssetId -or -not $OutDir) {
    throw "--spec, --asset-id, and --out-dir are required"
  }
  $asset = Get-AssetSpec -SpecPath $Spec -WantedId $AssetId
  $previewFolder = Join-Path $OutDir $AssetId
  $previewId = $PreviewTaskId
  if (-not $previewId) {
    $taskFile = Join-Path $previewFolder "task_id.txt"
    if (-not (Test-Path -LiteralPath $taskFile)) {
      throw "Preview task id not supplied and task_id.txt not found: $taskFile"
    }
    $previewId = (Get-Content -Raw -LiteralPath $taskFile).Trim()
  }
  if (-not $RefineOutId) {
    $RefineOutId = "$AssetId`_refine_v1"
  }
  $folder = Join-Path $OutDir $RefineOutId
  New-Directory $folder
  $body = New-RefineBody -Asset $asset -PreviewId $previewId
  $body | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $folder "request_body.json") -Encoding UTF8
  Save-RefineReadme -Asset $asset -RequestBody $body -Folder $folder -Submitted:$true
  $created = Invoke-MeshyJson -Method "POST" -Uri $ApiRoot -Body $body
  $created.result | Set-Content -LiteralPath (Join-Path $folder "task_id.txt") -Encoding UTF8
  $task = Wait-Task -Id $created.result -Poll $PollSeconds -Timeout $TimeoutSeconds
  Write-RedactedResponse -Task $task -Path (Join-Path $folder "provider_response_redacted.json")
  Save-Downloads -Task $task -Folder $folder
  Save-TaskStatus -Task $task -Folder $folder
  Write-Host "Meshy refine complete: $($created.result) -> $folder"
  exit 0
}

if ($Command -eq "get") {
  if (-not $TaskId -or -not $OutDir) {
    throw "--task-id and --out-dir are required"
  }
  New-Directory $OutDir
  $task = Invoke-MeshyJson -Method "GET" -Uri "$ApiRoot/$TaskId"
  Write-RedactedResponse -Task $task -Path (Join-Path $OutDir "provider_response_redacted.json")
  if ($Download) {
    Save-Downloads -Task $task -Folder $OutDir
  }
  Save-TaskStatus -Task $task -Folder $OutDir
  Write-Host "Retrieved Meshy task: $TaskId -> $OutDir"
}
