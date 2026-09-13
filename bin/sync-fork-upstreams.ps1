<#
.SYNOPSIS
  Add an `upstream` remote to each JZKK720 fork mirror and fast-forward sync it
  with the real upstream source, so forks track upstream instead of drifting.

.DESCRIPTION
  Each fork mirror in ~/dev/forks/JZKK720/ was cloned from the JZKK720 fork and
  only has an `origin` remote. This script:
    1. Adds an `upstream` remote pointing at the real upstream repo (if missing).
    2. Fetches upstream.
    3. Fast-forwards the local default branch to upstream's default branch.
  It is idempotent and safe: it never force-pushes, never rewrites history, and
  leaves the fork's `origin` remote untouched.

.PARAMETER ForksRoot
  Root directory containing the fork mirrors. Default: ~/dev/forks/JZKK720

.PARAMETER DryRun
  Show what would be done without changing anything.

.EXAMPLE
  .\sync-fork-upstreams.ps1
  .\sync-fork-upstreams.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$ForksRoot = "$env:USERPROFILE\dev\forks\JZKK720",
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Map: local fork dir name -> real upstream owner/repo
# NOTE ON UNUSED MIRRORS: "Gskills" (google/skills) is kept in this map so the mirror
# stays current, but it is deliberately NOT an install source. Evaluated 2026-09-13:
# 137 skills, of which 118 are GCP "cloud" (GKE, BigQuery, AlloyDB, IAM, Cloud Run),
# 14 ads, 2 analytics, 1 identity, and only 2 generic "developers" meta-skills that just
# point at Google's own catalog. This bundle is a Windows/Copilot/Azure kit with no other
# GCP content, so installing a GCP subset would be arbitrary and would contradict the same
# framework-specific/domain-niche exclusion rule applied to rails-patterns and the ECC
# legal skills. Mirror-only by decision, not by omission.
$upstreamMap = @{
    "Gskills"                     = "google/skills"
    "caveman"                     = "JuliusBrussee/caveman"
    "last30days-skill"            = "mvanhorn/last30days-skill"
    "EverOS"                      = "EverMind-AI/EverOS"
    "agentskills"                 = "agentskills/agentskills"
    "markitdown"                  = "microsoft/markitdown"
    "firecrawl"                   = "firecrawl/firecrawl"
    "ponytail"                    = "DietrichGebert/ponytail"
    "improve"                     = "shadcn/improve"
    "headroom"                    = "headroomlabs-ai/headroom"
    "taste-skill"                 = "Leonxlnx/taste-skill"
    "ECC"                         = "affaan-m/ECC"
    "gstack"                      = "garrytan/gstack"
    "gbrain"                      = "garrytan/gbrain"
    "agent-skills"                = "addyosmani/agent-skills"
    "spec-kit"                    = "github/spec-kit"
    "superpowers"                 = "obra/superpowers"
    "llm_wiki"                    = "nashsu/llm_wiki"
    "hallmark"                    = "Nutlope/hallmark"
    "Scrapling"                   = "D4Vinci/Scrapling"
    "graphify"                    = "Graphify-Labs/graphify"
    "oz-skills"                   = "warpdotdev/oz-skills"
    "loop-engineering"            = "cobusgreyling/loop-engineering"
    "awesome-design-md"           = "VoltAgent/awesome-design-md"
    "SkillOpt"                    = "microsoft/SkillOpt"
    "open-code-review"            = "alibaba/open-code-review"
    "compound-engineering-plugin" = "EveryInc/compound-engineering-plugin"
    "awesome-llm-apps"            = "Shubhamsaboo/awesome-llm-apps"
    "archify"                     = "tt-a1i/archify"
    "book-to-skill"               = "virgiliojr94/book-to-skill"
    "huashu-design"               = "alchaincyf/huashu-design"
    "semantica"                   = "semantica-agi/semantica"
    "witr"                        = "pranshuparmar/witr"
    # Added 2026-09-13: previously cloned as fork mirrors but absent from this
    # map, so they were silently SKIPped and never tracked upstream.
    "context-engineering-kit"     = "NeoLabHQ/context-engineering-kit"
    "crucible"                    = "chaseai-yt/crucible"
    "claude-skills-llm-council"   = "aiwithremy/claude-skills-llm-council"
    "awesome-claude-skills"       = "ComposioHQ/awesome-claude-skills"
    "ui-skills"                   = "ibelick/ui-skills"
    # NOTE: "loop-engineering" is already mapped further up this table.
    # Added 2026-09-13 (14-repo evaluation, v1.8.0). NOTE the two deliberate renames:
    # the naive local dir name for each would have collided with an unrelated
    # already-existing fork, so the JZKK720 fork was created under a new name and that
    # name is what maps here.
    #   tech-leads-club/agent-skills -> `agent-skills` collided with addyosmani/agent-skills
    #   openai/skills                -> `skills` collided with vercel-labs/skills
    "tech-leads-club-agent-skills" = "tech-leads-club/agent-skills"
    "openai-skills"                = "openai/skills"
    "marketingskills"              = "coreyhaines31/marketingskills"
    "diagram-design"               = "cathrynlavery/diagram-design"
    "humanizer"                    = "blader/humanizer"
    "no-ai-slop"                   = "petergyang/no-ai-slop"
    "firstmate"                    = "kunchenguid/firstmate"
    "humanlayer-skills"            = "humanlayer/skills"    # Added 2026-09-13: the impeccable mirror was never cloned, so its 21 local/* port
    # rows had unreproducible provenance and were silently SKIPped here as unmapped.
    # NOTE: this mirror is a SPARSE checkout (~11MB, reference docs only) because upstream
    # is ~338MB and is a full application (CLI + browser extension + live server + hooks),
    # not a skill package. The sparse path is preserved by `git sparse-checkout`, so the
    # fetch/fast-forward below keeps working without re-materialising the whole tree.
    "impeccable"                  = "pbakaus/impeccable"}

