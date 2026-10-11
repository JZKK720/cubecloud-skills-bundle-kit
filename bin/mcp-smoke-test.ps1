# MCP entrypoint smoke test - deterministic command probes for each MCP server.
# This intentionally avoids long-lived daemon startup paths that can hang on Windows.
$env:PATH = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.bun\bin;$env:APPDATA\npm;$env:PATH"
$env:PYTHONUTF8 = "1"
$reportFile = "$env:USERPROFILE\dev\upstream\MCP_SMOKE_TEST.md"
$runId = "{0}_{1}" -f (Get-Date -Format "yyyyMMdd_HHmmss"), $PID
$reportDir = Split-Path -Parent $reportFile
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$results = @()

$servers = @(
  @{name="markitdown"; cmd="uvx"; args="markitdown-mcp@latest --help"; timeout=30},
  @{name="skillspector"; cmd="skillspector"; args="--help"; timeout=15},
  @{name="firecrawl"; cmd="npm"; args="view firecrawl-mcp version"; timeout=15},
  @{name="scrapling"; cmd="scrapling"; args="mcp --help"; timeout=15},
  @{name="gbrain"; cmd="gbrain"; args="serve --help"; timeout=15},
  @{name="graphify"; cmd="graphify-mcp"; args="--help"; timeout=15},
  @{name="headroom"; cmd="headroom"; args="mcp serve --help"; timeout=15},
  @{name="loop-engineering"; cmd="node"; args="-e `"const{spawn}=require('child_process');const p=spawn(process.env.APPDATA+'\\npm\\loop-mcp-server.cmd',[],{shell:true});let got='';p.stdout.on('data',d=>{got+=d;});p.stdin.write(JSON.stringify({jsonrpc:'2.0',id:1,method:'initialize',params:{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'probe',version:'1.0'}}})+'\n');setTimeout(()=>{console.log(got.includes('loop-engineering')?'MCP_OK':'MCP_FAIL:'+got.slice(0,120));p.kill();process.exit(got.includes('loop-engineering')?0:1);},4000);`""; timeout=20},
  @{name="watch-skill"; cmd="watch-skill"; args="serve --help"; timeout=15},
  @{name="wigolo"; cmd="npx"; args="-y wigolo --help"; timeout=20},
    @{name="skillopt"; cmd="python"; args="`"$PSScriptRoot\skillopt-mcp-probe.py`""; timeout=20},
        @{name="rea"; cmd="npx"; args="-y rea-agents@latest mcp --help"; timeout=30}
      )

foreach ($s in $servers) {
  Write-Output ("[SMOKE] {0} (timeout={1}s)" -f $s.name, $s.timeout)
  $outFile = Join-Path $env:TEMP "mcpfinal_$($s.name)_$runId`_out.log"
  $errFile = Join-Path $env:TEMP "mcpfinal_$($s.name)_$runId`_err.log"
  if (Test-Path $outFile) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
  if (Test-Path $errFile) { Remove-Item $errFile -Force -ErrorAction SilentlyContinue }
  
  $fullCmd = if ($s.args -and $s.args.Length -gt 0) { "$($s.cmd) $($s.args)" } else { "$($s.cmd)" }
  
  $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $fullCmd > `"$outFile`" 2> `"$errFile`"" -PassThru -WindowStyle Hidden
  $timedOut = $false
  $deadline = [DateTime]::UtcNow.AddSeconds($s.timeout)
  while (-not $proc.HasExited -and [DateTime]::UtcNow -lt $deadline) {
    [void]$proc.WaitForExit(250)
  }
  if (-not $proc.HasExited) { $timedOut = $true }

  if ($timedOut) {
    # Probe timed out = FAIL for deterministic smoke behavior.
    try { $proc.Kill() } catch {}
    $outSize = if (Test-Path $outFile) { (Get-Item $outFile).Length } else { 0 }
    $errSize = if (Test-Path $errFile) { (Get-Item $errFile).Length } else { 0 }
    $results += "| $($s.name) | FAIL | Timed out after $($s.timeout)s (out=${outSize}B, err=${errSize}B) |"
  } else {
    $exitCode = if ($null -ne $proc.ExitCode) { $proc.ExitCode } else { -1 }
    $outSize = if (Test-Path $outFile) { (Get-Item $outFile).Length } else { 0 }
    $errSize = if (Test-Path $errFile) { (Get-Item $errFile).Length } else { 0 }
    $errFirst = if (Test-Path $errFile) { (Get-Content $errFile -First 2 -ErrorAction SilentlyContinue) -join " | " } else { "" }
    if ($errFirst.Length -gt 100) { $errFirst = $errFirst.Substring(0,100) + "..." }
    if ($exitCode -ne 0 -and $errFirst -match "(?i)error|traceback|fatal|exception|cannot find|not recognized|not found") {
      $results += "| $($s.name) | FAIL | Exit ${exitCode}: ${errFirst} |"
    } else {
      $results += "| $($s.name) | PASS | Probe exit ${exitCode} (out=${outSize}B, err=${errSize}B): ${errFirst} |"
    }
  }
  if ($null -ne $proc) { $proc.Close() }
}

$report = @()
$report += "# MCP Daemon Smoke Test Results"
$report += ""
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += ""
$report += "Each MCP server entrypoint was probed with a deterministic timeout."
$report += ""
$report += "| Server | Verdict | Detail |"
$report += "|---|---|---|"
$report += $results
$report += ""
$passN = ($results | Where-Object { $_ -match "\| PASS \|" }).Count
$failN = ($results | Where-Object { $_ -match "\| FAIL \|" }).Count
$report += "**PASS: $passN | FAIL: $failN**"

$report | Out-File -FilePath $reportFile -Encoding UTF8
Write-Output "MCP smoke test report: $reportFile"
Write-Output "PASS=$passN FAIL=$failN"