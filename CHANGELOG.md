# Changelog

All notable changes to the CubeCloud Skills Bundle.

## [1.9.1] — 2026-09-14

Corrected a v1.9.0 size claim and reclaimed 1,482 MB of mirror overhead.

### Fixed — the v1.9.0 "~11 MB" figure was wrong

The impeccable mirror was described as a `~11 MB` sparse checkout. Its real total was
**370.5 MB** — 1.0 MB worktree plus **369.5 MB of `.git`**. The sparse checkout was real, but an
earlier `--deepen 100` had pulled a 301 MB history pack, and the figure counted only the
worktree. Corrected in `README.md`, `CHANGELOG.md`, `setup/skills-list.csv` and
`bin/sync-fork-upstreams.ps1`.

### Root cause — why the mirrors were 2.4 GB

`setup-global-skills.ps1` clones each mirror with `--depth 1`, but `sync-fork-upstreams.ps1`
fetches with a plain `git fetch upstream`, which **un-shallows and accumulates full history**.
Measured directly: one sync run grew the freshly-shallow impeccable mirror from **1.6 MB to
365 MB**. That is why 41 mirrors had accumulated **1,517 MB of `.git` against only 947 MB of
working trees**.

### Changed — 1,482 MB reclaimed

Removed `.git` from the **21 mirrors whose `.git` was ≥ 5 MB**. Nothing reads mirror git
history — verified by grepping every installed skill for `git log|show|blame|diff` against a
mirror path (**zero hits**) — and `install-skill.ps1` clones from GitHub, never from
`~/dev/forks/`.

- Worktrees preserved exactly: file counts verified identical across all 21 (**0 losses**).
- Both skills that actually read a mirror still work: `design-md-library` → **74 `DESIGN.md`**
  files; `archify` → `bin/archify.mjs` present.
- `cubecloud-skilldbundle-setup` (the repo itself, which lives in this directory) was guarded
  in code and left untouched at `453cd42`.

### The trim is durable

A mirror without `.git` is `SKIP`ped by sync as *"not a git checkout"*, so it can never be
re-fattened. `sync-fork-upstreams.ps1` now reports `Synced: 0, skipped: 49, Failed: 0`:
**20 mirrors stay syncable** (all small ones) and **29 are static** (the 21 trimmed plus the 8
one-file port stubs). Forks root: **2,470 MB → 988 MB**. Mirror count stays **49** — nothing
was deleted.

### Known limitation introduced

`JZKK720/impeccable` is now static, so it will not fast-forward to upstream. Its content
matches upstream at the revision the 21 ports were cut from, so the ports are correct; a future
re-port needs a fresh `git clone --depth 1 --filter=blob:none --sparse` of
`pbakaus/impeccable` directly. Also noted: the fork's `main` is at `f88b2837` (skill v4.1.1)
while upstream `main` is at `cb56ed6c1`.

### Not fixed — flagged for a decision

`sync-fork-upstreams.ps1` still uses a depth-unlimited `git fetch`, so the 20 remaining
syncable mirrors will keep growing `.git` over time. Fixing it would mean changing the fetch to
`--depth 1` (a behaviour change on a working script), and the fork-vs-upstream FF failure on
shallow mirrors needs a merge-base fallback. Both are deferred rather than rushed.

## [1.9.0] — 2026-09-14

Traced the `impeccable` upstream end-to-end, repaired its provenance, and completed the port
set. The v1.8.0 ports were correct content with an **unreproducible source**: the manifest cited
`~/dev/forks/impeccable/skill/reference/*.md`, which has never existed on this machine, while the
fork `JZKK720/impeccable` was live on GitHub and had never been cloned. `sync-fork-upstreams.ps1`
silently `SKIP`ped the repo as "no upstream mapping". Same failure shape as the orphaned `local/*`
sources fixed in v1.8.2 — an advertised source that does not exist, behind a gate that reports
success while doing nothing.

### Added — 15 ports (impeccable 6 → 21)

`impeccable-adapt`, `impeccable-adapt-native`, `impeccable-audit`, `impeccable-audit-native`,
`impeccable-android`, `impeccable-ios`, `impeccable-colorize`, `impeccable-craft-floor`,
`impeccable-extract`, `impeccable-harden`, `impeccable-operate`, `impeccable-optimize`,
`impeccable-overdrive`, `impeccable-quieter`, `impeccable-shape`.

Upstream exposes **35** compiled reference docs; v1.8.0 ported the 6 whose names matched existing
skills. A coupling audit classified the rest: **21 of 35 are pure prose** — zero instructions to
run a bundled script, no dependency on upstream-only artifacts. 14 were **excluded at the
document level**, not by keyword: `live`, `live-setup`, `init`, `new-work`, `critique`,
`visualize` (live browser iteration), `hooks`, `doctor`, `routing` (script-driven), `layout`,
`typeset`, `polish` (script-coupled), `craft` (deprecated alias), and `document` (28 refs to
`PRODUCT.md` / `.impeccable/design.json` / "the live panel").

