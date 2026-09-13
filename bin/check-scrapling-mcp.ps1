$env:PATH = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.bun\bin;$env:APPDATA\npm;$env:PATH"
$env:PYTHONUTF8 = "1"

Write-Output "=== scrapling mcp --help ==="
cmd /c "uvx scrapling mcp --help > $env:TEMP\scrapling_mcp_help.log 2>&1"
Get-Content "$env:TEMP\scrapling_mcp_help.log" -ErrorAction SilentlyContinue | Select-Object -First 15