# skillspector-local.ps1
#
# Run SkillSpector against a LOCAL Ollama model instead of a cloud provider.
#
# WHY: the hard security gate (`skillspector scan`, exit 0=proceed / 1=block) is
# static by default (`--no-llm`). The optional LLM-assisted pass needs credentials;
# pointing it at local Ollama lets us CLEAR OR CONFIRM the static findings without
# a cloud API key AND without shipping skill source to a third party.
#
# HOW: SkillSpector has NO `ollama` provider. Ollama is reached through the
# `openai` provider via OPENAI_BASE_URL. OPENAI_API_KEY must be NON-EMPTY (the
# provider returns None otherwise) but Ollama ignores its value.
#
# SCOPE: sets process-level env vars for the child process only. It does NOT
# write to the registry, the User profile, or any config file. Settings do not
# persist beyond the session; add them to the User environment to make permanent.
#
# USAGE
#   .\skillspector-local.ps1 scan <path>              # terminal output
#   .\skillspector-local.ps1 scan <path> -f json      # json to stdout
#   .\skillspector-local.ps1 scan <path> -f json -o report.json
#   .\skillspector-local.ps1 -Model deepseek-v4.1-flash:cloud scan <path>
#   .\skillspector-local.ps1 -Check                   # verify wiring, no scan
#
# NO param() BLOCK - THIS IS INTENTIONAL. DO NOT ADD ONE.
# SkillSpector's CLI uses short flags (-f, -o, -r) that collide with PowerShell's
# parameter binder in three separate ways, all hit and fixed while building this:
#   1. A positional param swallowed the `scan` verb -> exit 2 "No such command".
#   2. A named param starting with `o` caught `-o <file>`, so every LLM call
#      pointed at a filesystem path and died on `c://` (httpcore.UnsupportedProtocol).
#   3. [CmdletBinding()] injects -OutVariable/-OutBuffer, making bare `-o`
#      ambiguous ("参数名称 'o' 存在歧义") before skillspector ever ran.
# Even a plain `param()` without CmdletBinding binds positionally, which is
# collision 1 again. So we take the raw array and parse ONLY our three flags,
# leaving every other token untouched for skillspector.

$ErrorActionPreference = 'Stop'

$Model    = 'ornith-1.5:9b'
$Endpoint = 'http://127.0.0.1:11434/v1'
$Check    = $false
$ssArgs   = New-Object System.Collections.Generic.List[string]

# Minimal manual parse: consume only -Model/-Endpoint/-Check, forward the rest.
$raw = @($args)
for ($i = 0; $i -lt $raw.Count; $i++) {
  $a = [string]$raw[$i]
  switch -Regex ($a) {
    '^-Model$'    { if ($i + 1 -lt $raw.Count) { $Model    = [string]$raw[++$i] }; continue }
    '^-Endpoint$' { if ($i + 1 -lt $raw.Count) { $Endpoint = [string]$raw[++$i] }; continue }
    '^-Check$'    { $Check = $true; continue }
    default       { $ssArgs.Add($a) }
  }
}

# --- resolve skillspector (may be off PATH in a stale shell session) ---
$exe = (Get-Command skillspector -ErrorAction SilentlyContinue).Source
if (-not $exe) {
  $cand = Join-Path $env:USERPROFILE '.local\bin\skillspector.exe'
  if (Test-Path $cand) { $exe = $cand }
}
if (-not $exe) {
  Write-Host 'skillspector not found (run bin\verify-state.ps1 to see what is missing).' -ForegroundColor Red
  exit 2
}

# --- registry override: silences "not found in model_registry.yaml" warnings ---
# The registry lives in setup/ (source of truth); this script lives in bin/.
$registry = $null
foreach ($cand in @(
  (Join-Path $PSScriptRoot 'skillspector-ollama-models.yaml'),
  (Join-Path $PSScriptRoot '..\setup\skillspector-ollama-models.yaml')
)) {
  if (Test-Path $cand) { $registry = (Resolve-Path $cand).Path; break }
}

# --- wire the openai provider at the local Ollama endpoint (process-scoped) ---
$env:SKILLSPECTOR_PROVIDER = 'openai'
$env:OPENAI_BASE_URL       = $Endpoint
$env:OPENAI_API_KEY        = 'ollama'      # placeholder; required non-empty, value unused
$env:SKILLSPECTOR_MODEL    = $Model
if ($registry) { $env:SKILLSPECTOR_MODEL_REGISTRY = $registry }

if ($Check) {
  Write-Host '=== skillspector-local wiring ===' -ForegroundColor Cyan
  Write-Host ("  exe              : {0}" -f $exe)
  Write-Host ("  provider         : {0}" -f $env:SKILLSPECTOR_PROVIDER)
  Write-Host ("  base url         : {0}" -f $env:OPENAI_BASE_URL)
  Write-Host ("  api key          : set (len {0}, value unused by Ollama)" -f $env:OPENAI_API_KEY.Length)
  Write-Host ("  model            : {0}" -f $env:SKILLSPECTOR_MODEL)
  Write-Host ("  registry override: {0}" -f $(if ($registry) { $registry } else { 'NOT FOUND' }))

  try {
    $tagsUrl = ($Endpoint -replace '/v1/?$', '').TrimEnd('/') + '/api/tags'
    $tags = (Invoke-WebRequest -Uri $tagsUrl -UseBasicParsing -TimeoutSec 8).Content | ConvertFrom-Json
    $names = @($tags.models | ForEach-Object { $_.name })
    Write-Host ("  ollama server    : UP ({0} models)" -f $names.Count) -ForegroundColor Green
    if ($names -contains $Model) {
      Write-Host ("  model available  : YES ({0})" -f $Model) -ForegroundColor Green
      if ($Model -like '*cloud*') {
        Write-Host '  WARNING: this is a cloud-routed model - inference runs OFF-MACHINE.' -ForegroundColor Yellow
      }
    } else {
      Write-Host ("  model available  : NO - '{0}' not in ollama list" -f $Model) -ForegroundColor Red
      Write-Host ("    available: {0}" -f (($names | Select-Object -First 12) -join ', '))
    }
  } catch {
    Write-Host ("  ollama server    : UNREACHABLE - {0}" -f $_.Exception.Message) -ForegroundColor Red
  }
  exit 0
}

if ($ssArgs.Count -eq 0) {
  Write-Host 'Nothing to run. Pass skillspector args, e.g.:' -ForegroundColor Yellow
  Write-Host '  .\skillspector-local.ps1 scan <path> -f json -o report.json'
  Write-Host '  .\skillspector-local.ps1 -Check'
  exit 2
}

& $exe @ssArgs
exit $LASTEXITCODE
