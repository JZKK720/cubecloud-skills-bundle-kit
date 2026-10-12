<#
.SYNOPSIS
  Validate the VS Code MCP config against the bundle's expected server set.

.DESCRIPTION
  Reads the live mcp.json and asserts every server declared in setup/mcp.json.template is
  present. Exits non-zero when the file is missing, invalid, or a bundle server is absent, so
  verify-global-bundle.ps1's MCP gate is real instead of always-green (this script previously
  printed a summary and never set an exit code).

  Name matching is tolerant: a server installed from the MCP gallery is keyed "owner/name"
  (e.g. "firecrawl/firecrawl-mcp-server"), while the template keys it by short name
  ("firecrawl"). Compare normalized leaf names, not raw keys, or every gallery install reads
  as missing.

.PARAMETER McpPath
  Path to the MCP config to validate. Defaults to the VS Code user mcp.json. Override to test
  an alternate profile or a fixture.
#>

[CmdletBinding()]
param(
  [string]$McpPath = "$env:APPDATA\Code\User\mcp.json"
)

. (Join-Path $PSScriptRoot 'lib\bundle-common.ps1')

if (-not (Test-Path $McpPath)) {
  Write-Output "MISS mcp.json at $McpPath"
  exit 1
}

try {
  $m = Get-Content $McpPath -Raw | ConvertFrom-Json
} catch {
  Write-Output "ERROR: invalid JSON in ${McpPath}: $($_.Exception.Message)"
  exit 1
}

Write-Output "JSON valid"
$live = @($m.servers.PSObject.Properties.Name)
$live | ForEach-Object { Write-Output "  $_" }
Write-Output ""
Write-Output "scrapling args: $($m.servers.scrapling.args -join ', ')"
Write-Output "graphify args: $($m.servers.graphify.args -join ', ')"

# Expected bundle servers are declared once, in setup/mcp.json.template. Read them from there
# instead of hardcoding a second copy that silently drifts.
$repoRoot = Get-BundleRoot $PSScriptRoot
$tplPath = if ($repoRoot) { Join-Path $repoRoot 'setup\mcp.json.template' } else { $null }
if (-not $tplPath -or -not (Test-Path $tplPath)) {
  Write-Output "WARN template not found at $tplPath - server cross-check skipped"
  exit 0
}
$res = Test-BundleMcpServers $McpPath $repoRoot

if ($res.Missing.Count -gt 0) {
  Write-Output "FAIL bundle MCP servers not configured: $($res.Missing -join ', ')"
  exit 1
}
Write-Output "PASS all $($res.Wanted.Count) bundle MCP servers present"
exit 0