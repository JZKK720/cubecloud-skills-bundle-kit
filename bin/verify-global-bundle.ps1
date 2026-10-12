$ErrorActionPreference = 'Stop'
$env:PATH = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.bun\bin;$env:APPDATA\npm;$env:PATH"

Write-Host '=== CLI ==='
$tools = @(
    'skillspector', 'skills-ref', 'specify', 'skillopt-eval', 'agent-reach', 'graphify',
    'markitdown', 'scrapling', 'uipro', 'firecrawl', 'gbrain', 'headroom'
)

$missing = @()
foreach ($tool in $tools) {
    $cmd = Get-Command $tool -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host ("PASS {0} -> {1}" -f $tool, $cmd.Source)
    }
    else {
        Write-Host ("MISS {0}" -f $tool)
        $missing += $tool
    }
}

Write-Host "`n=== MCP ==="
$validateMcpScript = Join-Path $PSScriptRoot 'validate-mcp.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $validateMcpScript
if ($LASTEXITCODE -ne 0) {
    throw "MCP validation failed with exit code $LASTEXITCODE"
}

if ($missing.Count -gt 0) {
    throw ("Missing CLI tools: {0}" -f ($missing -join ', '))
}

Write-Host "`nGlobal bundle verification passed."
exit 0