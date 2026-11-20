<#
.SYNOPSIS
  Bring every installed skill's frontmatter to spec after a refresh or reinstall.

.DESCRIPTION
  `skills-ref validate` allows only name/description/license/compatibility/metadata/
  allowed-tools at top level. Upstream skills often ship Claude-Code-only keys, and a skill
  folder's name must match its frontmatter `name:`.

  This script fixes both, across the collection or one skill:
    1. Nests Claude-only keys under `metadata:` (values preserved, Copilot ignores the block).
    2. Aligns frontmatter `name:` to the directory name when they differ.

  It reads and writes through an explicit UTF-8 codec. Get-Content/Set-Content round-trip
  through the console code page on this host and silently corrupt non-ASCII text.

  Idempotent: a skill that already validates is left untouched.

.PARAMETER Path
  A skill directory, or a collection directory. Default: ~/.agents/skills

.PARAMETER SkipNameAlignment
  Do not rename the frontmatter `name:` to match the directory.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File bin/repair-skill-frontmatter.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File bin/repair-skill-frontmatter.ps1 -Path ~/.agents/skills/taste-skill
#>
[CmdletBinding()]
param(
  [string]$Path = "$env:USERPROFILE\.agents\skills",
  [switch]$SkipNameAlignment
)

$ErrorActionPreference = 'Stop'
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$ClaudeOnlyKeys = @(
  'argument-hint', 'disable-model-invocation', 'user-invocable', 'user_invocable',
  'version', 'origin', 'tools', 'tags', 'triggers', 'mutating', 'writes_pages', 'writes_to',
  'hooks', 'allowed_tools', 'license_url', 'model'
)

function Repair-One([string]$SkillDir) {
  $md = Join-Path $SkillDir 'SKILL.md'
  if (-not (Test-Path $md)) { return $null }

  $before = cmd /c "skills-ref validate `"$SkillDir`" 2>&1"
  if ($LASTEXITCODE -eq 0) { return 'valid' }

  $changed = $false
  $lines = ([System.IO.File]::ReadAllText($md, $utf8)) -split "\r?\n"
  if (-not $lines -or $lines[0].TrimEnd() -ne '---') { return 'no-frontmatter' }

  $end = -1; $seen = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].TrimEnd() -eq '---') { $seen++; if ($seen -eq 2) { $end = $i; break } }
  }
  if ($end -lt 0) { return 'no-frontmatter' }

  # --- 1. nest Claude-only keys ---
  $moved = @(); $keep = @(); $i = 0
  while ($i -lt $end) {
    $hit = $null
    foreach ($k in $ClaudeOnlyKeys) { if ($lines[$i] -match "^$([regex]::Escape($k)):") { $hit = $k; break } }
    if ($hit) {
      $block = @($lines[$i] -replace "^$([regex]::Escape($hit)):", "  $hit`:")
      $i++
      while ($i -lt $end -and $lines[$i] -match '^\s+\S') { $block += "  $($lines[$i])"; $i++ }
      $moved += $block
    } else { $keep += $lines[$i]; $i++ }
  }
  if ($moved.Count -gt 0) {
    $changed = $true
    $metaIdx = -1
    for ($k = 0; $k -lt $keep.Count; $k++) { if ($keep[$k] -match '^metadata:') { $metaIdx = $k; break } }
    if ($metaIdx -ge 0) {
      $j = $metaIdx + 1
      while ($j -lt $keep.Count -and $keep[$j] -match '^\s+\S') { $j++ }
      $keep = @($keep[0..($j-1)]) + $moved + @($keep[$j..($keep.Count-1)])
    } else {
      $keep = $keep + @('metadata:') + $moved
    }
    # de-duplicate whole indented lines inside the metadata block
    $final = @(); $seenLines = @{}; $inMeta = $false
    foreach ($l in $keep) {
      if ($l -match '^metadata:') { $inMeta = $true }
      elseif ($l -match '^\S') { $inMeta = $false }
      if ($inMeta -and $l -match '^\s+\S') {
        $norm = $l.Trim()
        if ($seenLines.ContainsKey($norm)) { continue }
        $seenLines[$norm] = $true
      }
      $final += $l
    }
    $keep = $final
  }

  # --- 2. align frontmatter name to the directory name ---
  if (-not $SkipNameAlignment) {
    $dirName = Split-Path $SkillDir -Leaf
    for ($k = 0; $k -lt $keep.Count; $k++) {
      if ($keep[$k] -match '^name:\s*(.+?)\s*$') {
        if ($Matches[1] -ne $dirName) {
          $keep[$k] = "name: $dirName"
          $changed = $true
        }
        break
      }
    }
  }

  if (-not $changed) { return 'unfixable' }
  [System.IO.File]::WriteAllText($md, (($keep + $lines[$end..($lines.Count-1)]) -join "`n"), $utf8)

  $after = cmd /c "skills-ref validate `"$SkillDir`" 2>&1"
  if ($LASTEXITCODE -eq 0) { return 'repaired' }
  return 'still-invalid'
}

$targets = if (Test-Path (Join-Path $Path 'SKILL.md')) { @(Get-Item $Path) }
           else { @(Get-ChildItem $Path -Directory | Where-Object { -not $_.Name.StartsWith('.') }) }

$tally = @{}
foreach ($t in $targets) {
  $r = Repair-One $t.FullName
  if (-not $r) { continue }
  $tally[$r] = 1 + $(if ($tally.ContainsKey($r)) { $tally[$r] } else { 0 })
  if ($r -in @('repaired','still-invalid','no-frontmatter')) { Write-Host ("  {0,-16} {1}" -f $r, $t.Name) }
}

Write-Host ""
Write-Host "=== summary ($($targets.Count) directories) ===" -ForegroundColor Cyan
foreach ($k in @('valid','repaired','still-invalid','no-frontmatter','unfixable')) {
  if ($tally.ContainsKey($k)) { Write-Host ("  {0,-16} {1}" -f $k, $tally[$k]) }
}
if ($tally.ContainsKey('still-invalid') -and $tally['still-invalid'] -gt 0) { exit 1 }
exit 0
