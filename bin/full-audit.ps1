# Full audit script - writes results to a file for reading
. (Join-Path $PSScriptRoot 'lib\bundle-common.ps1')
Initialize-BundlePath
$reportFile = "$env:USERPROFILE\dev\upstream\AUDIT_REPORT.md"
$results = @()

# Per-run id for temp log names. Reusing "audit_mcp_<name>.log" across runs meant a
# leftover process holding the file made the NEXT run's Remove-Item throw (and the
# audit appear to hang). Unique names make a lock impossible to collide with, so the
# audit never depends on being able to delete a file someone else still has open.
$runId = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$script:tmpArtifacts = @()

function Add-Result($category, $item, $verdict, $detail) {
  $script:results += "| $category | $item | $verdict | $detail |"
}

# ============ AUDIT 1: MCP SERVERS ============
Add-Result "Category" "Item" "Verdict" "Detail"
Add-Result "---" "---" "---" "---"

# Check mcp.json validity
# IMPORTANT: a valid-but-EMPTY "servers" object is not a pass. Verified 2026-10-28: this audit
# printed "Valid JSON, 0 servers" and still reported PASS, while ~5 MCP servers sat unconfigured
# for weeks because Phase 5 of the installer had never run on this machine. The daemon probes
# below use a HARDCODED list, so they kept passing (the CLIs run standalone) and could not see
# that nothing was wired into VS Code at all. Cross-check the live config against
# setup\mcp.json.template, which is the single source of truth for what should be configured.
try {
  $mcp = Get-Content "$env:APPDATA\Code\User\mcp.json" -Raw | ConvertFrom-Json
  $serverCount = @($mcp.servers.PSObject.Properties).Count
  $tplPath = Join-Path (Get-BundleRoot $PSScriptRoot) 'setup\mcp.json.template'
  $expected = @()
  if (Test-Path $tplPath) {
    $tpl = Get-Content $tplPath -Raw | ConvertFrom-Json
    $expected = @($tpl.servers.PSObject.Properties.Name)
  }
  if ($serverCount -eq 0) {
    Add-Result "MCP" "mcp.json" "FAIL" "Valid JSON but 0 servers configured (expected $($expected.Count) from mcp.json.template - run Phase 5)"
  } else {
    Add-Result "MCP" "mcp.json" "PASS" "Valid JSON, $serverCount servers"
  }
  foreach ($prop in $mcp.servers.PSObject.Properties) {
    Add-Result "MCP" "$($prop.Name) config" "PASS" "type=$($prop.Value.type) cmd=$($prop.Value.command)"
  }
  if ($expected.Count) {
    $live = @($mcp.servers.PSObject.Properties.Name)
    # Compare on the leaf name so a gallery install (e.g. "microsoft/markitdown") matches the
    # template's plain "markitdown" instead of reading as missing.
    $liveLeaf = $live | ForEach-Object { ($_ -split '/')[-1] }
    $missing = $expected | Where-Object { $liveLeaf -notcontains (($_ -split '/')[-1]) }
    if ($missing.Count) {
      Add-Result "MCP" "bundle servers" "FAIL" "$($missing.Count) of $($expected.Count) not configured: $($missing -join ', ')"
    } else {
      Add-Result "MCP" "bundle servers" "PASS" "all $($expected.Count) template servers configured"
    }
  }
} catch {
  Add-Result "MCP" "mcp.json" "FAIL" $_.Exception.Message
}

