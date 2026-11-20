$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\bundle-common.ps1')
Initialize-BundlePath
$script:failed = 0

Write-Host '=== CLI CHECK (21) ==='
# This list must match the "CLIs" row in README.md. It previously stopped at 18 and
# omitted `rea` and `git-wt`, so a missing REA CLI could never be detected while the
# README still advertised it on PATH. `skillevaluator` is the optional advisory
# evaluator (quality/harness/overlap); `skillspector` stays the only blocking gate.
$tools = @(
  'skillspector','skills-ref','specify','skillopt-eval','agent-reach','graphify',
  'markitdown','scrapling','uipro','firecrawl','gbrain','headroom',
  'witr','semantica','loop','watch-skill','wigolo','ocr','rea','git-wt',
  'skillevaluator'
)
$missing = @()
foreach ($t in $tools) {
  $cmd = Get-Command $t -ErrorAction SilentlyContinue
  if ($cmd) {
    Write-Host "PASS $t -> $($cmd.Source)"
  } else {
    Write-Host "MISS $t"
    $missing += $t
  }
}
if ($missing.Count -gt 0) {
  Write-Host "FAIL $($missing.Count) of $($tools.Count) CLIs missing: $($missing -join ', ')"
  $script:failed = 1
}

# `rea-agents` (the rea MCP server) refuses to start below Node 22.x>=22.23.4, 24.x>=24.22.1 or
# 26.12.1+. On Windows the Machine PATH entry (C:\Program Files\nodejs) precedes the User PATH, so
# a user-scoped newer Node can be shadowed. `setup/mcp.json.template` used to pin an explicit PATH
# for the rea server to work around that; it no longer does, because the machine-wide Node was
# raised to 26.13.1 on 2026-11-20. Both shapes are still supported: if a pin reappears, the check
# probes the pinned Node, otherwise it probes whatever `node` the server will actually see.
function Test-NodeFloor([string]$versionText) {
  $v = $versionText -replace '^v', ''
  $parts = ($v -split '\.') | ForEach-Object { [int]($_ -replace '\D', '') }
  $major = if ($parts.Count -ge 1) { $parts[0] } else { 0 }
  $minor = if ($parts.Count -ge 2) { $parts[1] } else { 0 }
  $patch = if ($parts.Count -ge 3) { $parts[2] } else { 0 }
  if ($major -gt 26) { return $true }
  if ($major -eq 26) { return ($minor -gt 12 -or ($minor -eq 12 -and $patch -ge 1)) }
  if ($major -eq 24) { return ($minor -gt 22 -or ($minor -eq 22 -and $patch -ge 1)) }
  if ($major -eq 22) { return ($minor -gt 23 -or ($minor -eq 23 -and $patch -ge 4)) }
  return $false
}

# Optional: honour a PATH pin in the template if one is present.
$reaNodeDir = $null
$tplForRea = Join-Path (Get-BundleRoot $PSScriptRoot) 'setup\mcp.json.template'
if ($tplForRea -and (Test-Path $tplForRea)) {
  try {
    $tplJson = Get-Content $tplForRea -Raw | ConvertFrom-Json
    $reaPath = $tplJson.servers.rea.env.PATH
    if ($reaPath) {
      $first = ($reaPath -split ';')[0]
      if ($first -and (Test-Path (Join-Path $first 'node.exe'))) { $reaNodeDir = $first }
    }
  } catch { }
}

if ($reaNodeDir) {
  $reaVer = (& (Join-Path $reaNodeDir 'node.exe') --version 2>&1)
  if (Test-NodeFloor $reaVer) {
    Write-Host "PASS rea node $reaVer (pinned in mcp.json.template) meets the rea-agents floor"
  } else {
    Write-Host "FAIL rea node $reaVer is below the rea-agents floor (22.x>=22.23.4 / 24.x>=24.22.1 / 26.12.1+)"
    $script:failed = 1
  }
  if (Get-Command node -ErrorAction SilentlyContinue) {
    $sysVer = (& node --version 2>&1)
    if (Test-NodeFloor $sysVer) {
      Write-Host "PASS system node $sysVer"
    } else {
      Write-Host "INFO system node $sysVer is below the rea floor, but rea has its own pinned PATH; other npx-based tools (wigolo, firecrawl) are unaffected"
    }
  }
} elseif (Get-Command node -ErrorAction SilentlyContinue) {
  $nodeVer = (& node --version 2>&1)
  if (Test-NodeFloor $nodeVer) {
    Write-Host "PASS node $nodeVer meets the rea-agents floor (no PATH pin needed)"
  } else {
    Write-Host "FAIL node $nodeVer is too old for the rea MCP server (needs 22.x>=22.23.4, 24.x>=24.22.1 or 26.12.1+); rea will time out"
    $script:failed = 1
  }
} else {
  Write-Host "FAIL node not on PATH - the npx-based MCP servers (rea, wigolo) cannot start"
  $script:failed = 1
}

