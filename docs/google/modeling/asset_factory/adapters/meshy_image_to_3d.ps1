param(
  [ValidateSet("dry-run", "run", "get")]
  [string]$Command = "dry-run",
  [string]$Spec,
  [string]$AssetId,
  [string]$OutDir,
  [string]$TaskId,
  [int]$PollSeconds = 10,
  [int]$TimeoutSeconds = 900,
  [switch]$Download
)

$ErrorActionPreference = "Stop"
$ApiRoot = "https://api.meshy.ai/openapi/v1/image-to-3d"

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

function Get-MimeType {
  param([string]$Path)
  $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
  if ($ext -eq ".jpg" -or $ext -eq ".jpeg") {
    return "image/jpeg"
  }
  if ($ext -eq ".png") {
    return "image/png"
  }
  throw "Unsupported image extension for Meshy Image to 3D: $ext"
}

function Get-DataUri {
  param([string]$Path)
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $mime = Get-MimeType -Path $Path
  $encoded = [Convert]::ToBase64String($bytes)
  return "data:$mime;base64,$encoded"
}

function New-ImageBody {
  param($Asset, [string]$ResolvedImagePath)
  $body = Convert-ObjectToHashtable $Asset.api_body
  if (-not $body) {
    $body = [ordered]@{}
  }
  $body["image_url"] = Get-DataUri -Path $ResolvedImagePath
  if (-not $body.Contains("target_formats")) {
    $body["target_formats"] = @("glb")
  }
  if ($body["target_formats"] -is [string]) {
    $body["target_formats"] = @($body["target_formats"])
  }
  return $body
}

function Redact-RequestBody {
  param($Body, [string]$SourcePath)
  $copy = [ordered]@{}
  foreach ($key in $Body.Keys) {
    if ($key -eq "image_url" -or $key -eq "texture_image_url") {
      $copy[$key] = "<data-uri from $SourcePath>"
    } else {
      $copy[$key] = $Body[$key]
    }
  }
  return $copy
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
    thumbnail_urls = [ordered]@{}
    texture_urls = @()
  }
  if ($Task.model_urls) {
    foreach ($prop in $Task.model_urls.PSObject.Properties) {
      $summary.model_urls[$prop.Name] = Redact-Url $prop.Value
    }
  }
  if ($Task.thumbnail_urls) {
    foreach ($prop in $Task.thumbnail_urls.PSObject.Properties) {
      $summary.thumbnail_urls[$prop.Name] = Redact-Url $prop.Value
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
    "# Meshy Image to 3D Task Status",
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
    "- ``thumbnail_front.png`` / ``thumbnail_right.png`` / ``thumbnail_back.png`` / ``thumbnail_left.png``",
    "",
    "Provider response is saved as ``provider_response_redacted.json``; signed URLs are stripped."
  )
  $lines -join "`n" | Set-Content -LiteralPath (Join-Path $Folder "STATUS.md") -Encoding UTF8
}

function Save-Readme {
  param($Asset, [string]$SourcePath, [string]$Folder, [bool]$Submitted)
  $lines = @(
    "# Meshy Image to 3D Request",
    "",
    "Asset id: ``$($Asset.id)``",
    "Display name: $($Asset.display_name)",
    "Submitted: ``$Submitted``",
    "Source image: ``$SourcePath``",
    "",
    "## Purpose",
    "",
    $Asset.acceptance_notes -join "`n",
    "",
    "## Safety",
    "",
    "The API key is read from ``MESHY_API_KEY`` and is not written to this folder. The request body stores a redacted image marker, not the full data URI."
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
  if ($Task.thumbnail_urls) {
    foreach ($prop in $Task.thumbnail_urls.PSObject.Properties) {
      Invoke-WebRequest -Uri $prop.Value -OutFile (Join-Path $Folder "thumbnail_$($prop.Name).png") -UseBasicParsing
    }
  }
}

function Wait-Task {
  param([string]$Id, [int]$Poll, [int]$Timeout)
  $deadline = (Get-Date).AddSeconds($Timeout)
  $lastStatus = ""
  while ($true) {
    $task = Invoke-MeshyJson -Method "GET" -Uri "$ApiRoot/$Id"
    if ($task.status -ne $lastStatus) {
      Write-Host "Meshy image task $Id`: $($task.status) $($task.progress)%"
      $lastStatus = $task.status
    }
    if ($task.status -in @("SUCCEEDED", "FAILED", "CANCELED")) {
      return $task
    }
    if ((Get-Date) -gt $deadline) {
      throw "Timed out waiting for Meshy image task $Id"
    }
    Start-Sleep -Seconds ([Math]::Max(1, $Poll))
  }
}

if ($Command -in @("dry-run", "run")) {
  if (-not $Spec -or -not $AssetId -or -not $OutDir) {
    throw "--spec, --asset-id, and --out-dir are required"
  }
  $asset = Get-AssetSpec -SpecPath $Spec -WantedId $AssetId
  if (-not $asset.source_image_path) {
    throw "Asset requires source_image_path for image-to-3d: $AssetId"
  }
  $sourcePath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $asset.source_image_path))
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source image not found: $sourcePath"
  }
  $folder = Join-Path $OutDir $AssetId
  New-Directory $folder
  Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $folder "source_reference$([System.IO.Path]::GetExtension($sourcePath))") -Force
  $body = New-ImageBody -Asset $asset -ResolvedImagePath $sourcePath
  Redact-RequestBody -Body $body -SourcePath $asset.source_image_path |
    ConvertTo-Json -Depth 20 |
    Set-Content -LiteralPath (Join-Path $folder "request_body_redacted.json") -Encoding UTF8
  Save-Readme -Asset $asset -SourcePath $asset.source_image_path -Folder $folder -Submitted:($Command -eq "run")
  if ($Command -eq "dry-run") {
    Write-Host "Dry run wrote $(Join-Path $folder "request_body_redacted.json")"
    exit 0
  }
  $created = Invoke-MeshyJson -Method "POST" -Uri $ApiRoot -Body $body
  $created.result | Set-Content -LiteralPath (Join-Path $folder "task_id.txt") -Encoding UTF8
  $task = Wait-Task -Id $created.result -Poll $PollSeconds -Timeout $TimeoutSeconds
  Write-RedactedResponse -Task $task -Path (Join-Path $folder "provider_response_redacted.json")
  Save-Downloads -Task $task -Folder $folder
  Save-TaskStatus -Task $task -Folder $folder
  Write-Host "Meshy image-to-3D complete: $($created.result) -> $folder"
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
  Write-Host "Retrieved Meshy image-to-3D task: $TaskId -> $OutDir"
}
