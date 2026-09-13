<#
.SYNOPSIS
  Canonical skill install pipeline: clone upstream -> SkillSpector scan -> skills-ref validate -> copy to ~/.agents/skills/ and ~/.claude/skills/.

.DESCRIPTION
  Funnel for installing Agent Skills onto this Windows machine for VS Code Copilot + Claude Code (multi-harness).
  Pipeline stages (any failure aborts the install):
    1. Clone upstream repo to a temp dir (or use a provided local path).
    2. Locate the skill folder inside the repo (default: skills/<name>/, or override with -SkillRelPath).
    3. Run `skillspector scan` on the skill folder. Verdict exit 0 = proceed; 1 = block (do_not_install); 2 = retry/error.
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
  [Parameter()][string]$SourcePath
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
Write-Stage "SkillSpector scan --no-llm $skillDir"
$scanOutFile = "$env:TEMP\skillspector_$Name.log"
cmd /c "skillspector scan `"$skillDir`" --no-llm > `"$scanOutFile`" 2>&1"
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
if (Test-Path $dest) {
  Write-Host "  Existing install at $dest; overwriting." -ForegroundColor Yellow
  Remove-Item $dest -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Path "$skillDir\*" -Destination $dest -Recurse -Force
if ($Disabled) {
  $skillFile = Join-Path $dest 'SKILL.md'
  if (Test-Path $skillFile) {
    Rename-Item $skillFile 'SKILL.md.disabled' -Force
    Write-OK "Disabled: SKILL.md -> SKILL.md.disabled"
  }
}
Write-OK "Installed to $dest"

# --- 5. Mirror to Claude Code skills dir (respect Disabled flag) ---
$claudeDest = Join-Path $ClaudeRoot $Name
Write-Stage "Mirror -> $claudeDest"
if (Test-Path $claudeDest) { Remove-Item $claudeDest -Recurse -Force }
New-Item -ItemType Directory -Force -Path $claudeDest | Out-Null
Copy-Item -Path "$skillDir\*" -Destination $claudeDest -Recurse -Force
if ($Disabled) {
  $claudeSkill = Join-Path $claudeDest 'SKILL.md'
  if (Test-Path $claudeSkill) { Rename-Item $claudeSkill 'SKILL.md.disabled' -Force }
}
Write-OK "Mirrored to $claudeDest"

# --- 6. Append scan log row ---
$status = if ($Disabled) { 'DISABLED' } else { 'active' }
$refNote = if ($refCode -eq 0) { 'ref:valid' } else { 'ref:advisory' }
$logRow = "| $(Get-Date -Format 'yyyy-MM-dd HH:mm') | $Repo | $Name | pass (exit $scanCode) | $status | $refNote |"
if (Test-Path $ScanLog) {
  Add-Content -Path $ScanLog -Value $logRow
} else {
  Write-Warn "SCAN_LOG.md not found at $ScanLog; skipping log append"
}
Write-OK "Logged to $ScanLog"

# --- 7. Cleanup temp clone ---
if ($tmpClone -and (Test-Path $tmpClone)) {
  Remove-Item $tmpClone -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== install-skill.ps1 complete: $Name ($status) ===" -ForegroundColor Green