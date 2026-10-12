<#
Shared helpers for the bundle's audit/verify scripts.

Dot-source from a sibling script:
  . (Join-Path $PSScriptRoot 'lib\bundle-common.ps1')

These consolidate logic that was previously copy-pasted across verify-state.ps1,
validate-mcp.ps1 and check-mcp-cmds.ps1 (PATH prelude, MCP template cross-check and the
gallery-tolerant name normalization). Keep behavior identical when refactoring callers.
#>

# Prepend the tool install locations to PATH for this process. Mirrors the prelude the
# standalone verify scripts each set inline. The witr entry is optional and harmless if absent.
function Initialize-BundlePath {
  $env:PATH = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.bun\bin;$env:APPDATA\npm;$env:LOCALAPPDATA\Programs\witr;$env:PATH"
  $env:PYTHONUTF8 = '1'
}

# Locate the bundle repo root by walking up from a script directory until setup\skills-list.csv
# is found. Returns $null when no repo root is in scope (e.g. a bare deployed helper).
function Get-BundleRoot([string]$StartDir) {
  $dir = $StartDir
  while ($dir) {
    if (Test-Path (Join-Path $dir 'setup\skills-list.csv')) { return $dir }
    $parent = Split-Path $dir -Parent
    if (-not $parent -or $parent -eq $dir) { return $null }
    $dir = $parent
  }
  return $null
}

# Normalize an MCP server key to a comparable leaf name. A server installed from the MCP
# gallery is keyed "owner/name" (e.g. "firecrawl/firecrawl-mcp-server") while the template keys
# it by short name ("firecrawl"); comparing normalized leaves treats them as the same server.
function Get-NormalizedMcpName([string]$Name) {
  $leaf = ($Name -split '/')[-1]
  return ($leaf -replace '[^a-z0-9]', '').ToLowerInvariant()
}

# Read the bundle's expected MCP server set from setup/mcp.json.template (the single source of
# truth). Returns an empty array when the template is absent.
function Get-BundleMcpServers([string]$RepoRoot) {
  if (-not $RepoRoot) { return @() }
  $tpl = Join-Path $RepoRoot 'setup\mcp.json.template'
  if (-not (Test-Path $tpl)) { return @() }
  return @((Get-Content $tpl -Raw | ConvertFrom-Json).servers.PSObject.Properties.Name)
}

# Compare the live MCP config against the template's expected set.
# Returns a hashtable @{ Ok; Missing; Wanted; Live; LiveNorm }.
function Test-BundleMcpServers([string]$McpPath, [string]$RepoRoot) {
  $wanted = Get-BundleMcpServers $RepoRoot
  $result = @{ Ok = $false; Missing = @(); Wanted = $wanted; Live = @(); LiveNorm = @() }
  if (-not (Test-Path $McpPath)) { return $result }
  try { $m = Get-Content $McpPath -Raw | ConvertFrom-Json } catch { return $result }

  $live = @($m.servers.PSObject.Properties.Name)
  $liveNorm = @($live | ForEach-Object { Get-NormalizedMcpName $_ })
  $result.Live = $live
  $result.LiveNorm = $liveNorm

  if ($wanted.Count -eq 0) { $result.Ok = $true; return $result }  # no template = nothing to assert
  $missing = @()
  foreach ($w in $wanted) {
    $wn = Get-NormalizedMcpName $w
    if (@($liveNorm | Where-Object { $_ -eq $wn -or $_ -like "*$wn*" }).Count -eq 0) { $missing += $w }
  }
  $result.Missing = $missing
  $result.Ok = ($missing.Count -eq 0)
  return $result
}