# Smoke test each MCP server (start, wait, if running = pass)
#
# IMPORTANT: these commands are launchers. `uvx`/`npx` spawn the real server as a
# CHILD (uvx -> markitdown-mcp, npx -> node -> firecrawl-mcp). Process.Kill() only
# kills cmd.exe, so the actual server survived as an orphan that kept the redirect
# files open -- which is why a later run's Remove-Item threw and the audit wedged,
# and why 19 stale server processes accumulated. Stop-Tree below reaps descendants
# first. Verdicts are also taken from the SERVER'S OWN liveness, not from whether
# stderr happened to contain "error", so a result no longer flips between runs.
function Stop-Tree {
  param([int]$ProcessId)
  $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue
  foreach ($c in $children) { Stop-Tree -ProcessId $c.ProcessId }
  Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

$mcpServers = @(
  @{name="markitdown"; cmd="uvx"; args="markitdown-mcp@latest"; timeout=20},
  @{name="skillspector"; cmd="skillspector"; args="mcp"; timeout=15},
  @{name="firecrawl"; cmd="npx"; args="-y firecrawl-mcp@latest"; timeout=25},
  @{name="scrapling"; cmd="scrapling"; args="mcp"; timeout=25},
  @{name="gbrain"; cmd="gbrain"; args="serve"; timeout=15},
  @{name="graphify"; cmd="graphify-mcp"; args="--transport stdio"; timeout=15}
)

# Detect a dead proxy before probing daemons. A proxy that accepts no TCP connection makes
# every npx/uvx launcher fail with "error sending request" - the server never runs, so the
# probe would report a fault that has nothing to do with the bundle. Verified 2026-11-02:
# markitdown dies in 18s behind a dead proxy and stays up indefinitely without one.
$script:probeProxyOverride = $false
$proxyToTest = if ($env:HTTPS_PROXY) { $env:HTTPS_PROXY } elseif ($env:HTTP_PROXY) { $env:HTTP_PROXY } else { $null }
if ($proxyToTest) {
  try {
    $u = [System.Uri]$proxyToTest
    $tcp = New-Object System.Net.Sockets.TcpClient
    $connected = $tcp.ConnectAsync($u.Host, $u.Port).Wait(1500)
    $tcp.Close()
    if (-not $connected) {
      $script:probeProxyOverride = $true
      Add-Result "MCP" "proxy" "WARN" "'$proxyToTest' is unreachable - daemon probes run with the proxy dropped (environment fault, not a bundle fault)"
    }
  } catch {
    $script:probeProxyOverride = $true
    Add-Result "MCP" "proxy" "WARN" "'$proxyToTest' is unusable ($($_.Exception.Message)) - daemon probes run with the proxy dropped"
  }
}

foreach ($s in $mcpServers) {
  $outFile = Join-Path $env:TEMP "audit_mcp_$($s.name)_$runId.log"
  $errFile = Join-Path $env:TEMP "audit_mcp_$($s.name)_${runId}_err.log"
  $script:tmpArtifacts += $outFile
  $script:tmpArtifacts += $errFile
  Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue

  $fullCmd = if ($s.args) { "$($s.cmd) $($s.args)" } else { "$($s.cmd)" }

  # Start process with timeout using .NET diagnostics
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/c $fullCmd > `"$outFile`" 2>`"$errFile`""
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.EnvironmentVariables["PATH"] = $env:PATH
  $psi.EnvironmentVariables["PYTHONUTF8"] = "1"

  # A stdio MCP server treats stdin EOF as "client went away" and exits immediately.
  # `cmd /c "..."` inherits whatever stdin the audit process has; when the audit is run
  # from a pipeline, a task runner or Copilot's shell - i.e. anything where
  # [Console]::IsInputRedirected is True - that stdin is already at EOF, so every server
  # exited in ~5s with rc=0 and no output, and was graded WARN "exited early".
  # Verified 2026-11-20: `skillspector mcp` with stdin=DEVNULL exits rc=0 in 4.7s, with a
  # blocking stdin it is still alive at 12s; the real JSON-RPC handshake answers in 5.1s.
  # Redirect stdin so the server blocks on an open pipe - never written to, so reads block -
  # exactly as it does in VS Code, whatever the caller's stdin happens to be. That makes the
  # probe deterministic instead of dependent on how the audit itself was launched.
  $psi.RedirectStandardInput = $true

  # A dead proxy in the parent shell makes every npx/uvx launcher die with
  # "error sending request for url (...)" before the server is ever reached. That is an
  # environment fault, not a bundle fault, so drop the proxy for the probe rather than
  # reporting a WARN the reader cannot act on. Only the probe is affected - nothing is
  # written back to the user's environment.
  if ($script:probeProxyOverride) {
    foreach ($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY')) {
      if ($psi.EnvironmentVariables.ContainsKey($k)) { $psi.EnvironmentVariables.Remove($k) | Out-Null }
      $psi.EnvironmentVariables[$k] = ''
    }
  }

  $proc = [System.Diagnostics.Process]::Start($psi)
  $aliveBeforeTimeout = -not $proc.WaitForExit($s.timeout * 1000)

  # Sample the log sizes BEFORE reaping. Stop-Tree kills the real server (e.g. scrapling's
  # python child) mid-write, and anyio then flushes an "Exception Group Traceback" into the
  # already-redirected stderr file. Measuring afterwards therefore reports the audit's own
  # teardown as though it were the server's output - `scrapling` read 6047B on every run while
  # an identical probe without the kill wrote 0B. Verified 2026-11-02.
  $outSize = if (Test-Path $outFile) { (Get-Item $outFile).Length } else { 0 }
  $errSize = if (Test-Path $errFile) { (Get-Item $errFile).Length } else { 0 }
  $errHead = if ($errSize -gt 0) {
    (Get-Content $errFile -EA SilentlyContinue | Where-Object { $_ -match '\S' } | Select-Object -First 1) -replace '\|','/'
  } else { '' }

  # Always reap the whole tree: on timeout it stops the leak, and on a fast exit it
  # cleans up any launcher grandchild that outlived the shell.
  Stop-Tree -ProcessId $proc.Id

  if ($aliveBeforeTimeout) {
    # Server was still up when the timeout fired == it started and stayed up.
    $errNote = if ($errSize -gt 0) { ", err=${errSize}B: $errHead" } else { '' }
    Add-Result "MCP" "$($s.name) daemon" "PASS" "Started OK, still up at $($s.timeout)s (out=${outSize}B$errNote)"
  } elseif ($outSize -gt 0) {
    Add-Result "MCP" "$($s.name) daemon" "PASS" "Exited early with output (out=${outSize}B, err=${errSize}B)"
  } elseif ($errSize -gt 0) {
    # A single-writer daemon that is ALREADY running refuses a second instance. That is a
    # healthy server, not a fault: verified 2026-10-28, `gbrain serve` (PGLite, one writer)
    # exits 1 with "local database is already open ... PID <n>" whenever VS Code already
    # holds the lock, which flipped a PASS into a spurious WARN between runs. Recognize the
    # lock-contention message and treat it as evidence the server is up.
    $errText = if (Test-Path $errFile) { Get-Content $errFile -Raw -ErrorAction SilentlyContinue } else { '' }
    if ($errText -match 'already open|already running|\.gbrain-lock|address already in use|EADDRINUSE') {
      $pidHit = [regex]::Match($errText, 'PID\s+(\d+)')
      $who = if ($pidHit.Success) { "PID $($pidHit.Groups[1].Value)" } else { 'another process' }
      Add-Result "MCP" "$($s.name) daemon" "PASS" "Already running ($who holds the single-writer lock)"
    } elseif ($errText -match 'error sending request|proxy|Could not connect|ECONNREFUSED') {
      $proxyVal = if ($env:HTTPS_PROXY) { $env:HTTPS_PROXY } else { $env:HTTP_PROXY }
      Add-Result "MCP" "$($s.name) daemon" "WARN" "Launcher could not reach the network (dead proxy '$proxyVal') - not a server fault; see $errFile"
    } else {
      $firstErr = (Get-Content $errFile -EA SilentlyContinue | Where-Object { $_ -match '\S' } | Select-Object -First 1) -replace '\|','/'
      Add-Result "MCP" "$($s.name) daemon" "WARN" "Exited early, stderr=${errSize}B: $firstErr (see $errFile)"
    }
  } else {
    Add-Result "MCP" "$($s.name) daemon" "WARN" "Exited early, no output within $($s.timeout)s"
  }
  $proc.Close()
}

# ============ AUDIT 2: CLI TOOLS ============
$clis = @(
  @{name="skillspector"; test="--version"},
  @{name="skills-ref"; test="--version"},
  @{name="specify"; test="--version"},
  @{name="skillopt-eval"; test="--help"},
  @{name="agent-reach"; test="--help"},
  @{name="graphify"; test="--version"},
  @{name="markitdown"; test="--version"},
  @{name="uipro"; test="--version"},
  @{name="firecrawl"; test="--version"},
  @{name="gbrain"; test="--version"}
)

foreach ($c in $clis) {
  $found = (Get-Command $c.name -ErrorAction SilentlyContinue).Source
  if (-not $found) {
    Add-Result "CLI" $c.name "FAIL" "Not on PATH"
    continue
  }
  $logFile = Join-Path $env:TEMP "audit_cli_$($c.name).log"
  cmd /c "$($c.name) $($c.test) > `"$logFile`" 2>&1"
  $exitCode = $LASTEXITCODE
  $output = if (Test-Path $logFile) { (Get-Content $logFile -First 1 -ErrorAction SilentlyContinue) } else { "" }
  if ($exitCode -eq 0 -or $output) {
    $ver = $output.ToString().Substring(0, [Math]::Min(60, $output.ToString().Length))
    Add-Result "CLI" $c.name "PASS" "v: $ver"
  } else {
    Add-Result "CLI" $c.name "WARN" "Exit ${exitCode}, no output"
  }
}

# ============ AUDIT 3: SKILLS SPEC VALIDATION ============
# Hidden directories under ~/.agents/skills are staging/backup folders, not skills. They used
# to be validated as skills, producing a permanent SKILL.md FAIL and MIRROR WARN.
$skillsDir = "$env:USERPROFILE\.agents\skills"
$allSkillDirs = Get-ChildItem $skillsDir -Directory -Force
$skillDirs = $allSkillDirs | Where-Object { -not $_.Name.StartsWith('.') }
$validCount = 0
$advisoryCount = 0
$failCount = 0

foreach ($sd in $skillDirs) {
  $skillPath = $sd.FullName
  $logFile = Join-Path $env:TEMP "audit_skillsref_$($sd.Name).log"
  cmd /c "skills-ref validate `"$skillPath`" > `"$logFile`" 2>&1"
  $exitCode = $LASTEXITCODE
  $output = if (Test-Path $logFile) { Get-Content $logFile -ErrorAction SilentlyContinue } else { @() }
  if ($exitCode -eq 0 -and ($output -join " ") -match "Valid skill") {
    $validCount++
  } elseif ($exitCode -eq 0) {
    $validCount++
  } else {
    $advisoryCount++
    $firstIssue = ($output | Select-Object -First 2) -join " ; "
    if ($firstIssue.Length -gt 80) { $firstIssue = $firstIssue.Substring(0, 80) + "..." }
    Add-Result "SKILLS-REF" $sd.Name "ADVISORY" $firstIssue
  }
}
Add-Result "SKILLS-REF" "Summary" "INFO" "Valid: $validCount, Advisory: $advisoryCount, Fail: $failCount"

# ============ AUDIT 4: SKILL FRONTMATTER + FILE CHECK ============
$missingFrontmatter = @()
$missingSkillMd = @()
foreach ($sd in $skillDirs) {
  $skillFile = Join-Path $sd.FullName "SKILL.md"
  if (-not (Test-Path $skillFile)) {
    $missingSkillMd += $sd.Name
    Add-Result "SKILL-FILE" $sd.Name "FAIL" "SKILL.md missing"
    continue
  }
  $content = Get-Content $skillFile -Raw -ErrorAction SilentlyContinue
  if (-not ($content -match "^---")) {
    Add-Result "SKILL-FILE" $sd.Name "FAIL" "No YAML frontmatter"
  }
  if (-not ($content -match "name:")) {
    Add-Result "SKILL-FILE" $sd.Name "FAIL" "No 'name' field in frontmatter"
  }
  if (-not ($content -match "description:")) {
    Add-Result "SKILL-FILE" $sd.Name "FAIL" "No 'description' field"
  }
}
if ($missingSkillMd.Count -eq 0) {
  Add-Result "SKILL-FILE" "All skills" "PASS" "All $($skillDirs.Count) skills have SKILL.md"
}

# ============ AUDIT 5: CLAUDE CODE MIRROR PARITY ============
$agentsSkills = Get-ChildItem $skillsDir -Directory -Force | Where-Object { -not $_.Name.StartsWith('.') } | Select-Object -ExpandProperty Name
$claudeSkills = Get-ChildItem "$env:USERPROFILE\.claude\skills" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
# VS Code provisions these for the Azure/Entra/Foundry extensions and writes only to
# ~/.agents/skills. They are absent from the Claude mirror by design, so asserting parity over
# them produced a WARN that could never clear - which trains the reader to ignore the WARN row.
#
# The prefix alone is not enough: `airunway-aks-setup` and `python-appservice-deploy` match the
# prefix BUT are real manifest rows that must be mirrored. A name is only extension-exempt when
# it is not a manifest row, otherwise excluding it would mask a genuine mirroring gap.
$extSkillPattern = '^(azure-|entra-|discover-azure|microsoft-foundry|python-appservice-deploy|airunway-aks-setup|appinsights-instrumentation)'
$manifestCsv = Get-BundleRoot $PSScriptRoot
$manifestNames = @()
if ($manifestCsv) {
  $manifestNames = Get-Content (Join-Path $manifestCsv 'setup\skills-list.csv') |
    Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' } |
    ForEach-Object { ($_ -split '\|')[1].Trim() }
}
$mirrorExpected = @($agentsSkills | Where-Object { $_ -notmatch $extSkillPattern -or $manifestNames -contains $_ })
$extSkills = @($agentsSkills | Where-Object { $mirrorExpected -notcontains $_ })
$notMirrored = @($mirrorExpected | Where-Object { $_ -notin $claudeSkills })
$extraInClaude = @($claudeSkills | Where-Object { $_ -notin $agentsSkills })
if ($notMirrored.Count -eq 0) {
  Add-Result "MIRROR" "Parity" "PASS" "All $($mirrorExpected.Count) mirrorable skills present in Claude Code ($($extSkills.Count) extension skills excluded by design)"
} else {
  Add-Result "MIRROR" "Parity" "WARN" "Not mirrored: $($notMirrored -join ', ')"
}
if ($extraInClaude.Count -gt 0) {
  Add-Result "MIRROR" "Extra in Claude" "INFO" "Extra: $($extraInClaude -join ', ')"
}

# ============ AUDIT 6: DISABLED + DOCS + FORKS ============
# Disabled skills
$disabledDir = "$env:USERPROFILE\.agents\skills._disabled"
$disabledSkills = Get-ChildItem $disabledDir -Directory -ErrorAction SilentlyContinue
foreach ($d in $disabledSkills) {
  $hasDisabled = Test-Path (Join-Path $d.FullName "SKILL.md.disabled")
  $hasActive = Test-Path (Join-Path $d.FullName "SKILL.md")
  if ($hasDisabled -and -not $hasActive) {
    Add-Result "DISABLED" $d.Name "PASS" "Properly disabled (SKILL.md.disabled)"
  } else {
    Add-Result "DISABLED" $d.Name "WARN" "hasDisabled=$hasDisabled hasActive=$hasActive"
  }
}

# Governance docs
$docs = @("README.md","CONFLICTS.md","MEMORY_POLICY.md","UPDATE_POLICY.md")
foreach ($d in $docs) {
  $path = "$env:USERPROFILE\.agents\$d"
  if (Test-Path $path) {
    $lines = (Get-Content $path | Measure-Object -Line).Lines
    Add-Result "DOCS" $d "PASS" "$lines lines"
  } else {
    Add-Result "DOCS" $d "FAIL" "Missing"
  }
}
# SCAN_LOG
$scanLog = "$env:USERPROFILE\dev\upstream\SCAN_LOG.md"
if (Test-Path $scanLog) {
  $lines = (Get-Content $scanLog | Measure-Object -Line).Lines
  Add-Result "DOCS" "SCAN_LOG.md" "PASS" "$lines lines"
} else {
  Add-Result "DOCS" "SCAN_LOG.md" "FAIL" "Missing"
}

# Fork mirrors
$forkDir = "$env:USERPROFILE\dev\forks\JZKK720"
$forkCount = (Get-ChildItem $forkDir -Directory -ErrorAction SilentlyContinue).Count
Add-Result "FORKS" "JZKK720 mirrors" "PASS" "$forkCount fork repos cloned"

# Install helper
# Existence alone is not enough: on 2026-10-28 the deployed helper was still the 7,525-byte
# July build while the repo copy was 12,119 bytes with baseline support + atomic staging.
# A stale helper silently skips suppression baselines, so every reviewed skill re-blocks at
# install time and the audit cannot tell. Compare content, not just presence.
$helperPath = "$env:USERPROFILE\dev\bin\install-skill.ps1"
$helperSrc  = Join-Path (Get-BundleRoot $PSScriptRoot) 'setup\install-skill.ps1'
if (-not (Test-Path $helperPath)) {
  Add-Result "HELPER" "install-skill.ps1" "FAIL" "Missing"
} elseif ((Test-Path $helperSrc) -and
          ((Get-FileHash $helperPath).Hash -ne (Get-FileHash $helperSrc).Hash)) {
  Add-Result "HELPER" "install-skill.ps1" "FAIL" "Stale - deployed copy differs from setup/install-skill.ps1 (re-run Phase 1b)"
} else {
  $lines = (Get-Content $helperPath | Measure-Object -Line).Lines
  Add-Result "HELPER" "install-skill.ps1" "PASS" "$lines lines (matches repo)"
}

# Suppression baselines deployed next to the helper
$baselineSrcDir = Join-Path (Get-BundleRoot $PSScriptRoot) 'baselines'
$baselineDstDir = "$env:USERPROFILE\dev\baselines"
if (Test-Path $baselineSrcDir) {
  $srcCount = (Get-ChildItem $baselineSrcDir -Filter '*.baseline.yaml' -File).Count
  $dstCount = if (Test-Path $baselineDstDir) {
    (Get-ChildItem $baselineDstDir -Filter '*.baseline.yaml' -File).Count
  } else { 0 }
  if ($dstCount -lt $srcCount) {
    Add-Result "BASELINES" "deployed" "FAIL" "$dstCount of $srcCount deployed to ~/dev/baselines"
  } else {
    Add-Result "BASELINES" "deployed" "PASS" "$dstCount baseline files"
  }
}

# ============ AUDIT 7: SKILLSPECTOR RE-SCAN ============
# Scan 3 sample skills to verify the scanner is functional
$sampleSkills = @("hallmark", "ponytail", "improve")
$repoRoot = Get-BundleRoot $PSScriptRoot
foreach ($s in $sampleSkills) {
  $skillPath = "$skillsDir\$s"
  $logFile = Join-Path $env:TEMP "audit_skillspector_$s.log"
  # Apply the committed suppression baseline, exactly as install-skill.ps1 does; without it a
  # reviewed skill re-reports do_not_install and shows a false FAIL here.
  $baseline = Resolve-SkillBaseline $s $repoRoot
  if ($baseline) {
    cmd /c "skillspector scan `"$skillPath`" --no-llm --baseline `"$baseline`" > `"$logFile`" 2>&1"
  } else {
    cmd /c "skillspector scan `"$skillPath`" --no-llm > `"$logFile`" 2>&1"
  }
  $exitCode = $LASTEXITCODE
  if ($exitCode -eq 0) {
    Add-Result "SKILLSPECTOR" $s "PASS" "Scan exit 0 (safe)$(if ($baseline) { ' (baseline)' })"
  } elseif ($exitCode -eq 1) {
    $detail = if ($baseline) { "do_not_install (baseline stale/incomplete - re-baseline)" } else { "do_not_install (exit 1)" }
    Add-Result "SKILLSPECTOR" $s "FAIL" $detail
  } else {
    Add-Result "SKILLSPECTOR" $s "WARN" "Scan exit $exitCode"
  }
}

# ============ AUDIT 8: SKILLEVALUATOR ADVISORY (never blocking) ============
# SkillSpector answers "is it safe". SkillEvaluator answers "is it good" and "will the harness
# load it" - questions the gate does not ask. It is ADVISORY by design: `tier1` reports
# "Security Scan: INCOMPLETE" on skills SkillSpector passes cleanly, so it cannot be a gate.
# Quality scoring is keyless, so it always runs when the CLI is present. Similarity (Tier 2)
# needs an embedding provider key and Tier 3 needs Docker + a model, so neither is attempted.
if (Get-Command skillevaluator -ErrorAction SilentlyContinue) {
  $seOut = "$env:USERPROFILE\dev\upstream\skillevaluator"
  if (-not (Test-Path $seOut)) { New-Item -ItemType Directory -Force -Path $seOut | Out-Null }
  $gradeRows = @()
  $graded = 0; $avg = 0
  foreach ($sd in $skillDirs) {
    $safe = ($sd.Name -replace '[^A-Za-z0-9_.-]', '_')
    $skillOut = Join-Path $seOut $safe
    New-Item -ItemType Directory -Force -Path $skillOut | Out-Null
    & skillevaluator quality-check $sd.FullName -o $skillOut -r json > $null 2>&1
    $qj = Join-Path $skillOut 'skillevaluator-quality.json'
    if (Test-Path $qj) {
      try {
        $d = Get-Content $qj -Raw | ConvertFrom-Json
        $qs = $d.quality_summary
        if (-not $qs -and $d.results -and $d.results.Count -gt 0) { $qs = $d.results[0].quality }
        if ($qs) { $gradeRows += [pscustomobject]@{ Name = $sd.Name; Grade = [string]$qs.grade; Score = [double]$qs.overall_score } }
      } catch { }
    }
  }
  $graded = $gradeRows.Count
  if ($graded -gt 0) {
    $avg = ($gradeRows | Measure-Object -Property Score -Average).Average
    $dist = ($gradeRows | Group-Object Grade | Sort-Object Name | ForEach-Object { "$($_.Name):$($_.Count)" }) -join ' '
    Add-Result "SKEVAL-ADVISORY" "quality" "INFO" "$graded skills scored, avg $([math]::Round($avg,1))/100 ($dist)"
    # A skill graded F is a real authoring problem, but it is not a security or load failure.
    $fails = @($gradeRows | Where-Object { $_.Grade -eq 'F' })
    if ($fails.Count -gt 0) {
      Add-Result "SKEVAL-ADVISORY" "grade F" "INFO" "$($fails.Count) skill(s) graded F: $(($fails | ForEach-Object { $_.Name }) -join ', ')"
    }
  } else {
    Add-Result "SKEVAL-ADVISORY" "quality" "INFO" "no quality reports produced"
  }

  # Tier 2 (duplicate detection) needs an embedding provider. Ollama is checked because it is
  # local and keyless; a missing provider is reported as INFO, never as a FAIL, because the
  # collection being "unchecked" is not the same as it being clean.
  $ollamaUp = $false
  try { $null = Invoke-RestMethod 'http://localhost:11434/api/tags' -TimeoutSec 4; $ollamaUp = $true } catch { }
  if ($ollamaUp) {
    # Reaching Ollama is NOT enough: skillspector's embedding client only runs when the provider
    # env vars are set. Without them the run reports `incomplete` and zero findings, which a
    # naive parser reads as "no duplicates" — a false clean. Set them for this call only.
    $savedEnv = @{}
    foreach ($v in @('SKILL_EVAL_EMBEDDING_PROVIDER','SKILL_EVAL_LLM_API_KEY','SKILL_EVAL_EMBEDDING_BASE_URL','SKILL_EVAL_LLM_BASE_URL')) {
      $savedEnv[$v] = [Environment]::GetEnvironmentVariable($v)
    }
    $env:SKILL_EVAL_EMBEDDING_PROVIDER = 'openai-compatible'
    $env:SKILL_EVAL_LLM_API_KEY        = 'ollama-local'
    $env:SKILL_EVAL_EMBEDDING_BASE_URL = 'http://localhost:11434/v1'
    $env:SKILL_EVAL_LLM_BASE_URL       = 'http://localhost:11434/v1'

    $t2Out = "$env:USERPROFILE\dev\upstream\skillevaluator-tier2"
    if (-not (Test-Path $t2Out)) { New-Item -ItemType Directory -Force -Path $t2Out | Out-Null }
    Remove-Item (Join-Path $t2Out 'skillevaluator-similarity.json') -Force -ErrorAction SilentlyContinue
    & skillevaluator similarity-check $skillsDir --type skill --threshold 0.85 `
        --model 'nomic-embed-text:latest' -o $t2Out -r json > $null 2>&1
    $t2j = Join-Path $t2Out 'skillevaluator-similarity.json'
    if (Test-Path $t2j) {
      try {
        $d2 = Get-Content $t2j -Raw | ConvertFrom-Json
        # NEVER report a count from an incomplete/failed run: that is a false clean.
        if ($d2.overall_status -ne 'passed' -and $d2.overall_status -ne 'failed') {
          $why = ''
          if ($d2.results -and $d2.results.Count -gt 0 -and $d2.results[0].legacy) {
            $why = (@($d2.results[0].legacy.errors) | ForEach-Object { ($_ | Out-String).Trim() } | Select-Object -First 1)
          }
          $why = ($why -replace '\s+', ' ')
          if ($why.Length -gt 150) { $why = $why.Substring(0, 150) + '...' }
          Add-Result "SKEVAL-ADVISORY" "tier2 duplicates" "INFO" "run $($d2.overall_status) - no trustworthy count ($why)"
        } else {
          $sev2 = $d2.finding_counts.unique_by_severity
          $pairs2 = @()
          if ($d2.results -and $d2.results.Count -gt 0 -and $d2.results[0].legacy) {
            $pairs2 = @($d2.results[0].legacy.errors | ForEach-Object { ($_ | Out-String).Trim() } | Where-Object { $_ -match 'SIMILARITY' })
          }
          Add-Result "SKEVAL-ADVISORY" "tier2 duplicates" "INFO" "$($pairs2.Count) pair(s) above 0.85 (critical=$($sev2.critical) high=$($sev2.high)); see docs/plans/2026-11-20-skill-duplicates.md"
          $crit = @($pairs2 | Where-Object { $_ -match 'CRITICAL' })
          foreach ($c in $crit) { Add-Result "SKEVAL-ADVISORY" "exact duplicate" "INFO" $c }
        }
      } catch {
        Add-Result "SKEVAL-ADVISORY" "tier2 duplicates" "INFO" "report unreadable: $($_.Exception.Message)"
      }
    } else {
      Add-Result "SKEVAL-ADVISORY" "tier2 duplicates" "INFO" "similarity run produced no report"
    }

    foreach ($v in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($v, $savedEnv[$v]) }
  } else {
    Add-Result "SKEVAL-ADVISORY" "tier2 duplicates" "INFO" "skipped - no embedding provider (start Ollama, or set SKILL_EVAL_EMBEDDING_PROVIDER + SKILL_EVAL_LLM_API_KEY)"
  }
} else {
  Add-Result "SKEVAL-ADVISORY" "quality" "INFO" "skillevaluator not on PATH (optional advisory; install with: uv tool install skillevaluator)"
}

# ============ WRITE REPORT ============
$report = @()
$report += "# Full Audit Report"
$report += ""
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += ""
$report += "## Results Matrix"
$report += ""
$report += "| Category | Item | Verdict | Detail |"
$report += "|---|---|---|---|"
$report += $results
$report += ""
$report += "## Summary Counts"
$report += ""
$passCount = ($results | Where-Object { $_ -match "\| PASS \|" }).Count
$failCount = ($results | Where-Object { $_ -match "\| FAIL \|" }).Count
# WARN and ADVISORY are reported SEPARATELY. The old code counted them as one union
# ("WARN/ADVISORY: N"), which hid that the number was ~all advisory skills-ref
# results plus a single real WARN, and made it read as unexplained flakiness.
$warnCount = ($results | Where-Object { $_ -match "\| WARN \|" }).Count
$advisoryRowCount = ($results | Where-Object { $_ -match "\| ADVISORY \|" }).Count
$report += "- PASS: $passCount"
$report += "- FAIL: $failCount"
$report += "- WARN: $warnCount"
$report += "- ADVISORY: $advisoryRowCount"
$report += ""
$report += "## Skill Count"
$report += "- Total in ~/.agents/skills/: $($skillDirs.Count)"
$report += "- Azure: $((($skillDirs | Where-Object { $_.Name -match '^(azure|entra|microsoft|python-app|airunway|appinsights)' })).Count)"
$report += "- New: $((($skillDirs | Where-Object { $_.Name -notmatch '^(azure|entra|microsoft|python-app|airunway|appinsights)' })).Count)"
$report += "- Disabled: $($disabledSkills.Count)"
$report += "- Claude Code mirror: $($claudeSkills.Count)"
$report += "- Fork mirrors: $forkCount"

$report | Out-File -FilePath $reportFile -Encoding UTF8
Write-Output "Report written to $reportFile"
Write-Output "PASS: $passCount | FAIL: $failCount | WARN: $warnCount | ADVISORY: $advisoryRowCount"

# Best-effort cleanup of this run's temp artifacts. Non-fatal by design: with the
# process tree reaped above nothing should still hold these, but a locked leftover
# must never be able to fail the audit.
$script:tmpArtifacts += (Get-ChildItem $env:TEMP -Filter "audit_skillsref_*.log" -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName)
$script:tmpArtifacts += (Get-ChildItem $env:TEMP -Filter "audit_cli_*.log" -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName)
$script:tmpArtifacts += (Get-ChildItem $env:TEMP -Filter "audit_skillspector_*.log" -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName)
Remove-Item $script:tmpArtifacts -Force -ErrorAction SilentlyContinue
