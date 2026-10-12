# make-release.ps1 - one-command release for the CubeCloud skills bundle.
#
# Kills the whole class of stale-tag / stale-release drift by doing, in order:
#   1. Verify clean tree + on main.
#   2. Validate the counter reconciliations (manifest rows vs README badge).
#   3. Rewrite CHANGELOG "[Unreleased] - <date>" -> "[<version>] - <date>"
#      (fails if there is no [Unreleased] block, or if the version already exists).
#   4. Update README badge + title + table counts from the -BundledCount/-OnDiskCount
#      parameters (the manifest row count is the source of truth; active/disabled is
#      derived from the CSV).
#   5. Commit "chore(release): v<version>".
#   6. Push main; create annotated tag; push tag (deleting a stale remote tag first
#      if it points anywhere else).
#   7. Create the GitHub Release with the changelog body via gh --notes-file --latest.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File bin\make-release.ps1 -Version 1.9.19 `
#     -BundledCount 275 -OnDiskCount 302 -Title "short release title"
#
# Modes:
#   -DryRun   Preview every write; changes nothing on disk or remote.
#   -NoPush    Stage the release locally (stamp + commit + tag), print the publish
#              commands, and touch neither origin nor GitHub. Use to review before
#              it goes public.
#
# Notes:
#   - gh auth: uses GH_TOKEN from git credential fill (no `gh auth login` needed;
#     login rejects credential-manager tokens for missing read:org).
#   - Never prints the token.
#   - README count regexes are ASCII-only by design: a BOM-less .ps1 with literal
#     non-ASCII (brain emoji, em-dash) is parsed as ANSI by Windows PowerShell 5.1,
#     which corrupts the literal so the pattern silently stops matching. Build any
#     non-ASCII replacement character from its code point (e.g. [char]0x2014) - a
#     literal '\uXXXX' is written out verbatim, it is not a PowerShell escape.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [int] $BundledCount,
    [Parameter(Mandatory)] [int] $OnDiskCount,
    [string] $Title,
    [string] $DisabledCount = '1',
    [switch] $DryRun,
    # Stage the release locally (stamp + commit + tag) but do not push, create the GitHub
    # release, or touch the remote. Lets a release be reviewed before it becomes public.
    [switch] $NoPush
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