# The skillopt MCP server is a FILE under the SkillOpt mirror, not a binary, so no Get-Command
# check can see it: if the mirror is absent the server dies with "can't open file" at runtime.
$skilloptServer = "$env:USERPROFILE\dev\forks\JZKK720\SkillOpt\plugins\copilot\skillopt\mcp_server.py"
if (Test-Path $skilloptServer) {
  Write-Host "PASS skillopt MCP server -> $skilloptServer"
} else {
  Write-Host "FAIL skillopt MCP server missing at $skilloptServer (clone microsoft/SkillOpt into the fork mirror)"
  $script:failed = 1
}

Write-Host "`n=== MCP CHECK ==="
$mcpPath = "$env:APPDATA\Code\User\mcp.json"
if (-not (Test-Path $mcpPath)) {
  Write-Host "MISS mcp.json at $mcpPath"
  exit 1
}
try {
  $m = Get-Content $mcpPath -Raw | ConvertFrom-Json
  Write-Host 'PASS mcp.json valid'
  $live = @($m.servers.PSObject.Properties.Name)
  Write-Host "INFO live server count: $($live.Count)"
} catch {
  Write-Host "FAIL mcp.json invalid: $($_.Exception.Message)"
  exit 1
}

# Expected bundle servers are declared once, in setup/mcp.json.template. Read
# them from there instead of hardcoding a second copy that will silently drift.
# Name matching is tolerant: a server installed from the MCP gallery is keyed as
# "owner/name" and version-pinned, while the template keys it by the short name
# with @latest (e.g. "firecrawl" vs "firecrawl/firecrawl-mcp-server").
$repoRoot = Get-BundleRoot $PSScriptRoot
$tplPath = if ($repoRoot) { Join-Path $repoRoot 'setup\mcp.json.template' } else { $null }
if ($tplPath -and (Test-Path $tplPath)) {
  $res = Test-BundleMcpServers $mcpPath $repoRoot
  if ($res.Missing.Count -gt 0) {
    Write-Host "FAIL bundle MCP servers not configured: $($res.Missing -join ', ')"
    $script:failed = 1
  } else {
    Write-Host "PASS all $($res.Wanted.Count) bundle MCP servers present"
  }
} else {
  Write-Host "WARN mcp.json.template not found at $tplPath - server cross-check skipped"
}

Write-Host "`n=== SKILLS CHECK ==="
$agents = "$env:USERPROFILE\.agents\skills"
$parked = "$env:USERPROFILE\.agents\skills._disabled"
if (Test-Path $agents) {
  Write-Host "PASS ~/.agents/skills = $(@(Get-ChildItem $agents -Directory).Count) dirs"
} else {
  Write-Host "MISS $agents"
  $script:failed = 1
}
if (Test-Path $parked) {
  $parkedNames = @(Get-ChildItem $parked -Directory)
  Write-Host "INFO ~/.agents/skills._disabled = $($parkedNames.Count) parked"

  # A parked skill is only genuinely parked if its SKILL.md was renamed. A bare
  # SKILL.md left inside a parked dir is still discoverable - the directory
  # simply being present proves nothing.
  $leaked = @($parkedNames | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') })
  if ($leaked.Count -gt 0) {
    Write-Host "FAIL parked but still discoverable: $($leaked.Name -join ', ')"
    $script:failed = 1
  } else {
    Write-Host 'PASS no parked skill is still discoverable'
  }
}

Write-Host ''
if ($script:failed -eq 0) { Write-Host 'RESULT: OK'; exit 0 }
Write-Host 'RESULT: FAILED'; exit 1
