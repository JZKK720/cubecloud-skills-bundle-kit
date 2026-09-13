$servers = @("markitdown","skillspector","firecrawl","scrapling","gbrain")
foreach ($n in $servers) {
  Write-Output "=== $n ==="
  $errPath = "$env:TEMP\mcpfinal_${n}_err.log"
  $outPath = "$env:TEMP\mcpfinal_${n}_out.log"
  $errSize = if (Test-Path $errPath) { (Get-Item $errPath).Length } else { "N/A" }
  $outSize = if (Test-Path $outPath) { (Get-Item $outPath).Length } else { "N/A" }
  Write-Output "  out=${outSize}B err=${errSize}B"
  if (Test-Path $errPath) {
    $lines = Get-Content $errPath -ErrorAction SilentlyContinue
    if ($lines) { $lines | Select-Object -First 3 | ForEach-Object { Write-Output "  >> $_" } }
    else { Write-Output "  (empty stderr - server started as daemon)" }
  }
}
Write-Output ""
Write-Output "=== graphify (no log - likely crashed) ==="
$gErr = "$env:TEMP\mcpfinal_graphify_err.log"
$gOut = "$env:TEMP\mcpfinal_graphify_out.log"
Write-Output "  err exists: $(Test-Path $gErr) | out exists: $(Test-Path $gOut)"