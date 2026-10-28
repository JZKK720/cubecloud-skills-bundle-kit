<#
.SYNOPSIS
  Fast, environment-independent integrity gate for the bundle repository itself.

.DESCRIPTION
  Unlike full-audit.ps1 / verify-state.ps1 (which inspect a *machine* with skills, CLIs and MCP
  daemons installed), this script inspects only the repo's own artifacts, so it runs anywhere —
  including a bare CI runner. It catches the defect class that let counts, the manifest, and the
  release stamper drift apart:

    1. Every .ps1 under bin/ and setup/ parses (AST syntax check).
    2. setup/mcp.json.template and .vscode/tasks.json are valid JSON.
    3. skills-list.csv integrity: parseable rows, no duplicate names, no malformed rows, and every
       local/* row resolves to an existing upstream/<name>/SKILL.md.
    4. Count reconciliation: the manifest row count (the real source of truth) must equal every
       "N bundled" claim in README.md and AGENTS.md, and every "N bundled" count regex in
       bin/make-release.ps1 must actually match README.md (a regex that matches nothing silently
       leaves stale numbers behind).

  Exit 0 = all PASS. Exit 1 = at least one FAIL. WARN lines never fail the gate.

.EXAMPLE
  pwsh -NoProfile -File bin/check-bundle-integrity.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $RepoRoot 'setup\skills-list.csv'))) {
  Write-Host "FAIL: could not locate repo root (no setup/skills-list.csv above $PSScriptRoot)" -ForegroundColor Red
  exit 1
}

$script:pass = 0
$script:fail = 0
$script:warn = 0

function Pass($m) { Write-Host "PASS: $m" -ForegroundColor Green; $script:pass++ }
function Fail($m) { Write-Host "FAIL: $m" -ForegroundColor Red;   $script:fail++ }
function Warn($m) { Write-Host "WARN: $m" -ForegroundColor Yellow; $script:warn++ }

Write-Host "=== 1. PowerShell syntax (AST parse) ==="
$psFiles = @()
foreach ($dir in @('bin', 'setup')) {
  $d = Join-Path $RepoRoot $dir
  if (Test-Path $d) { $psFiles += Get-ChildItem $d -Recurse -File -Filter '*.ps1' }
}
$psFiles += Get-ChildItem $RepoRoot -File -Filter '*.ps1' -ErrorAction SilentlyContinue
$parseErrors = 0
foreach ($f in $psFiles) {
  $errs = $null
  $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
  if ($errs -and $errs.Count -gt 0) {
    $parseErrors++
    $rel = $f.FullName.Substring($RepoRoot.Length + 1)
    foreach ($e in $errs) { Fail "syntax: ${rel}:$($e.Extent.StartLineNumber) $($e.Message)" }
  }
}
if ($parseErrors -eq 0) { Pass "$($psFiles.Count) PowerShell files parse cleanly" }

Write-Host "`n=== 2. JSON validity ==="
foreach ($j in @('setup\mcp.json.template', '.vscode\tasks.json')) {
  $p = Join-Path $RepoRoot $j
  if (-not (Test-Path $p)) { Warn "$j not found (skipped)"; continue }
  try { $null = Get-Content $p -Raw | ConvertFrom-Json; Pass "$j is valid JSON" }
  catch { Fail "$j is invalid JSON: $($_.Exception.Message)" }
}

Write-Host "`n=== 3. skills-list.csv integrity ==="
$csvPath = Join-Path $RepoRoot 'setup\skills-list.csv'
$rows = Get-Content $csvPath | Where-Object { $_ -and -not $_.StartsWith('#') -and $_ -match '^[a-zA-Z]' }
$names = @()
$malformed = @()
foreach ($line in $rows) {
  $parts = $line -split '\|'
  if ($parts.Count -lt 2 -or -not $parts[0].Trim() -or -not $parts[1].Trim()) { $malformed += $line }
  else { $names += $parts[1].Trim() }
}
if ($malformed.Count) { $malformed | ForEach-Object { Fail "malformed manifest row: $_" } }
else { Pass "all $($rows.Count) manifest rows are well-formed" }

$dupes = $names | Group-Object | Where-Object Count -gt 1
if ($dupes) { $dupes | ForEach-Object { Fail "duplicate manifest name '$($_.Name)' x$($_.Count)" } }
else { Pass "no duplicate skill names in manifest" }

$localRows = $rows | Where-Object { $_ -match '^local/' }
$missingLocal = 0
foreach ($line in $localRows) {
  $parts = $line -split '\|'
  $name = $parts[1].Trim()
  $override = if ($parts.Count -ge 5) { $parts[4].Trim() } else { '' }
  $srcDir = if ($override) { Join-Path $RepoRoot $override } else { Join-Path $RepoRoot "upstream\$name" }
  if (-not (Test-Path (Join-Path $srcDir 'SKILL.md'))) {
    $missingLocal++
    $shown = if ($override) { $override } else { "upstream/$name" }
    Fail "local row '$name' has no SKILL.md at $shown"
  }
}
if ($localRows.Count -and $missingLocal -eq 0) { Pass "all $($localRows.Count) local/* rows resolve to a SKILL.md" }

Write-Host "`n=== 4. Count reconciliation ==="
$manifestCount = $rows.Count
$readme = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'README.md'))
$agents = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'AGENTS.md'))

# Present-tense skill-count claims only. Historical changelog prose (e.g. "5 bundled
# capabilities") must not be treated as a live count, so match the specific phrasings.
$claims = @()
$claims += [regex]::Matches($readme, '(\d+) bundled skills \(')
$claims += [regex]::Matches($readme, 'Skills \((\d+) bundled')
$claims += [regex]::Matches($agents, '(\d+) bundle skills')
$mismatched = $claims | Where-Object { $_.Groups[1].Value -ne "$manifestCount" }
if ($mismatched) {
  foreach ($m in $mismatched) { Fail "stale count claim '$($m.Value.Trim())' (manifest = $manifestCount)" }
} else { Pass "all $($claims.Count) present-tense 'bundled' claims equal manifest ($manifestCount)" }

# The active count must equal manifest - disabled. This regex must stay ASCII-only: CI runs
# pwsh (UTF-8) while local runs Windows PowerShell 5.1 (ANSI on a BOM-less file), so a literal
# em-dash behaves differently between them. '.' matches the dash under both.
$disabledCount = @($rows | Where-Object { ($_ -split '\|')[3].Trim() -eq 'true' }).Count
$expectedActive = $manifestCount - $disabledCount
$activeClaims = [regex]::Matches($readme, 'Skills \(\d+ bundled . (\d+) active')
$activeBad = $activeClaims | Where-Object { $_.Groups[1].Value -ne "$expectedActive" }
if ($activeBad) {
  foreach ($m in $activeBad) { Fail "stale active count '$($m.Value.Trim())' (expected $expectedActive = $manifestCount - $disabledCount)" }
} elseif ($activeClaims.Count) { Pass "active count matches manifest - disabled ($expectedActive)" }
else { Warn 'no "N bundled - N active" claim found to check' }

$badge = [regex]::Match($readme, 'skills-(\d+)%20bundled')
if (-not $badge.Success) { Fail 'README has no skills-N%20bundled badge' }
elseif ($badge.Groups[1].Value -ne "$manifestCount") { Fail "README badge says $($badge.Groups[1].Value), manifest = $manifestCount" }
else { Pass "README skills badge matches manifest ($manifestCount)" }

$layout = [regex]::Match($readme, 'manifest of (\d+) entries')
if (-not $layout.Success) { Warn 'README layout block has no "manifest of N entries" line' }
elseif ($layout.Groups[1].Value -ne "$manifestCount") { Fail "README layout says manifest of $($layout.Groups[1].Value), actual = $manifestCount" }
else { Pass "README layout manifest count matches ($manifestCount)" }

$guidePath = Join-Path $RepoRoot 'setup\SETUP_GUIDE.md'
if (Test-Path $guidePath) {
  $guide = [System.IO.File]::ReadAllText($guidePath)
  $g = [regex]::Match($guide, '(\d+) manifest entries')
  if (-not $g.Success) { Warn 'SETUP_GUIDE has no "N manifest entries" line' }
  elseif ($g.Groups[1].Value -ne "$manifestCount") { Fail "SETUP_GUIDE says $($g.Groups[1].Value) manifest entries, actual = $manifestCount" }
  else { Pass "SETUP_GUIDE manifest count matches ($manifestCount)" }
}

# Every count regex in make-release.ps1 must actually match README (a 0-match regex is a silent no-op).
# Probes are kept ASCII-only: Windows PowerShell 5.1 parses a BOM-less .ps1 as ANSI, so a literal
# em-dash or emoji in this file would be corrupted and stop matching.
$release = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'bin\make-release.ps1'))
$probes = @(
  'skills-\d+%20bundled',
  'version-[\d.]+-orange',
  ' \d+ bundled skills \(',
  '(\*\*)\d+(\*\* are bundle-installed)',
  '(\| .*?Skills on disk\s+\|\s+\*\*)\d+(\*\*)',
  '(\d+) bundled . \d+ active',
  'manifest of \d+ entries \(\d+ active',
  'Skills \(\d+ bundled\)'
)
$deadPatterns = 0
foreach ($probe in $probes) {
  if ($release -notmatch [regex]::Escape($probe)) { Warn "make-release.ps1 no longer contains pattern '$probe'"; continue }
  if ([regex]::Matches($readme, $probe).Count -eq 0) { Fail "make-release.ps1 pattern '$probe' matches 0 times in README.md"; $deadPatterns++ }
}
if ($deadPatterns -eq 0) { Pass "all $($probes.Count) make-release.ps1 count patterns match README.md" }

# ---- CLI / MCP count claims -------------------------------------------------
# The skills counts were reconciled but the CLI and MCP counts were not, which is how
# README came to advertise 20 CLIs including `rea` and `git-wt` while both were absent
# from PATH and verify-state.ps1 only checked 18. Tie each claim to the list it is
# actually asserting, so a name can never be advertised without being checked.
$verifyState = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'bin\verify-state.ps1'))

# CLI: the README "CLIs" row names each tool in backticks; every one must appear in the
# verify-state CLI array (the thing that proves it is on PATH).
$cliClaim = [regex]::Match($readme, '\|\s*\S+\s*CLIs\s*\|\s*\*\*(\d+)\*\*')
if (-not $cliClaim.Success) {
  Warn 'README has no "CLIs" count row to check'
} else {
  $cliRow = $readme.Substring($cliClaim.Index, [Math]::Min(2000, $readme.Length - $cliClaim.Index))
  $cliRow = ($cliRow -split "`n")[0]
  $named = [regex]::Matches($cliRow, '`([a-z0-9][a-z0-9._-]*)`') |
    ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne 'git-wt' -or $true } | Select-Object -Unique
  # `git-wt` (worktrunk) is annotated in the README as "(worktrunk)"; keep it, and drop
  # the parenthetical duplicate if the same name is repeated.
  $unchecked = $named | Where-Object { $verifyState -notmatch ("'" + [regex]::Escape($_) + "'") }
  if ($cliClaim.Groups[1].Value -ne "$($named.Count)") {
    Fail "README claims $($cliClaim.Groups[1].Value) CLIs but names $($named.Count): $($named -join ', ')"
  } elseif ($unchecked.Count) {
    Fail "README advertises CLIs that verify-state.ps1 does not check: $($unchecked -join ', ')"
  } else {
    Pass "all $($named.Count) README CLIs are listed in verify-state.ps1"
  }
}

# MCP: the README count must equal the number of servers in the template (the source of truth).
$mcpClaim = [regex]::Match($readme, '\|\s*\S+\s*MCP servers\s*\|\s*\*\*(\d+)\*\*')
$tplPath = Join-Path $RepoRoot 'setup\mcp.json.template'
if ($mcpClaim.Success -and (Test-Path $tplPath)) {
  $tplCount = @((Get-Content $tplPath -Raw | ConvertFrom-Json).servers.PSObject.Properties).Count
  if ($mcpClaim.Groups[1].Value -ne "$tplCount") {
    Fail "README claims $($mcpClaim.Groups[1].Value) MCP servers, template defines $tplCount"
  } else {
    Pass "README MCP server count matches template ($tplCount)"
  }
} elseif (-not $mcpClaim.Success) {
  Warn 'README has no "MCP servers" count row to check'
}

Write-Host ""
Write-Host "RESULT: PASS=$script:pass FAIL=$script:fail WARN=$script:warn"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