### Why ports and not a direct install

Verified rather than assumed. Upstream ships one catch-all skill whose `SKILL.md` mandates
`node scripts/context.mjs`. Its `.agents/skills/impeccable` payload is **153 files**, including a
513 KB live-browser bundle, a 260 KB detector ruleset, a 121 KB question server, a 97 KB hook
library, and `hook-before-edit.mjs`, which intercepts every file edit. That is a code-execution
surface, not a prose library. The ports stay.

### Added — provenance

> **Superseded by v1.9.1.** The size figures below were wrong: the mirror really totalled
> 370.5 MB (not `~11 MB`) because `.git` still held full history. See the v1.9.1 entry.

- `~/dev/forks/JZKK720/impeccable` is now a **sparse, blob-filtered checkout (~11 MB)** of the
  fork, fast-forwarded to `pbakaus/impeccable` `upstream/main` at `cb56ed6c1`. A full clone would
  have been ~338 MB. The sparse path keeps `skill/reference`,
  `.agents/skills/impeccable/reference`, and both `SKILL.md` files, and still supports
  `sync-fork-upstreams.ps1`'s fetch/fast-forward contract.
- `sync-fork-upstreams.ps1`: added `"impeccable" = "pbakaus/impeccable"` to `$upstreamMap`.
- `setup/skills-list.csv`: the impeccable block now records the real source of record
  (mirror path, fork, commit, the compiled-vs-source file distinction, and the port/exclude
  rule), replacing the dangling `~/dev/forks/impeccable/` reference.
- A shallow-clone artifact was ruled out: `git merge --ff-only upstream/main` first failed with
  "refusing to merge unrelated histories", but after `git fetch --deepen 100` the merge-base
  resolved to the fork HEAD and fast-forward succeeded. Two `--depth 1` histories simply share no
  ancestor.

### Fixed

- **A UTF-8 BOM in all 15 newly generated ports.** The first pass wrote files via PowerShell's
  `Set-Content -Encoding UTF8`, which emits a BOM on PowerShell 5.1. That byte order mark is an
  invisible character at `SKILL.md:1`, so every port failed **both** SkillSpector
  (`HIGH: Hidden Instructions`, 60% confidence) **and** `skills-ref validate`
  (`must start with YAML frontmatter`). Writing BOM-free UTF-8 via `UTF8Encoding($false)` cleared
  both simultaneously; the gate's diagnostic was accurate, not a false positive.
- **`document` dropped after porting.** It passed the coupling screen but carried 28 references to
  upstream-only artifacts and "the live panel". Removed rather than shipped; count corrected
  16 → 15.
- **Ports regenerated from current upstream.** The mirror was four skill-versions behind
  (`f88b2837` = v4.1.1 → `cb56ed6c1`). Four ported docs had already changed upstream — `adapt`
  (+6), `audit` (+2/-1), `audit.native` (+1/-1), `harden` (+9), all new touch/gesture prose
  (`pointercancel`, `lostpointercapture`, interrupted gestures). All 15 were regenerated from
  `upstream/main` so they ship current instead of recreating drift. The 6 v1.8.0 ports were
  confirmed byte-identical to current upstream (0 changes).
- **Stale v1.8.0 counters.** `188 → 223 active manifest rows (20 are local/* ports)` is now
  `188 → 223` at v1.8.0 and `223 → 238` at v1.9.0 (`35 are local/* ports`).
- **Mojibake in the ported bodies (70 characters).** After the BOM fix the gate was green, but a
  byte-level audit found `U+9225` (鈥) where em-dashes belonged and `U+922B` (鈫) where arrows
  (`→`) belonged, across 15 of the 21 ports. Cause: **PowerShell 5.1 decodes a BOM-less file as
  ANSI**, so both `Get-Content -Raw` on the upstream source *and* the non-ASCII literals in the
  generation script were mangled (`Desktop 鈫?Mobile` instead of `Desktop → Mobile`). Fixed by
  reading sources through an explicit UTF-8 decoder (`[Text.Encoding]::UTF8.GetString`) and
  keeping the authored descriptions pure ASCII. Arrows and em-dashes now survive as real
  `U+2192` / `U+2014`; verified 70 → **0** corrupted characters across all 21 ports. Note the
  gate did **not** catch this — SkillSpector and `skills-ref` both passed on the mojibake, so it
  required a byte-level check.

### Verified

- Gate: 15/15 SAFE, **0 blocked**; issues are three benign heuristic matches — two
  "Autonomous Decision Making" hits (`audit`, `audit-native`) pointing at an *anti*-pattern list,
  and one "Memory Manipulation" hit (`colorize`) on a line that instructs asking the human.
