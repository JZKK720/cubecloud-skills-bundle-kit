$csvPath = "setup\skills-list.csv"
$lines = Get-Content $csvPath
foreach ($line in $lines) {
    if ($line -match "^\s*#" -or $line -match "^\s*$") { continue }
    $parts = $line -split '\|'
    $repo = $parts[0].Trim()
    $name = $parts[1].Trim()
    $skillRelPath = $parts[2].Trim()
    $disabled = $parts[3].Trim()
    if ($disabled -eq "true") { continue }

    # Invoke the canonical install helper via powershell -File so quoting and
    # execution policy behave the same as the installer's Phase 4 loop.
    # Do not name this array $args: it is an automatic variable in PowerShell.
    $installArgs = @()
    if ($repo -match '^local/') {
        # local/* rows are hand-authored skills vendored under upstream/<name>,
        # not cloneable git repos. Resolve them to a local source path.
        $src = Join-Path $PSScriptRoot "upstream\$name"
        if (-not (Test-Path (Join-Path $src 'SKILL.md'))) {
            Write-Host "  $name SKIP (local source missing or no SKILL.md)"
            continue
        }
        $installArgs = @("-SourcePath", $src, "-Name", $name)
    }
    else {
        $installArgs = @("-Repo", $repo, "-Name", $name)
        if ($skillRelPath) { $installArgs += @("-SkillRelPath", $skillRelPath) }
    }
    $argLine = ($installArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
    cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$env:USERPROFILE\dev\bin\install-skill.ps1`" $argLine 2>&1"
}