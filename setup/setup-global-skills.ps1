<#
.SYNOPSIS
  Global Skills + CLIs + MCP Setup for VS Code Copilot on Windows.
  Reproduces the full implementation on any Windows machine.

.DESCRIPTION
  This is a one-command setup script that:
  1. Installs prerequisites (uv, bun, ensures Node/Python/git)
  2. Creates directory skeleton (~/.agents/skills, ~/.claude/skills, ~/dev/upstream, etc.)
  3. Installs SkillSpector (security scanner) + skills-ref (spec validator)
  4. Persists PATH (~/.local/bin, ~/.bun/bin, ~/AppData/Roaming/npm) + PYTHONUTF8=1
  5. Installs all CLI tools (uv tool install + npm install -g + bun install -g)
  6. Installs all skills through the security-gated pipeline (scan -> validate -> copy)
  7. Copies the MCP server config to User/mcp.json
  8. Creates governance docs (README, CONFLICTS, MEMORY_POLICY, UPDATE_POLICY)
  9. Runs a final audit

  Run from any PowerShell terminal:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-global-skills.ps1

  Prerequisites already on the machine:
    - Python 3.13+ (winget install Python.Python.3.13)
    - Node.js 20+ (winget install OpenJS.NodeJS)
    - Git (winget install Git.Git)
    - VS Code (winget install Microsoft.VisualStudioCode)

