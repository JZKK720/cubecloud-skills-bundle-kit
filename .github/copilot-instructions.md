# CubeCloud Skills Bundle — Copilot instructions

## What this repo is

A Windows PowerShell toolkit where **the scripts are the product** — there is no application
code. Running the installer provisions a global VS Code Copilot Chat stack **onto the machine,
outside this repo**: skills into `~/.agents/skills/` (mirrored to `~/.claude/skills/`), CLIs onto
`PATH`, MCP servers into VS Code `User/mcp.json`, fork mirrors into `~/dev/forks/JZKK720/`, and
governance docs/scan logs into `~/.agents/` and `~/dev/upstream/`. Editing code here means editing
the installer, the skill manifest, the verification scripts, or the vendored skill sources.

Headline shape: a manifest of **275 skills**, **20 CLIs**, and **12 MCP servers**, plus vendored
clean-ports and a design-system library. **[../README.md](../README.md) is the single source of
truth for every count** and CI enforces it (see below). Other docs can lag — e.g.
[../AGENTS.md](../AGENTS.md)'s on-disk and fork-mirror numbers have drifted from README and are
*not* gate-enforced; when counts disagree, trust README and the live manifest.

## The one rule that bites: counts must reconcile, and CI enforces it

The row count of [../setup/skills-list.csv](../setup/skills-list.csv) is the real source of truth.
[../bin/check-bundle-integrity.ps1](../bin/check-bundle-integrity.ps1) (run by the
[bundle-integrity](workflows/bundle-integrity.yml) workflow on every push/PR) **fails CI** unless
that count equals:

- the README `skills-N%20bundled` badge, the `N bundled skills (` and `Skills (N bundled` claims,
  the `manifest of N entries` layout line, and the README active/disabled split;
- the `N bundle skills` claim in [../AGENTS.md](../AGENTS.md);
- the per-disposition breakdown the README publishes for
  [../setup/skills-unmanaged.txt](../setup/skills-unmanaged.txt);
- every count-stamping regex in [../bin/make-release.ps1](../bin/make-release.ps1) (a regex that
  matches README zero times is also a failure — it would silently leave stale numbers behind).

