# Installs only the skills missing from ~/.agents/skills/ via the security-gated
# install-skill.ps1 helper. Reads skills-list.csv, skips already-present skills,
# and routes local/* rows through -SourcePath (no git clone).
#
# -Refresh: also UPDATE already-installed skills whose SKILL.md content differs from
# its current source. This is a content refresh, not a reinstall: it never re-runs
# the SkillSpector gate (the source was gated when it was first installed and the
# fork mirrors are git-tracked, so every change is reversible). Use -WhatIf to
# preview. Hand-ported skills and the bundle's own install-time `argument-hint:`
# additions are preserved - see the notes on $protected and Merge-ArgumentHint.
[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$Refresh
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:PYTHONUTF8 = '1'
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"

# Resolve repo root dynamically by walking upward until setup/skills-list.csv is found.
function Find-RepoRoot([string]$startDir) {
  $current = Resolve-Path $startDir
  while ($true) {
    if (Test-Path (Join-Path $current.Path 'setup\skills-list.csv')) {
      return $current.Path
    }
    $parent = Split-Path $current.Path -Parent
    if (-not $parent -or $parent -eq $current.Path) {
      break
    }
    $current = Resolve-Path $parent
  }
  return $null
}

$repoRoot = Find-RepoRoot $PSScriptRoot
if (-not $repoRoot) {
  Write-Host "Could not resolve repo root from $PSScriptRoot" -ForegroundColor Red
  exit 1
}

$csv   = Join-Path $repoRoot 'setup\skills-list.csv'
$helper = "$env:USERPROFILE\dev\bin\install-skill.ps1"

if (-not (Test-Path $csv))   { Write-Host "CSV not found: $csv" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $helper)) { Write-Host "Helper not found: $helper" -ForegroundColor Red; exit 1 }

Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
# SCAN_LOG must exist before the helper tries to append.
if (-not (Test-Path "$env:USERPROFILE\dev\upstream\SCAN_LOG.md")) {
  @("# SkillSpector Scan Log","","| Date | Repo | Skill | Verdict | Status | Notes |","|---|---|---|---|---|---|") |
    Out-File "$env:USERPROFILE\dev\upstream\SCAN_LOG.md" -Encoding UTF8
}

$lines = Get-Content $csv | Where-Object { $_ -and -not $_.StartsWith("#") }
$installed = 0; $blocked = 0; $skipped = 0; $wouldRefresh = 0

# ---------------------------------------------------------------------------
# -Refresh support
# ---------------------------------------------------------------------------
$forkRoot = "$env:USERPROFILE\dev\forks\JZKK720"

# Skills that must NEVER be overwritten by a refresh.
#   - Any row whose repo is "local/*" (or that overrides -SourcePath) is a hand-authored
#     port that lives in THIS repo, not upstream. Refreshing it would replace curated
#     prose with the thing it was ported away from.
#   - codex-review / codex-build: upstream reduced these to ~17-line compatibility shims
#     that delegate to the sibling claudex-loop skill, because the real workflow MOVED
#     into claudex-loop. Overwriting would delete a working standalone workflow in favour
#     of a pointer, so they are pinned and the user decides.
#   - RENAMED-UPSTREAM skills: the installed copy deliberately carries a DIFFERENT
#     frontmatter `name:` than upstream (and a matching directory name). The bundle renames
#     these to avoid a cross-root collision or to match the manifest name. A refresh copies
#     upstream's `name:` back and BREAKS the install. Verified 2026-09-21: a dry run flagged
#     exactly these three, and the only differing line was the `name:` field.
#       hallmark                    -> 3 rewritten reference links (upstream-only doc paths)
#       taste-skill                 -> upstream name is 'design-taste-frontend', which ALREADY
#                                      EXISTS as a real .copilot/skills skill => collision
#       create-technical-design-doc -> upstream name is 'technical-design-doc-creator'
#     Evidence for the convention: all 294 installed skills satisfy name == folder name,
#     with zero exceptions. Same hazard class as the documented book-to-skill 702->414
#     regression, so this is enforced in code, not in a comment.
#   - compound-engineering-plugin (EveryInc): the 20 `ce-*` skills plus `lfg`. Their mirror
#     was cloned on 2026-09-21 (fork pinned at 84bdf8c, 2026-08-27) purely for provenance,
#     which made `-Refresh` suddenly able to SEE them -- and refresh would TRUNCATE them.
#     Measured installed-vs-source lines: ce-ideate 434->74, ce-debug 339->117,
#     ce-test-browser 242->51, ce-handoff 142->55 (upstream-current is 123 for ce-debug, so
#     the stale FORK is behind upstream too -- refreshing targets neither state correctly).
#     The installed copies are far richer than any current source; until a human decides
#     whether that is deliberate local enrichment or a stale install, refresh is BLOCKED.
#     Same rationale as codex-review/codex-build above: never trade a richer working skill
#     for a thinner pointer.
$protected = @(
    'codex-review',
    'codex-build',
    'hallmark',
    'taste-skill',
    'create-technical-design-doc',
    'ce-ideate',
    'ce-strategy',
    'ce-product-pulse',
    'ce-compound-refresh',
    'ce-explain',
    'ce-debug',
    'ce-simplify-code',
    'ce-commit',
    'ce-commit-push-pr',
    'ce-worktree',
    'ce-handoff',
    'ce-promote',
    'ce-setup',
    'ce-retune',
    'ce-test-browser',
    'lfg'
)

