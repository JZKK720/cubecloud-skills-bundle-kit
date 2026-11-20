<#
.SYNOPSIS
  Tier 2 similarity check: find duplicate skills across the installed collection.

.DESCRIPTION
  NVIDIA SkillEvaluator embeds each skill's description (or full body with -FullBody) and reports
  pairs above a similarity threshold: EXACT_DUPLICATE (>0.95), HIGH_SIMILARITY (>0.85), SIMILAR.

  This needs an EMBEDDING PROVIDER. A local Ollama instance works and costs nothing:

      ollama pull nomic-embed-text
      # then this script uses http://localhost:11434/v1 automatically

  Without a provider the check reports `incomplete` for every skill and no catalog is written,
  so the script says so explicitly instead of pretending the collection is clean.

  ADVISORY: this never blocks an install. `skillspector` remains the only gate; a duplicate is a
  curation question, not a safety one.

.PARAMETER Path
  Collection directory. Default: ~/.agents/skills

.PARAMETER Threshold
  Inter-skill similarity threshold. Default: 0.85

.PARAMETER FullBody
  Embed full SKILL.md bodies instead of just descriptions (slower, catches near-copies).

.PARAMETER EmbedModel
  Ollama embedding model. Default: nomic-embed-text:latest

.PARAMETER OutDir
  Report directory. Default: ~/dev/upstream/skillevaluator-tier2

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File bin/skillevaluator-tier2.ps1
#>
[CmdletBinding()]
param(
  [string]$Path = "$env:USERPROFILE\.agents\skills",
  [double]$Threshold = 0.85,
  [switch]$FullBody,
  [string]$EmbedModel = 'nomic-embed-text:latest',
  [string]$OutDir = "$env:USERPROFILE\dev\upstream\skillevaluator-tier2"
)

$ErrorActionPreference = 'Stop'
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"

if (-not (Get-Command skillevaluator -ErrorAction SilentlyContinue)) {
  Write-Host "skillevaluator not on PATH; install with: uv tool install --python 3.13 skillevaluator"
  exit 0
}

# The openai client is an optional extra of skillevaluator; the similarity check needs it.
$toolPython = Get-ChildItem "$env:APPDATA\uv\tools\skillevaluator" -Recurse -Filter python.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($toolPython) {
  $hasOpenAI = & $toolPython.FullName -c "import importlib.util; print(importlib.util.find_spec('openai') is not None)" 2>&1
  if ($hasOpenAI -notmatch 'True') {
    Write-Host "Installing the openai client into the skillevaluator env (needed for embeddings)..."
    uv pip install --python $toolPython.FullName openai 2>&1 | Select-Object -Last 2 | ForEach-Object { "  $_" }
  }
}

# Prefer a local Ollama endpoint; it needs no key and no network egress.
$ollamaUp = $false
try {
  $null = Invoke-RestMethod 'http://localhost:11434/api/tags' -TimeoutSec 4
  $ollamaUp = $true
} catch { }

if ($ollamaUp) {
  $env:SKILL_EVAL_EMBEDDING_PROVIDER = 'openai-compatible'
  $env:SKILL_EVAL_LLM_API_KEY        = 'ollama-local'
  $env:SKILL_EVAL_EMBEDDING_BASE_URL = 'http://localhost:11434/v1'
  $env:SKILL_EVAL_LLM_BASE_URL       = 'http://localhost:11434/v1'
  Write-Host "provider : local Ollama at http://localhost:11434/v1 ($EmbedModel)" -ForegroundColor Cyan
} elseif ($env:SKILL_EVAL_EMBEDDING_PROVIDER -and $env:SKILL_EVAL_LLM_API_KEY) {
  Write-Host "provider : $($env:SKILL_EVAL_EMBEDDING_PROVIDER) (from environment)" -ForegroundColor Cyan
} else {
  Write-Host "No embedding provider available." -ForegroundColor Yellow
  Write-Host "  Ollama is not reachable at http://localhost:11434 and SKILL_EVAL_EMBEDDING_PROVIDER is unset." -ForegroundColor Yellow
  Write-Host "  Fix: ollama pull $EmbedModel   (or export SKILL_EVAL_EMBEDDING_PROVIDER + SKILL_EVAL_LLM_API_KEY)" -ForegroundColor Yellow
  Write-Host "  Tier 2 reports 'incomplete' without one, so it is being skipped rather than faked." -ForegroundColor Yellow
  exit 0
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$args = @('similarity-check', $Path, '--type', 'skill', '--threshold', "$Threshold", '--model', $EmbedModel, '-o', $OutDir, '-r', 'json')
if ($FullBody) { $args += '--full-body' }
# `similarity-check` exits 1 when duplicates are FOUND, and writes that to stderr. Under
# $ErrorActionPreference='Stop' a native command's stderr becomes a terminating error, which
# would abort the script before the report is read. Drop to Continue for this call only.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& skillevaluator @args 2>&1 | Select-Object -Last 3 | ForEach-Object { "  $_" }
$ErrorActionPreference = $prevEap

$report = Join-Path $OutDir 'skillevaluator-similarity.json'
if (-not (Test-Path $report)) {
  Write-Host "No report produced; the similarity run did not complete." -ForegroundColor Yellow
  exit 1
}

$d = Get-Content $report -Raw | ConvertFrom-Json
Write-Host ""
Write-Host "=== Tier 2 similarity ($($d.overall_status)) ===" -ForegroundColor Cyan
$sev = $d.finding_counts.unique_by_severity
if ($sev) { Write-Host ("  critical={0} high={1} medium={2}" -f $sev.critical, $sev.high, $sev.medium) }

$errs = @()
if ($d.results -and $d.results.Count -gt 0 -and $d.results[0].legacy) { $errs = @($d.results[0].legacy.errors) }
$pairs = @($errs | ForEach-Object { ($_ | Out-String).Trim() } | Where-Object { $_ -match 'SIMILARITY' })
if ($pairs.Count -eq 0) {
  Write-Host "  no duplicate pairs above $Threshold" -ForegroundColor Green
} else {
  Write-Host "  $($pairs.Count) duplicate pair(s):" -ForegroundColor Yellow
  $pairs | Select-Object -First 25 | ForEach-Object { Write-Host "    $_" }
  if ($pairs.Count -gt 25) { Write-Host "    ... $($pairs.Count - 25) more in $report" }
}
Write-Host ""
Write-Host "Report: $report" -ForegroundColor DarkGray
Write-Host "ADVISORY only - a duplicate is a curation decision, never a safety block." -ForegroundColor DarkGray
exit 0