function Step($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Ok($m) { Write-Host "  OK: $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  WARN: $m" -ForegroundColor Yellow }
function Die($m) { Write-Host "  FAIL: $m" -ForegroundColor Red; exit 1 }
function Run([string] $cmdline) {
    if ($DryRun) { Write-Host "  [dry-run] $cmdline" -ForegroundColor DarkCyan; return @() }
    $out = cmd /c "`"$cmdline`" 2>&1"
    return $out
}

# --- 1. tree + branch ---
Step 'Preconditions'
$branch = (git branch --show-current)
if ($branch -ne 'main') { Die "not on main (on '$branch') - this repo releases from main only" }
$st = git status --porcelain
if ($st) { Die "working tree not clean:`n$($st | Out-String)" }
git fetch origin --quiet 2>$null
$behind = git rev-list --count main..origin/main
if ($behind -gt 0) { Die "main is behind origin/main by $behind commits - pull first" }
Ok "on main, clean, up to date"

# --- 2. counters ---
Step 'Counter reconciliation'
$manifest = (Get-Content (Join-Path $repo 'setup\skills-list.csv') |
    Where-Object { $_ -match '^[a-zA-Z][^|#]*\|' }).Count
if ($manifest -ne $BundledCount) {
    Die "manifest rows ($manifest) != -BundledCount ($BundledCount). Pass the real number."
}
# Derive the disabled/active split from the manifest rather than assuming exactly one disabled
# row, so the README stamps stay correct if the disabled set ever changes.
$disabledCount = (Get-Content (Join-Path $repo 'setup\skills-list.csv') |
    Where-Object { $_ -match '^[a-zA-Z][^|#]*\|' -and ($_ -split '\|')[3].Trim() -eq 'true' }).Count
$activeCount = $BundledCount - $disabledCount
$tag = "v$Version"
if (git tag -l $tag) { Die "tag $tag already exists locally" }
Ok "manifest $manifest rows matches -BundledCount; tag $tag is free"

# --- 3. CHANGELOG stamp ---
Step 'CHANGELOG'
$clPath = Join-Path $repo 'CHANGELOG.md'
$cl = [System.IO.File]::ReadAllText($clPath)
$stamp = "## [$Version] - $(Get-Date -Format 'yyyy-MM-dd')"
if ($cl -notmatch '(?m)^## \[Unreleased\]') { Die 'no [Unreleased] block found in CHANGELOG.md' }
if ($cl.Contains("## [$Version]")) { Die "CHANGELOG already has a [$Version] section" }
if ($DryRun) { Write-Host "  [dry-run] would replace '## [Unreleased] - ...' with '$stamp'" -ForegroundColor DarkCyan }
else {
    $clNew = $cl -replace '(?m)^## \[Unreleased\][^\r\n]*', $stamp
    [System.IO.File]::WriteAllText($clPath, $clNew, (New-Object System.Text.UTF8Encoding($false)))
    Ok "stamped [$Version]"
}

# --- 4. README badge/counts ---
Step 'README'
$rdPath = Join-Path $repo 'README.md'
$rd = [System.IO.File]::ReadAllText($rdPath, [System.Text.Encoding]::UTF8)
$pairs = @(
    , ('skills-\d+%20bundled', "skills-$BundledCount%20bundled")
    , ('version-[\d.]+-orange', "version-$Version-orange")
    , (' \d+ bundled skills \(', " $BundledCount bundled skills (")
    # The on-disk figure appears in prose as "**N** are bundle-installed" (L25) and in the
    # table row "| ... Skills on disk | **N** |" (L25). Match the number directly; the old
    # '\(\*\*\d+\*\* on disk\)' pattern matched nothing and silently left stale counts.
    # These patterns stay ASCII-only on purpose: a BOM-less .ps1 with literal non-ASCII (the
    # brain emoji) is parsed as ANSI by Windows PowerShell 5.1 and the literal is corrupted, so
    # the pattern silently stops matching. Use .*? to skip the non-ASCII marker instead.
    , ('(\*\*)\d+(\*\* are bundle-installed)', "`${1}$OnDiskCount`${2}")
    , ('(\| .*?Skills on disk\s+\|\s+\*\*)\d+(\*\*)', "`${1}$OnDiskCount`${2}")
    # These patterns must be ASCII-only *and* their replacements must not embed non-ASCII
    # literals. A BOM-less .ps1 with literal non-ASCII (the brain emoji, the em-dash) is parsed
    # as ANSI by Windows PowerShell 5.1, corrupting the literal. So: match with .*? when possible,
    # and build any non-ASCII replacement character from its code point at runtime
    # ([char]0x2014), because PowerShell does not expand \uXXXX escapes in string literals or in
    # a -replace replacement. (A literal '\u2014' in a replacement is written out verbatim.)
    , ('(\*\*)\d+(\*\* are bundle-installed)', "`${1}$OnDiskCount`${2}")
    , ('(\| .*?Skills on disk\s+\|\s+\*\*)\d+(\*\*)', "`${1}$OnDiskCount`${2}")
    # The "258" prose sites (L51/L115/L404) are the number that keeps drifting.
    $emDash = [char]0x2014
    , ('(\d+) bundled . \d+ active', "$BundledCount bundled $emDash $activeCount active")
    , ('manifest of \d+ entries \(\d+ active', "manifest of $BundledCount entries ($activeCount active")
    , ('Skills \(\d+ bundled\)', "Skills ($BundledCount bundled)")
)
$report = @()
foreach ($p in $pairs) {
    $before = [regex]::Matches($rd, $p[0]).Count
    if ($before -eq 0) { $report += "no match for $($p[0]) (left as-is)"; continue }
    if (-not $DryRun) { $rd = [regex]::Replace($rd, $p[0], $p[1]) }
    $report += "replaced $before x '$($p[0])' -> '$($p[1])'"
}
if ($DryRun) { $report | ForEach-Object { Write-Host "  [dry-run] $_" -ForegroundColor DarkCyan } }
else {
    [System.IO.File]::WriteAllText($rdPath, $rd, (New-Object System.Text.UTF8Encoding($false)))
    $report | ForEach-Object { Ok $_ }
}
# body for the GitHub release, extracted pre-write so it reflects the stamped header.
# Guarded: in a fresh repo the [Unreleased] block is the top section, so the next "## [" may not
# exist and Substring would throw. The release body is only used on the non-dry-run push path.
if ($DryRun) {
    Write-Host '  [dry-run] would extract the release-notes body from the stamped CHANGELOG section' -ForegroundColor DarkCyan
}
else {
    $clNow = [System.IO.File]::ReadAllText($clPath)
    $s = $clNow.IndexOf("## [$Version]")
    if ($s -lt 0) { Die "stamped [$Version] section not found in CHANGELOG" }
    $after = $clNow.Substring($s + 10)
    $m = [regex]::Match($after, '(?m)^## \[')
    $e = if ($m.Success) { $m.Index } else { -1 }
    $releaseBody = if ($e -gt 0) { $clNow.Substring($s, $e).TrimEnd() } else { $clNow.Substring($s).TrimEnd() }
    if (-not $releaseBody) { Die 'could not extract release notes from CHANGELOG' }
}

# --- 5. commit ---
Step 'Commit'
$files = @($clPath, $rdPath) | Where-Object { Test-Path $_ }
if ($DryRun) { Write-Host '  [dry-run] git add CHANGELOG.md README.md; git commit -m "chore(release): ..."' -ForegroundColor DarkCyan }
else {
    git add -- $files
    git commit -m "chore(release): $tag - $BundledCount bundled skills" -m $Title | Out-Null
    Ok "committed $tag"
}

# --- 6. push + tag ---
Step 'Push + tag'
if ($DryRun) {
    Write-Host '  [dry-run] git push origin main; git tag -a <tag>; git push origin <tag>' -ForegroundColor DarkCyan
}
elseif ($NoPush) {
    # Tag locally so the staged release is complete and inspectable, but do not contact origin.
    git tag -a $tag -m "$tag - $BundledCount bundled skills" -m $Title
    Ok "tagged $tag locally (NOT pushed)"
    Warn "remote unchanged - review, then push: git push origin main; git push origin $tag"
}
else {
    git push origin main | Out-Null
    Ok 'pushed main'
    git tag -a $tag -m "$tag - $BundledCount bundled skills" -m $Title
    # If a stale remote tag exists, replace it (delete, re-push)
    $remoteTag = git ls-remote --tags origin refs/tags/$tag
    if ($remoteTag) {
        Warn "remote tag $tag exists - replacing"
        git push origin ":refs/tags/$tag" | Out-Null
    }
    git push origin $tag | Out-Null
    Ok "tagged and pushed $tag"
}

# --- 7. GitHub release ---
Step 'GitHub release'
if ($DryRun) {
    Write-Host '  [dry-run] gh release create <tag> --title ... --notes-file ... --latest' -ForegroundColor DarkCyan
}
elseif ($NoPush) {
    Write-Host "  [no-push] skipped GitHub release for $tag (run without -NoPush after pushing)" -ForegroundColor DarkCyan
}
else {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        # gh is not always in the same place: the MSI/WinGet install lands in
        # %LOCALAPPDATA%\Programs, WinGet shims in %LOCALAPPDATA%\Microsoft\WinGet\Links, and a
        # machine-wide install in Program Files. Probe each rather than assuming one.
        $ghCandidates = @(
            "$env:ProgramFiles\GitHub CLI",
            "$env:LOCALAPPDATA\Programs\GitHub CLI",
            "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
            "$env:ProgramFiles\GitHub CLI\bin"
        )
        foreach ($d in $ghCandidates) {
            if ((Test-Path $d) -and -not (Get-Command gh -ErrorAction SilentlyContinue)) {
                $env:Path = "$env:Path;$d"
            }
        }
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Die 'gh CLI not found (install GitHub CLI or add its dir to PATH)' }
    }
    $credInput = "protocol=https`nhost=github.com`n`n"
    $tokLine = $credInput | git credential fill 2>$null | Where-Object { $_ -like 'password=*' }
    if (-not $tokLine) { Die 'no stored github credential (git credential fill empty)'
    }
    $env:GH_TOKEN = ($tokLine -replace '^password=', '')
    $notes = Join-Path $env:TEMP "release-$Version-notes.md"
    [System.IO.File]::WriteAllText($notes, $releaseBody, (New-Object System.Text.UTF8Encoding($false)))
    $relTitle = if ($Title) { "$tag - $Title" } else { "$tag - $BundledCount bundled skills" }
    $url = gh release create $tag --title $relTitle --notes-file $notes --latest 2>&1
    Ok "release created: $url"
}

Step 'Done'
if ($DryRun) {
    Write-Host 'DRY RUN - nothing was written. Re-run without -DryRun to publish.' -ForegroundColor Yellow
}
elseif ($NoPush) {
    $relTitle = if ($Title) { "$tag - $Title" } else { "$tag - $BundledCount bundled skills" }
    Write-Host "Staged $tag locally (unpushed). To publish:" -ForegroundColor Yellow
    Write-Host "  git push origin main"
    Write-Host "  git push origin $tag"
    Write-Host "  gh release create $tag --title `"$relTitle`" --notes-file <notes> --latest"
}
else {
    Write-Host "Released $tag. Verify:" -ForegroundColor Green
    Write-Host "  gh release view $tag"
}