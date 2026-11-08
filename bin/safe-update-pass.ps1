<#
.SYNOPSIS
  Guarded maintenance update pass for the CubeCloud bundle on Windows.

.DESCRIPTION
  Standardizes safe local updates and avoids the Python 3.13 headroom build path.
  Steps:
    1. Upgrade uv-managed tools.
    2. Reinstall skills-ref from the GitHub subdirectory source.
    3. Reinstall headroom-ai in an isolated uv tool env using Python 3.12.
    4. Remove pip-installed headroom-ai from shared Python envs to prevent
       openspace/litellm dependency conflicts on future upgrades.
    5. Update gbrain via bun.
    6. Run the 10-server MCP smoke test.

  Run:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\bin\safe-update-pass.ps1

.PARAMETER SkipSmoke
  Skip the final MCP smoke test.
#>

[CmdletBinding()]
param(
  [switch]$SkipSmoke
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  WARN: $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "  FAIL: $msg" -ForegroundColor Red }

function Assert-Command([string]$name, [string]$hint) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    Write-Fail "$name not found. $hint"
    exit 1
  }
}

function Test-PyVersion([string]$ver) {
  try {
    $null = & py -$ver --version 2>$null
    return $true
  } catch {
    return $false
  }
}

function Invoke-Logged([string]$title, [scriptblock]$block) {
  Write-Step $title
  & $block
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Assert-Command -name "uv" -hint "Install with: winget install astral-sh.uv"
Assert-Command -name "bun" -hint "Install with: winget install Oven-sh.Bun"
Assert-Command -name "py" -hint "Install Python launcher with Python on Windows"

if (-not (Test-PyVersion "3.12")) {
  Write-Fail "Python 3.12 is required for guarded headroom updates."
  Write-Host "  Install: winget install Python.Python.3.12"
  exit 1
}
Write-OK "Python 3.12 detected: $(& py -3.12 --version 2>&1)"

Invoke-Logged "Update uv-managed tools" {
  try {
    uv tool upgrade --all
    if ($LASTEXITCODE -ne 0) { throw "uv tool upgrade --all exited with code $LASTEXITCODE" }
    Write-OK "uv tool upgrade --all completed"
  } catch {
    Write-Warn "uv tool upgrade --all reported issues. Continuing with deterministic reinstalls."
  }
}

Invoke-Logged "Repair skills-ref deterministically" {
  try { uv tool uninstall skills-ref | Out-Null } catch {}
  uv tool install --python 3.13 "git+https://github.com/agentskills/agentskills.git#subdirectory=skills-ref"
  if ($LASTEXITCODE -ne 0) {
    Write-Fail "skills-ref reinstall failed"
    exit 1
  }
  Write-OK "skills-ref reinstalled"
}

Invoke-Logged "Repair scrapling deterministically (mcp pinned < 2)" {
  # scrapling[ai] declares `mcp>=1.27.0` with no upper bound. A plain `uv tool upgrade --all`
  # therefore pulls mcp 2.x, which renamed `mcp.server.fastmcp` -> `mcp.server.mcpserver`;
  # scrapling imports the 1.x path, so its MCP daemon dies on startup. The upgrade above is
  # exactly what re-breaks it, so re-pin here every run. Verified 2026-11-02.
  try { uv tool uninstall scrapling | Out-Null } catch {}
  uv tool install --python 3.13 --with "mcp<2" "scrapling[ai]"
  if ($LASTEXITCODE -ne 0) {
    Write-Fail "scrapling reinstall failed"
    exit 1
  }
  Write-OK "scrapling reinstalled with mcp < 2"
}

Invoke-Logged "Install headroom in isolated uv tool env (Python 3.12 guard)" {
  try { uv tool uninstall headroom-ai | Out-Null } catch {}
  uv tool install --python 3.12 "headroom-ai[proxy]"
  if ($LASTEXITCODE -ne 0) {
    Write-Fail "headroom reinstall failed on Python 3.12"
    exit 1
  }
  Write-OK "headroom-ai installed via uv tool on Python 3.12"
}

Invoke-Logged "Remove shared pip headroom to prevent openspace/litellm resolver conflicts" {
  # Keep upgrades clean by avoiding shared-site dependency churn.
  # Headroom should be sourced from uv tool isolation only.
  $pyUninstallTargets = @("3.12", "3.13")
  foreach ($ver in $pyUninstallTargets) {
    if (Test-PyVersion $ver) {
      try {
        cmd /c "py -$ver -m pip uninstall -y headroom-ai >nul 2>nul"
        if ($LASTEXITCODE -eq 0) {
          Write-OK "Removed pip headroom-ai from Python $ver (or package not present)"
        } else {
          throw "pip uninstall returned $LASTEXITCODE"
        }
      } catch {
        Write-Warn "Could not uninstall pip headroom-ai for Python $ver; continuing"
      }
    }
  }
}

Invoke-Logged "Update gbrain" {
  bun install -g github:garrytan/gbrain
  if ($LASTEXITCODE -ne 0) {
    Write-Fail "gbrain update failed"
    exit 1
  }
  Write-OK "gbrain updated"
}

Invoke-Logged "Version and path verification" {
  $uvHeadroom = Join-Path $env:USERPROFILE ".local\bin\headroom.exe"
  if (-not (Test-Path $uvHeadroom)) {
    Write-Fail "Expected uv-managed headroom not found at $uvHeadroom"
    exit 1
  }

  # Ensure uv tool binaries win in this session even if user PATH order is stale.
  $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"

  $headroomCmd = Get-Command headroom -ErrorAction SilentlyContinue
  if ($null -eq $headroomCmd) {
    Write-Fail "headroom command not found after reinstall"
    exit 1
  }
  if ($headroomCmd.Source -notlike "*$env:USERPROFILE\.local\bin*") {
    Write-Warn "headroom resolves to non-uv path: $($headroomCmd.Source)"
    Write-Warn "Persist user PATH with ~/.local/bin first to avoid future drift."
  } else {
    Write-OK "headroom resolves to uv tool path: $($headroomCmd.Source)"
  }

  $hv = & headroom --version 2>&1
  $gv = & gbrain --version 2>&1
  Write-OK "$hv"
  Write-OK "$gv"
}

if (-not $SkipSmoke) {
  Invoke-Logged "Run 10-server MCP smoke test" {
    powershell -NoProfile -ExecutionPolicy Bypass -File .\bin\mcp-smoke-test.ps1
    if ($LASTEXITCODE -ne 0) {
      Write-Fail "MCP smoke test failed"
      exit 1
    }
  }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SAFE UPDATE PASS COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
