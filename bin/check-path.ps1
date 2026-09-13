# Check current persistent user PATH and identify missing bin dirs
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
$allPath = $userPath + ";" + $machinePath

Write-Output "=== Current User PATH ==="
$userPath -split ';' | ForEach-Object { if ($_ -ne '') { Write-Output "  $_" } }

Write-Output ""
Write-Output "=== Required bin dirs for MCP/CLI support ==="
$required = @(
  "$env:USERPROFILE\.local\bin",           # uv tools (skillspector, skills-ref, specify, skillopt, agent-reach, graphify, markitdown, scrapling)
  "$env:USERPROFILE\.bun\bin",             # bun globals (gbrain, gstack)
  "$env:APPDATA\npm"   # npm globals (uipro, firecrawl, ponytail)
)

foreach ($dir in $required) {
  $present = $allPath -like "*$dir*"
  $exists = Test-Path $dir
  $status = if ($present) { "ALREADY on PATH" } elseif ($exists) { "MISSING from PATH (dir exists)" } else { "MISSING (dir doesn't exist)" }
  Write-Output "  $dir -> $status"
}