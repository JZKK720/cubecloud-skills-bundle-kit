$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
$env:PYTHONUTF8 = "1"
$skills = @("airunway-aks-setup","hallmark","ponytail","taste-skill")
foreach ($s in $skills) {
  Write-Output "=== $s ==="
  $skillPath = "$env:USERPROFILE\.agents\skills\$s"
  $logFile = "$env:TEMP\adv_$s.log"
  cmd /c "skills-ref validate `"$skillPath`" > `"$logFile`" 2>&1"
  Get-Content $logFile -ErrorAction SilentlyContinue
  Write-Output ""
}