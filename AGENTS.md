# CubeCloud Skills Bundle — Copilot Instructions

## What this repo is

A Windows PowerShell toolkit (no application code — **scripts are the product**) that installs a
global VS Code Copilot Chat stack: 257 bundle skills (284 on disk incl. 27 Azure/Entra/Foundry
extension skills), 18 CLIs, 11 MCP servers, 50 fork mirrors, 74 DESIGN.md files — all gated by
NVIDIA SkillSpector. The source of truth for every count is [README.md](README.md) (badges +
"What you get" table); [setup/SETUP_GUIDE.md](setup/SETUP_GUIDE.md) documents phases and
verification; [CHANGELOG.md](CHANGELOG.md) records dated fixes. Link, don't duplicate.

## Layout map

| Path | Role |
| --- | --- |
| `setup/setup-global-skills.ps1` | Global installer (phases 0–7) — see "Installer surface" below |
| `setup/skills-list.csv` | **Pipe-delimited** manifest: `repo\|name\|skillRelPath\|disabled[\|localSourcePath]`; `local/*` rows point at vendored clean-ports under `upstream/` |
| `bin/*.ps1` | Audit/repair/verify scripts; shared prelude (PATH prepend + `PYTHONUTF8=1`), emit Markdown reports into `~/dev/upstream/` (`AUDIT_REPORT.md`, `MCP_SMOKE_TEST.md`) or console PASS/MISS/FAIL lines |
| `upstream/` | Vendored skill sources for `local/*` manifest rows — mix of methodology-only clean ports (`archify`, `webapp-testing`, `idea-to-design`) and adapted copies (`agent-reach`) |
| `docs/plans/` | Dated evaluation/plan reports |
| `plans/001-local-addon-sourcepaths.md` | **Closed P1 fix (DONE)** — see "Closed: plan 001" below |

## Full verification routine (run this, in order)

Use `bin/full-audit.ps1` — the canonical, **parameter-less** audit. It is self-contained
(no sub-script calls), runs 7 inline phases, and writes `~/dev/upstream/AUDIT_REPORT.md`:
MCP `mcp.json` + 6 daemon liveness probes → 10 CLI version probes → `skills-ref validate`
per skill → SKILL.md frontmatter check → `~/.claude/skills` mirror parity → disabled/docs/forks
existence → SkillSpector re-scan. Final line: `PASS: N | FAIL: N | WARN: N | ADVISORY: N`.
WARN and ADVISORY are counted separately — report both, never a unioned count.

