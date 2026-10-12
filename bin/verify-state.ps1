$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\bundle-common.ps1')
Initialize-BundlePath
$script:failed = 0

Write-Host '=== CLI CHECK (18) ==='
$tools = @(
  'skillspector','skills-ref','specify','skillopt-eval','agent-reach','graphify',
  'markitdown','scrapling','uipro','firecrawl','gbrain','headroom',
  'witr','semantica','loop','watch-skill','wigolo','ocr'
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