- `skills-ref validate`: **15/15 valid**.
- Sources resolve: **21/21** `impeccable-*`; installed copies hash-match sources **15/15** in both
  roots.
- Counters: manifest **238** (237 active + 1 disabled), `local/*` **35**, fork mirrors **49**,
  installed **286** `~/.agents/skills/` + **506** `~/.claude/skills/`. 0 empty fork mirrors,
  0 skills missing a `SKILL.md`.

## [1.8.2] — 2026-09-14

Release verification. No feature changes.

### Fixed — two `local/*` port sources were never committed to git

`local/evidence-graph-review` and `local/ops-authorization-methodology` were advertised by the
manifest, but `upstream/evidence-graph-review/` and `upstream/ops-authorization-methodology/`
did not exist on disk and had **never** existed in git history (`git log --all -- <path>` is
empty).

The installer's guard is a silent `SKIP`, never an error:

```
SKIP (local source missing or no SKILL.md)
```

So on **any fresh machine** those two rows were quietly skipped and counted as "skipped", while
the install still reported success. The skills existed here only because they were hand-authored
in place. Both installed copies are real content (82 and 87 lines), so the port text was
**recoverable, not lost** — unlike the `book-to-skill` incident in v1.7.0.

Recovered byte-exactly from `~/.agents/skills/<name>/SKILL.md` back into `upstream/`, after
confirming neither copy carried an install-time `argument-hint:` that must not be written back.
All 20 `local/*` rows now resolve; verified 20/20.

Found by checking every manifest row's **source path** against the filesystem. A count-only audit
would have missed it entirely.

### Fixed — stale counters

- `21 are local/* ports` → **20**, in CHANGELOG v1.8.0 and the 2026-09-13 evaluation plan.
  The count was taken before `local/humanizer` was converted to an upstream install.
- `36 new rows` → **35**, in the same evaluation plan's file-changes table.

## [1.8.1] — 2026-09-14

### Added

- **Opt-in `archify` CLI** via `setup-global-skills.ps1 -IncludeArchifyCli`. Writes a single
  86-byte `~/.local/bin/archify.cmd` shim that forwards to the archify fork mirror's
  `bin/archify.mjs`.

  `archify` is a **zero-runtime-dependency** Node CLI — `bin/archify.mjs` imports only `node:`
  stdlib, and the mirror has no `node_modules` and needs none. Verified before shipping:

  ```
  archify doctor                                     -> exit 0, all 15 checks ok
  archify render architecture production-deployment  -> 820,813 bytes, exit 0
  archify validate architecture ... --quality showcase -> exit 0, receipt present
  ```

  **Why a shim and not an npm install:** upstream `package.json` sets `"private": true`, so
  the package can never be published to or installed from the npm registry. It also needs
  nothing but Node >= 18, which the installer already requires. A two-line `.cmd` has no
  version to drift, no lockfile, and nothing to uninstall.

  **Why opt-in:** every other phase of the installer is unconditional. This one puts a new
  command on the user's PATH — a visible system change — so it requires the switch. It also
  depends on the archify fork mirror, so it is incompatible with `-SkipForks`; the installer
  warns and continues rather than failing.

  The phase runs `archify doctor` before writing the shim, so it never advertises a command it
  has not verified. The `%USERPROFILE%` reference is expanded when the shim *runs*, not when it
  is written, so it survives re-clones.

  This is a **CLI-only** addition. The archify *skill* is still the clean methodology port at
  `upstream/archify/` — upstream the skill is SkillSpector-blocked (HIGH MP3), and the gate does
  not apply to the CLI as a separate concern.

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

### Fixed — pre-existing, found during release verification

- **Two `local/*` port sources were never committed to git.** The manifest advertised
  `local/evidence-graph-review` and `local/ops-authorization-methodology`, but
  `upstream/evidence-graph-review/` and `upstream/ops-authorization-methodology/` did not
  exist on disk and had **never** existed in git history (`git log --all -- <path>` is empty).

  The installer's guard is a silent `SKIP`, never an error:

  ```
  SKIP (local source missing or no SKILL.md)
  ```

  So on **any fresh machine** those two rows are quietly skipped and counted as "skipped",
  and the install still reports success. The skills exist here only because they were
  hand-authored in place. Both installed copies are real content (82 and 87 lines), so the
  port text was **recoverable, not lost** — unlike the `book-to-skill` incident in v1.7.0.

  Recovered byte-exactly from `~/.agents/skills/<name>/SKILL.md` back into `upstream/`,
  after confirming neither copy carried an install-time `argument-hint:` that must not be
  written back. All 20 `local/*` rows now resolve; verified 20/20.

  Worth noting how this was found: not by reading the docs, but by checking every row's
  source path against the filesystem. A count-only audit would have missed it entirely.

### Fixed — counters (v1.8.1 era)

- Skills: 188 → 223 active manifest rows (20 are `local/*` ports)
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