function Get-SourceSkillFile {
  param([string]$Repo, [string]$Name, [string]$RelPath, [string]$SourceOverride, [string]$RepoRoot)
  if ($Repo -like 'local/*' -or $SourceOverride) {
    $sp = if ($SourceOverride) { $SourceOverride } else { "upstream/$Name" }
    if (-not [System.IO.Path]::IsPathRooted($sp)) { $sp = Join-Path $RepoRoot $sp }
    return (Join-Path $sp 'SKILL.md')
  }
  # Fork mirror directory name is the repo's last path segment for every mapped repo.
  $dir = $Repo.Split('/')[-1]
  $rp  = if ($RelPath) { $RelPath } else { "skills/$Name" }
  return (Join-Path (Join-Path $forkRoot $dir) (Join-Path $rp 'SKILL.md'))
}

# Insert an arbitrary installed line (e.g. argument-hint:) into fresh source content.
# The bundle adds `argument-hint:` at install time and upstream does not ship it, so a
# naive overwrite silently drops it. We re-attach it directly after the description
# block, handling multi-line descriptions whose continuation lines are indented.
function Merge-ArgumentHint {
  param([string]$SourceText, [string]$HintLine)

  $lines = $SourceText -split "`n"
  $fmEnd = -1; $seen = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].TrimEnd() -eq '---') { $seen++; if ($seen -eq 2) { $fmEnd = $i; break } }
  }
  if ($fmEnd -lt 0) { return $SourceText }   # no frontmatter: refuse to guess

  $lastDesc = -1; $inDesc = $false
  for ($i = 0; $i -lt $fmEnd; $i++) {
    $l = $lines[$i]
    if ($l -match '^description:') { $inDesc = $true; $lastDesc = $i; continue }
    if ($inDesc -and $l -match '^\s+\S') { $lastDesc = $i; continue }
    if ($l -match '^\S') { $inDesc = $false }
  }
  if ($lastDesc -lt 0) { return $SourceText }  # no description: refuse to guess

  $out = @()
  $out += $lines[0..$lastDesc]
  $out += $HintLine
  if ($lastDesc + 1 -le $lines.Count - 1) { $out += $lines[($lastDesc + 1)..($lines.Count - 1)] }
  return ($out -join "`n")
}

