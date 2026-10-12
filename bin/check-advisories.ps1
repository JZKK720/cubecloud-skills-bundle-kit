# skills-ref advisory probe. Scans every skill that has a committed suppression baseline
# (previously a hardcoded list of 4 names that drifted as the bundle changed), plus any names
# passed as arguments. Advisory only - it reports, it does not gate.
. (Join-Path $PSScriptRoot 'lib\bundle-common.ps1')
Initialize-BundlePath

$repoRoot = Get-BundleRoot $PSScriptRoot
$skills = @()
if ($args.Count) {
  $skills = $args
} elseif ($repoRoot) {
  $skills = @(Get-ChildItem (Join-Path $repoRoot 'baselines') -Filter '*.baseline.yaml' -ErrorAction SilentlyContinue |
    ForEach-Object { $_.BaseName -replace '\.baseline$', '' })
}
if (-not $skills.Count) { Write-Output "No baselines found and no skill names given; nothing to check."; exit 0 }

foreach ($s in $skills) {
  Write-Output "=== $s ==="
  $skillPath = "$env:USERPROFILE\.agents\skills\$s"
  if (-not (Test-Path $skillPath)) { Write-Output "  (not installed; skipped)"; Write-Output ""; continue }
  $logFile = "$env:TEMP\adv_$s.log"
  cmd /c "skills-ref validate `"$skillPath`" > `"$logFile`" 2>&1"
  Get-Content $logFile -ErrorAction SilentlyContinue
  Write-Output ""
}