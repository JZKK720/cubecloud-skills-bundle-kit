$tmp = "$env:TEMP\karpathy_probe"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
cmd /c "git clone --depth 1 https://github.com/JZKK720/andrej-karpathy-skills.git `"$tmp`" >nul 2>nul"
Write-Output "clone exit: $LASTEXITCODE"
Write-Output "=== SKILL.md files ==="
Get-ChildItem $tmp -Recurse -Filter "SKILL.md" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Replace($tmp, '') }
Write-Output ""
Write-Output "=== Repo structure (top-level) ==="
Get-ChildItem $tmp -ErrorAction SilentlyContinue | Select-Object Name, Mode
Write-Output ""
Write-Output "=== skills/ subdirs (if exists) ==="
$skillsDir = Join-Path $tmp "skills"
if (Test-Path $skillsDir) {
  Get-ChildItem $skillsDir -Directory | Select-Object Name
}
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue