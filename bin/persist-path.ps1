# Permanently add ~/.bun\bin to user PATH (for gbrain and other bun globals)
$dir = "$env:USERPROFILE\.bun\bin"
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")

if ($userPath -like "*$dir*") {
  Write-Output "ALREADY on PATH: $dir"
} else {
  $newPath = "$dir;$userPath"
  [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
  Write-Output "ADDED to user PATH: $dir"
}

# Also set PYTHONUTF8=1 permanently for the user (needed by skillspector, skills-ref, scrapling, etc.)
$utf8 = [System.Environment]::GetEnvironmentVariable("PYTHONUTF8", "User")
if ($utf8 -eq "1") {
  Write-Output "PYTHONUTF8 already set to 1 for user"
} else {
  [System.Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
  Write-Output "Set PYTHONUTF8=1 permanently for user"
}

# Verify
$verifyPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$verifyUtf8 = [System.Environment]::GetEnvironmentVariable("PYTHONUTF8", "User")
Write-Output ""
Write-Output "=== Verification ==="
Write-Output "bun\bin on PATH: $($verifyPath -like '*\.bun\bin*')"
Write-Output "PYTHONUTF8 = $verifyUtf8"
Write-Output ""
Write-Output "Note: Restart VS Code (or any new terminal) for these changes to take effect."