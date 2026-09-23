# Global Skills + CLIs + MCP Setup Guide

## How to reproduce this setup on a new Windows machine

### Quick start (one command)

1. Copy the `~/dev/setup/` folder to the new machine (USB, GitHub, OneDrive, etc.)
1. Open PowerShell and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-global-skills.ps1
```

Optional: also configure Code - Insiders, Cursor, and VSCodium user profiles:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-global-skills.ps1 -IncludeAdditionalEditorProfiles
```

1. Restart VS Code. Done.

### What the setup script does

| Phase | What                                                                                                                                                                                                                                                                                                                         | Time    |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| 0     | Check/install prerequisites (Python, Node, Git, uv, bun)                                                                                                                                                                                                                                                                     | ~2 min  |
| 0b    | Persist PATH + PYTHONUTF8=1 for user                                                                                                                                                                                                                                                                                         | instant |
| 0c    | Create directory skeleton (~/.agents/skills, ~/.claude/skills, ~/dev/)                                                                                                                                                                                                                                                       | instant |
| 1     | Install SkillSpector (security scanner) + skills-ref (spec validator)                                                                                                                                                                                                                                                        | ~2 min  |
| 1b    | Copy install-skill.ps1 helper to ~/dev/bin/                                                                                                                                                                                                                                                                                  | instant |
| 2     | Install 18 CLI tools (uv tool + npm + bun + release binary)                                                                                                                                                                                                                                                                  | ~5 min  |
| 3     | Clone 50 fork mirrors (JZKK720 mirrors + awesome-design-md + microsoft/SkillOpt + alibaba/open-code-review + EveryInc/compound-engineering-plugin + Shubhamsaboo/awesome-llm-apps + openai/skills + tech-leads-club/agent-skills + coreyhaines31/marketingskills + humanlayer/skills + kunchenguid/firstmate + blader/humanizer + petergyang/no-ai-slop + cathrynlavery/diagram-design + tt-a1i/archify + virgiliojr94/book-to-skill + pbakaus/impeccable + wuyoscar/jev-skill) (skip with -SkipForks) | ~2 min  |
| 3b    | **Opt-in** (`-IncludeArchifyCli`): write `~/.local/bin/archify.cmd` shim for the archify CLI. Runs `archify doctor` first; skips with a warning if the mirror is absent | instant |
| 4     | Install 257 manifest entries (256 active + 1 disabled) through the security-gated pipeline; combined with extension/CLI-provisioned skills this yields 281 dirs in `~/.agents/skills/` (plus 14 parked in `skills._disabled/`)                                                                          | ~5 min  |
| 5     | Configure 11 MCP servers in VS Code User/mcp.json (and optional alternate editor profiles)                                                                                                                                                                                                                                   | instant |
| 5b    | Pin Copilot utility models in VS Code User/settings.json (and optional alternate editor profiles)                                                                                                                                                                                                                            | instant |
| 6     | Create governance docs (README, CONFLICTS, MEMORY_POLICY, UPDATE_POLICY, SCAN_LOG)                                                                                                                                                                                                                                           | instant |
| 7     | Quick audit (skill count, CLI check, mcp.json validation)                                                                                                                                                                                                                                                                    | instant |

**Total time: ~15 minutes** (or ~10 min with `-SkipForks`)

### Files in this package

```
~/dev/setup/
├── setup-global-skills.ps1   # Master one-command installer
├── install-skill.ps1          # Security-gated skill install helper (scan→validate→copy)
├── skills-list.csv            # List of skills to install (repo|name|relPath|disabled)
├── mcp.json.template          # MCP server config template (11 servers)
└── SETUP_GUIDE.md             # This file
```

### Prerequisites on the new machine

The script checks for these and installs uv/bun if missing. These must be pre-installed:

```powershell
winget install Python.Python.3.12
winget install Python.Python.3.13
winget install OpenJS.NodeJS
winget install Git.Git
winget install Microsoft.VisualStudioCode
```

`Python 3.12` is required for the guarded headroom update path used by `bin/safe-update-pass.ps1`.

### What gets installed

**11 MCP servers** (in VS Code User/mcp.json):

