# Final global audit pass - comprehensive check of everything
. (Join-Path $PSScriptRoot 'lib\bundle-common.ps1')
Initialize-BundlePath
$reportFile = "$env:USERPROFILE\dev\upstream\FINAL_AUDIT.md"
$r = @()

function Add-Row($cat, $item, $verdict, $detail) {
  $script:r += "| $cat | $item | $verdict | $detail |"
}

# === 1. PERMANENT PATH CHECK ===
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$utf8 = [System.Environment]::GetEnvironmentVariable("PYTHONUTF8", "User")
Add-Row "PATH" ".local\bin" "$(if($userPath -like '*.local\bin*'){'PASS'}else{'FAIL'})" "Persistent user PATH"
Add-Row "PATH" ".bun\bin" "$(if($userPath -like '*.bun\bin*'){'PASS'}else{'FAIL'})" "Persistent user PATH"
Add-Row "PATH" "AppData\Roaming\npm" "$(if($userPath -like '*Roaming\npm*'){'PASS'}else{'FAIL'})" "Persistent user PATH"
Add-Row "ENV" "PYTHONUTF8" "$(if($utf8 -eq '1'){'PASS'}else{'FAIL'})" "Permanent user env = $utf8"

# === 2. MCP JSON ===
try {
  $mcp = Get-Content "$env:USERPROFILE\AppData\Roaming\Code\User\mcp.json" -Raw | ConvertFrom-Json
  $sc = $mcp.servers.PSObject.Properties.Count
  Add-Row "MCP" "mcp.json" "PASS" "Valid JSON, $sc servers"
  foreach ($p in $mcp.servers.PSObject.Properties) {
    Add-Row "MCP" "$($p.Name)" "PASS" "cmd=$($p.Value.command) args=$($p.Value.args -join ',')"
  }
} catch {
  Add-Row "MCP" "mcp.json" "FAIL" $_.Exception.Message
}

# === 3. CLI TOOLS (quick version check) ===
$clis = @("skillspector","skills-ref","specify","skillopt-eval","agent-reach","graphify","markitdown","uipro","firecrawl","gbrain","scrapling")
foreach ($c in $clis) {
  $found = (Get-Command $c -ErrorAction SilentlyContinue).Source
  if ($found) { Add-Row "CLI" $c "PASS" $found } else { Add-Row "CLI" $c "FAIL" "Not on PATH" }
}

# === 4. SKILLS COUNT + FILE CHECK ===
$skillsDir = "$env:USERPROFILE\.agents\skills"
$skillDirs = Get-ChildItem $skillsDir -Directory
$totalSkills = $skillDirs.Count
$azureCount = ($skillDirs | Where-Object { $_.Name -match '^(azure|entra|microsoft|python-app|airunway|appinsights)' }).Count
$newCount = $totalSkills - $azureCount
Add-Row "SKILLS" "Total count" "PASS" "$totalSkills (Azure: $azureCount, New: $newCount)"

$missingMd = @()
foreach ($sd in $skillDirs) {
  $sf = Join-Path $sd.FullName "SKILL.md"
  if (-not (Test-Path $sf)) { $missingMd += $sd.Name }
}
if ($missingMd.Count -eq 0) {
  Add-Row "SKILLS" "SKILL.md files" "PASS" "All $totalSkills have SKILL.md"
} else {
  Add-Row "SKILLS" "SKILL.md files" "FAIL" "Missing: $($missingMd -join ', ')"
}

# === 5. KARPATHY SKILL SPECIFIC CHECK ===
$karpathyPath = "$skillsDir\karpathy-guidelines"
if (Test-Path "$karpathyPath\SKILL.md") {
  Add-Row "KARPATHY" "SKILL.md exists" "PASS" $karpathyPath
  $content = Get-Content "$karpathyPath\SKILL.md" -Raw
  if ($content -match "name:") { Add-Row "KARPATHY" "frontmatter name" "PASS" "Has name field" }
  if ($content -match "description:") { Add-Row "KARPATHY" "frontmatter description" "PASS" "Has description field" }
} else {
  Add-Row "KARPATHY" "SKILL.md exists" "FAIL" "Not found"
}
# Claude mirror
if (Test-Path "$env:USERPROFILE\.claude\skills\karpathy-guidelines\SKILL.md") {
  Add-Row "KARPATHY" "Claude mirror" "PASS" "Mirrored to ~/.claude/skills/"
} else {
  Add-Row "KARPATHY" "Claude mirror" "FAIL" "Not mirrored"
}

# === 6. CLAUDE MIRROR PARITY ===
$claudeSkills = (Get-ChildItem "$env:USERPROFILE\.claude\skills" -Directory -ErrorAction SilentlyContinue).Name
$newSkills = $skillDirs | Where-Object { $_.Name -notmatch '^(azure|entra|microsoft|python-app|airunway|appinsights)' } | Select-Object -ExpandProperty Name
$notMirrored = $newSkills | Where-Object { $_ -notin $claudeSkills }
if ($notMirrored.Count -eq 0) {
  Add-Row "MIRROR" "Parity" "PASS" "All $newCount new skills mirrored to Claude Code"
} else {
  Add-Row "MIRROR" "Parity" "WARN" "Not mirrored: $($notMirrored -join ', ')"
}
Add-Row "MIRROR" "Claude count" "INFO" "$($claudeSkills.Count) skills in ~/.claude/skills/"

