# make_review_zip.ps1
# Build a LEAN zip of the SW_MMO prototype for a code/design review (e.g. uploading to
# claude.ai for a Fable review). Strips the huge stuff (asset packs, binaries, git history,
# preview images) and keeps everything small and text-y: GDScript, docs, JSON data, scenes,
# tools, config. Run it via make_review_zip.bat (double-click) or directly with PowerShell.
#
# The zip is written to the PARENT folder of the project so it is never zipped into itself,
# and every run is timestamped so nothing is clobbered.

$ErrorActionPreference = 'Stop'

# --- Tunables (edit these if you want) ---------------------------------------------------
# Any single file larger than this many KB is skipped (a backstop after the dir/ext rules).
$MaxFileKB = 1024
# Whole top-level folders to drop entirely (these are the giants - 925MB+ of assets, etc.).
$SkipTopDirs = @('.git', '.godot', 'assets', 'MMO_Assets', '.import', 'bin', 'obj', '.mono',
                 '.claude', '.vscode', '.idea')
# Folder names to drop wherever they appear (nested), e.g. the preview-image gallery in docs.
$SkipAnyDirs = @('.godot', 'asset_previews', '__pycache__', 'node_modules')
# File extensions to drop (models, textures, audio/video, archives, binaries, big blobs).
$SkipExt = @(
    '.png','.jpg','.jpeg','.gif','.bmp','.tga','.tiff','.webp','.ico','.psd',
    '.glb','.gltf','.obj','.fbx','.blend','.blend1','.dae','.stl','.3ds',
    '.wav','.ogg','.mp3','.flac','.aac','.mp4','.mov','.avi','.mkv',
    '.zip','.7z','.rar','.tar','.gz','.bz2',
    '.exe','.dll','.pck','.so','.dylib','.bin','.db','.sqlite','.pdf'
)
# -----------------------------------------------------------------------------------------

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootName = Split-Path -Leaf $root
$maxBytes = $MaxFileKB * 1KB
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outZip = Join-Path (Split-Path -Parent $root) ("{0}_review_{1}.zip" -f $rootName, $stamp)

Write-Host ""
Write-Host "SW_MMO review-zip builder" -ForegroundColor Cyan
Write-Host "  project : $root"
Write-Host "  output  : $outZip"
Write-Host "  rules   : skip top dirs [$($SkipTopDirs -join ', ')]; skip >${MaxFileKB}KB files; skip binary/asset extensions"
Write-Host ""

# Collect files, pruning the giant top-level folders up front (so we never walk 925MB of assets).
$files = New-Object System.Collections.Generic.List[System.IO.FileInfo]
Get-ChildItem -LiteralPath $root -Force | ForEach-Object {
    if ($_.PSIsContainer) {
        if ($SkipTopDirs -contains $_.Name) { return }
        Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force | ForEach-Object { $files.Add($_) }
    } else {
        $files.Add($_)
    }
}

# Per-file filter: nested skip-dirs, skipped extensions, and the size backstop.
$included = New-Object System.Collections.Generic.List[System.IO.FileInfo]
$skippedSize = 0
$skippedExt = 0
foreach ($f in $files) {
    $rel = $f.FullName.Substring($root.Length).TrimStart('\')
    $segs = ($rel -replace '\\','/').Split('/')
    $inSkipDir = $false
    foreach ($s in $segs) { if ($SkipAnyDirs -contains $s) { $inSkipDir = $true; break } }
    if ($inSkipDir) { continue }
    if ($SkipExt -contains $f.Extension.ToLower()) { $skippedExt++; continue }
    if ($f.Length -gt $maxBytes) { $skippedSize++; continue }
    $included.Add($f)
}

if ($included.Count -eq 0) {
    Write-Host "Nothing matched the include rules - aborting." -ForegroundColor Red
    exit 1
}

# Build the zip with the .NET API so the folder structure is preserved (Compress-Archive
# flattens a file list). Entries are prefixed with the project folder name so it unzips clean.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path -LiteralPath $outZip) { Remove-Item -LiteralPath $outZip -Force }
$zip = [System.IO.Compression.ZipFile]::Open($outZip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $included) {
        $rel = $f.FullName.Substring($root.Length).TrimStart('\').Replace('\','/')
        $entry = "$rootName/$rel"
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $f.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal)
    }
} finally {
    $zip.Dispose()
}

$zipKB = [math]::Round((Get-Item -LiteralPath $outZip).Length / 1KB, 1)
$srcKB = [math]::Round((($included | Measure-Object Length -Sum).Sum) / 1KB, 1)

Write-Host "Done." -ForegroundColor Green
Write-Host "  included files : $($included.Count)  ($srcKB KB uncompressed)"
Write-Host "  skipped (ext)  : $skippedExt   skipped (>${MaxFileKB}KB): $skippedSize"
Write-Host ("  zip size       : {0} KB  ({1} MB)" -f $zipKB, [math]::Round($zipKB/1024,2))
Write-Host "  zip path       : $outZip" -ForegroundColor Yellow
Write-Host ""

# Show the 12 biggest files that made it in, as a sanity check.
Write-Host "Largest included files:"
$included | Sort-Object Length -Descending | Select-Object -First 12 | ForEach-Object {
    "{0,8:N1} KB  {1}" -f ($_.Length/1KB), $_.FullName.Substring($root.Length).TrimStart('\')
} | Write-Host
Write-Host ""