if (-not (Test-Path $ForksRoot)) {
    Write-Host "Forks root not found: $ForksRoot" -ForegroundColor Red
    exit 1
}

$ok = 0; $skipped = 0; $failed = 0

# Local branch name -> upstream default branch, for repos where they differ.
# These need a human decision (branch rename / unrelated history), not a guess.
$manualReview = @{
    "graphify" = "v8"   # local tracks v4, upstream default is now v8
}

# Fork mirrors that intentionally carry a fork-only commit and therefore can
# never fast-forward. Skipped with an explicit reason instead of failed.
$expectedDivergent = @(
    "caveman"   # fork adds a "chore: sync SKILL.md copies [skip ci]" commit
)

foreach ($dir in (Get-ChildItem $ForksRoot -Directory | Sort-Object Name)) {
    $name = $dir.Name
    if (-not $upstreamMap.ContainsKey($name)) {
        Write-Host "  SKIP $name (no upstream mapping)" -ForegroundColor DarkYellow
        $skipped++
        continue
    }
    $upstream = $upstreamMap[$name]
    $repo = $dir.FullName

    # Skip anything that is not actually a git checkout. Some mapped directories
    # (e.g. loop-engineering) may be plain drop-in folders rather than clones.
    # Without this guard `git symbolic-ref` writes to stderr, and because
    # $ErrorActionPreference is 'Stop' that aborts the whole run.
    if (-not (Test-Path (Join-Path $repo ".git"))) {
        Write-Host "  SKIP $name (not a git checkout)" -ForegroundColor DarkYellow
        $skipped++
        continue
    }

    # Determine default branch. Capture stderr so a git message is never
    # promoted to a terminating error under $ErrorActionPreference = 'Stop'.
    # NOTE: do not inspect $LASTEXITCODE here — a pipeline resets it to the exit
    # code of the last pipeline command (Select-Object), which is 0, but the
    # variable also leaks a stale non-zero value from any earlier git call and
    # would then wrongly force the fallback branch. Validate the text instead.
    $defaultBranch = (& git -C $repo symbolic-ref --short HEAD 2>&1 | Select-Object -First 1)
    if (-not $defaultBranch -or "$defaultBranch" -match '^fatal:') {
        $defaultBranch = "main"
    }

    # Repos whose upstream default branch no longer matches the locally checked
    # out branch. Fast-forwarding across a default-branch change is a deliberate
    # decision, so report and skip instead of guessing.
    if ($manualReview.ContainsKey($name)) {
        Write-Host "  SKIP $name (upstream default branch changed: local '$defaultBranch' vs upstream '$($manualReview[$name])' - manual review)" -ForegroundColor DarkYellow
        $skipped++
        continue
    }

    # Repos that carry an intentional fork-only commit on top of upstream. These
    # can never fast-forward, so reporting them as failures every run is noise.
    if ($expectedDivergent -contains $name) {
        Write-Host "  SKIP $name (expected divergence: fork carries a fork-only commit)" -ForegroundColor DarkYellow
        $skipped++
        continue
    }

    if ($DryRun) {
        Write-Host "  [dry-run] $name : add upstream=$upstream, fetch, ff $defaultBranch"
        continue
    }

    try {
        # Git writes ordinary progress output ("Updating files: 61% ...") and
        # hints to stderr. With $ErrorActionPreference = 'Stop' PowerShell
        # promotes that to a terminating NativeCommandError, so a perfectly
        # successful fast-forward was being reported as FAILED. Merge stderr
        # into stdout and judge success by $LASTEXITCODE instead.
        $ErrorActionPreference = 'Continue'

        # Add upstream remote if missing
        $remotes = @(& git -C $repo remote 2>&1)
        if ($remotes -notcontains "upstream") {
            & git -C $repo remote add upstream "https://github.com/$upstream.git" 2>&1 | Out-Null
            Write-Host "  $name : added upstream -> $upstream" -ForegroundColor Green
        }

        # Fetch upstream
        & git -C $repo fetch upstream 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "fetch failed" }

        # Fast-forward local default branch to upstream default branch
        $upstreamBranch = "upstream/$defaultBranch"
        $localHead = (& git -C $repo rev-parse HEAD 2>&1 | Select-Object -First 1)
        $upstreamHead = (& git -C $repo rev-parse "$upstreamBranch" 2>&1 | Select-Object -First 1)
        if (-not $upstreamHead -or "$upstreamHead" -match '^(fatal|error):') {
            Write-Host "  $name : upstream branch '$upstreamBranch' not found, skipping" -ForegroundColor DarkYellow
            $skipped++
            continue
        }
        if ($localHead -eq $upstreamHead) {
            Write-Host "  $name : already up to date" -ForegroundColor DarkGray
            $skipped++
            continue
        }
        & git -C $repo merge --ff-only "$upstreamBranch" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "ff merge failed (local changes?)" }
        Write-Host "  $name : fast-forwarded to upstream ($upstreamBranch)" -ForegroundColor Green
        $ok++
    }
    catch {
        Write-Host "  $name : FAILED - $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "Done. Synced: $ok, Already-up-to-date/skipped: $skipped, Failed: $failed" -ForegroundColor Cyan
