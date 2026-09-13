$env:PATH = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.bun\bin;$env:APPDATA\npm;$env:PATH"
$env:PYTHONUTF8 = "1"

Write-Output "=== graphify-mcp --help ==="
cmd /c "graphify-mcp --help > $env:TEMP\graphify_mcp_help.log 2>&1"
Get-Content "$env:TEMP\graphify_mcp_help.log" -ErrorAction SilentlyContinue | Select-Object -First 15

Write-Output ""
Write-Output "=== scrapling --help (look for mcp subcommand) ==="
cmd /c "scrapling --help > $env:TEMP\scrapling_help.log 2>&1"
Get-Content "$env:TEMP\scrapling_help.log" -ErrorAction SilentlyContinue | Select-Object -First 15