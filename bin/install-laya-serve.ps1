# install-laya-serve.ps1 - opt-in installer for the Laya local decision sidecar.
#
# Copies the vendored server into a machine-local runtime home, writes the
# start/stop shims onto PATH, and registers a per-user autostart (HKCU Run key).
# Idempotent: safe to re-run; re-copies files and re-asserts the Run key.
#
# Opt-in by design (mirrors setup-global-skills.ps1 -IncludeArchifyCli): this puts
# a daemon on the machine and a key in the registry, so it ships as a separate
# script rather than an unconditional installer phase.
#
# Requires: C:\rocm-sdk\.venv (ROCm torch + laya) - verified by this script.
param(
    [string]$VenvPython = 'C:\rocm-sdk\.venv\Scripts\python.exe',
    [string]$RuntimeHome = 'C:\rocm-sdk',
    [switch]$Start
)
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here '..\upstream\laya\laya-serve.py'
$src = (Resolve-Path $src).Path

if (-not (Test-Path $VenvPython)) {
    Write-Host "FAIL: venv python not found at $VenvPython" -ForegroundColor Red
    Write-Host '  The sidecar needs the ROCm torch runtime (see setup/SETUP_GUIDE.md - laya section).'
    exit 1
}
if (-not (Test-Path $src)) { Write-Host "FAIL: vendored server not found: $src" -ForegroundColor Red; exit 1 }

New-Item -ItemType Directory -Force -Path $RuntimeHome | Out-Null
$dst = Join-Path $RuntimeHome 'laya-serve.py'
Copy-Item $src $dst -Force
Write-Host "OK: server -> $dst"

$binDir = Join-Path $env:USERPROFILE '.local\bin'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

# Start shim: foreground-friendly launcher, no console window when started at logon
$shimStart = Join-Path $binDir 'laya-serve.cmd'
@'
@echo off
rem laya-serve: start the Laya decision sidecar in the background (no console window)
rem Live state:  curl http://127.0.0.1:8770/api/health
rem Stop:        laya-serve-stop.cmd
set PYW=C:\rocm-sdk\.venv\Scripts\python.exe
if not exist "%PYW%" (
  echo ERROR: %PYW% not found
  exit /b 1
)
start "laya-serve" /B "%PYW%" "C:\rocm-sdk\laya-serve.py" > "C:\rocm-sdk\laya-serve-stdout.log" 2>&1
echo laya-serve starting on http://127.0.0.1:8770 (log: C:\rocm-sdk\laya-serve.log)
'@ | Set-Content $shimStart -Encoding ASCII
Write-Host "OK: shim -> $shimStart"

# Stop shim
$shimStop = Join-Path $binDir 'laya-serve-stop.cmd'
@'
@echo off
rem stop the laya-serve sidecar via its pidfile
if exist "C:\rocm-sdk\laya-serve.pid" (
  set /p PID=<"C:\rocm-sdk\laya-serve.pid"
  taskkill /PID %PID% /F /T >nul 2>nul
  del "C:\rocm-sdk\laya-serve.pid" 2>nul
  echo laya-serve (PID %PID%) stopped
) else (
  echo no pidfile found - sidecar not running?
  exit /b 1
)
'@ | Set-Content $shimStop -Encoding ASCII
Write-Host "OK: shim -> $shimStop"

# Auto-start: HKCU Run key (per-user, no elevation needed)
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runVal = 'cmd.exe /c "' + $shimStart + '"'
if (-not (Get-ItemProperty -Path $runKey -Name 'LayaServe' -ErrorAction SilentlyContinue)) {
    New-ItemProperty -Path $runKey -Name 'LayaServe' -PropertyType String -Value $runVal | Out-Null
    Write-Host "OK: autostart registered (HKCU Run\\LayaServe)"
} else {
    Set-ItemProperty -Path $runKey -Name 'LayaServe' -Value $runVal
    Write-Host "OK: autostart already registered -> updated"
}

if ($Start) {
    & $shimStart
    Write-Host 'OK: -Start passed; sidecar launching (health at /api/health will turn ok=true after ~40s of load+warmup)'
}

Write-Host ''
Write-Host 'laya-serve install complete. Verify:  http://127.0.0.1:8770/api/health'