- markitdown, skillspector, firecrawl, scrapling, gbrain, graphify, headroom, loop-engineering, watch-skill, wigolo, skillopt

**Copilot utility model pins** (in VS Code User/settings.json):

- `chat.utilityModel = ollama-models/gemma4:26b-a4b-it-qat`
- `chat.utilitySmallModel = ollama-models/ornith:9b-q8_0`
- `chat.byokUtilityModelDefault = mainAgent` (BYOK fallback when a utility flow needs a default)

**18 CLI tools** (on permanent user PATH):

- skillspector, skills-ref, specify, skillopt-eval, agent-reach, graphify, markitdown, scrapling, semantica (via uv)
- uipro, firecrawl, loop, wigolo, ocr (via npm)
- gbrain (via bun)
- headroom, watch-skill (via uv; watch-skill from GitHub source)
- witr (via GitHub release binary — Go binary, no Go toolchain needed)

**257 manifest entries (256 active + 1 disabled) + extension/CLI-provisioned and hand-ported skills = 281 dirs in `~/.agents/skills/`** (discovered by VS Code Copilot Chat), with **14 more parked** in `skills._disabled/` (1 upstream-disabled + 13 Copilot-incompatible, see v1.9.10 in the changelog):

- superpowers methodology (12 skills): TDD, systematic-debugging, writing/executing-plans, subagent-driven-development, code review, git-worktrees, finishing-branch, writing-skills, using-superpowers, dispatching-parallel-agents
- ECC agent engineering (35 skills): safety-guard, token-budget-advisor, intent-driven-development, verification-loop, eval-harness, agent-self-evaluation, prompt-optimizer, rules-distill, knowledge-ops, codebase-onboarding, repo-scan, code-tour, search-first, blueprint, strategic-compact, enterprise-agent-ops, production-audit, error-handling, delivery-gate, coding-standards, context-budget, security-review, security-scan, security-bounty-hunter, brand-discovery, brand-voice, frontend-design-direction, make-interfaces-feel-better, continuous-agent-loop, cost-tracking, cost-aware-llm-pipeline, automation-audit-ops, connections-optimizer, mcp-server-patterns, backend-patterns
- self-learning (meta-skill for skill authoring)
- improve (audit-to-plan)
- loopy (loop library)
- loop-engineering (loop infrastructure companion skill)
- watch-skill (video intelligence companion skill)
- wigolo (local-first web intelligence companion skill)
- ponytail (minimal-code YAGNI)
- hallmark (anti-slop UI design)
- taste-skill (frontend taste/polish)
- karpathy-guidelines (coding guidelines)
- agent-reach (15-platform research access, installed via its own CLI)
- graphify (folder→knowledge graph, installed via its own CLI)
- caveman (DISABLED — token compression, opt-in only)
- oz-skills (14 active): analysis-artifacts, ci-fix, create-pull-request, dbt-model-index, docs-update, github-bug-report-triage, github-issue-dedupe, mcp-builder, scheduler, seo-aeo-audit, slack-qa-investigate, terraform-style-check, web-accessibility-audit, web-performance-audit
- ui-skills (7 active): ui-skills-root, baseline-ui, create-design-md, fixing-accessibility, fixing-metadata, fixing-motion-performance, improve-ui
- agent-skills (23 active, unique entries): api-and-interface-design, browser-testing-with-devtools, ci-cd-and-automation, code-review-and-quality, code-simplification, context-engineering, debugging-and-error-recovery, deprecation-and-migration, documentation-and-adrs, doubt-driven-development, frontend-ui-engineering, git-workflow-and-versioning, idea-refine, incremental-implementation, interview-me, observability-and-instrumentation, performance-optimization, planning-and-task-breakdown, security-and-hardening, shipping-and-launch, source-driven-development, spec-driven-development, using-agent-skills
- loop-engineering (5 active): loop-triage, minimal-fix, loop-constraints, loop-verifier, loop-budget
- changelog-generator (1 active): from ComposioHQ/awesome-claude-skills
- ARIS ports (3 active): aris-novelty-check, aris-research-lit, aris-idea-creator (methodology-only ports from wanshuiyin/Auto-claude-code-research-in-sleep)
- design-md-library (wrapper that indexes the 74 DESIGN.md files in the awesome-design-md fork mirror)
- gstack-review (hand-adapted pre-landing PR review port, with 8 reference files)
- idea-to-design (clean port of brainstorming — methodology only, no browser server)
- webapp-testing (clean port — methodology only, no bundled scripts; agent writes native Playwright or uses browser MCP tools)
- open-code-review (2 active): open-code-review, open-code-review-delegate — deterministic + agent hybrid code review via `ocr` CLI (alibaba/open-code-review, Apache-2.0). The delegate skill is LLM-free on the OCR side.
- tech-leads-club/agent-skills (12 active): DDD set (domain-analysis, domain-identification-grouping, coupling-analysis, decomposition-planning-roadmap, tactical-ddd, modular-design-principles) + create-technical-design-doc, create-rfc, harness-eval, spec-driven-eval, not-your-babysitter, learning-opportunities
- marketingskills (8 active): product-marketing, copywriting, content-strategy, competitor-profiling, launch, pricing, marketing-loops, marketing-psychology
- openai/skills (5 active, Apache-2.0 per skill): figma, screenshot, pdf, transcribe, security-threat-model
- firstmate (4 active): bearings, diagnostic-reasoning, bootstrap-diagnostics, project-management
- humanlayer/skills (3 active): show-me, improve-claude-md, narrow-react-prop-types
- prose de-slopping (2 active): humanizer (blader/humanizer), no-ai-slop (petergyang/no-ai-slop)
- archify (1 active, clean port): tt-a1i/archify is gate-BLOCKED (HIGH MP3) — methodology-only port at upstream/archify/SKILL.md, gates 0/100 SAFE

