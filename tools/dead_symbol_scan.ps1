<#
.SYNOPSIS
    Dead-public-symbol scanner for scripts/rules/*.gd and scripts/net/*.gd (Wave G process rec).

.DESCRIPTION
    Finds PUBLIC symbols that ship with a green smoke asserting behavior but have NO live
    (non-test) consumer -- "dead code whose test asserts the opposite of what shipped."
    This is exactly the G1 failure mode (pvp_rules_model.is_kill / PVP_DEATH_SEVERITY): a
    public func/const, a passing smoke, and zero live call sites.

    ------------------------------------------------------------------------------------
    WHAT COUNTS AS A "PUBLIC SYMBOL"
    ------------------------------------------------------------------------------------
      * Top-level (column-0) function whose name does NOT start with '_':
              func name(...)   /   static func name(...)
        The '_' exclusion drops private helpers AND every Godot virtual
        (_ready, _init, _process, _physics_process, _input, _enter_tree, ...) -- those are
        engine callbacks, never public API, so they can never be "orphans."
      * Top-level  const NAME  declarations (any casing), EXCEPT `const X = preload(...)`:
        those are internal import ALIASES, not exported API (nobody references FileA.Alias
        from another file), so including them would be pure noise.

    ------------------------------------------------------------------------------------
    HOW REFERENCES ARE COUNTED
    ------------------------------------------------------------------------------------
      Cross-file access to a rules/net symbol in GDScript is always QUALIFIED:
              Alias.name(...)         # via  const Alias := preload("res://.../file.gd")
              Singleton.name(...)     # via the Net / D6Rules autoloads
              preload("...").NAME     # inline preload
              "name"                  # string form (connect / call / @rpc-by-name)
      So a cross-file reference is any occurrence of  .name  or  "name"  (whole word) in
      some OTHER .gd file under scripts/. Anchoring on the leading '.'/'"' keeps false
      positives low: it will not match a symbol that is merely a SUFFIX of a longer
      identifier. The trade-off is a few false NEGATIVES (a dead symbol whose name collides
      with another class's method looks referenced) -- acceptable: we would rather never cry
      wolf on a symbol that is actually wired.

      In-file use is detected separately with a bare whole-word match (\bname\b), because a
      class references its OWN members unqualified.

    ------------------------------------------------------------------------------------
    CLASSIFICATION  (per public symbol)
    ------------------------------------------------------------------------------------
      HEALTHY        - referenced by >=1 live (non-test) file OTHER than its own. Not reported.
      RPC endpoint   - annotated @rpc(...): invoked over the wire (`f.rpc_id(...)` / by name),
                       so it legitimately has no ordinary call site. Info only, never an orphan.
      ALLOW-LISTED   - in $AllowList below (reached reflectively / by the engine). Info only.
      INTERNAL       - no external and no test reference, but USED within its own file
                       (module-private config const / helper). Info only, NOT an orphan:
                       a symbol used in-module is not dead, and failing on ~150 internal
                       config consts would bury the real signal. (Documented refinement of
                       the literal "own-file-only == orphan" rule, to keep false positives low.)

      ORPHANS  (these drive the non-zero exit):
      TESTS-ONLY (live-wired file)  - referenced ONLY by scripts/tests/*, and its file ALSO
                       contains at least one live-wired symbol. HIGHER PRIORITY: the file is
                       demonstrably on the live path, so a tested-but-uncalled public symbol
                       sitting next to shipped siblings is the likeliest forgotten dead code.
                       This is where G1 sat: pvp_rules_model.gd ships can_fire/is_full_loot on
                       the live path, but is_kill / PVP_DEATH_SEVERITY are tests-only. (NOTE: this
                       bucket also holds granular library APIs whose live consumer only calls a
                       subset -- triage, don't assume every entry is a bug.)
      TESTS-ONLY (not-yet-wired file)   - referenced ONLY by tests, in a file with NO live-wired
                       symbol at all. Usually a "pure model + smoke" foundation built AHEAD of
                       wiring (this repo's deliberate pure-first style); lower urgency, but still
                       a public API with no live consumer.
      DEAD           - referenced NOWHERE (not live, not tests, not even its own file). Truly dead.

.NOTES
    Standalone. NOT wired into tools/check_project.ps1 (Wave G may gate it later; see the
    suggested line below). Read-only: reads *.gd, writes nothing. Reference corpus is every
    *.gd under scripts/ -- symbols reached only from a .tscn/editor connection can't be seen
    (add them to $AllowList).
    Exit code: 0 = no orphans (only healthy / RPC / allow-listed / internal),
               1 = one or more TESTS-ONLY or DEAD orphans found.

.PARAMETER ShowInternal
    Also list the INTERNAL (module-private) symbols, which are summarized by count by default.

.EXAMPLE
    pwsh tools/dead_symbol_scan.ps1
    powershell -File tools/dead_symbol_scan.ps1

    Suggested (NOT applied) gate line for tools/check_project.ps1, once the known orphans are
    reconciled/allow-listed (or scope the future gate to the partially-wired bucket only):

        Write-Host "`nDead public-symbol scan:"
        & powershell -NoProfile -File "$projectRoot\tools\dead_symbol_scan.ps1"
        if ($LASTEXITCODE -ne 0) { throw "Dead public-symbol scan found orphan(s)." }
#>

[CmdletBinding()]
param(
    [switch]$ShowInternal
)

$ErrorActionPreference = "Stop"

# --- Locate the project root (parent of this tools/ dir) ---------------------------------
$toolsDir    = $PSScriptRoot
$projectRoot = Split-Path -Parent $toolsDir

# Directories whose PUBLIC symbols we audit.
$SourceDirs = @('scripts/rules', 'scripts/net')

# Root of the reference corpus: every .gd under here is searched for call sites.
$ScriptsRoot = Join-Path $projectRoot 'scripts'

# ----------------------------------------------------------------------------------------
# Allow-list: known-intentional public API with no reference the heuristic can follow
# (reached reflectively, from a .tscn signal, or by the engine). Entries are "symbol"
# (any file) or "file_basename.gd:symbol" (scoped). Keep SHORT + documented; each entry is a
# promise the symbol is wired somewhere the scanner cannot see. @rpc funcs are auto-detected
# and do NOT belong here.
# ----------------------------------------------------------------------------------------
$AllowList = @(
    # (seed: none required. @rpc auto-detection covers the wire endpoints. Add an entry only
    #  for a symbol reached reflectively / by the engine that the scanner genuinely can't see.)
)

# ----------------------------------------------------------------------------------------

function Get-RelPath {
    param([string]$FullPath)
    $rel = $FullPath.Substring($projectRoot.Length).TrimStart('\', '/')
    return ($rel -replace '\\', '/')
}

function Test-AllowListed {
    param([string]$Name, [string]$File)
    $base = Split-Path -Leaf $File
    foreach ($entry in $AllowList) {
        if ($entry -eq $Name) { return $true }
        if ($entry -eq ("{0}:{1}" -f $base, $Name)) { return $true }
    }
    return $false
}

# --- 1) Build the reference corpus: all *.gd under scripts/ -----------------------------
$corpus       = @()
$contentByRel = @{}
foreach ($gd in Get-ChildItem -Path $ScriptsRoot -Filter *.gd -File -Recurse) {
    $rel  = Get-RelPath $gd.FullName
    $text = Get-Content -LiteralPath $gd.FullName -Raw
    if ($null -eq $text) { $text = '' }
    $corpus += [pscustomobject]@{
        Rel     = $rel
        IsTest  = ($rel -match '(^|/)scripts/tests/')
        Content = $text
    }
    $contentByRel[$rel] = $text
}

# --- 2) Extract public symbols from the audited source dirs -----------------------------
$symbols = @()
foreach ($dir in $SourceDirs) {
    $dirPath = Join-Path $projectRoot $dir
    if (-not (Test-Path $dirPath)) { continue }
    foreach ($gd in Get-ChildItem -Path $dirPath -Filter *.gd -File) {
        $rel   = Get-RelPath $gd.FullName
        $lines = Get-Content -LiteralPath $gd.FullName
        $pendingRpc = $false
        foreach ($line in $lines) {
            if ($line -match '^\s*@rpc') { $pendingRpc = $true; continue }   # arm next func
            if ($line -match '^\s*@')    { continue }                        # other annotation

            $mFunc = [regex]::Match($line, '^(?:static\s+)?func\s+([A-Za-z][A-Za-z0-9_]*)\s*\(')
            if ($mFunc.Success) {
                $symbols += [pscustomobject]@{
                    Name = $mFunc.Groups[1].Value; File = $rel; Kind = 'func'; IsRpc = $pendingRpc
                }
                $pendingRpc = $false
                continue
            }

            $mConst = [regex]::Match($line, '^const\s+([A-Za-z_][A-Za-z0-9_]*)')
            if ($mConst.Success) {
                $cname = $mConst.Groups[1].Value
                # Skip private (_-prefixed) and preload import aliases -- not exported API.
                if (-not $cname.StartsWith('_') -and ($line -notmatch 'preload\s*\(')) {
                    $symbols += [pscustomobject]@{
                        Name = $cname; File = $rel; Kind = 'const'; IsRpc = $false
                    }
                }
                $pendingRpc = $false
                continue
            }

            if ($line.Trim() -ne '') { $pendingRpc = $false }
        }
    }
}

# --- 3) Classify each symbol by its references ------------------------------------------
$healthy      = @()
$internal     = @()
$rpcEndpoints = @()
$allowed      = @()
$orphansTest  = @()   # referenced ONLY by tests
$orphansDead  = @()   # referenced nowhere at all
$wiredFiles   = @{}   # files that contain >=1 live-wired (HEALTHY or RPC) symbol

foreach ($sym in $symbols) {
    $qualified = [regex]::new('[."]' + [regex]::Escape($sym.Name) + '(?![A-Za-z0-9_])')  # .name / "name"
    $bareWord  = [regex]::new('\b' + [regex]::Escape($sym.Name) + '\b')

    $liveRefs = @()
    $testRefs = @()
    foreach ($c in $corpus) {
        if ($c.Rel -eq $sym.File) { continue }        # own-file refs handled separately
        if ($qualified.IsMatch($c.Content)) {
            if ($c.IsTest) { $testRefs += $c.Rel } else { $liveRefs += $c.Rel }
        }
    }

    # In-file use: the symbol appears (bare) on a line other than its own declaration.
    $ownContent = ''
    if ($contentByRel.ContainsKey($sym.File)) { $ownContent = $contentByRel[$sym.File] }
    $ownUsed = ($bareWord.Matches($ownContent).Count -ge 2)

    $record = [pscustomobject]@{
        Name = $sym.Name; Kind = $sym.Kind; File = $sym.File; IsRpc = $sym.IsRpc
        LiveRefs = ($liveRefs | Sort-Object -Unique); TestRefs = ($testRefs | Sort-Object -Unique)
    }

    if ($sym.IsRpc)                           { $rpcEndpoints += $record; $wiredFiles[$sym.File] = $true; continue }
    if ($liveRefs.Count -gt 0)                { $healthy      += $record; $wiredFiles[$sym.File] = $true; continue }
    if (Test-AllowListed $sym.Name $sym.File) { $allowed      += $record; continue }
    if ($testRefs.Count -gt 0)                { $orphansTest  += $record; continue }   # test beats in-file
    if ($ownUsed)                             { $internal     += $record; continue }
    $orphansDead += $record
}

# Split the tests-only orphans by whether their file is otherwise wired (the G1 shape).
$orphansTestPartial = @()   # tests-only in a file that HAS live-wired siblings  (HIGH confidence)
$orphansTestPure    = @()   # tests-only in a file with no live-wired symbol     (not-yet-wired)
foreach ($o in $orphansTest) {
    if ($wiredFiles.ContainsKey($o.File)) { $orphansTestPartial += $o } else { $orphansTestPure += $o }
}

$totalOrphans = $orphansTestPartial.Count + $orphansTestPure.Count + $orphansDead.Count

# --- 4) Report --------------------------------------------------------------------------
Write-Host "=============================================================================="
Write-Host " Dead public-symbol scan   (scripts/rules + scripts/net)"
Write-Host "=============================================================================="
Write-Host ("  public symbols audited      : {0}" -f $symbols.Count)
Write-Host ("  healthy (live consumer)     : {0}" -f $healthy.Count)
Write-Host ("  RPC / wire endpoints        : {0}   (info)" -f $rpcEndpoints.Count)
Write-Host ("  internal-only (in-module)   : {0}   (info)" -f $internal.Count)
if ($allowed.Count -gt 0) {
    Write-Host ("  allow-listed                : {0}   (info)" -f $allowed.Count)
}
Write-Host ""
Write-Host ("  ORPHAN tests-only, in a LIVE-WIRED file : {0}   <-- higher priority (where G1 sat)" -f $orphansTestPartial.Count)
Write-Host ("  ORPHAN tests-only, not-yet-wired file   : {0}" -f $orphansTestPure.Count)
Write-Host ("  ORPHAN dead (referenced nowhere)        : {0}   <-- crispest signal" -f $orphansDead.Count)
Write-Host ""

if ($orphansTestPartial.Count -gt 0) {
    Write-Host "------------------------------------------------------------------------------"
    Write-Host " TESTS-ONLY ORPHANS in a LIVE-WIRED file (higher priority -- this is where G1 sat):"
    Write-Host " public API + green smoke + zero live call sites, sitting next to shipped siblings."
    Write-Host " Triage: also includes library APIs whose live consumer calls only a subset."
    Write-Host "------------------------------------------------------------------------------"
    foreach ($grp in ($orphansTestPartial | Group-Object File | Sort-Object Name)) {
        Write-Host ("  {0}" -f $grp.Name)
        foreach ($o in ($grp.Group | Sort-Object Name)) {
            Write-Host ("      [{0}] {1}   (tests: {2})" -f $o.Kind, $o.Name, (($o.TestRefs | ForEach-Object { Split-Path -Leaf $_ }) -join ', '))
        }
    }
    Write-Host ""
}

if ($orphansDead.Count -gt 0) {
    Write-Host "------------------------------------------------------------------------------"
    Write-Host " DEAD ORPHANS -- referenced nowhere (no live code, no test, not even in-file):"
    Write-Host "------------------------------------------------------------------------------"
    foreach ($o in ($orphansDead | Sort-Object File, Name)) {
        Write-Host ("  [{0}] {1}   <-  {2}" -f $o.Kind, $o.Name, $o.File)
    }
    Write-Host ""
}

if ($orphansTestPure.Count -gt 0) {
    Write-Host "------------------------------------------------------------------------------"
    Write-Host " TESTS-ONLY ORPHANS -- not-yet-wired 'pure model + smoke' files (lower urgency):"
    Write-Host " (a public API exercised by a smoke but not yet consumed by any live path)"
    Write-Host "------------------------------------------------------------------------------"
    foreach ($grp in ($orphansTestPure | Group-Object File | Sort-Object Name)) {
        $names = ($grp.Group | Sort-Object Name | ForEach-Object { $_.Name }) -join ', '
        Write-Host ("  {0}" -f $grp.Name)
        Write-Host ("      {0}" -f $names)
    }
    Write-Host ""
}

if ($rpcEndpoints.Count -gt 0) {
    Write-Host "------------------------------------------------------------------------------"
    Write-Host " RPC / wire endpoints (@rpc) -- public over the network, NOT orphans:"
    Write-Host "------------------------------------------------------------------------------"
    $rpcNames = ($rpcEndpoints | Sort-Object Name | ForEach-Object { $_.Name }) -join ', '
    Write-Host ("  {0}" -f $rpcNames)
    Write-Host ""
}

if ($ShowInternal -and $internal.Count -gt 0) {
    Write-Host "------------------------------------------------------------------------------"
    Write-Host " INTERNAL-ONLY (used within their own module; not dead, not orphans):"
    Write-Host "------------------------------------------------------------------------------"
    foreach ($grp in ($internal | Group-Object File | Sort-Object Name)) {
        $names = ($grp.Group | Sort-Object Name | ForEach-Object { $_.Name }) -join ', '
        Write-Host ("  {0}: {1}" -f $grp.Name, $names)
    }
    Write-Host ""
}

if ($totalOrphans -gt 0) {
    Write-Host ("RESULT: FAIL -- {0} orphan public symbol(s): {1} tests-only in live-wired files, {2} not-yet-wired, {3} dead." -f `
        $totalOrphans, $orphansTestPartial.Count, $orphansTestPure.Count, $orphansDead.Count)
    Write-Host "        Wire each to a live call site, delete/park it, or (if intentionally public)"
    Write-Host "        add it to `$AllowList with a reason. Start with the HIGH-confidence block."
    exit 1
} else {
    Write-Host "RESULT: OK -- every public symbol has a live consumer (or is @rpc / allow-listed / in-module)."
    exit 0
}