.PARAMETER SkipForks
  Skip cloning the JZKK720 fork mirror repos (saves time if you don't need backups).

.PARAMETER SkipAudit
  Skip the final audit pass.

.PARAMETER IncludeAdditionalEditorProfiles
  Also configure MCP + Copilot utility model pins for Code - Insiders, Cursor, and VSCodium
  user profiles in addition to VS Code Stable.

.PARAMETER IncludeArchifyCli
  Also install a bare `archify` command into ~/.local/bin, as a thin shim over the archify
  fork mirror. archify is a zero-runtime-dependency Node CLI, so this needs no package
  manager and performs no global npm install.

  OPT-IN because every other phase in this script is unconditional, and this one makes a new
  command visible on the user's PATH. Requires the archify fork mirror, so it is incompatible
  with -SkipForks (the script warns and skips rather than failing).

.EXAMPLE
  .\setup-global-skills.ps1
  .\setup-global-skills.ps1 -SkipForks
  .\setup-global-skills.ps1 -SkipForks -SkipAudit
  .\setup-global-skills.ps1 -IncludeAdditionalEditorProfiles
  .\setup-global-skills.ps1 -IncludeArchifyCli
#>

[CmdletBinding()]
param(
  [switch]$SkipForks,
  [switch]$SkipAudit,
  [switch]$IncludeAdditionalEditorProfiles,
  [switch]$IncludeArchifyCli
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK($msg) { Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  WARN: $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "  FAIL: $msg" -ForegroundColor Red }

$editorUserDirs = @(
  "$env:APPDATA\Code\User"
)
if ($IncludeAdditionalEditorProfiles) {
  $editorUserDirs += @(
    "$env:APPDATA\Code - Insiders\User",
    "$env:APPDATA\Cursor\User",
    "$env:APPDATA\VSCodium\User"
  )
}
$editorUserDirs = $editorUserDirs | Select-Object -Unique

function Set-JsoncSetting([string]$Path, [hashtable]$Values) {
  $content = if (Test-Path $Path) { Get-Content $Path -Raw } else { "{`r`n}`r`n" }
  $missingLines = New-Object System.Collections.Generic.List[string]

  foreach ($entry in $Values.GetEnumerator()) {
    $escapedKey = [regex]::Escape($entry.Key)
    $pattern = '(?m)^\s*"' + $escapedKey + '"\s*:\s*"[^"]*"\s*,?\s*$'
    $replacementLine = "  `"$($entry.Key)`": `"$($entry.Value)`","

    if ($content -match $pattern) {
      $content = [regex]::new($pattern).Replace($content, $replacementLine, 1)
    }
    else {
      $null = $missingLines.Add($replacementLine)
    }
  }

  if ($missingLines.Count -gt 0) {
    $content = $content.TrimEnd()
    $insertBlock = ($missingLines -join "`r`n")
    if ($content.EndsWith('}')) {
      $content = $content.Substring(0, $content.Length - 1).TrimEnd()
      if (-not $content.EndsWith("`r`n") -and -not $content.EndsWith("`n")) {
        $content += "`r`n"
      }
      $content += $insertBlock + "`r`n}`r`n"
    }
    else {
      if (-not $content.EndsWith("`r`n") -and -not $content.EndsWith("`n")) {
        $content += "`r`n"
      }
      $content += $insertBlock + "`r`n"
    }
  }

  [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

# ============================================================
# PHASE 0: PREREQUISITES
# ============================================================
Write-Step "Phase 0: Prerequisites"

# Check Python
$pythonOk = $false
try { $null = & python --version 2>&1; $pythonOk = $true } catch {}
if (-not $pythonOk) { Write-Fail "Python not found. Install: winget install Python.Python.3.13"; exit 1 }
Write-OK "Python: $(python --version 2>&1)"

# Check Node
$nodeOk = $false
try { $null = & node --version 2>&1; $nodeOk = $true } catch {}
if (-not $nodeOk) { Write-Fail "Node.js not found. Install: winget install OpenJS.NodeJS"; exit 1 }
Write-OK "Node: $(node --version 2>&1)"

# Check Git
try { $null = & git --version 2>&1; Write-OK "Git: $(git --version 2>&1)" }
catch { Write-Fail "Git not found. Install: winget install Git.Git"; exit 1 }

# Install uv (Python package manager) if not present
try { $null = & uv --version 2>&1; Write-OK "uv: $(uv --version 2>&1)" }
catch {
  Write-Host "  Installing uv..." -NoNewline
  cmd /c "winget install --id astral-sh.uv --silent --accept-source-agreements --accept-package-agreements --disable-interactivity >nul 2>nul"
  Write-OK "uv installed (restart terminal to pick up PATH)"
}

# Install bun if not present
try { $null = & bun --version 2>&1; Write-OK "bun: $(bun --version 2>&1)" }
catch {
  Write-Host "  Installing bun..." -NoNewline
  cmd /c "winget install --id Oven-sh.Bun --silent --accept-source-agreements --accept-package-agreements --disable-interactivity >nul 2>nul"
  Write-OK "bun installed (restart terminal to pick up PATH)"
}

# Refresh PATH for this session
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
$env:PYTHONUTF8 = "1"

# ============================================================
# PHASE 0b: PERSISTENT PATH + ENV
# ============================================================
Write-Step "Phase 0b: Persistent PATH + PYTHONUTF8"

$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$requiredDirs = @(
  "$env:USERPROFILE\.local\bin",
  "$env:USERPROFILE\.bun\bin",
  "$env:APPDATA\npm"
)
foreach ($dir in $requiredDirs) {
  if ($userPath -notlike "*$dir*") {
    $userPath = "$dir;$userPath"
    Write-OK "Added $dir to user PATH"
  }
  else {
    Write-OK "$dir already on PATH"
  }
}
[System.Environment]::SetEnvironmentVariable("PATH", $userPath, "User")

$utf8 = [System.Environment]::GetEnvironmentVariable("PYTHONUTF8", "User")
if ($utf8 -ne "1") {
  [System.Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
  Write-OK "Set PYTHONUTF8=1 for user"
}
else {
  Write-OK "PYTHONUTF8 already set"
}

# ============================================================
# PHASE 0c: DIRECTORY SKELETON
# ============================================================
Write-Step "Phase 0c: Directory skeleton"

$dirs = @(
  "$env:USERPROFILE\.agents\skills._disabled",
  "$env:USERPROFILE\.agents\skills._staging",
  "$env:USERPROFILE\.agents\skills._reference",
  "$env:USERPROFILE\.claude\skills",
  "$env:USERPROFILE\.claude\commands",
  "$env:USERPROFILE\.claude\hooks",
  "$env:USERPROFILE\dev\upstream",
  "$env:USERPROFILE\dev\forks\JZKK720",
  "$env:USERPROFILE\dev\bin",
  "$env:USERPROFILE\dev\setup"
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
Write-OK "$($dirs.Count) directories created/verified"

# ============================================================
# PHASE 1: SECURITY GATE (SkillSpector + skills-ref)
# ============================================================
Write-Step "Phase 1: Security gate - SkillSpector + skills-ref"

$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"

# Install skillspector[mcp]
try { $null = & skillspector --version 2>&1; Write-OK "skillspector: $(skillspector --version 2>&1)" }
catch {
  Write-Host "  Installing skillspector[mcp]..." -NoNewline
  cmd /c "uv tool install --python 3.13 `"skillspector[mcp] @ git+https://github.com/NVIDIA/skillspector.git`" >nul 2>nul"
  cmd /c "uv tool update-shell >nul 2>nul"
  $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
  Write-OK "skillspector installed"
}

# Install skills-ref
try { $null = & skills-ref --version 2>&1; Write-OK "skills-ref: $(skills-ref --version 2>&1)" }
catch {
  Write-Host "  Installing skills-ref..." -NoNewline
  $tmpClone = "$env:TEMP\agentskills_setup"
  if (Test-Path $tmpClone) { Remove-Item $tmpClone -Recurse -Force }
  cmd /c "git clone --depth 1 https://github.com/agentskills/agentskills.git `"$tmpClone`" >nul 2>nul"
  cmd /c "uv tool install --python 3.13 `"$tmpClone\skills-ref`" >nul 2>nul"
  Remove-Item $tmpClone -Recurse -Force -ErrorAction SilentlyContinue
  Write-OK "skills-ref installed"
}

# ============================================================
# PHASE 1b: INSTALL HELPER SCRIPT
# ============================================================
Write-Step "Phase 1b: Install helper script"

$helperSrc = Join-Path $PSScriptRoot "install-skill.ps1"
$helperDst = "$env:USERPROFILE\dev\bin\install-skill.ps1"
if (Test-Path $helperSrc) {
  Copy-Item $helperSrc $helperDst -Force
  Write-OK "install-skill.ps1 copied to ~/dev/bin/"
}
else {
  Write-Warn "install-skill.ps1 not found in $PSScriptRoot - you need to copy it manually"
}

# ============================================================
# PHASE 2: CLI TOOLS
# ============================================================
Write-Step "Phase 2: CLI tools"

# headroom-ai depends on ast-grep-cli, whose Rust-compiled sg.exe triggers a
# Windows Defender false positive ("virus or potentially unwanted software",
# os error 225). Add a scoped Defender exclusion before attempting the install.
# Requires admin privileges; if it fails, headroom install will fail with a
# clear error and the user can run bin/add-defender-exclusion-ast-grep.ps1
# in an elevated PowerShell and re-run this script.
$sgPath = "$env:APPDATA\uv\tools\ast-grep-cli"
try {
  $null = Add-MpPreference -ExclusionPath $sgPath -ErrorAction Stop
  $null = Add-MpPreference -ExclusionProcess "sg.exe" -ErrorAction Stop
  Write-OK "Defender exclusion for ast-grep-cli (sg.exe) added"
}
catch {
  Write-Warn "Could not add Defender exclusion (not admin?). headroom install may fail."
  Write-Warn "  Fix: run bin/add-defender-exclusion-ast-grep.ps1 in an elevated PowerShell, then re-run this script."
}

$pyTools = @(
  # specify-cli installs as 'specify' binary (not 'specify-cli')
  @{name = "specify-cli"; pkg = "specify-cli"; py = "3.13" },
  # skillopt (microsoft/SkillOpt, MIT) ships 3 console scripts: skillopt-train,
  # skillopt-eval, skillopt-sleep. There is NO binary named 'skillopt', so probe
  # skillopt-eval for the skip-if-present check (matches the audit scripts).
  @{name = "skillopt-eval"; pkg = "skillopt"; py = "3.13" },
  @{name = "agent-reach"; pkg = "git+https://github.com/Panniantong/Agent-Reach.git"; py = "3.13" },
  # graphifyy[mcp] installs as 'graphify' binary (not 'graphifyy')
  @{name = "graphifyy[mcp]"; pkg = "graphifyy[mcp]"; py = "3.13" },
  @{name = "markitdown[all]"; pkg = "markitdown[all]"; py = "3.13" },
  @{name = "scrapling[ai]"; pkg = "scrapling[ai]"; py = "3.13" },
  @{name = "headroom-ai[proxy]"; pkg = "headroom-ai[proxy]"; py = "3.12" },
  @{name = "watch-skill"; pkg = "git+https://github.com/oxbshw/watch-skill.git"; py = "3.13" },
  # semantica (semantica-agi/semantica, MIT): Python knowledge-graph library.
  # Ships 17 plugin skills at plugins/skills/*/SKILL.md. Requires Python 3.10+.
  @{name = "semantica"; pkg = "semantica"; py = "3.13" }
)
foreach ($t in $pyTools) {
  $binName = $t.name -replace '\[.*\]', ''
  # headroom-ai installs as 'headroom' binary
  if ($binName -eq 'headroom-ai') { $binName = 'headroom' }
  # specify-cli installs as 'specify' binary
  if ($binName -eq 'specify-cli') { $binName = 'specify' }
  # graphifyy installs as 'graphify' binary
  if ($binName -eq 'graphifyy') { $binName = 'graphify' }
  $already = Get-Command $binName -ErrorAction SilentlyContinue
  if ($already) { Write-OK "$binName already installed"; continue }
  $pyVersion = if ($t.py) { $t.py } else { "3.13" }
  if ($pyVersion -eq "3.12") {
    $hasPy312 = $false
    try { $null = & py -3.12 --version 2>&1; $hasPy312 = $true } catch {}
    if (-not $hasPy312) {
      Write-Warn "Python 3.12 not found; skipping $($t.name). Install Python 3.12 then run bin/safe-update-pass.ps1."
      continue
    }
  }
  Write-Host "  Installing $($t.name)..." -NoNewline
  cmd /c "uv tool install --python $pyVersion `"$($t.pkg)`" > `"$env:TEMP\install_$($t.name).log`" 2>&1"
  if ($LASTEXITCODE -eq 0) { Write-OK "" } else { Write-Fail "exit $LASTEXITCODE" }
}

# npm tools
$npm = "C:\Program Files\nodejs\npm.cmd"
if (-not (Test-Path $npm)) { $npm = (Get-Command npm -ErrorAction SilentlyContinue).Source }
if ($npm) {
  $npmTools = @(
    @{pkg = "ui-ux-pro-max-cli"; bin = "uipro" },
    @{pkg = "firecrawl-cli"; bin = "firecrawl" },
    @{pkg = "@cobusgreyling/loop"; bin = "loop" },
    @{pkg = "wigolo"; bin = "wigolo" },
    @{pkg = "@alibaba-group/open-code-review"; bin = "ocr" }
  )
  foreach ($tool in $npmTools) {
    $pkg = $tool.pkg
    $binName = $tool.bin
    $already = Get-Command $binName -ErrorAction SilentlyContinue
    if ($already) { Write-OK "$binName already installed"; continue }
    Write-Host "  Installing $pkg..." -NoNewline
    cmd /c "`"$npm`" install -g $pkg >nul 2>nul"
    if ($LASTEXITCODE -eq 0) { Write-OK "" } else { Write-Fail "exit $LASTEXITCODE" }
  }
}

# bun tools
foreach ($pkg in @("github:garrytan/gbrain")) {
  $binName = ($pkg -split ':')[-1] -replace 'github:', ''
  $already = Get-Command $binName -ErrorAction SilentlyContinue
  if ($already) { Write-OK "$binName already installed"; continue }
  Write-Host "  Installing $pkg..." -NoNewline
  cmd /c "bun install -g $pkg >nul 2>nul"
  if ($LASTEXITCODE -eq 0) { Write-OK "" } else { Write-Fail "exit $LASTEXITCODE" }
}

# agent-reach setup
$ar = Get-Command agent-reach -ErrorAction SilentlyContinue
if ($ar) {
  Write-Host "  Running agent-reach install --env=auto..." -NoNewline
  cmd /c "agent-reach install --env=auto >nul 2>nul"
  Write-OK "agent-reach channels configured"
}

# gbrain init
$gb = Get-Command gbrain -ErrorAction SilentlyContinue
if ($gb) {
  Write-Host "  Running gbrain init --pglite --no-embedding..." -NoNewline
  cmd /c "gbrain init --pglite --no-embedding >nul 2>nul"
  Write-OK "gbrain initialized (PGLite, deferred embeddings)"
}

# witr (pranshuparmar/witr, Apache-2.0): Go binary from GitHub releases.
# No Go toolchain needed — download prebuilt Windows binary.
$witrBin = Get-Command witr -ErrorAction SilentlyContinue
if (-not $witrBin) {
  Write-Host "  Installing witr (GitHub release binary)..." -NoNewline
  try {
    $progressPreference = 'SilentlyContinue'
    $witrRelease = Invoke-RestMethod "https://api.github.com/repos/pranshuparmar/witr/releases/latest"
    $witrAsset = $witrRelease.assets | Where-Object { $_.name -eq 'witr-windows-amd64.zip' } | Select-Object -First 1
    if ($witrAsset) {
      $witrZip = Join-Path $env:TEMP "witr-install.zip"
      $witrExtract = Join-Path $env:TEMP "witr-install-extract"
      Invoke-WebRequest -Uri $witrAsset.browser_download_url -OutFile $witrZip
      if (Test-Path $witrExtract) { Remove-Item $witrExtract -Recurse -Force }
      Expand-Archive -Path $witrZip -DestinationPath $witrExtract -Force
      $witrDest = Join-Path $env:LOCALAPPDATA "Programs\witr"
      if (-not (Test-Path $witrDest)) { New-Item -ItemType Directory -Path $witrDest -Force | Out-Null }
      Copy-Item (Join-Path $witrExtract "witr.exe") $witrDest -Force
      $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
      if ($userPath -notlike "*$witrDest*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$witrDest", "User")
      }
      $env:Path += ";$witrDest"
      Write-OK ""
    }
    else { Write-Fail "no Windows asset found" }
  }
  catch { Write-Fail $_.Exception.Message }
}
else { Write-OK "witr already installed" }

# ============================================================
# PHASE 3: FORK MIRRORS (optional)
# ============================================================
if (-not $SkipForks) {
  Write-Step "Phase 3: Fork mirrors (JZKK720)"
  $forks = @(
    "Gskills", "caveman", "last30days-skill", "EverOS", "agentskills",
    "markitdown", "firecrawl", "ponytail", "improve", "headroom",
    "taste-skill", "ECC", "gstack", "gbrain", "agent-skills",
    "spec-kit", "superpowers", "llm_wiki", "hallmark", "Scrapling",
    "graphify", "oz-skills"
  )
  $dest = "$env:USERPROFILE\dev\forks\JZKK720"
  foreach ($f in $forks) {
    $target = Join-Path $dest $f
    if (Test-Path $target) { continue }
    cmd /c "git clone --depth 1 https://github.com/JZKK720/$f.git `"$target`" >nul 2>nul"
  }
  # Non-JZKK720 fork mirror: VoltAgent/awesome-design-md (74 DESIGN.md design system
  # files, MIT). Indexed by the design-md-library wrapper skill. Different owner, so
  # handled outside the JZKK720 loop above.
  $admTarget = Join-Path $dest "awesome-design-md"
  if (-not (Test-Path $admTarget)) {
    cmd /c "git clone --depth 1 https://github.com/VoltAgent/awesome-design-md.git `"$admTarget`" >nul 2>nul"
  }
  # Non-JZKK720 fork mirror: microsoft/SkillOpt (MIT). The PyPI wheel installs the
  # CLI binaries (skillopt-train/eval/sleep), but the Copilot MCP server at
  # plugins/copilot/skillopt/mcp_server.py shells out to scripts/train.py and
  # scripts/eval_only.py, which live in the repo, NOT the wheel. The MCP server
  # reads SKILLOPT_REPO (set in mcp.json.template) to locate these scripts.
  $skilloptTarget = Join-Path $dest "SkillOpt"
  if (-not (Test-Path $skilloptTarget)) {
    cmd /c "git clone --depth 1 https://github.com/microsoft/SkillOpt.git `"$skilloptTarget`" >nul 2>nul"
  }
  # Non-JZKK720 fork mirror: alibaba/open-code-review (Apache-2.0). The `ocr` CLI
  # is installed via npm, but the repo ships 2 portable SKILL.md files at
  # skills/open-code-review/ and skills/open-code-review-delegate/ that the
  # security-gated install pipeline copies from a local clone. The delegate skill
  # is LLM-free on the OCR side — the host agent drives the review.
  $ocrTarget = Join-Path $dest "open-code-review"
  if (-not (Test-Path $ocrTarget)) {
    cmd /c "git clone --depth 1 https://github.com/alibaba/open-code-review.git `"$ocrTarget`" >nul 2>nul"
  }
  # Non-JZKK720 fork mirror: EveryInc/compound-engineering-plugin (MIT, 24.2k★).
  # 25 cherry-picked skills (non-review) added to skills-list.csv. Copilot is a
  # first-class target; zero $ARGUMENTS/mcp__ coupling in skill bodies.
  $ceTarget = Join-Path $dest "compound-engineering-plugin"
  if (-not (Test-Path $ceTarget)) {
    cmd /c "git clone --depth 1 https://github.com/EveryInc/compound-engineering-plugin.git `"$ceTarget`" >nul 2>nul"
  }
  # Non-JZKK720 fork mirror: Shubhamsaboo/awesome-llm-apps (Apache-2.0).
  # 4 deterministic local-tool skills added to skills-list.csv. Zero Claude-Code
  # coupling; each ships stdlib-only Python scripts with CI-eval-gated tests.
  $allaTarget = Join-Path $dest "awesome-llm-apps"
  if (-not (Test-Path $allaTarget)) {
    cmd /c "git clone --depth 1 https://github.com/Shubhamsaboo/awesome-llm-apps.git `"$allaTarget`" >nul 2>nul"
  }  # Non-JZKK720 fork mirror: tt-a1i/archify (MIT, v2.17).
  # Interactive architecture diagram skill. 5 diagram types, typed JSON IR, validator.
  # Supports Claude Code, Codex CLI, Cursor, OpenCode.
  #
  # FIXED 2026-09-13: this line previously read `$archifyTarget` with an ESCAPED dollar
  # (backtick-dollar), which interpolated nothing and ran `git clone ... $<path>` — the
  # clone silently failed, which is why ~/dev/forks/JZKK720/archify was never created by
  # the installer. Same bug fixed on the book-to-skill line below.
  # The `archify` SKILL itself is not installed from here: upstream is SkillSpector-blocked
  # (HIGH MP3), so the bundle ships a clean methodology-only port at upstream/archify/.
  # This mirror is still cloned because the port's SKILL.md tells the agent to use this
  # checkout when it needs the real renderer (bin/archify.mjs validate|deliver|visual-check).
  $archifyTarget = Join-Path $dest "archify"
  if (-not (Test-Path $archifyTarget)) {
    cmd /c "git clone --depth 1 https://github.com/tt-a1i/archify.git `"$archifyTarget`" >nul 2>nul"
  }
  # Non-JZKK720 fork mirror: virgiliojr94/book-to-skill (MIT).
  # Converts books/documents into structured agent skills. Supports Copilot
  # CLI, Claude Code, Amp.
  # FIXED 2026-09-13: escaped-dollar bug (see note above) — the clone never ran.
  # NOTE: upstream is SkillSpector-blocked (CRITICAL), so the bundle installs a clean
  # methodology-only port that uses the `markitdown` CLI for extraction instead.
  $btsTarget = Join-Path $dest "book-to-skill"
  if (-not (Test-Path $btsTarget)) {
    cmd /c "git clone --depth 1 https://github.com/virgiliojr94/book-to-skill.git `"$btsTarget`" >nul 2>nul"
  }
  # Non-JZKK720 fork mirror: alchaincyf/huashu-design (MIT).
  # Bilingual (CN/EN) design skill: prototypes, slides, animations, infographics,
  # expert reviews. 40+ design styles. Agent-agnostic. SKILL.md at repo root.
  $huashuTarget = Join-Path $dest "huashu-design"
  if (-not (Test-Path $huashuTarget)) {
    cmd /c "git clone --depth 1 https://github.com/alchaincyf/huashu-design.git `"$huashuTarget`" >nul 2>nul"
  }
  # Non-JZKK720 fork mirror: semantica-agi/semantica (MIT).
  # Python knowledge-graph library with 17 plugin skills. CLI: uv tool install semantica.
  $semanticaTarget = Join-Path $dest "semantica"
  if (-not (Test-Path $semanticaTarget)) {
    cmd /c "git clone --depth 1 https://github.com/semantica-agi/semantica.git `"$semanticaTarget`" >nul 2>nul"
  }
  # Non-JZKK720 fork mirror: pranshuparmar/witr (Apache-2.0).
  # "Why is this running?" — Go CLI for process ancestry investigation.
  # Binary via GitHub releases (Go not required). No SKILL.md (CLI tool).
  $witrTarget = Join-Path $dest "witr"
  if (-not (Test-Path $witrTarget)) {
    cmd /c "git clone --depth 1 https://github.com/pranshuparmar/witr.git `"$witrTarget`" >nul 2>nul"
  }

  # ---------------------------------------------------------------------------
  # Added 2026-09-13 (v1.8.0, 14-repo evaluation). JZKK720 forks, so the plain
  # `JZKK720/<name>` form applies. Two names are deliberately NOT the upstream repo
  # name — see the note in sync-fork-upstreams.ps1: the naive name for each collided
  # with an unrelated pre-existing fork (addyosmani/agent-skills and vercel-labs/skills).
  # ---------------------------------------------------------------------------
  $evaluationMirrors = @(
    "tech-leads-club-agent-skills",  # <- tech-leads-club/agent-skills (name collided)
    "openai-skills",                 # <- openai/skills (name collided)
    "marketingskills",               # <- coreyhaines31/marketingskills
    "diagram-design",                # <- cathrynlavery/diagram-design
    "humanizer",                     # <- blader/humanizer (SKILL.md at repo root)
    "no-ai-slop",                    # <- petergyang/no-ai-slop
    "firstmate",                     # <- kunchenguid/firstmate
    "humanlayer-skills"              # <- humanlayer/skills
  )
  foreach ($m in $evaluationMirrors) {
    $mTarget = Join-Path $dest $m
    if (Test-Path $mTarget) { continue }
    cmd /c "git clone --depth 1 https://github.com/JZKK720/$m.git `"$mTarget`" >nul 2>nul"
  }
  $forkCount = (Get-ChildItem $dest -Directory).Count
  Write-OK "$forkCount fork repos mirrored"
}

# ============================================================
# PHASE 3b: OPTIONAL archify CLI shim
# ============================================================
# archify is a zero-runtime-dependency Node CLI: bin/archify.mjs imports only node:
# stdlib, and the mirror has no node_modules and needs none. So the bare command can be
# offered without a package manager, a registry, or a global npm install.
#
# Why this SHIPS AS A SHIM and not an npm install:
#   - upstream package.json sets "private": true, so archify can never be published to or
#     installed from the npm registry;
#   - it needs Node >= 18 (already a prerequisite of this script) and nothing else;
#   - a 2-line .cmd has no version to drift, no lockfile, and nothing to uninstall.
#
# Why OPT-IN: every other phase in this script is unconditional. This one puts a new
# command on the user's PATH, which is a visible system change, so it requires
# -IncludeArchifyCli.
#
# Note the SKILL/CLI split: upstream is SkillSpector-blocked (HIGH MP3), which is why the
# *skill* installs as a clean port (see skills-list.csv -> local/archify). The CLI is a
# separate concern and the gate does not apply to it. This phase adds only the command.
if ($IncludeArchifyCli) {
  Write-Step "Phase 3b: archify CLI shim (opt-in)"

  $archifyCli = "$env:USERPROFILE\dev\forks\JZKK720\archify\archify\bin\archify.mjs"
  $shimDir = "$env:USERPROFILE\.local\bin"
  $shimPath = Join-Path $shimDir "archify.cmd"

  if (-not (Test-Path $archifyCli)) {
    # Reachable when the user passed -SkipForks, or the mirror clone failed.
    Write-Warn "archify mirror not found at $archifyCli"
    Write-Warn "  The shim IS the mirror's CLI, so it needs the mirror. Re-run without"
    Write-Warn "  -SkipForks, or run bin/sync-fork-upstreams.ps1, then re-add -IncludeArchifyCli."
  }
  else {
    # Verify the CLI actually runs before advertising it. `doctor` is read-only and checks
    # the Node version plus every renderer, schema and reference the CLI depends on, so a
    # passing doctor is real evidence the shim will work -- not just that a file exists.
    $doctorOut = cmd /c "node `"$archifyCli`" doctor 2>&1" | Out-String
    if ($LASTEXITCODE -eq 0 -and $doctorOut -match "Archify is ready") {
      New-Item -ItemType Directory -Force -Path $shimDir | Out-Null
      # %USERPROFILE% is expanded when the shim RUNS, not when it is written, so the file
      # stays valid across re-clones and for whatever user it lives under.
      @(
        "@echo off",
        "node `"%USERPROFILE%\dev\forks\JZKK720\archify\archify\bin\archify.mjs`" %*"
      ) | Out-File $shimPath -Encoding ASCII
      Write-OK "archify CLI ready -> $shimPath"
      Write-OK "  try: archify doctor | archify render architecture in.json out.html"
    }
    else {
      Write-Warn "archify CLI present but 'doctor' did not pass; shim not written."
      Write-Host $doctorOut
    }
  }
}

# ============================================================
# PHASE 4: SKILLS INSTALL (via install-skill.ps1)
# ============================================================
Write-Step "Phase 4: Skills install (security-gated)"

$skillsCsv = Join-Path $PSScriptRoot "skills-list.csv"
if (-not (Test-Path $skillsCsv)) {
  Write-Fail "skills-list.csv not found in $PSScriptRoot"
  exit 1
}

$helper = "$env:USERPROFILE\dev\bin\install-skill.ps1"
if (-not (Test-Path $helper)) {
  Write-Fail "install-skill.ps1 not found at $helper"
  exit 1
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
# Ensure the governance/log dir exists before skills try to append to SCAN_LOG.md
# (the helper warns if missing; this prevents that warning on a fresh machine).
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\dev\upstream" | Out-Null
if (-not (Test-Path "$env:USERPROFILE\dev\upstream\SCAN_LOG.md")) {
  @("# SkillSpector Scan Log", "", "| Date | Repo | Skill | Verdict | Status | Notes |", "|---|---|---|---|---|---|") |
  Out-File "$env:USERPROFILE\dev\upstream\SCAN_LOG.md" -Encoding UTF8
}
$lines = Get-Content $skillsCsv | Where-Object { $_ -and -not $_.StartsWith("#") }
$installed = 0; $blocked = 0; $skipped = 0

foreach ($line in $lines) {
  $parts = $line -split '\|'
  $repo = $parts[0].Trim()
  $name = $parts[1].Trim()
  $relPath = $parts[2].Trim()
  $disabled = $parts[3].Trim() -eq "true"
  $sourcePath = if ($parts.Length -ge 5) { $parts[4].Trim() } else { '' }

  # Skip if already installed
  $destDir = if ($disabled) { "$env:USERPROFILE\.agents\skills._disabled\$name" }
  else { "$env:USERPROFILE\.agents\skills\$name" }
  if (Test-Path $destDir) { $skipped++; continue }

  Write-Host "  $name..." -NoNewline

  # Handle local/* entries: these are hand-authored skills that live in the
  # repo's upstream/ folder (5th CSV column), not on GitHub. Use -SourcePath.
  if ($repo -match '^local/') {
    if (-not $sourcePath) { $sourcePath = "upstream/$name" }
    if (-not [System.IO.Path]::IsPathRooted($sourcePath)) {
      $sourcePath = Join-Path (Split-Path $PSScriptRoot -Parent) $sourcePath
    }
    if (-not (Test-Path (Join-Path $sourcePath 'SKILL.md'))) {
      Write-Host " SKIP (local source missing or no SKILL.md)"; $skipped++
      continue
    }
    $installArgs = @("-SourcePath", $sourcePath, "-Name", $name)
  }
  else {
    # NOTE: do not use $args here - it is an automatic variable in PowerShell
    # and reassigning it corrupts splatting. Use a plain-named array instead.
    $installArgs = @("-Repo", $repo, "-Name", $name)
    if ($relPath) { $installArgs += @("-SkillRelPath", $relPath) }
  }
  if ($disabled) { $installArgs += "-Disabled" }

  # Invoke via `powershell -ExecutionPolicy Bypass -File` so the helper loads
  # even when the user's effective execution policy would block `& $helper`.
  $argLine = ($installArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
  $out = cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$helper`" $argLine 2>&1" | Out-String
  if ($out -match "complete:.*active" -or $out -match "complete:.*DISABLED") {
    Write-Host " OK"; $installed++
  }
  elseif ($out -match "BLOCK|FAIL|Die") {
    Write-Host " BLOCKED"; $blocked++
  }
  else {
    Write-Host " ?"; $skipped++
  }
}
Write-OK "Installed: $installed, Blocked: $blocked, Skipped (already present): $skipped"

# ============================================================
# PHASE 5: MCP CONFIG
# ============================================================
Write-Step "Phase 5: MCP server config"

$mcpTemplate = Join-Path $PSScriptRoot "mcp.json.template"
$primaryMcpDest = "$env:APPDATA\Code\User\mcp.json"
if (Test-Path $mcpTemplate) {
  foreach ($editorUserDir in $editorUserDirs) {
    New-Item -ItemType Directory -Force -Path $editorUserDir | Out-Null
    $profileName = Split-Path (Split-Path $editorUserDir -Parent) -Leaf
    $mcpDest = Join-Path $editorUserDir "mcp.json"

    # Preserve existing servers if mcp.json already exists
    if (Test-Path $mcpDest) {
      try {
        $existing = Get-Content $mcpDest -Raw | ConvertFrom-Json
        $template = Get-Content $mcpTemplate -Raw | ConvertFrom-Json
        # Merge: add template servers that don't exist
        foreach ($prop in $template.servers.PSObject.Properties) {
          if (-not $existing.servers.PSObject.Properties[$prop.Name]) {
            $existing.servers | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
          }
        }
        $existing | ConvertTo-Json -Depth 10 | Out-File $mcpDest -Encoding UTF8
        Write-OK "[$profileName] Merged MCP servers into existing mcp.json"
      }
      catch {
        Copy-Item $mcpTemplate $mcpDest -Force
        Write-OK "[$profileName] Replaced mcp.json with template (existing was invalid)"
      }
    }
    else {
      Copy-Item $mcpTemplate $mcpDest -Force
      Write-OK "[$profileName] Created mcp.json from template"
    }
  }
}
else {
  Write-Warn "mcp.json.template not found - copy manually"
}

# ============================================================
# PHASE 5b: COPILOT UTILITY MODEL PINS
# ============================================================
Write-Step "Phase 5b: Copilot utility model pins"

foreach ($editorUserDir in $editorUserDirs) {
  New-Item -ItemType Directory -Force -Path $editorUserDir | Out-Null
  $profileName = Split-Path (Split-Path $editorUserDir -Parent) -Leaf
  $copilotSettingsPath = Join-Path $editorUserDir "settings.json"
  Set-JsoncSetting -Path $copilotSettingsPath -Values @{
    "chat.utilityModel"            = "ollama-models/gemma4:26b-a4b-it-qat"
    "chat.utilitySmallModel"       = "ollama-models/ornith:9b-q8_0"
    "chat.byokUtilityModelDefault" = "mainAgent"
  }
  Write-OK "[$profileName] Pinned VS Code Copilot utility models in user settings"
}

# ============================================================
# PHASE 5c: SKILLOPT-SLEEP NIGHTLY SCHEDULE
# ============================================================
# SkillOpt-Sleep harvests past session transcripts, mines recurring tasks,
# replays them offline, and stages a validated skill edit for review (adopt
# is manual by design). backend=mock spends no model budget; re-schedule with
# --backend claude/copilot to actually evolve skills once credentials are set.
# The scheduler auto-detects Windows and installs a Windows Scheduled Task
# (schtasks) named "SkillOpt-Sleep-<sanitized-path>" at 03:17 daily.
Write-Step "Phase 5c: SkillOpt-Sleep nightly schedule"
$sleepBin = Get-Command skillopt-sleep -ErrorAction SilentlyContinue
if ($sleepBin) {
  $sleepProject = "$env:USERPROFILE\dev"
  # Idempotent: skillopt-sleep schedule replaces the entry for this project.
  $sleepOut = cmd /c "skillopt-sleep schedule --project `"$sleepProject`" --backend mock --hour 3 --minute 17 2>&1" | Out-String
  if ($LASTEXITCODE -eq 0 -and $sleepOut -match "Scheduled nightly") {
    Write-OK "SkillOpt-Sleep scheduled nightly at 03:17 for $sleepProject (backend=mock)"
  }
  else {
    Write-Warn "skillopt-sleep schedule did not confirm success. Output:"
    Write-Host $sleepOut
  }
}
else {
  Write-Warn "skillopt-sleep CLI not found; skipping nightly schedule. Re-run setup after install to enable."
}

# ============================================================
# PHASE 6: GOVERNANCE DOCS
# ============================================================
Write-Step "Phase 6: Governance docs"

# README.md
$readme = @(
  "# Global Agent Skills Stack",
  "",
  "This directory is the VS Code Copilot Chat skill discovery root.",
  "See ~/dev/setup/SETUP_GUIDE.md for full setup instructions.",
  "",
  "## Install pipeline",
  "All skills installed via ~/dev/bin/install-skill.ps1 (SkillSpector scan -> skills-ref validate -> copy).",
  "",
  "## Security policy",
  "SkillSpector is a hard gate. No skill lands without a passing scan (exit 0).",
  "See ~/dev/upstream/SCAN_LOG.md for full verdict history."
)
$readme | Out-File "$env:USERPROFILE\.agents\README.md" -Encoding UTF8
Write-OK "README.md"

# SCAN_LOG.md
if (-not (Test-Path "$env:USERPROFILE\dev\upstream\SCAN_LOG.md")) {
  @(
    "# SkillSpector Scan Log",
    "",
    "| Date | Repo | Skill | Verdict | Status | Notes |",
    "|---|---|---|---|---|---|"
  ) | Out-File "$env:USERPROFILE\dev\upstream\SCAN_LOG.md" -Encoding UTF8
  Write-OK "SCAN_LOG.md created"
}
else {
  Write-OK "SCAN_LOG.md already exists"
}

# CONFLICTS.md, MEMORY_POLICY.md, UPDATE_POLICY.md
@( "# Known Conflicts", "", "Active methodology: superpowers (single).", "Caveman: disabled by default (opt-in token compression).", "Memory: gbrain MCP (primary)." ) | Out-File "$env:USERPROFILE\.agents\CONFLICTS.md" -Encoding UTF8
@( "# Memory Policy", "", "Primary: gbrain MCP (PGLite, zero-config).", "EverOS: Windows-incompatible (fcntl). Not used.", "recall: Claude Code only (needs hooks)." ) | Out-File "$env:USERPROFILE\.agents\MEMORY_POLICY.md" -Encoding UTF8
@( "# Update Policy", "", "Monthly: git pull upstreams, re-scan changed skills, uv tool upgrade --all.", "After any skill change: reload VS Code window." ) | Out-File "$env:USERPROFILE\.agents\UPDATE_POLICY.md" -Encoding UTF8
Write-OK "All governance docs created"

# ============================================================
# PHASE 7: FINAL AUDIT (optional)
# ============================================================
if (-not $SkipAudit) {
  Write-Step "Phase 7: Quick audit"

  $skillCount = (Get-ChildItem "$env:USERPROFILE\.agents\skills" -Directory).Count
  Write-OK "Total skills: $skillCount"

  $mcpValid = $false
  try { $null = Get-Content $primaryMcpDest -Raw | ConvertFrom-Json; $mcpValid = $true } catch {}
  Write-OK "mcp.json valid: $mcpValid"

  try {
    $copilotSettings = Get-Content "$env:APPDATA\Code\User\settings.json" -Raw
    $utilityPinned = $copilotSettings -match '"chat\.utilityModel"\s*:\s*"ollama-models/gemma4:26b-a4b-it-qat"'
    $utilitySmallPinned = $copilotSettings -match '"chat\.utilitySmallModel"\s*:\s*"ollama-models/ornith:9b-q8_0"'
    $byokFallbackPinned = $copilotSettings -match '"chat\.byokUtilityModelDefault"\s*:\s*"mainAgent"'
    Write-OK "Copilot utility model pinned: $utilityPinned"
    Write-OK "Copilot small utility model pinned: $utilitySmallPinned"
    Write-OK "Copilot BYOK fallback pinned: $byokFallbackPinned"
  }
  catch {
    Write-Warn "Copilot user settings unavailable for audit"
  }

  if ($IncludeAdditionalEditorProfiles) {
    foreach ($editorUserDir in $editorUserDirs | Where-Object { $_ -ne "$env:APPDATA\Code\User" }) {
      $profileName = Split-Path (Split-Path $editorUserDir -Parent) -Leaf
      $profileMcpPath = Join-Path $editorUserDir "mcp.json"
      $profileSettingsPath = Join-Path $editorUserDir "settings.json"
      $profileMcpValid = $false
      try { $null = Get-Content $profileMcpPath -Raw | ConvertFrom-Json; $profileMcpValid = $true } catch {}
      Write-OK "[$profileName] mcp.json valid: $profileMcpValid"

      try {
        $profileSettings = Get-Content $profileSettingsPath -Raw
        $profileUtilityPinned = $profileSettings -match '"chat\.utilityModel"\s*:\s*"ollama-models/gemma4:26b-a4b-it-qat"'
        $profileUtilitySmallPinned = $profileSettings -match '"chat\.utilitySmallModel"\s*:\s*"ollama-models/ornith:9b-q8_0"'
        $profileByokFallbackPinned = $profileSettings -match '"chat\.byokUtilityModelDefault"\s*:\s*"mainAgent"'
        Write-OK "[$profileName] utility model pinned: $profileUtilityPinned"
        Write-OK "[$profileName] utility small model pinned: $profileUtilitySmallPinned"
        Write-OK "[$profileName] BYOK fallback pinned: $profileByokFallbackPinned"
      }
      catch {
        Write-Warn "[$profileName] user settings unavailable for audit"
      }
    }
  }

  $cliOk = 0; $cliFail = 0
  foreach ($c in @("skillspector", "skills-ref", "specify", "agent-reach", "graphify", "markitdown", "gbrain", "scrapling", "uipro", "firecrawl", "headroom", "skillopt-eval", "ocr")) {
    if (Get-Command $c -ErrorAction SilentlyContinue) { $cliOk++ } else { $cliFail++ }
  }
  Write-OK "CLI tools: $cliOk OK, $cliFail missing"

  if ($IncludeArchifyCli) {
    $archifyCmd = Get-Command archify -ErrorAction SilentlyContinue
    if ($archifyCmd) {
      Write-OK "archify CLI shim: $($archifyCmd.Source)"
    }
    else {
      Write-Warn "archify CLI shim requested but not on PATH - see Phase 3b above"
    }
  }

  $claudeCount = (Get-ChildItem "$env:USERPROFILE\.claude\skills" -Directory -ErrorAction SilentlyContinue).Count
  Write-OK "Claude Code skills: $claudeCount"

  $forkCount = (Get-ChildItem "$env:USERPROFILE\dev\forks\JZKK720" -Directory -ErrorAction SilentlyContinue).Count
  Write-OK "Fork mirrors: $forkCount"
}

# ============================================================
# DONE
# ============================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SETUP COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart VS Code (or reload window: Ctrl+Shift+P -> Developer: Reload Window)"
if ($IncludeAdditionalEditorProfiles) {
  Write-Host "  2. Restart other editor windows too (Code - Insiders/Cursor/VSCodium)"
  Write-Host "  3. In Copilot Chat, type # to see MCP tools"
  Write-Host "  4. Try: 'use the improve skill to audit this codebase'"
}
else {
  Write-Host "  2. In Copilot Chat, type # to see MCP tools"
  Write-Host "  3. Try: 'use the improve skill to audit this codebase'"
}
Write-Host ""
Write-Host "Files created:"
Write-Host "  ~/.agents/skills/          - $skillCount skills (VS Code Copilot discovery)"
Write-Host "  ~/.claude/skills/          - Claude Code mirror"
Write-Host "  ~/dev/bin/install-skill.ps1 - security-gated install helper"
Write-Host "  ~/dev/setup/               - this setup package (portable)"
Write-Host "  ~/dev/upstream/SCAN_LOG.md - security scan log"