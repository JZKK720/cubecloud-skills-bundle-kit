# Fast audit - no MCP daemon tests (those block). Checks everything else.
$env:PATH = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.bun\bin;$env:APPDATA\npm;$env:PATH"
$env:PYTHONUTF8 = "1"
$reportFile = "$env:USERPROFILE\dev\upstream\AUDIT_REPORT.md"
$r = @()

function Add-Row($cat, $item, $verdict, $detail) {
  $script:r += "| $cat | $item | $verdict | $detail |"
}

# === MCP JSON ===
try {
  $mcp = Get-Content "$env:USERPROFILE\AppData\Roaming\Code\User\mcp.json" -Raw | ConvertFrom-Json
  $sc = $mcp.servers.PSObject.Properties.Count
  Add-Row "MCP" "mcp.json" "PASS" "Valid JSON, $sc servers"
  foreach ($p in $mcp.servers.PSObject.Properties) {
    Add-Row "MCP" "$($p.Name)" "PASS" "type=$($p.Value.type) cmd=$($p.Value.command) args=$($p.Value.args -join ',')"
  }
} catch {
  Add-Row "MCP" "mcp.json" "FAIL" $_.Exception.Message
}

# === CLI TOOLS ===
$clis = @("skillspector","skills-ref","specify","skillopt-eval","agent-reach","graphify","markitdown","uipro","firecrawl","gbrain")
foreach ($c in $clis) {
  $found = (Get-Command $c -ErrorAction SilentlyContinue).Source
  if ($found) {
    $logFile = Join-Path $env:TEMP "audit_cli_$c.log"
    cmd /c "$c --version > `"$logFile`" 2>&1" | Out-Null
    $out = if (Test-Path $logFile) { (Get-Content $logFile -First 1 -ErrorAction SilentlyContinue) } else { "" }
    if ($out) { Add-Row "CLI" $c "PASS" $out } else { Add-Row "CLI" $c "PASS" "On PATH (version check returned empty)" }
  } else {
    Add-Row "CLI" $c "FAIL" "Not on PATH"
  }
}

# === SKILLS SPEC VALIDATION (skills-ref) ===
$skillsDir = "$env:USERPROFILE\.agents\skills"
$skillDirs = Get-ChildItem $skillsDir -Directory
$validN = 0; $advN = 0
$advList = @()
foreach ($sd in $skillDirs) {
  $logFile = Join-Path $env:TEMP "audit_sr_$($sd.Name).log"
  cmd /c "skills-ref validate `"$($sd.FullName)`" > `"$logFile`" 2>&1" | Out-Null
  $exitCode = $LASTEXITCODE
  $out = if (Test-Path $logFile) { Get-Content $logFile -ErrorAction SilentlyContinue } else { @() }
  if ($exitCode -eq 0 -and ($out -join " ") -match "Valid skill") {
    $validN++
  } else {
    $advN++
    $firstIssue = ($out | Select-Object -First 1) -replace "Validation failed for.*:", ""
    $advList += "$($sd.Name): $($firstIssue.Trim())"
  }
}
Add-Row "SKILLS-REF" "Summary" "INFO" "Valid: $validN, Advisory: $advN (out of $($skillDirs.Count))"
if ($advN -gt 0 -and $advN -le 10) {
  foreach ($a in $advList) { Add-Row "SKILLS-REF" $a.Split(':')[0] "ADVISORY" ($a.Split(':',2)[1].Trim()) }
}

# === SKILL FILE CHECK ===
$missingMd = @(); $missingFm = @(); $missingName = @(); $missingDesc = @()
foreach ($sd in $skillDirs) {
  $sf = Join-Path $sd.FullName "SKILL.md"
  if (-not (Test-Path $sf)) { $missingMd += $sd.Name; continue }
  $content = Get-Content $sf -Raw -ErrorAction SilentlyContinue
  if (-not ($content -match "^---")) { $missingFm += $sd.Name }
  if (-not ($content -match "name:")) { $missingName += $sd.Name }
  if (-not ($content -match "description:")) { $missingDesc += $sd.Name }
}
if ($missingMd.Count -eq 0) { Add-Row "SKILL-FILE" "SKILL.md" "PASS" "All $($skillDirs.Count) skills have SKILL.md" }
else { Add-Row "SKILL-FILE" "SKILL.md" "FAIL" "Missing: $($missingMd -join ', ')" }
if ($missingFm.Count -eq 0) { Add-Row "SKILL-FILE" "Frontmatter" "PASS" "All have YAML frontmatter" }
else { Add-Row "SKILL-FILE" "Frontmatter" "FAIL" "Missing: $($missingFm -join ', ')" }
if ($missingName.Count -eq 0) { Add-Row "SKILL-FILE" "name field" "PASS" "All have 'name:' field" }
else { Add-Row "SKILL-FILE" "name field" "FAIL" "Missing: $($missingName -join ', ')" }
if ($missingDesc.Count -eq 0) { Add-Row "SKILL-FILE" "description field" "PASS" "All have 'description:' field" }
else { Add-Row "SKILL-FILE" "description field" "FAIL" "Missing: $($missingDesc -join ', ')" }

# === CLAUDE MIRROR PARITY ===
$agentsSkills = $skillDirs.Name
$claudeSkills = (Get-ChildItem "$env:USERPROFILE\.claude\skills" -Directory -ErrorAction SilentlyContinue).Name
$notMirrored = $agentsSkills | Where-Object { $_ -notin $claudeSkills }
if ($notMirrored.Count -eq 0) {
  Add-Row "MIRROR" "Parity" "PASS" "All $($agentsSkills.Count) skills mirrored to Claude Code"
} else {
  Add-Row "MIRROR" "Parity" "WARN" "Not mirrored: $($notMirrored -join ', ')"
}

# === DISABLED SKILLS ===
$disabledDir = "$env:USERPROFILE\.agents\skills._disabled"
$disabledSkills = Get-ChildItem $disabledDir -Directory -ErrorAction SilentlyContinue
foreach ($d in $disabledSkills) {
  $hasDisabled = Test-Path (Join-Path $d.FullName "SKILL.md.disabled")
  $hasActive = Test-Path (Join-Path $d.FullName "SKILL.md")
  if ($hasDisabled -and -not $hasActive) {
    Add-Row "DISABLED" $d.Name "PASS" "Properly disabled"
  } else {
    Add-Row "DISABLED" $d.Name "WARN" "hasDisabled=$hasDisabled hasActive=$hasActive"
  }
}

# === GOVERNANCE DOCS ===
foreach ($d in @("README.md","CONFLICTS.md","MEMORY_POLICY.md","UPDATE_POLICY.md")) {
  $path = "$env:USERPROFILE\.agents\$d"
  if (Test-Path $path) {
    $lines = (Get-Content $path | Measure-Object -Line).Lines
    Add-Row "DOCS" $d "PASS" "$lines lines"
  } else {
    Add-Row "DOCS" $d "FAIL" "Missing"
  }
}
$scanLog = "$env:USERPROFILE\dev\upstream\SCAN_LOG.md"
if (Test-Path $scanLog) {
  $lines = (Get-Content $scanLog | Measure-Object -Line).Lines
  Add-Row "DOCS" "SCAN_LOG.md" "PASS" "$lines lines"
} else {
  Add-Row "DOCS" "SCAN_LOG.md" "FAIL" "Missing"
}

# === FORKS + HELPER ===
$forkCount = (Get-ChildItem "$env:USERPROFILE\dev\forks\JZKK720" -Directory -ErrorAction SilentlyContinue).Count
Add-Row "FORKS" "JZKK720 mirrors" "PASS" "$forkCount repos"
$helperPath = "$env:USERPROFILE\dev\bin\install-skill.ps1"
if (Test-Path $helperPath) {
  $lines = (Get-Content $helperPath | Measure-Object -Line).Lines
  Add-Row "HELPER" "install-skill.ps1" "PASS" "$lines lines"
} else {
  Add-Row "HELPER" "install-skill.ps1" "FAIL" "Missing"
}

# === SKILLSPECTOR SAMPLE SCAN ===
foreach ($s in @("hallmark","ponytail","improve")) {
  $skillPath = "$skillsDir\$s"
  $logFile = Join-Path $env:TEMP "audit_ss_$s.log"
  cmd /c "skillspector scan `"$skillPath`" --no-llm > `"$logFile`" 2>&1" | Out-Null
  $exitCode = $LASTEXITCODE
  if ($exitCode -eq 0) { Add-Row "SKILLSPECTOR" $s "PASS" "Scan exit 0 (safe)" }
  elseif ($exitCode -eq 1) { Add-Row "SKILLSPECTOR" $s "FAIL" "do_not_install" }
  else { Add-Row "SKILLSPECTOR" $s "WARN" "exit $exitCode" }
}

# === WRITE REPORT ===
$report = @()
$report += "# Full Audit Report"
$report += ""
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += ""
$report += "## Results Matrix"
$report += ""
$report += "| Category | Item | Verdict | Detail |"
$report += "|---|---|---|---|"
$report += $r
$report += ""
$passCount = ($r | Where-Object { $_ -match "\| PASS \|" }).Count
$failCount = ($r | Where-Object { $_ -match "\| FAIL \|" }).Count
$warnCount = ($r | Where-Object { $_ -match "\| (WARN|ADVISORY|INFO) \|" }).Count
$report += "## Summary"
$report += ""
$report += "- **PASS: $passCount**"
$report += "- **FAIL: $failCount**"
$report += "- **WARN/ADVISORY/INFO: $warnCount**"
$report += ""
$azureCount = ($skillDirs | Where-Object { $_.Name -match '^(azure|entra|microsoft|python-app|airunway|appinsights)' }).Count
$newCount = $skillDirs.Count - $azureCount
$report += "## Counts"
$report += "- Total skills in ~/.agents/skills/: $($skillDirs.Count) (Azure: $azureCount, New: $newCount)"
$report += "- Disabled: $($disabledSkills.Count)"
$report += "- Claude Code mirror: $($claudeSkills.Count)"
$report += "- Fork mirrors: $forkCount"
$report += ""
$report += "## MCP Daemon Notes"
$report += "MCP daemon startup tests are not included in this automated audit because they block the terminal."
$report += "To manually test: reload VS Code window, then use #mention in Copilot Chat to invoke each MCP tool."
$report += "MCP servers registered: $($mcp.servers.PSObject.Properties.Name -join ', ')"

$report | Out-File -FilePath $reportFile -Encoding UTF8
Write-Output "REPORT WRITTEN: $reportFile"
Write-Output "PASS=$passCount FAIL=$failCount WARN=$warnCount"