For fast iterations when MCP daemons are irrelevant or would hang the run, `bin/fast-audit.ps1`
is the same result-matrix minus daemon tests. For a quick global-state check,
`bin/verify-state.ps1` is console-only (PASS/MISS/FAIL/INFO, exit 1 on failure) and reads the
expected MCP set from `setup/mcp.json.template` (the single source of truth; leaf-name
normalization means gallery installs don't read as missing).

Smoke-testing MCP servers in isolation: `bin/mcp-smoke-test.ps1` (deterministic `--help` probes,
writes `~/dev/upstream/MCP_SMOKE_TEST.md`, no hanging daemons). In VS Code, the verified path is
the `verify-global-bundle` workspace task → `bin/verify-global-bundle.ps1` (avoids large inline
`-Command` quoting failures).

## Verification = counters + counts, every time

A session is only "done" when the numbers reconcile. Check all four:
1. `bin/full-audit.ps1` → report the PASS/FAIL/WARN/ADVISORY line explicitly.
2. `(Get-ChildItem ~/.agents/skills -Directory).Count` vs README badge (284 on disk / 257 bundled).
3. `~/.agents/skills._disabled/` count vs README (14: 1 upstream + 13 Copilot-incompatible).
4. Manifest row count in `setup/skills-list.csv` (257: regex `^[a-zA-Z][^|#]*\|`) vs README "257".
   Comment/blank lines do not count. If numbers diverge, fix counters inline **and the truth**.

## Post-merge workflow

After merging from `origin/main` or installing any new skills batch:
1. Run the full verification routine above (or at minimum `bin/full-audit.ps1`) and report PASS / FAIL / WARN counts.
2. Re-check all four counter reconciliations. If they diverge, flag it before claiming completion.

## Closed: plan 001 `local/*` installs (fixed + verified)

Plan [plans/001-local-addon-sourcepaths.md](plans/001-local-addon-sourcepaths.md) is the gate for
"fully verified": `local/impeccable-audit`, `local/impeccable-craft-floor` etc. rows in the CSV are
rewritten into bogus GitHub clone URLs by the installer, so the clean-port replacements for
SkillSpector-blocked upstreams silently never install (**P1/M/MED**). Verified fix: the installer
must pass `-SourcePath` (already supported by `bin/install-skill.ps1`) for `local/*` rows. Do not
declare full verification complete while this plan is open; run its drift-check
(`git diff --stat b5c05f2..HEAD`) and respect its STOP conditions before editing.

## Installer surface (know before touching setup-global-skills.ps1)

`[CmdletBinding()]` switches: `-SkipForks`, `-SkipAudit`, `-IncludeAdditionalEditorProfiles`
(MCP + model pins for Code-Insiders/Cursor/VSCodium), `-IncludeArchifyCli` (opt-in 86-byte
`~/.local/bin/archify.cmd` shim; needs fork mirrors — incompatible with `-SkipForks`, warns and
continues). Phases: 0 prereqs (uv/bun) · 0b PATH+PYTHONUTF8 persist · 0c dir skeleton ·
1 SkillSpector+skills-ref · 2 18 CLIs · 3 clone 50 forks · 3b archify shim ·
4 install 257 manifest skills (security-gated) · 5 write 11 MCP servers to `User/mcp.json` ·
5b Copilot utility model pins · 5c SkillOpt-Sleep nightly task · 6 governance docs · 7 audit.

## `install-missing-skills.ps1 -WhatIf` does NOT prevent installs

Verified 2026-09-13. `-WhatIf` only gates the **refresh** path (via
`$PSCmdlet.ShouldProcess`). The **install** path calls `install-skill.ps1` as a child process
with no `-WhatIf` propagation, so it **really installs everything**.

Do not treat `-WhatIf` as a dry run. It is not safe to run for a preview. If you want a
preview, read `skills-list.csv` directly instead — the rows are the plan. To genuinely verify
without installing, check source-path existence for each row.

## Two fork names are deliberately NOT the upstream repo name

`install-skill.ps1` clones `JZKK720/<last-path-segment>`. Two candidates collided with
unrelated pre-existing forks, so both were forked under a new name:

| Upstream | Naive name (already taken by) | Actual fork |
| --- | --- | --- |
| `tech-leads-club/agent-skills` | `agent-skills` (addyosmani/agent-skills — **this bundle's active mirror**) | `tech-leads-club-agent-skills` |
| `openai/skills` | `skills` (vercel-labs/skills) | `openai-skills` |

Never "simplify" these names. A naive clone of the tech-leads-club repo into `agent-skills`
would overwrite the addyosmani mirror that 23 manifest rows depend on.

## Escaped-dollar in `git clone` lines is a silent failure

`setup-global-skills.ps1` had two clone lines written as `` `$"var`" `` (backtick-dollar = an
escaped literal `$`). Those interpolated nothing, so the clone command received a literal
`$<path>` argument and failed silently under `>nul 2>nul`. Effect: `archify` and `book-to-skill`
mirrors were never created by the installer. Fixed 2026-09-13.

When adding a clone line, confirm the variable is `"$var"` (no backtick) and that the
directory actually appears afterward — `>nul 2>nul` hides every error.

## Large install batches (10+ skills)

When installing 10+ skills in one session, start each batch in its own sub-process invocation so a single skill failure doesn't orphan the rest. If the batch exceeds ~20 skills, suggest a fresh chat or `/compact` to avoid context exhaustion mid-batch.
