<#
.SYNOPSIS
  Optional advisory SkillEvaluator pass over the installed skill collection.

.DESCRIPTION
  `skillspector` remains the ONLY blocking gate. This script runs NVIDIA SkillEvaluator's
  keyless static checks, which answer questions the gate does not:

    quality-check  - graded quality score (Correctness/Discoverability/Reliability/Efficiency)
    Harness compatibility - will the harness actually LOAD this skill?
    lint-scripts   - advisory AST checks on Python scripts
    pii-scan       - PII, credentials and local identifiers in skill content

  It deliberately does NOT run similarity-check (Tier 2): that needs an embedding provider
  (SKILL_EVAL_EMBEDDING_PROVIDER=openai|anthropic|nv_build|bedrock|openai-compatible plus a key),
  and without one it reports `incomplete` rather than a result. Tier 3 needs Docker and an LLM
  key. Both are opt-in, not part of this pass.

  Findings are ADVISORY: this script never fails a build and never blocks an install.

.PARAMETER Path
  A skill directory, or a collection directory containing many skills.
  Default: ~/.agents/skills

.PARAMETER OutDir
  Where SkillEvaluator writes its json/html reports. Default: ~/dev/upstream/skillevaluator

.PARAMETER MaxSkills
  Cap the number of skills evaluated (each is a separate process). Default: 0 = all.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File bin/skillevaluator-advisory.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File bin/skillevaluator-advisory.ps1 -Path ~/.agents/skills/ffmpeg-skill
#>
[CmdletBinding()]
param(
  [string]$Path = "$env:USERPROFILE\.agents\skills",
  [string]$OutDir = "$env:USERPROFILE\dev\upstream\skillevaluator",
  [int]$MaxSkills = 0
)

$ErrorActionPreference = 'Stop'
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"

if (-not (Get-Command skillevaluator -ErrorAction SilentlyContinue)) {
  Write-Host "skillevaluator not on PATH. Install it with:" -ForegroundColor Yellow
  Write-Host "  uv tool install --python 3.13 skillevaluator" -ForegroundColor Yellow
  Write-Host "This tool is ADVISORY - skillspector remains the only blocking gate."
  exit 0
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$targets = @()
if (Test-Path (Join-Path $Path 'SKILL.md')) {
  $targets = @(Get-Item $Path)
} else {
  $targets = @(Get-ChildItem $Path -Directory |
    Where-Object { -not $_.Name.StartsWith('.') -and (Test-Path (Join-Path $_.FullName 'SKILL.md')) })
}
if ($MaxSkills -gt 0) { $targets = $targets | Select-Object -First $MaxSkills }

Write-Host "=== SkillEvaluator advisory pass ===" -ForegroundColor Cyan
Write-Host "  target : $Path"
Write-Host "  skills : $($targets.Count)"
Write-Host "  output : $OutDir"
Write-Host "  NOTE   : advisory only; skillspector is the gate." -ForegroundColor DarkGray

$rows = @()
$gradeCount = @{}
foreach ($t in $targets) {
  $name = $t.Name
  $safe = ($name -replace '[^A-Za-z0-9_.-]', '_')
  $skillOut = Join-Path $OutDir $safe
  New-Item -ItemType Directory -Force -Path $skillOut | Out-Null

  $q = ''
  $qExit = 1
  try {
    $q = & skillevaluator quality-check $t.FullName -o $skillOut -r json 2>&1 | Out-String
    $qExit = $LASTEXITCODE
  } catch { $q = $_.Exception.Message }

  $grade = ''
  $score = ''
  $qj = Join-Path $skillOut 'skillevaluator-quality.json'
  if (Test-Path $qj) {
    try {
      $d = Get-Content $qj -Raw | ConvertFrom-Json
      $qs = $d.quality_summary
      if (-not $qs -and $d.results -and $d.results.Count -gt 0) { $qs = $d.results[0].quality }
      if ($qs) {
        $grade = [string]$qs.grade
        if ($null -ne $qs.overall_score) { $score = [string]$qs.overall_score }
      }
    } catch { }
  }
  # Fall back to the CLI text when the json shape changes between releases.
  if (-not $grade -and $q -match 'Grade:\s*([A-F])') { $grade = $Matches[1] }
  if (-not $score -and $q -match '([0-9]+\.[0-9])/100') { $score = $Matches[1] }

  if ($grade) {
    if ($gradeCount.ContainsKey($grade)) { $gradeCount[$grade] = $gradeCount[$grade] + 1 }
    else { $gradeCount[$grade] = 1 }
  }
  $rows += [pscustomobject]@{ Skill = $name; Grade = $grade; Score = $score; Exit = $qExit }
}

$rows | Sort-Object { [double]($_.Score -as [double]) } -Descending |
  Format-Table -AutoSize | Out-String -Width 200 | Write-Host

Write-Host "=== grade distribution ===" -ForegroundColor Cyan
foreach ($g in @('A', 'B', 'C', 'D', 'F')) {
  if ($gradeCount.ContainsKey($g)) { Write-Host ("  {0}: {1}" -f $g, $gradeCount[$g]) }
}
$scored = @($rows | Where-Object { $_.Score })
if ($scored.Count -gt 0) {
  $avg = ($scored | ForEach-Object { [double]$_.Score } | Measure-Object -Average).Average
  Write-Host ("  average score: {0:N1}/100 across {1} skills" -f $avg, $scored.Count)
}
Write-Host ""
Write-Host "Reports: $OutDir" -ForegroundColor DarkGray
Write-Host "This pass is ADVISORY: it never blocks an install. Run bin/mcp-smoke-test.ps1 and" -ForegroundColor DarkGray
Write-Host "bin/full-audit.ps1 for the blocking gates." -ForegroundColor DarkGray