So if you **add or remove a manifest row, update README (and AGENTS.md's `bundle skills` number)
in the same change**, or CI goes red. The integrity gate inspects only repo artifacts (no installed
skills/CLIs/MCP required), so it is the first thing to run after touching the manifest, README, or
any `.ps1`.

## Verify / lint / "test" commands

There is no unit-test framework; verification is script-driven. Pick the **narrowest** script for
what you changed — that is the "single test" equivalent.

| Scope | Command | Notes |
| --- | --- | --- |
| Repo artifacts only (what CI runs) | `pwsh -NoProfile -File bin/check-bundle-integrity.ps1` | AST-parses every `.ps1` in `bin/` + `setup/`, validates `mcp.json.template` + `.vscode/tasks.json` JSON, checks CSV integrity + `local/*` resolution, reconciles all counts. Exit 1 on any FAIL; WARN never fails. **No install needed.** |
| Installed machine, full | `.\bin\full-audit.ps1` | Canonical parameter-less audit; 7 inline phases (MCP + daemon liveness → CLI version probes → `skills-ref validate` → SKILL.md frontmatter → `~/.claude/skills` mirror parity → disabled/docs/forks → SkillSpector re-scan). Writes `~/dev/upstream/AUDIT_REPORT.md`; final line `PASS: N | FAIL: N | WARN: N | ADVISORY: N` (report WARN and ADVISORY separately, never unioned). |
| Installed machine, fast | `.\bin\fast-audit.ps1` | Same result matrix minus the hanging MCP-daemon probes. |
| Quick global-state check | `.\bin\verify-state.ps1` | Console-only PASS/MISS/FAIL/INFO, exit 1 on failure; reads expected MCP set from `setup/mcp.json.template`. |
| MCP servers in isolation | `.\bin\mcp-smoke-test.ps1` | Deterministic `--help` probes (no daemons); writes `~/dev/upstream/MCP_SMOKE_TEST.md`. |
| Inside VS Code | Run the `verify-global-bundle` task | → [../bin/verify-global-bundle.ps1](../bin/verify-global-bundle.ps1); avoids large inline `-Command` quoting failures. Delegates MCP checks to [../bin/validate-mcp.ps1](../bin/validate-mcp.ps1). |

Install / maintenance entry points (run from the **repo root**):

- Install everything: `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\setup-global-skills.ps1`
  — switches: `-SkipForks`, `-SkipAudit`, `-IncludeAdditionalEditorProfiles`, `-IncludeArchifyCli`.
- Add one skill: `.\bin\install-skill.ps1 -Repo owner/repo -Name skill-name` (`-Disabled`,
  `-SkillRelPath ...`, `-SourcePath ...`, `-BaselinePath ...`).
- Safe update pass: `.\bin\safe-update-pass.ps1`. Cut a release: `.\bin\make-release.ps1 [-NoPush]`.

## Architecture: two worlds

**1. Repo artifacts (what you edit):**

- [../setup/](../setup/) — the installer and its config: `setup-global-skills.ps1` (phases 0–7),
  `install-skill.ps1` (the security-gated scan→validate→copy helper), `skills-list.csv` (the
  manifest), `mcp.json.template` (the 12-server source of truth), `skills-unmanaged.txt`.
- [../bin/](../bin/) — audit / verify / repair / release scripts. All share the prelude in
  [../bin/lib/bundle-common.ps1](../bin/lib/bundle-common.ps1) (dot-source it; see conventions).
- [../upstream/](../upstream/) — vendored skill sources for `local/*` manifest rows (clean ports of
  SkillSpector-blocked upstreams) plus governance docs and generated audit reports.
- [../baselines/](../baselines/) — SkillSpector suppression baselines (`<name>.baseline.yaml`).
- [../plans/](../plans/), [../docs/plans/](../docs/plans/) — dated, step-by-step plan/eval reports.

**2. Install targets (what the installer writes, outside the repo):** `~/.agents/skills/` (+
`~/.claude/skills/` mirror), CLIs on `PATH`, VS Code `User/mcp.json`, `~/dev/forks/JZKK720/`,
`~/dev/upstream/*.md` reports. Audit scripts inspect **these**, so they only pass on a provisioned
machine; `check-bundle-integrity.ps1` inspects only the repo and passes anywhere.

Data flow: `setup-global-skills.ps1` Phase 4 reads each `skills-list.csv` row and shells out to
`install-skill.ps1`, which runs `skillspector scan --no-llm --baseline <...>` (exit 0 = install,
1 = hard block, 2 = error) then `skills-ref validate` (advisory) before copying the skill into
both skill roots. [../Update-Skills.ps1](../Update-Skills.ps1) is a thin legacy CSV-driven wrapper
over the same helper.

## Key conventions (non-obvious)

- **Manifest format** — `skills-list.csv` is **pipe-delimited**, not comma:
  `repo|name|skillRelPath|disabled[|localSourcePath]`. Lines starting with `#` are parked skills
  (kept with an inline reason code), not active rows. A row is "active" per the regex
  `^[a-zA-Z][^|#]*\|`; the 4th field `true` means disabled.
- **`local/*` rows install from disk, never GitHub** — a row whose repo field is `local/<name>`
  is a hand-authored port vendored at `upstream/<name>/` (or the optional 5th-column path). The
  installer resolves it to `-SourcePath` and **skips** it if `SKILL.md` is missing; the integrity
  gate fails if any `local/*` row has no `SKILL.md`. Never rewrite a `local/*` row into a clone URL.
- **Shared prelude** — dot-source [../bin/lib/bundle-common.ps1](../bin/lib/bundle-common.ps1) in
  new `bin/` scripts: `Initialize-BundlePath` (prepends tool dirs + sets `PYTHONUTF8=1`),
  `Get-BundleRoot`, `Resolve-SkillBaseline`, and `Test-BundleMcpServers`
  (`setup/mcp.json.template` is the single source of truth for the expected MCP set; leaf-name
  normalization means gallery `owner/name` installs don't read as missing). Don't re-inline these.
- **Keep CI-parsed `.ps1` ASCII-only** — CI runs `pwsh` (UTF-8) while local runs Windows
  PowerShell 5.1 (ANSI on a BOM-less file), so a literal em-dash or emoji in a count-check regex
  behaves differently across them and breaks matching. Use `.` to match a dash in those regexes.
- **Suppression baselines are required for reviewed skills** — a bare `skillspector scan`
  re-blocks them. `install-skill.ps1` and the audit scripts pass `--baseline`, resolving in order:
  explicit `-BaselinePath` → `baselines/<name>.baseline.yaml` → `~/dev/baselines/<name>...` →
  `$env:SKILL_BASELINES_DIR`. If a skill shows an unexpected `do_not_install`, check for a baseline
  before assuming the scanner disagrees.
- **Two fork names intentionally differ from upstream** — `install-skill.ps1` clones
  `JZKK720/<last-path-segment>`, but `tech-leads-club/agent-skills` → `tech-leads-club-agent-skills`
  and `openai/skills` → `openai-skills`, because the naive names collide with other active mirrors.
  Don't "simplify" them.
- **`install-missing-skills.ps1 -WhatIf` is NOT a dry run** — `-WhatIf` only gates the refresh path;
  the install path shells out to `install-skill.ps1` with no propagation and really installs. To
  preview, read `skills-list.csv` directly — the rows are the plan.
- **`>nul 2>nul` hides clone failures** — when adding a clone line to the installer, confirm the
  variable is `"$var"` (a backtick before `$` makes it a literal `$var` argument) and that the
  directory actually appears afterward.
- **Generated reports live in `~/dev/upstream/`, not the repo** — don't commit audit output.

## Where to look next

- [../AGENTS.md](../AGENTS.md) — the deep operational playbook (phase-by-phase installer surface,
  dated-fix rationale, the full verification routine and counter reconciliations).
- [../setup/SETUP_GUIDE.md](../setup/SETUP_GUIDE.md) — installer phases, prerequisites, security
  model, and the SkillSpector blocked-skills table.
- [../CHANGELOG.md](../CHANGELOG.md) — dated record of fixes; cite it, don't restate it.
- `graphify` — when `graphify-out/graph.json` exists, prefer `graphify query "<question>"` (and
  `graphify path`/`graphify explain`) over broad grep for architecture/relationship questions;
  `/graphify` in Copilot Chat builds or refreshes the graph.
