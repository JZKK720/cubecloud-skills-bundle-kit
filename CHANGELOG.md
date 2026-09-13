# Changelog

All notable changes to the CubeCloud Skills Bundle.

## [1.8.0] — 2026-09-13

14-repo evaluation. 104 candidate skills gated with `skillspector scan --no-llm`.

### Added — 35 skills

- **tech-leads-club/agent-skills (MIT), 12** — DDD set (`domain-analysis`,
  `domain-identification-grouping`, `coupling-analysis`, `decomposition-planning-roadmap`,
  `tactical-ddd`, `modular-design-principles`), plus `create-technical-design-doc` (1055
  lines), `create-rfc`, `harness-eval`, `spec-driven-eval`, `not-your-babysitter`,
  `learning-opportunities`. Fork: `JZKK720/tech-leads-club-agent-skills`.
- **coreyhaines31/marketingskills (MIT), 8** — `product-marketing`, `copywriting`,
  `content-strategy`, `competitor-profiling`, `launch`, `pricing`, `marketing-loops`,
  `marketing-psychology`. Fork: `JZKK720/marketingskills`.
- **openai/skills (Apache-2.0 per skill), 5** — `figma`, `screenshot`, `pdf`, `transcribe`,
  `security-threat-model`. Fork: `JZKK720/openai-skills`.
- **kunchenguid/firstmate (MIT), 4** — `bearings`, `diagnostic-reasoning`,
  `bootstrap-diagnostics`, `project-management`. Fork: `JZKK720/firstmate`.
- **humanlayer/skills (MIT), 3** — `show-me`, `improve-claude-md`,
  `narrow-react-prop-types`. Fork: `JZKK720/humanlayer-skills`.
- **Prose de-slopping, 2** — `humanizer` (blader/humanizer, MIT, 291 lines) and
  `no-ai-slop` (petergyang/no-ai-slop, MIT, 61 lines).
- **archify (clean port, 1)** — tt-a1i/archify is gate-BLOCKED (`HIGH MP3`). Methodology-only
  port at `upstream/archify/SKILL.md`; gates 0/100 SAFE. Drops the renderer/schemas/examples.

### Fixed

- **`i-have-adhd` manifest path.** Upstream moved the skill from `.cursor/skills/` to
  `skills/`; the stale row would have failed with `SKILL.md not found` on every fresh machine.
- **Two fork-name collisions.** The naive fork names were already taken by unrelated repos:
  `agent-skills` (held by addyosmani — this bundle's active mirror, 23 rows depend on it) and
  `skills` (held by vercel-labs). Forked as `tech-leads-club-agent-skills` and `openai-skills`.
- **Stale clone URL in Quick start** — the repo was renamed to `cubecloud-skills-bundle-kit`.

### Excluded

- **OpenMontage** — AGPL-3.0. **WeKnora / OpenMAIC** — products, not skill packages.
- **19 gate-blocked entries parked as comments** with reason codes, so the installer stops
  retrying them.

### Changed

- Skills: 188 → 223 active manifest rows (21 are `local/*` ports)
- Fork mirrors: 39 → 48
- Installed: 236 → 271 in `~/.agents/skills/`
- `skills-ref` valid: 167 → 196

### Verified

`full-audit.ps1` → `PASS: 51 | FAIL: 0`. `install-missing-skills.ps1` re-run →
`Installed: 0 / Blocked: 0 / Skipped: 223`. `sync-fork-upstreams.ps1` → `Failed: 0`.
`humanizer` byte-identical to upstream (29102 bytes). All 9 `install-skill.ps1` copies still
hash identically.

## [1.7.0] — 2026-09-13

- **Added `-Refresh` to `install-missing-skills.ps1`** — updates already-installed skills whose
  SKILL.md content differs from source, without reinstalling. Guards `local/*` ports and
  `codex-review` / `codex-build`, and preserves the install-time `argument-hint:`.
- First run brought 79 skills up to date.
- **Incident:** the first refresh shipped with a too-narrow protection rule and overwrote two
  ports — `book-to-skill` (702 → 414 lines, unrecoverable) and `diagram-design` (565 → 273,
  recovered). The rule was then implemented in code, not prose.

## [1.6.3] — 2026-09-13

- Tracked the upstream `crucible` → `claudex-loop` rename; added `constraint-driven-development`,
  `budget-negotiator`, `install-loop`, `counterparty-channel-discipline`,
  `operator-approval-loop`. Pruned 17 gate-blocked entries to comments.

## [1.6.2] — 2026-09-13

- Repaired the install/update pipeline, portability, and stale counters.

## [1.6.1] — 2026-09-13

- Integrated context-engineering-kit (35 unique skills).

## [1.1.0] — 2026-07-29

### Added

- **archify** (`tt-a1i/archify`, MIT, 7.8k★) — agent skill for interactive architecture, workflow, sequence, dataflow, and lifecycle diagrams. Generates self-contained HTML with inline SVG, dark/light themes, and PNG/WebP/SVG/WebM export. SkillSpector: 0/100 LOW/SAFE. Zero Claude Code coupling.
- Fork mirror: `~/dev/forks/JZKK720/archify/`

### Changed

- Skills: 144 → 145
- Fork mirrors: 32 → 33

> Superseded in 1.8.0: upstream `archify` is now **gate-blocked** (`HIGH MP3`), so it ships as a
> clean methodology-only port instead of a direct install.

## [1.0.0] — 2026-07-23

### Initial release

- 144 skills (superpowers methodology, ui-skills, agent-skills, ECC agent engineering, Azure patterns, design systems, code review, debugging)
- 16 CLIs on PATH
- 11 MCP servers
- 32 fork mirrors
- 74 DESIGN.md files
- Security-gated install pipeline (SkillSpector + skills-ref)