Notes:

- Azure/Foundry skills are standard extension-provided Copilot skills.
- Custom implementations in this setup are `agent-reach` and `gstack-review`.

**50 fork mirrors** (in ~/dev/forks/JZKK720/ — read-only backups, incl. VoltAgent/awesome-design-md, microsoft/SkillOpt, alibaba/open-code-review, EveryInc/compound-engineering-plugin, Shubhamsaboo/awesome-llm-apps, openai/skills, tech-leads-club/agent-skills, coreyhaines31/marketingskills, humanlayer/skills, kunchenguid/firstmate, blader/humanizer, petergyang/no-ai-slop, cathrynlavery/diagram-design, tt-a1i/archify, virgiliojr94/book-to-skill, alchaincyf/huashu-design, loop-engineering, watch-skill, wigolo, pbakaus/impeccable, wuyoscar/jev-skill — the last as a **sparse, depth-1** checkout with its `.git` trimmed
(v1.9.1), since upstream is a ~358 MB application rather than a skill package. That mirror is
now **static**: sync skips it as "not a git checkout", so it will not auto-update. 21 of the 50
mirrors are static; the other 20 stay syncable.)

### SkillOpt-Sleep (nightly self-evolution)

The setup schedules a **SkillOpt-Sleep** nightly cycle (Phase 5c) that harvests past session transcripts, mines recurring tasks, replays them offline, and stages a validated skill edit for review. Installed as a Windows Scheduled Task at 03:17 daily with `backend=mock` (spends no model budget). Adopt is manual by design — nothing changes until you run `skillopt-sleep adopt`.

```powershell
skillopt-sleep status      # show state + latest staged proposal
skillopt-sleep adopt       # apply the latest staged proposal (with backup)
skillopt-sleep unschedule --all   # remove the nightly task
skillopt-sleep schedule --project ~/dev --backend claude --hour 3 --minute 17
```

Logs land in `<project>/.skillopt-sleep/cron.log`. The Copilot MCP server (`skillopt` in mcp.json) exposes `skillopt_list_configs`, `skillopt_train`, `skillopt_eval` for interactive skill optimization on benchmark configs.

**5 governance docs** (in ~/.agents/ + ~/dev/upstream/):

- README.md, CONFLICTS.md, MEMORY_POLICY.md, UPDATE_POLICY.md, SCAN_LOG.md

### Security model