foreach ($line in $lines) {
  $parts = $line -split '\|'
  $repo       = $parts[0].Trim()
  $name       = $parts[1].Trim()
  $relPath    = $parts[2].Trim()
  $disabled   = $parts[3].Trim() -eq "true"
  $sourcePath = if ($parts.Length -ge 5) { $parts[4].Trim() } else { '' }

  $destDir = if ($disabled) { "$env:USERPROFILE\.agents\skills._disabled\$name" }
             else { "$env:USERPROFILE\.agents\skills\$name" }

  if ((Test-Path $destDir) -and -not $Refresh) {
    $skipped++; Write-Host "skip $name (present)"; continue
  }

  # ---- REFRESH PATH: update an existing skill in place from its current source ----
  if ((Test-Path $destDir) -and $Refresh) {
    # HARD RULE: only refresh rows sourced from a git fork mirror.
    #
    # A `local/*` row (or any row carrying an explicit -SourcePath override) is a
    # hand-authored port that lives INSIDE this repo under upstream/. Its content came
    # from somewhere else and was deliberately rewritten for Copilot. "Refreshing" it
    # against the bundle's own upstream/ file is circular and DESTRUCTIVE: the
    # working-tree upstream/ copy can be leaner than what was installed, so this
    # silently downgrades the port. This is not a heuristic - it was observed
    # overwriting book-to-skill (702 -> 414 lines) and diagram-design (565 -> 273).
    if ($repo -like 'local/*' -or $sourcePath) {
      $skipped++; Write-Host "skip $name (protected local port)"; continue
    }
    if ($protected -contains $name) {
      $skipped++; Write-Host "skip $name (protected hand-port)"; continue
    }

    $destSkill = Join-Path $destDir 'SKILL.md'
    $srcSkill  = Get-SourceSkillFile -Repo $repo -Name $name -RelPath $relPath `
                                     -SourceOverride $sourcePath -RepoRoot $repoRoot

    if (-not (Test-Path $srcSkill)) { $skipped++; Write-Host "skip $name (no source)"; continue }
    if (-not (Test-Path $destSkill)) { $skipped++; Write-Host "skip $name (no installed SKILL.md)"; continue }

    $srcText  = [System.IO.File]::ReadAllText($srcSkill)
    $destText = [System.IO.File]::ReadAllText($destSkill)

    # Preserve the bundle's install-time argument-hint addition.
    $hint = ($destText -split "`n" | Where-Object { $_ -match '^argument-hint:' } | Select-Object -First 1)
    $newText = $srcText
    if ($hint -and ($srcText -notmatch '(?m)^argument-hint:')) {
      $newText = Merge-ArgumentHint -SourceText $srcText -HintLine $hint
    }

    # Compare against the content we would WRITE, not against the raw source.
    # After a successful merge the installed file legitimately differs from the raw
    # source (it carries the preserved argument-hint line), so comparing to $srcText
    # flagged the same skills again on every run and rewrote them forever.
    if ($newText -eq $destText) { $skipped++; Write-Host "skip $name (up to date)"; continue }

    if ($PSCmdlet.ShouldProcess($destSkill, 'refresh SKILL.md')) {
      [System.IO.File]::WriteAllText($destSkill, $newText, (New-Object System.Text.UTF8Encoding $false))
      # Keep the Claude Code mirror in sync when it exists.
      $claudeSkill = "$env:USERPROFILE\.claude\skills\$name\SKILL.md"
      if (Test-Path $claudeSkill) {
        [System.IO.File]::WriteAllText($claudeSkill, $newText, (New-Object System.Text.UTF8Encoding $false))
      }
      Write-Host "refresh $name ... OK"; $installed++
    } else {
      # ShouldProcess returned false (i.e. -WhatIf): still report it as a pending change,
      # otherwise the preview under-counts and looks like nothing would happen.
      Write-Host "refresh $name ... WHATIF"; $wouldRefresh++
    }
    continue
  }

  Write-Host "install $name ..." -NoNewline
  if ($repo -like 'local/*' -or $sourcePath) {
    if (-not $sourcePath) { $sourcePath = "upstream/$name" }
    if (-not [System.IO.Path]::IsPathRooted($sourcePath)) {
      $sourcePath = Join-Path $repoRoot $sourcePath
    }
    $installArgs = @("-Name", $name, "-SourcePath", $sourcePath)
  } else {
    $installArgs = @("-Repo", $repo, "-Name", $name)
    if ($relPath) { $installArgs += @("-SkillRelPath", $relPath) }
  }
  if ($disabled) { $installArgs += "-Disabled" }

  $argLine = ($installArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
  $out = cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$helper`" $argLine 2>&1" | Out-String
  if ($out -match "complete:.*active" -or $out -match "complete:.*DISABLED") {
    Write-Host " OK"; $installed++
  } elseif ($out -match "BLOCK|FAIL|Die") {
    Write-Host " BLOCKED"; $blocked++; Write-Host $out -ForegroundColor DarkYellow
  } else {
    Write-Host " ?"; $skipped++; Write-Host $out -ForegroundColor DarkGray
  }
}
Write-Host ""
if ($Refresh) {
  $label = if ($WhatIfPreference) { 'Would refresh' } else { 'Refreshed' }
  # Braces are required: "$label:" is parsed as a drive-qualified variable reference.
  Write-Host "${label}: $($installed + $wouldRefresh)  Up-to-date/protected: $skipped  Blocked: $blocked" -ForegroundColor Cyan
} else {
  Write-Host "Installed: $installed  Blocked: $blocked  Skipped: $skipped" -ForegroundColor Cyan
}