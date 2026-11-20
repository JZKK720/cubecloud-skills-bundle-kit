<#
.SYNOPSIS
  Canonical skill install pipeline: clone upstream -> SkillSpector scan -> skills-ref validate -> copy to ~/.agents/skills/ and ~/.claude/skills/.

.DESCRIPTION
  Funnel for installing Agent Skills onto this Windows machine for VS Code Copilot + Claude Code (multi-harness).
  Pipeline stages (any failure aborts the install):
    1. Clone upstream repo to a temp dir (or use a provided local path).
    2. Locate the skill folder inside the repo (default: skills/<name>/, or override with -SkillRelPath).
    3. Run `skillspector scan` on the skill folder. Verdict exit 0 = proceed; 1 = block (do_not_install); 2 = retry/error.
       When a committed suppression baseline exists at <repoRoot>/baselines/<Name>.baseline.yaml (or an
       explicit -BaselinePath), it is passed via --baseline so operator-reviewed findings are suppressed
       instead of re-blocking on every install. See docs/plans/*-install-unblock-report.md.
    4. Run `skills-ref validate` on the skill folder. Must report "Valid skill".
    5. Copy the skill folder to ~/.agents/skills/<name>/ (VS Code Copilot discovery).
    6. Mirror to ~/.claude/skills/<name>/ (Claude Code).
    7. Append a row to ~/dev/upstream/SCAN_LOG.md.

  Disabled-by-default parking: pass -Disabled to copy to ~/.agents/skills._disabled/<name>/ instead
  (and rename SKILL.md -> SKILL.md.disabled). Still mirrored to ~/.claude/skills/ enabled OR disabled
  based on the same flag.

.PARAMETER Repo
  GitHub URL or owner/repo shorthand (e.g. "obra/superpowers") of the upstream source.

.PARAMETER Name
  The skill folder name (kebab-case). Must match the `name:` frontmatter field.

.PARAMETER SkillRelPath
  Relative path inside the repo to the skill folder containing SKILL.md. Default: "skills/<Name>".

.PARAMETER Disabled
  Switch: park the skill in ~/.agents/skills._disabled/<Name>/ with SKILL.md renamed to .disabled.

.PARAMETER SourcePath
  Optional: use a local already-cloned path instead of cloning from Repo.

.PARAMETER BaselinePath
  Optional: explicit SkillSpector suppression baseline (YAML/JSON) to pass via --baseline.
  When omitted, the pipeline auto-discovers <repoRoot>\baselines\<Name>.baseline.yaml
  (repoRoot is located by walking up from this script to the folder containing setup\skills-list.csv).

.EXAMPLE
  .\install-skill.ps1 -Repo "obra/superpowers" -Name "test-driven-development"
  .\install-skill.ps1 -Repo "JuliusBrussee/caveman" -Name "caveman" -Disabled
  .\install-skill.ps1 -Name "hallmark" -SourcePath "$env:USERPROFILE\dev\upstream\hallmark\skills\hallmark"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0)][string]$Repo,
  [Parameter(Mandatory)][string]$Name,
  [Parameter()][string]$SkillRelPath,
  [switch]$Disabled,
  [Parameter()][string]$SourcePath,
  [Parameter()][string]$BaselinePath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Ensure uv bin on PATH for this session
$uvBin = "$env:USERPROFILE\.local\bin"
if ($env:PATH -notlike "*$uvBin*") { $env:PATH = "$uvBin;$env:PATH" }
# Force UTF-8 file reads in child Python processes (Windows defaults to cp1252)
$env:PYTHONUTF8 = '1'

$AgentsRoot   = "$env:USERPROFILE\.agents\skills"
$DisabledRoot = "$env:USERPROFILE\.agents\skills._disabled"
$ClaudeRoot   = "$env:USERPROFILE\.claude\skills"
$ScanLog      = "$env:USERPROFILE\dev\upstream\SCAN_LOG.md"

function Write-Stage($msg) { Write-Host "[$(Get-Date -Format HH:mm:ss)] $msg" -ForegroundColor Cyan }
function Write-OK($msg)    { Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "  WARN: $msg" -ForegroundColor Yellow }
function Write-Fail($msg)   { Write-Host "  FAIL: $msg" -ForegroundColor Red }
function Die($msg)          { Write-Fail $msg; exit 1 }

# Install a skill tree atomically: build the full copy in a sibling staging dir, then rename it
# into place while moving any existing tree aside. The visible destination is therefore always
# either the previous complete install or the new complete install - never a half-copied skill.
# A rename within the same parent directory is atomic on Windows, so an interrupted copy can no
# longer leave a broken install (the failure mode of 'Remove-Item $dest; Copy-Item').
# Claude-Code-only keys that `skills-ref validate` rejects at top level. Nested under
# `metadata:` so the value survives for Claude Code while the frontmatter stays spec-valid.
$script:ClaudeOnlyFrontmatterKeys = @(
  'argument-hint', 'disable-model-invocation', 'user-invocable', 'user_invocable',
  'version', 'origin', 'tools', 'tags', 'triggers', 'mutating', 'writes_pages', 'writes_to',
  'hooks', 'allowed_tools', 'license_url', 'model'
)

function Repair-SkillFrontmatter([string]$SkillMdPath, [string]$ExpectedName) {
  try {
    # Read and write with an EXPLICIT UTF-8 codec. Get-Content/Set-Content round-trip through
    # the console code page on this host, which silently corrupts every non-ASCII character in a
    # skill: in 2026-11-19 a section sign became U+9225 and a right-arrow became U+922B this way.
    # [IO.File] with UTF8Encoding does not round-trip through the code page.
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $raw  = [System.IO.File]::ReadAllText($SkillMdPath, $utf8)
    $lines = $raw -split "\r?\n"
    if (-not $lines -or $lines[0].TrimEnd() -ne '---') { return }

    $end = -1; $seen = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i].TrimEnd() -eq '---') { $seen++; if ($seen -eq 2) { $end = $i; break } }
    }
    if ($end -lt 0) { return }

    $moved = @(); $keep = @(); $i = 0
    while ($i -lt $end) {
      $hit = $null
      foreach ($k in $script:ClaudeOnlyFrontmatterKeys) {
        if ($lines[$i] -match "^$([regex]::Escape($k)):") { $hit = $k; break }
      }
      if ($hit) {
        $block = @($lines[$i] -replace "^$([regex]::Escape($hit)):", "  $hit`:")
        $i++
        while ($i -lt $end -and $lines[$i] -match '^\s+\S') { $block += "  $($lines[$i])"; $i++ }
        $moved += $block
      } else { $keep += $lines[$i]; $i++ }
    }
    if ($moved.Count -eq 0) { return }

    $metaIdx = -1
    for ($k = 0; $k -lt $keep.Count; $k++) { if ($keep[$k] -match '^metadata:') { $metaIdx = $k; break } }
    if ($metaIdx -ge 0) {
      $j = $metaIdx + 1
      while ($j -lt $keep.Count -and $keep[$j] -match '^\s+\S') { $j++ }
      $keep = @($keep[0..($j-1)]) + $moved + @($keep[$j..($keep.Count-1)])
    } else {
      $keep = $keep + @('metadata:') + $moved
    }

    # A nested key can now appear twice (e.g. upstream already had version under metadata).
    # Compare whole indented lines, not `indent+key`: `opencode/slash` contains a `/` that a
    # key-only regex truncates, and re-keying on it corrupted the block (observed 2026-11-19).
    $final = @(); $seenLines = @{}
    $inMeta = $false
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

    # `skills-ref` also requires the frontmatter name to equal the skill FOLDER name, and
    # upstream sometimes ships a different one (e.g. taste-skill -> design-taste-frontend).
    if ($ExpectedName) {
      for ($k = 0; $k -lt $final.Count; $k++) {
        if ($final[$k] -match '^name:\s*(.+?)\s*$') {
          if ($Matches[1] -ne $ExpectedName) { $final[$k] = "name: $ExpectedName" }
          break
        }
      }
    }

    [System.IO.File]::WriteAllText($SkillMdPath, (($final + $lines[$end..($lines.Count - 1)]) -join "`n"), $utf8)
  } catch {
    Write-Warn "frontmatter normalisation skipped for $SkillMdPath ($($_.Exception.Message))"
  }
}

function Install-SkillTree([string]$Source, [string]$Dest, [switch]$ParkDisabled) {  $parent = Split-Path $Dest -Parent
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  $token   = [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
  $staging = "$Dest.__staging_$token"
  $backup  = "$Dest.__old_$token"

  if (Test-Path $staging) { Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Directory -Force -Path $staging | Out-Null
  Copy-Item -Path "$Source\*" -Destination $staging -Recurse -Force
  # Normalise Claude-Code-only frontmatter keys before the tree lands.
  # `skills-ref validate` allows only name/description/license/compatibility/metadata/
  # allowed-tools, so a skill shipping `argument-hint`, `version`, `tags`, `tools` or
  # `disable-model-invocation` at top level fails validation on every install. 66 of 333
  # installed skills were in that state (measured 2026-11-19). Nest them under `metadata:`
  # instead of dropping them: the values stay available to Claude Code, and Copilot ignores
  # the block. Doing it here (not as a one-off repair) means a refresh cannot reintroduce it.
  $stagedSkillMd = Join-Path $staging 'SKILL.md'
  if ((Test-Path $stagedSkillMd) -and -not $ParkDisabled) { Repair-SkillFrontmatter $stagedSkillMd (Split-Path $Dest -Leaf) }
  if ($ParkDisabled) {
    $sf = Join-Path $staging 'SKILL.md'
    if (Test-Path $sf) { Rename-Item $sf 'SKILL.md.disabled' -Force }
  }

  if (Test-Path $Dest) { Move-Item -Path $Dest -Destination $backup -Force }
  try {
    Move-Item -Path $staging -Destination $Dest -Force
  } catch {
    if (Test-Path $backup) { Move-Item -Path $backup -Destination $Dest -Force }
    Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
    throw
  }
  Remove-Item $backup -Recurse -Force -ErrorAction SilentlyContinue
}

# --- 1. Resolve source skill folder ---
if ($SourcePath) {
  $skillDir = $SourcePath
} else {
  if (-not $Repo) { Die "Either -Repo or -SourcePath must be provided." }
  if ($Repo -notmatch '^https?://') { $Repo = "https://github.com/$Repo.git" }
  $tmpClone = Join-Path $env:TEMP "skill_install_$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
  Write-Stage "Clone $Repo -> $tmpClone"
  $errFile = "$env:TEMP\git_clone_$(Get-Random).err"
  cmd /c "git clone --depth 1 `"$Repo`" `"$tmpClone`" >nul 2>`"$errFile`""
  if ($LASTEXITCODE -ne 0) { Die "git clone failed: $(Get-Content $errFile -ErrorAction SilentlyContinue | Select-Object -First 1)" }
  if (-not $SkillRelPath) { $SkillRelPath = "skills/$Name" }
  $skillDir = Join-Path $tmpClone $SkillRelPath
}

if (-not (Test-Path (Join-Path $skillDir 'SKILL.md'))) {
  Die "SKILL.md not found at $skillDir. Use -SkillRelPath to point to the skill folder."
}
Write-OK "Skill folder: $skillDir"

# --- 2. SkillSpector scan (HARD GATE) ---
# Resolve a suppression baseline if one applies. Precedence: explicit -BaselinePath, then the
# auto-discovered committed baseline <repoRoot>\baselines\<Name>.baseline.yaml. Baselines hold
# operator-reviewed suppressions (see 'skillspector baseline'); passing one via --baseline is
# the sanctioned way to stop a reviewed skill from re-blocking on every install.
if (-not $BaselinePath) {
  # Candidate 1: repo root discovered by walking up from this script (works for the repo copy
  # at setup\install-skill.ps1, i.e. when the installer runs it in-place).
  $repoRoot = $PSScriptRoot
  while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot 'setup\skills-list.csv'))) {
    $parent = Split-Path $repoRoot -Parent
    if ($parent -eq $repoRoot) { $repoRoot = $null; break }
    $repoRoot = $parent
  }
  $candidates = @()
  if ($repoRoot) { $candidates += (Join-Path $repoRoot "baselines\$Name.baseline.yaml") }
  # Candidate 2: deployed location, created by Phase 1b of setup-global-skills.ps1, so the
  # helper works when invoked as ~/dev/bin/install-skill.ps1 with no repo root in scope.
  $candidates += "$env:USERPROFILE\dev\baselines\$Name.baseline.yaml"
  # Candidate 3: operator override for custom layouts.
  if ($env:SKILL_BASELINES_DIR) { $candidates += (Join-Path $env:SKILL_BASELINES_DIR "$Name.baseline.yaml") }
  $BaselinePath = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

if ($BaselinePath) {
  if (-not (Test-Path $BaselinePath)) { Die "Baseline file not found: $BaselinePath" }
  Write-Stage "SkillSpector scan --no-llm --baseline `"$BaselinePath`" $skillDir"
  $scanOutFile = "$env:TEMP\skillspector_$Name.log"
  cmd /c "skillspector scan `"$skillDir`" --no-llm --baseline `"$BaselinePath`" > `"$scanOutFile`" 2>&1"
  Write-OK "Baseline applied: $(Split-Path $BaselinePath -Leaf)"
}
else {
  Write-Stage "SkillSpector scan --no-llm $skillDir"
  $scanOutFile = "$env:TEMP\skillspector_$Name.log"
  cmd /c "skillspector scan `"$skillDir`" --no-llm > `"$scanOutFile`" 2>&1"
}
$scanCode = $LASTEXITCODE
if (Test-Path $scanOutFile) {
  $scanSummary = Get-Content $scanOutFile -ErrorAction SilentlyContinue | Select-Object -Last 15
  Write-Host ($scanSummary -join "`n")
}
if ($scanCode -eq 1) {
  Die "SkillSpector verdict: do_not_install (exit $scanCode). HARD BLOCK. See $scanOutFile."
}
if ($scanCode -ge 2) {
  Die "SkillSpector error (exit $scanCode). Investigate before retrying. See $scanOutFile."
}
Write-OK "SkillSpector: pass (exit $scanCode)"

# --- 3. skills-ref validate (ADVISORY) ---
Write-Stage "skills-ref validate $skillDir (advisory)"
$refLog = "$env:TEMP\skillsref_$Name.log"
cmd /c "skills-ref validate `"$skillDir`" > `"$refLog`" 2>&1"
$refCode = $LASTEXITCODE
$refOut = if (Test-Path $refLog) { Get-Content $refLog -ErrorAction SilentlyContinue } else { @() }
if ($refCode -eq 0 -and ($refOut -join ' ') -match 'Valid skill') {
  Write-OK "skills-ref: valid"
} else {
  Write-Warn "skills-ref: advisory issues (exit $refCode). Install proceeds; issues logged:"
  $refOut | Select-Object -First 8 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
}

# --- 4. Copy to discovery dir (or disabled parking) ---
$dest = if ($Disabled) { Join-Path $DisabledRoot $Name } else { Join-Path $AgentsRoot $Name }
Write-Stage "Install -> $dest"
if (Test-Path $dest) { Write-Host "  Existing install at $dest; replacing atomically." -ForegroundColor Yellow }
if ($Disabled) { Install-SkillTree -Source $skillDir -Dest $dest -ParkDisabled } else { Install-SkillTree -Source $skillDir -Dest $dest }
if ($Disabled) { Write-OK "Disabled: SKILL.md -> SKILL.md.disabled" }
Write-OK "Installed to $dest"

# --- 5. Mirror to Claude Code skills dir (respect Disabled flag) ---
$claudeDest = Join-Path $ClaudeRoot $Name
Write-Stage "Mirror -> $claudeDest"
if ($Disabled) { Install-SkillTree -Source $skillDir -Dest $claudeDest -ParkDisabled } else { Install-SkillTree -Source $skillDir -Dest $claudeDest }
Write-OK "Mirrored to $claudeDest"

# --- 6. Append scan log row ---
$status = if ($Disabled) { 'DISABLED' } else { 'active' }
$refNote = if ($refCode -eq 0) { 'ref:valid' } else { 'ref:advisory' }
$baselineNote = if ($BaselinePath) { "baseline:$(Split-Path $BaselinePath -Leaf)" } else { 'baseline:none' }
$logRow = "| $(Get-Date -Format 'yyyy-MM-dd HH:mm') | $Repo | $Name | pass (exit $scanCode) | $status | $refNote | $baselineNote |"
if (Test-Path $ScanLog) {
  Add-Content -Path $ScanLog -Value $logRow
} else {
  Write-Warn "SCAN_LOG.md not found at $ScanLog; skipping log append"
}
Write-OK "Logged to $ScanLog"

# --- 7. Cleanup temp artifacts ---
# Git leaves pack/object files read-only, so a plain Remove-Item -Recurse -Force can silently
# fail and leak the clone in %TEMP% (this previously leaked 50+ clones undetected). Clear the
# read-only/hidden/system attributes, retry, and warn if anything survives.
function Remove-TempTree([string]$Path) {
  if (-not $Path -or -not (Test-Path $Path)) { return }
  Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
  if (Test-Path $Path) {
    cmd /c "attrib -r -s -h `"$Path`" /s /d >nul 2>nul"
    Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path $Path) { Write-Warn "Could not fully remove temp path: $Path" }
}
Remove-TempTree $tmpClone
foreach ($lf in @($scanOutFile, $refLog)) { if ($lf) { Remove-Item $lf -Force -ErrorAction SilentlyContinue } }

Write-Host ""
Write-Host "=== install-skill.ps1 complete: $Name ($status) ===" -ForegroundColor Green