Every skill is scanned by **NVIDIA SkillSpector** before install:

- `skillspector scan --no-llm <dir>` (static analysis, 68 vulnerability patterns)
- Exit 0 = safe → install proceeds
- Exit 1 = do_not_install → HARD BLOCK, skill is not installed
- Exit 2 = error → investigate before retrying

`skills-ref validate` runs as an ADVISORY check (logs spec drift but doesn't block).

### Skills blocked by SkillSpector (not installed — by design)

| Skill                      | Reason                                                                        | Clean port available?                                                         |
| -------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| brainstorming              | Tool parameter abuse in `stop-server.sh` (visual companion browser server)    | **Yes** → `idea-to-design` (methodology only, no browser server)              |
| last30days                 | Info stealer (reads browser cookies)                                          | No — use `agent-reach` for multi-platform research instead                    |
| ui-ux-pro-max              | Prompt extraction + unsafe defaults                                           | No — use `hallmark` + `taste-skill` for UI design instead                     |
| anysearch                  | Vulnerable `requests==2.20` (8 CVEs)                                          | No                                                                            |
| webapp-testing (oz-skills) | HIGH TM1 — tool parameter abuse (`shell=True` in `scripts/with_server.py:69`) | **Yes** → `webapp-testing` (clean port, methodology only, no bundled scripts) |

### Platform limitations (Windows)

| Tool     | Issue                                                                      | Workaround                                                                                                                                                                 |
| -------- | -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| EverOS   | `import fcntl` (Unix-only)                                                 | Not installed. gbrain MCP used instead.                                                                                                                                    |
| headroom | Windows Defender blocks `ast-grep-cli.exe` (false positive on Rust binary) | Run `bin/add-defender-exclusion-ast-grep.ps1` in an elevated PowerShell first, then `uv tool install "headroom-ai[proxy]"`. Exclusion is scoped to the ast-grep path only. |
| recall   | Needs Claude Code hooks                                                    | Claude Code only; not for VS Code Copilot.                                                                                                                                 |

### After setup

1. **Restart VS Code** (or `Ctrl+Shift+P` → `Developer: Reload Window`)
2. If you used `-IncludeAdditionalEditorProfiles`, restart those editor windows too (Code - Insiders/Cursor/VSCodium)
3. In Copilot Chat, type `#` to see MCP tools appear
4. Try: "use the improve skill to audit this codebase"
5. Try: "use systematic-debugging to investigate this error"

### Verification task notes

- Use `verify-global-bundle` in workspace tasks to run script-backed verification (`bin/verify-global-bundle.ps1`).
- This avoids PowerShell quoting failures from large inline `-Command` strings.

### To update skills later

```powershell
# Standard safe update pass (guarded headroom update + skills-ref repair + gbrain update + smoke)
powershell -NoProfile -ExecutionPolicy Bypass -File .\bin\safe-update-pass.ps1

# Re-run the setup script (it skips already-installed items)
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-global-skills.ps1

# Or update individual tools manually
uv tool upgrade --all
npm update -g
bun install -g github:garrytan/gbrain

# Re-scan all skills quarterly
skillspector scan ~/.agents/skills/ --recursive --no-llm
```

### To add a new skill

```powershell
cd ~/dev/bin
.\install-skill.ps1 -Repo "owner/repo" -Name "skill-name"
# For disabled skills:
.\install-skill.ps1 -Repo "owner/repo" -Name "skill-name" -Disabled
# For custom skill paths:
.\install-skill.ps1 -Repo "owner/repo" -Name "skill-name" -SkillRelPath "path/to/skill"
```

### To port to GitHub (for cross-machine access)

```powershell
cd ~/dev/setup
git init
git add .
git commit -m "Global skills + CLIs + MCP setup package"
git remote add origin https://github.com/JZKK720/cubecloud-skills-bundle-kit.git
git push -u origin main
```

Then on any new machine:

```powershell
git clone https://github.com/JZKK720/cubecloud-skills-bundle-kit.git ~/dev/setup
powershell -NoProfile -ExecutionPolicy Bypass -File ~/dev/setup/setup/setup-global-skills.ps1
```