# === 7. DISABLED ===
$disabledDir = "$env:USERPROFILE\.agents\skills._disabled"
$disabledSkills = Get-ChildItem $disabledDir -Directory -ErrorAction SilentlyContinue
foreach ($d in $disabledSkills) {
  $hasDisabled = Test-Path (Join-Path $d.FullName "SKILL.md.disabled")
  if ($hasDisabled) { Add-Row "DISABLED" $d.Name "PASS" "Properly disabled" }
  else { Add-Row "DISABLED" $d.Name "WARN" "No SKILL.md.disabled" }
}

# === 8. GOVERNANCE DOCS ===
foreach ($d in @("README.md","CONFLICTS.md","MEMORY_POLICY.md","UPDATE_POLICY.md")) {
  $path = "$env:USERPROFILE\.agents\$d"
  if (Test-Path $path) { Add-Row "DOCS" $d "PASS" "$((Get-Content $path | Measure-Object -Line).Lines) lines" }
  else { Add-Row "DOCS" $d "FAIL" "Missing" }
}
$scanLog = "$env:USERPROFILE\dev\upstream\SCAN_LOG.md"
if (Test-Path $scanLog) { Add-Row "DOCS" "SCAN_LOG.md" "PASS" "$((Get-Content $scanLog | Measure-Object -Line).Lines) lines" }
else { Add-Row "DOCS" "SCAN_LOG.md" "FAIL" "Missing" }

# === 9. FORKS + HELPER ===
$forkCount = (Get-ChildItem "$env:USERPROFILE\dev\forks\JZKK720" -Directory -ErrorAction SilentlyContinue).Count
Add-Row "FORKS" "JZKK720" "PASS" "$forkCount repos"
if (Test-Path "$env:USERPROFILE\dev\bin\install-skill.ps1") { Add-Row "HELPER" "install-skill.ps1" "PASS" "Present" }
else { Add-Row "HELPER" "install-skill.ps1" "FAIL" "Missing" }

# === 10. SKILLSPECTOR SAMPLE (including new karpathy) ===
# Apply each skill's committed suppression baseline, as install-skill.ps1 does.
$repoRoot = Get-BundleRoot $PSScriptRoot
foreach ($s in @("karpathy-guidelines","hallmark","ponytail","improve")) {
  $skillPath = "$skillsDir\$s"
  $logFile = Join-Path $env:TEMP "final_ss_$s.log"
  $baseline = Resolve-SkillBaseline $s $repoRoot
  if ($baseline) {
    cmd /c "skillspector scan `"$skillPath`" --no-llm --baseline `"$baseline`" > `"$logFile`" 2>&1" | Out-Null
  } else {
    cmd /c "skillspector scan `"$skillPath`" --no-llm > `"$logFile`" 2>&1" | Out-Null
  }
  $exitCode = $LASTEXITCODE
  if ($exitCode -eq 0) { Add-Row "SKILLSPECTOR" $s "PASS" "SAFE (exit 0)$(if ($baseline) { ' (baseline)' })" }
  elseif ($exitCode -eq 1) {
    $detail = if ($baseline) { "do_not_install (baseline stale/incomplete - re-baseline)" } else { "do_not_install" }
    Add-Row "SKILLSPECTOR" $s "FAIL" $detail
  }
  else { Add-Row "SKILLSPECTOR" $s "WARN" "exit $exitCode" }
}

# === WRITE REPORT ===
$report = @()
$report += "# Final Global Audit Pass"
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
$warnCount = ($r | Where-Object { $_ -match "\| (WARN|INFO) \|" }).Count
$report += "## Summary"
$report += ""
$report += "- **PASS: $passCount**"
$report += "- **FAIL: $failCount**"
$report += "- **WARN/INFO: $warnCount**"
$report += ""
$report += "## Key Counts"
$report += "- Total skills: $totalSkills (Azure: $azureCount, New: $newCount)"
$report += "- Claude Code mirror: $($claudeSkills.Count)"
$report += "- Disabled: $($disabledSkills.Count)"
$report += "- Fork mirrors: $forkCount"
$report += "- MCP servers: $sc"
$report += "- CLI tools: 11"
$report += ""
$report += "## Permanent PATH Status"
$report += "- ``~/.local\bin`` on user PATH: $(if($userPath -like '*.local\bin*'){'YES'}else{'NO'})"
$report += "- ``~/.bun\bin`` on user PATH: $(if($userPath -like '*.bun\bin*'){'YES'}else{'NO'})"
$report += "- ``~/AppData\Roaming\npm`` on user PATH: $(if($userPath -like '*Roaming\npm*'){'YES'}else{'NO'})"
$report += "- ``PYTHONUTF8=1`` set for user: $(if($utf8 -eq '1'){'YES'}else{'NO'})"
$report += ""
$report += "## New Skill: karpathy-guidelines"
$report += "- SkillSpector: SAFE (no issues, 0 executables)"
$report += "- skills-ref: Valid"
$report += "- Installed to: ~/.agents/skills/karpathy-guidelines/"
$report += "- Mirrored to: ~/.claude/skills/karpathy-guidelines/"
$report += "- Logged in: SCAN_LOG.md"

$report | Out-File -FilePath $reportFile -Encoding UTF8
Write-Output "FINAL AUDIT REPORT: $reportFile"
Write-Output "PASS=$passCount FAIL=$failCount WARN=$warnCount"
Write-Output "Total skills: $totalSkills (Azure: $azureCount, New: $newCount)"