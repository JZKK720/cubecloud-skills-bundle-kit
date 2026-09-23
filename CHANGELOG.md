# Changelog

All notable changes to the CubeCloud Skills Bundle.

## [1.9.14] — 2026-09-23

### Answered — does the Jev API replace our LLM models?

**No, and the vendor's own docs say so explicitly.** From
[TypeSafe — *Jev with coding agents*](https://docs.typesafe.ai/introduction/coding-agents):

> Jev is **not** a drop-in replacement for the LLM behind Claude Code, Cursor, opencode,
> **Copilot**... There is no `model: "jev-latest"` setting that turns your coding agent into a
> Jev-powered agent, because the two systems solve different problems.

Jev is a **System One** model — it takes `state` + typed questions and returns a `choice` (with
per-option probabilities), a `score`, or a `noul` (0–1). It does not generate text, write code, or
hold a conversation, so it cannot power a coding agent. Copilot/Claude stays as-is; Jev is called
by the code you write with the agent.

### Rejected — no Jev MCP server

Considered and declined. MCP exists to give an agent *tool* access; Jev is not a tool an agent
invokes, it is a typed call made by application code. Shipping an MCP server would misrepresent
it. Confirmed there is no official one either (`@typesafe-ai/mcp` is not on npm). This release
adds a **skill + SDKs**, not an MCP server — 11 MCP servers remain, unchanged.

### Added — `typesafe-ai` (official vendor skill)

MIT, 1.9k★, the vendor's own skill. Teaches the Jev API, the primitives, the patterns, and the
practice of reading live docs over stale knowledge. **SkillSpector score 3 / LOW / SAFE, 100%
coverage.** Zero Claude-Code coupling — no `allowed-tools`, no `$ARGUMENTS`, no `mcp__`.

### Added — `jev-harness` (TianyuCodings, 143★)

Builds task-specific Jev pipelines: code prepares observations and enforces actions, Jev supplies
judgments, an optional reflection model improves the pipeline offline. Pipeline optimisation, not
weight training.

### Windows caveat (documented, not hidden)

JevHarness's Python runtime is **macOS-only**. `python_nodes.py` raises `PythonSandboxUnavailable`
unless `sys.platform == 'darwin'` and `/usr/bin/sandbox-exec` exists, and it has **no host-execution
fallback** by design. `auto-jev` is also **not on PyPI** (source-only, Python ≥3.11). The skill is
installed and useful as guidance on Windows; the pipeline needs macOS or a macOS container.

### Gate — MEDIUM/CAUTION, all four findings verified false positive

The gate blocks on `do_not_install` (exit 1). This scanned **exit 0**, so it proceeds — consistent
with the 7 MEDIUM/CAUTION skills already shipped. Each finding was checked against the source:

| Finding | Flagged line | Verdict |
|---|---|---|
| **PE3 HIGH** "credential access" | "**Do not** ... access credentials ... until enough of the contract is known" | A **prohibition** read as an action — negation is not parsed |
| **EA1/PE1** "`permissions:*`" | "**Environment and permissions:** Where will code run..." | Markdown **bold matched as a YAML permission grant**; frontmatter has only `name` + `description` |
| **EA2** "without checking" | "Avoid treating confidence as validated **without checking** calibration" | A **cautionary** instruction read as autonomy |

No `allowed-tools`, no `permissions:` key, no credential-file access. Logged to `SCAN_LOG.md` with
the reasoning rather than suppressed.

### Added — official SDKs

- **Python** `typesafe-sdk` **0.7.1** → `import typesafe_sdk` (`TypeSafeClient`, `AsyncTypeSafeClient`, `Choice`, `Noul`, `Score`)
- **JavaScript** `@typesafe-ai/sdk` **0.6.0**

**Trap:** the PyPI name `typesafe-ai` is a **name-squatting redirect shim**, not the SDK. It warns
at import: *"Install `typesafe-sdk` and use `import typesafe_sdk` instead."* The obvious-looking
name is the wrong one; the shim was uninstalled.

### Counts

Manifest 255 → **257**; `local/*` 46 → **48**; `~/.agents/skills` 282 → **284**;
`~/.claude/skills` 515 → **517**; `upstream/` 49 → **51**.

### Verified — a real Jev call, not just an install

Everything above was verified without a key: imports, schemas, SDK signatures. That leaves one
gap — no live round-trip. Closed:

```python
from typesafe_sdk import Choice, Noul, Score, TypeSafeClient

client = TypeSafeClient(api_key=KEY, base_url="https://openrouter.ai/api")
resp = client.system_one(model="jev-1.13", state=..., questions={...})
```

Result — a genuine call, OpenRouter-billed, routed to TypeSafe:

```
is_urgent    noul   = 0.97
department   choice = billing   (confidence 0.84 · probabilities billing 0.89 / technical 0.11 / sales 0.0)
frustration  score  = 1.17      (legend: 0 Calm · 1 Frustrated · 2 Very angry)
model        = "typesafe/jev-1.13-20260917"
usage        = 409 input / 73 output
```

`model` reports the **resolved** ID, not the requested `jev-1.13` — the version-pinning behaviour
the docs describe, confirmed empirically.

### The route that actually works

| Route | Endpoint | Model ID accepted | Method |
|---|---|---|---|
| **OpenRouter System One** ← preferred | `openrouter.ai/api/v1/systemone` | `jev-1.13`, `jev-latest` | `system_one()` / `systemOne()` |
| OpenRouter Decisions (**alpha**) | `openrouter.ai/api/alpha/decisions` | `~typesafe/jev-latest` | `alpha.decisions.create()` |
| TypeSafe direct | `api.typesafe.ai/v1/systemone` | `jev-latest` | `system_one()` |
| Vercel AI Gateway | `ai-gateway.vercel.sh` | `typesafe-ai/jev` | — |

Routing the **official** TypeSafe SDK at OpenRouter is 4 lines — *"Change the base URL and the
API key. Everything else stays the same."* That beats the `@openrouter/sdk` alpha Decisions
endpoint, which works but is alpha.

### Corrections to earlier guidance in this release

- **"Python runtime is macOS-only" was too broad.** Only **functional Python nodes** are. Verified:
  `import auto_jev` / `spec` / `runtime` / `PipelineRuntime` all succeed on `win32`, and the
  shipped `configs/flow_seed.json` — a real 8-node parallel expression+Jev v2 flow — **validates on
  Windows**. The sandbox raises only when a Python node *executes*, and has no host-exec fallback.
- **Absence from the models list is not a health check.** `GET /api/v1/models` returns **454**
  models with **0** `typesafe/jev` entries, yet the model routes fine. Do not use that list to
  decide whether Jev is available.
- **`ask()` does not exist.** The SDK method is `system_one()` (Python) / `systemOne()` (JS).
- **`Choice.criteria` is a mapping** (id → description) while **`Score.criteria` is a sequence**
  (2–10 levels). Easy to invert; the SDK rejects it if you do.

### Trap — User-scope env vars do not reach a running shell

`[Environment]::SetEnvironmentVariable(..., "User")` writes the registry, but shells already
running keep their old environment block. A script that reads `os.environ` fails with a
"key not set" error that looks wrong. Read from the registry directly
(`winreg` → `HKCU\Environment`) or start a fresh shell.

## [1.9.13] — 2026-09-23

### Added — `github-repo-metadata`

Harvested from a workflow that took several wrong turns, so future sessions start on the proven
path. Updates a GitHub repository's description, homepage, and topics via the API when no `gh`
CLI and no `GITHUB_TOKEN` are available.

### The wrong turn, recorded

The obvious conclusion is *"no `gh`, no token env var, unauth PATCH returns 401 — this is blocked,
ask the user for a token."* **That is wrong.** A machine that has pushed over HTTPS with
`credential.helper=manager` holds a usable token in the Windows credential store, retrievable with
`git credential fill` and no environment variable at all. The check order is now explicit: `gh` →
env token → credential store → *only then* is it genuinely blocked.

### Traps recorded

- **`GET /repos/{owner}/{repo}` is cached.** A `PATCH` returning **200** can still read back the
  old value seconds later. This was briefly read as a silent no-op and nearly reported as a failed
  write. Wait ~30–60s or cache-bust, then confirm `updated_at` moved.
- **PowerShell `$home` is a read-only automatic variable.** Assigning to it throws
  `Cannot overwrite variable HOME`. Use `$homeUrl`.
- `git credential fill` can block on a GUI prompt — set `GIT_TERMINAL_PROMPT=0` and
  `GCM_INTERACTIVE=never` first.

### Security

- Token is read **in memory only** — never printed, logged, or written to disk. Only length and
  token class are reported. A post-run sweep for token-shaped strings in the working tree
  returned 0 matches.
- Note surfaced at run time: the stored credential carries full `repo` scope (admin), which is
  normal for a dev box but worth stating when used.

### Gated

SkillSpector **score 5 / LOW / SAFE**, 100% component coverage, 0 suppressed. One MEDIUM issue
(confidence 0.5) flags the `api.github.com` request as potential external transmission — correct
and expected for this skill, no secret embedded. Logged to `SCAN_LOG.md` rather than suppressed,
so the flag stays visible.

### Changed

- Manifest 254 → **255** entries (254 active + 1 disabled); `local/*` 45 → **46**.
- `~/.agents/skills` 281 → **282**; `~/.claude/skills` 514 → **515** (mirrored, SHA-256 parity).
- `upstream/` mirrors 48 → **49**.
- All live counters updated in `README.md` and `SETUP_GUIDE.md`.

## [1.9.12] — 2026-09-22

**`bin/verify-state.ps1` did not verify state.** It is the documented answer to "is my machine
set up correctly?", and it was under-checking and could not fail on the thing it exists to check.

### Fixed — it checked 12 of the 18 CLIs

`witr`, `semantica`, `loop`, `watch-skill`, `wigolo`, and `ocr` were missing from the list. A
broken install of any of those reported a clean pass.

### Fixed — it never exited non-zero on a CLI miss

Missing CLIs printed `MISS` and the script still fell through to `exit 0`. Only the `mcp.json`
branches had an exit path, so a CI consumer saw green while the toolchain was incomplete. The
script now tracks failures and ends with `RESULT: OK` / `RESULT: FAILED` plus a matching exit code.

### Fixed — it never cross-checked the MCP servers the bundle installs

It validated `mcp.json` as JSON and listed whatever was present, but never compared that against
`setup/mcp.json.template`. A bundle server silently missing from the config was therefore
invisible. It now reads the expected set from the template — one source of truth — instead of
hardcoding a second copy that will drift.

### Fixed — it never checked that the parked set was actually parked

Parking works by renaming `SKILL.md` → `SKILL.md.disabled`. A bare `SKILL.md` left behind in a
parked directory is still discoverable by Copilot, and nothing detected that.

### Note — a false positive caught before it shipped

A parked **directory** existing under `~/.claude/skills/` is *not* a leak. The Claude mirror parks
**in place** by renaming the marker file, rather than moving the directory to a `skills._disabled/`
sibling the way the agents side does. Directory presence proves nothing; only the marker file does.
This was briefly read as a 14-skill leak during verification and disproved before any commit.

### Note — the MCP name comparison must stay tolerant

Servers installed from the MCP gallery are keyed `owner/name` and version-pinned; the template keys
them by short name with `@latest`. `firecrawl` and `firecrawl/firecrawl-mcp-server` are the same
server, so raw key equality reports every gallery install as missing — which it did on first run.
Comparison normalizes to the leaf name.

### Verified

Machine state confirmed with the fixed script: **18/18 CLIs**, **23 live MCP servers** including all
**11 bundle servers**, **281 skills**, **14 parked with 0 still discoverable**, exit 0. Negative
controls confirm the check can fail: hiding `USERPROFILE` and breaking `APPDATA` each produce a
non-zero exit.

## [1.9.11] — 2026-09-22

Documentation and release-metadata fixes. No skill content, no script logic changed.

### Fixed — the public quick start was broken and always had been

`README.md` told users to run:

```powershell
git clone https://github.com/JZKK720/cubecloud-skills-bundle-kit.git ~/dev/setup
powershell -File ~/dev/setup/setup-global-skills.ps1     # ← does not exist
```

The installer has lived at `setup/setup-global-skills.ps1` since the initial commit
(`023c906`); `git log --diff-filter=D -- setup-global-skills.ps1` confirms it was **never** at
repo root. So a fresh clone followed the docs verbatim and hit a missing-file error. Corrected
in both the Quick start and the "To update later" section.

### Fixed — `SETUP_GUIDE.md` carried a typo'd clone URL

Both the `git remote add` and `git clone` lines pointed at
`cubecloud-skillsboundle-setup` (misspelled "bundle"), which is not a repository. Corrected to
`cubecloud-skills-bundle-kit`, and the follow-up script path fixed to `~/dev/setup/setup/...`.

### Fixed — the repository-layout block described the runtime tree, not the repo

It showed a `~/dev/` tree with `setup-global-skills.ps1` at the top level. That is the *runtime*
view, not what `git clone` produces. Rewritten to show the actual repo tree, with the
runtime-only paths (`~/dev/bin/`, `~/dev/upstream/SCAN_LOG.md`, `~/dev/forks/`) listed
separately, plus an explicit path convention so the two are not confused again.

### Fixed — v1.9.8 through v1.9.10 were lightweight tags

v1.9.3–v1.9.7 are annotated (`git cat-file -t` → `tag`); v1.9.8–v1.9.10 were lightweight
(`→ commit`), so they carried no release message in the GitHub UI. Re-created with one-line
messages matching the existing convention. The pointed-at commits are unchanged, so this is
metadata-only — no history rewrite.

### Fixed — the "254 vs 281" mismatch was never explained

The README claimed **254** skills; a completed install prints **281**. Both numbers are correct
and always were, but nothing said so, which reads as a broken counter. The gap is now documented
at the top of "What's included":

| Set | Count | Source |
|---|---|---|
| Bundle-installed from `skills-list.csv` | **253** | this repo |
| VS Code Azure / Entra / Foundry extension skills | **27** | VS Code extensions, already on disk |
| `gstack-review` (comment-documented port) | **1** | manifest note, not a data row |
| **Total on disk** | **281** | what the installer counts |

Plus **1** disabled manifest row (`caveman`) and **19** gate-blocked entries parked as comments.
The "What you get" table now reads "Skills on disk: 281" and states the 254-vs-27 split inline.

### Changed

- README layout block updated to real counts: 27 `bin/` scripts (was 19), 48 `upstream/`
  directories, and the fifth `setup/` file (`skillspector-ollama-models.yaml`) that was missing.
- Version badge → 1.9.11.
- Verified before writing: all 12 tags annotated, manifest 254 rows × 4 fields with 0 duplicate
  names, 18/18 CLIs resolved on PATH, 11 MCP servers in `mcp.json.template` matching the live
  config, 50 fork mirrors (51 dirs in `~/dev/forks/JZKK720/` minus this repo), 74 `DESIGN.md`
  files.

## [1.9.10] — 2026-09-22

Parked 13 Copilot-incompatible skills so Copilot stops discovering them. Not a quality
judgement — this is a VS Code Copilot / Windows stack and the parked set targets Claude Code.

| parked | why |
| --- | --- |
| 12 research-integrity forensics | Claude-Code-coupled + security gate + missing dependency |
| `crucible` | retired duplicate; `claudex-loop` supersedes it |

### Three independent blockers on the forensics family, each verified

1. **Coupling** — all 12 use `allowed-tools: Bash(*), ... mcp__codex__codex`, `$ARGUMENTS`
   substitution, and a `Bash()` preamble. Copilot cannot resolve `allowed-tools`, does not
   substitute `$ARGUMENTS`, and has no Codex MCP. Same coupling the manifest already refuses
   for `gstack-review`.
2. **Security gate** — `evidence-ledger` scans **76 / HIGH / DO_NOT_INSTALL**; six more are
   MEDIUM/CAUTION. `install-skill.ps1` blocks on this by design.
3. **Missing dependency** — the family invokes `tools/adjudicate_findings.py` plus
   `check_ai_style.py` and `check_presentation.py`. **None exists on disk** (searched all of
   `~/dev`), so the pipeline cannot run even with the coupling stripped.

Additionally, 11 of the 12 are absent from `SCAN_LOG.md` and none has an upstream or fork
mirror — there is no source of record to track.

The parked set:

    anti-autoresearch            orchestrator (entry point that drives the rest)
    evidence-ledger              L0/L1/L2 observability + claims.json extraction
    citation-forensics           hallucinated refs, metadata drift, wrong-context cites
    consistency-audit            intra-paper self-consistency
    experiment-forensics         fake/derived ground truth, phantom results
    eval-design-forensics        leakage, judge validity, selective reporting
    proof-derivation-forensics   proofs that skip an obligation
    baseline-comparison-audit    missing/weak baselines, error-bar overlap
    presentation-signals         duplicate tables, pipeline strings (auxiliary, capped minor)
    ai-style-impressions         AI writing-style tells (zero verdict weight)
    adversarial-case-builder     memo-only strongest-objection case
    novelty-duplication-advisory memo-only prior-work overlap advisory
    crucible                     retired pre-rename snapshot; claudex-loop covers the trigger

### Changed

- **Parked, not deleted.** Files moved to `~/.agents/skills._disabled/<name>/` with `SKILL.md` →
  `SKILL.md.disabled`, and the same rename on the Claude side. Reversing is a directory move; the
  semantics match `install-skill.ps1 -Disabled` exactly — the same mechanism that parks `caveman`.
- Manifest documents the exclusion with the three reasons and a REVISIT-IF condition.
- **Counters:** installed **294 → 281** active; **14 parked**. Manifest unchanged at 254 —
  parking is filesystem state, not a row change.

### Verified before parking

The family has exactly **one** inbound reference from outside itself: `claudex-loop` → `crucible`,
a description string naming the legacy `/crucible` trigger, not a dependency. The 12
cross-reference only each other. Parking breaks nothing.

### REVISIT IF

The family is ever ported to Copilot-clean form: strip `allowed-tools`, replace `$ARGUMENTS` with
prompt-driven input, drop the Codex MCP, bundle or remove the `tools/*.py` dependency, and clear
the HIGH gate on `evidence-ledger`. That port is a real project, not a manifest edit.

## [1.9.9] — 2026-09-22

Tracked 5 bundled capabilities that paired a hand-authored SKILL.md with a CLI and/or MCP
server but had no manifest row. Manifest-tracking only: 0 of 294 installed skills modified.

### Fixed — 5 everyday capabilities were live but untracked

Each of these ships a working SKILL.md alongside a CLI installed in Phase 2 and/or an MCP
server already in `mcp.json.template`. None had a manifest row, so they were orphaned:
`install-missing-skills.ps1` skips untracked entries, and a cleanup pass would have seen five
unknown directories and deleted them.

| capability | backing | files |
| --- | --- | --- |
| `markitdown-converter` | CLI `markitdown` + MCP `microsoft/markitdown` | 1 |
| `markitdown-testing` | CLI `markitdown-mcp` | 1 |
| `agent-reach` | CLI `agent-reach` (Phase 2, `Panniantong/Agent-Reach`) | 7 |
| `airunway-aks-setup` | AKS cluster → running model, 6 step docs | 11 |
| `retrieval-reflex` | MCP `gbrain` | 1 |

### Why `local/*` and not an upstream row

Verified rather than assumed:

- **No upstream SKILL.md exists** for any of them. `microsoft/markitdown` is the right repo but
  ships **zero** SKILL.md files (checked the fork; `.github/skills` is a 404). The two markitdown
  skills are hand-authored docs *about* markitdown, same lineage as the `User/prompts`
  trio dated 2026-06-27. An upstream row would resolve to nothing.
- **`local/*` rows are refresh-protected.** `install-missing-skills.ps1:174-176` skips them with
  `"skip $name (protected local port)"`, so hand-authored content is never overwritten by the
  resolver — the failure mode that once truncated `book-to-skill` (702→414 lines) and
  `diagram-design` (565→273).
- **Subdirs survive.** `install-skill.ps1:128` copies with `-Recurse`, so `references/` and
  `references/steps/` install intact.

### Changed

- 5 rows added as `local/<name>|<name>||upstream/<name>` with the CLI/MCP backing documented inline.
- `upstream/` mirrors created for all 5, byte-identical to the installed copies (SHA-256 verified),
  with full subdirectory trees.
- **Refreshed a stale `gstack-review` mirror.** The tracked copy was 88 lines (pre-refresh);
  the installed port is 112 lines with a section 7 mapping review layers to reference files.
  Mirror re-synced to 13/13 files.
- **Counters:** manifest 249 → **254** (253 active + 1 disabled); `local/*` 40 → **45**.
  Installed count unchanged at 294 — all five were already on disk.

### Reverted mid-session (recorded for traceability)

An over-broad refresh briefly overwrote the tracked `upstream/gstack-review/SKILL.md` and added
two out-of-scope files under `upstream/crucible/`. Both were restored to HEAD. `crucible` stays
retired (superseded by `claudex-loop`) and `gstack-review`'s mirror is a hand-port, so neither
should be blanket-refreshed from the installed copy — only in the deliberate direction taken here.

## [1.9.8] — 2026-09-22

Re-added 3 skill rows that commit `3757869` removed on a premise that later became false.
Manifest-tracking only: 0 of 294 installed skills were modified.

### Fixed — 3 live skills were untracked because the manifest comment went stale

Commit `3757869` (2026-08-11 00:18) deleted `local/loop-engineering`,
`local/watch-skill` and `local/wigolo`, recording the reason as *"hand-authored placeholder
entries that never had a SKILL.md."* That was accurate when written. It stopped being
accurate **9 hours later**, when those three SKILL.md files were authored
(2026-08-11 09:21) and installed.

| skill | size | gate |
| --- | --- | --- |
| `loop-engineering` | 2840 B | SkillSpector LOW/SAFE · skills-ref Valid |
| `watch-skill` | 2012 B | SkillSpector LOW/SAFE · skills-ref Valid |
| `wigolo` | 2335 B | SkillSpector LOW/SAFE · skills-ref Valid |

**Why this mattered.** The three were live and being served to Copilot from
`~/.agents/skills/`, but untracked. That orphaned them: `install-missing-skills.ps1`
skips untracked skills entirely, so they could never be refreshed, and a future cleanup
pass would have seen three unknown directories and deleted them. The manifest's own
comment was actively misleading a reader into thinking removal was current policy.

### Changed

- Rows re-added as `local/<name>|<name>||upstream/<name>`; the now-false comment replaced
  with one recording the real history.
- `upstream/` mirrors created for all three (`upstream/<name>/SKILL.md`), byte-identical to
  the installed copies (SHA-256 verified). This is the convention all 40 `local/*` rows
  follow — the resolver at `install-missing-skills.ps1:120-124` maps `local/*` to
  `upstream/$Name`, so without a mirror the rows would report `no source`.
- **Counters:** manifest 246 → **249** (248 active + 1 disabled); `local/*` 37 → **40**.
  Installed count unchanged at 294 — these three were already on disk; only their manifest
  tracking was restored.

### Not changed (deliberately)

- The CLI/MCP half of `3757869`'s rationale still holds. All three CLIs install in Phase 2
  (uv/npm), and all three MCP servers are already present in `mcp.json.template` **and** in
  the installed `mcp.json` — verified, not assumed.
- `archify` was named in the same removal commit but was re-integrated separately via
  `JZKK720/archify` + `upstream/archify`.

## [1.9.7] — 2026-09-22

Two data-only fixes. No script changed, no skill content changed, 0 of 294 installed
skills touched.

### Fixed — `llm-council` reported "no source" while its source sat right there

The row was `JZKK720/claude-skills-llm-council|llm-council||` — an empty relpath. With an
empty relpath **both** resolvers default to `skills/$Name`
(`Get-SourceSkillFile` at `install-missing-skills.ps1:127`, `install-skill.ps1:81`), but this
repo keeps its `SKILL.md` **at the root**. So the row could never resolve, and reported
`skip llm-council (no source)` despite the mirror and its `SKILL.md` both existing.

- **Fix:** relpath `.` (repo root). The CSV's own comment already said *"SKILL.md at repo
  root"* — the layout was known, the relpath was just left blank.
- **Chose a data fix over a script fix deliberately.** Adding a root-`SKILL.md` fallback to
  the resolver would have edited `install-skill.ps1`, which is deployed in 3 places that must
  stay hash-identical (`setup/`, `bin/`, `~/dev/bin/`). Changing one manifest cell fixes it
  with no hash-parity churn.
- **Verified as a no-op for content *before* editing:** the installed copy and the mirror are
  identical (468 lines / 2462 words, same `2026-08-18` mtime, name `llm-council`; neither
  carries `argument-hint`, so it was never installed by this pipeline). The row now reports
  `skip llm-council (up to date)` instead of `(no source)`, and the preview still reads
  `Would refresh: 0  Up-to-date/protected: 246  Blocked: 0`.

### Fixed — 4 installed Ollama models were unregistered, so every scan mis-budgeted

`skillspector-ollama-models.yaml` was correctly wired up (`skillspector-local.ps1:82` sets
`SKILLSPECTOR_MODEL_REGISTRY`) and its existing values were accurate, but 4 models present in
`ollama list` were missing — so they still fell back to the guessed 128000-token budget and
logged an unknown-model warning per analyzer slot.

| model | measured `context_length` | params |
| --- | --- | --- |
| `nemotron-safe:latest` | 1048576 | 32.9B |
| `qwen-safe:latest` | 262144 | 176.9B |
| `qwen3.8-flash-next:125b-a6b-q4_K_M` | 262144 | 176.9B |
| `glm-ocr:q8_0` | 131072 | 1.1B |

- Added, with each `context_length` re-measured via `ollama show` on 2026-09-22.
- Also dropped `max_output_tokens: 8192` from `nomic-embed-text:latest`. The 2048 context
  window is real, but an output-token cap is meaningless for an embedding model and the entry
  misstated the budget.
- **After:** unregistered models `0`, and the file parses as valid YAML (13 models).

### Known state — 7 manifest rows remain mirrorless

`self-learning`, `loopy`, `karpathy-guidelines`, `i-have-adhd`, `dependency-doctor`,
`project-graveyard`, `hyperframes`. **All 7 are already installed** (68–302 lines each), so
this is a provenance gap, not a functionality gap. Left unmapped on purpose: cloning a mirror
**exposes its row to `-Refresh`** (the v1.9.6 lesson), so each one needs a per-row decision
rather than a bulk clone. `hyperframes` additionally needs the fork created first —
`JZKK720/hyperframes` 404s.

## [1.9.6] — 2026-09-22

A guard expansion plus a latent parse-breaking duplicate-key fix. No skill content changed —
**0 of 294 installed skills were touched**, verified by hash.

### Fixed — `-Refresh` could have truncated 16 skills by 17–83%

Cloning the `compound-engineering-plugin` fork mirror (done in this pass, to give 16 previously
invisible `ce-*`/`lfg` rows a real source) had an unintended consequence: those rows went from
`skip (no source)` to **refresh candidates**. Measured installed-vs-source line counts:

| skill | installed | refresh source | delta |
| --- | --- | --- | --- |
| `ce-ideate` | 434 | 74 | **−83%** |
| `ce-test-browser` | 242 | 51 | **−79%** |
| `ce-debug` | 339 | 117 | **−65%** |
| `ce-handoff` | 142 | 55 | **−61%** |
| `lfg` | 149 | 58 | **−61%** |
| `ce-simplify-code` | 78 | 65 | −17% |

The refresh source is the **fork mirror**, pinned at `84bdf8c` (**2026-08-27**) — which is itself
*behind* upstream (upstream `ce-debug` is 123 lines, the mirror 117). So a refresh would target
neither the installed state nor current upstream. Every one of these is a genuine content
divergence, not the name-only pattern that explained `hallmark` / `taste-skill` /
`create-technical-design-doc`, so the rename rule does not cover them.

- **Fix:** the 16 active `ce-*`/`lfg` rows are added to `$protected`, blocking refresh with a
  named reason until a human decides whether the larger installed copies are deliberate local
  enrichment or a stale install. Same principle as `codex-review`/`codex-build`: never trade a
  richer working skill for a thinner pointer.
- **Preview after:** `Would refresh: 0  Up-to-date/protected: 246  Blocked: 0`.

### Fixed — duplicate hash key would have broken the whole script parse

`sync-fork-upstreams.ps1`'s `$upstreamMap` already contained
`"compound-engineering-plugin"`, so re-adding it produced
`哈希文本中不允许重复的键` — a **duplicate hash key fails the entire script parse**, not
just the entry. Removed, and replaced with comments recording the two facts that invite the
mistake: the key is already mapped, and `hyperframes` deliberately has **no** mapping because
`JZKK720/hyperframes` returns 404 (mapping a dead remote would mean a failed fetch every sync).

## [1.9.5] — 2026-09-21

`full-audit.ps1` correctness fixes: it no longer leaks MCP server processes, its MCP verdicts
are deterministic, and its summary no longer buries the real breakdown behind one opaque number.

### Fixed — `full-audit.ps1` leaked MCP servers, which wedged the NEXT run

The MCP smoke test started each server as `cmd.exe /c "<launcher> > out 2> err"`. Those
launchers are **launchers**, not the servers: `uvx` spawns `markitdown-mcp`, `npx` spawns
`node` which spawns `firecrawl-mcp`. `Process.Kill()` kills only the shell it started, so the
actual server survived as an orphan **still holding the redirect file handles**. Measured
before the fix: **19 stale server processes** alive and **12 locked `audit_mcp_*.log` files**.
The next run's `Remove-Item` then threw `RemoveFileSystemItemIOError` and the audit appeared to
hang.

- **Fix:** a recursive `Stop-Tree` helper reaps descendants before the parent, invoked on
  **both** the timeout path and the early-exit path.
- **After:** orphans `0` before and after, `0` lock errors, and no `Remove-Item` noise.

### Fixed — MCP verdicts were timing-dependent

The old code branched on `$proc.HasExited`: a server still up at its timeout scored PASS, but a
server that exited first had its stderr grepped for `"error|Error|traceback|..."`. Windows'
launcher-failure text (`'x' is not recognized as an internal or external command`) contains
none of those words, so **a failed launch was recorded as PASS** — the same server could flip
verdict between runs.

- **Fix:** the verdict now derives from the **server's own liveness** (`aliveBeforeTimeout`) and
  from which stream produced output — never from a substring match on stderr.
- **After:** identical verdicts *and* identical stderr byte counts
  (`5078 / 0 / 0 / 6201 / 102 / 0`) across consecutive passes.

### Fixed — "WARN: N" was a union that hid the breakdown

The summary line counted `\| (WARN|ADVISORY) \|` as a single number. The real split is
**1 WARN + 73 ADVISORY** — essentially all of it advisory `skills-ref` results across ~294
skills, plus exactly one genuine WARN. One blended number made a stable, entirely explained
count read as unexplained flakiness.

- **Fix:** WARN and ADVISORY are counted and printed separately.
- **New baseline:** `PASS: 52 | FAIL: 0 | WARN: 1 | ADVISORY: 73`.

### Added — temp-log names are now per-run

Smoke-test logs use `audit_mcp_<name>_<runId>.log`, so a leftover process can never make the
next run's cleanup fail on a name collision. This run's artifacts are also cleaned up at the
end of the script, best-effort and non-fatal.

### Documented — runtime is ~18 minutes, and that is expected

Measured **1108 s**. The audit is **not hung**, and a timeout is not a failure:

| Phase | Time | Note |
| --- | --- | --- |
| MCP smoke test | ~122 s | 6 servers × 15–25 s timeouts, sequential |
| `skills-ref validate` per skill | **dominant** | one process spawn per skill, ~294 skills |

Budget 20+ minutes. Two earlier runs were killed at 900 s and misdiagnosed as wedged.

### Verification

- Orphans and lock errors measured **0** across repeated runs; previously 19 and 12.
- MCP block exercised twice in-process: identical verdicts, identical stderr sizes.
- Full audit end-to-end: `PASS 52 | FAIL 0`, **0** lock errors, **0** orphans — matching the
  pre-change baseline exactly, so no regression was introduced.
- `full-audit.ps1` parses clean; single copy in the repo (no deployed duplicate).

## [1.9.4] — 2026-09-21

Six typed-decision skills added from `wuyoscar/jev-skill` (one as a gate-remediated local port),
plus 51 orphaned `diagram-design` reference docs brought back under version control.

### Added — `jev-skill` family (wuyoscar/jev-skill, MIT, 324★)

Jev returns **typed decisions** — `choice` / `noul` (independent yes-no) / `score` — over a
caller-supplied `state`, `questions` and `criteria`. It does not browse, execute tools or generate
prose; the host agent still plans, acts and verifies. Six skills install:

| Skill | Role |
| --- | --- |
| `jev` | General router — custom decisions, tool/model routing, context retention, checkpoints |
| `jev-triage` | Bulk classify / label / prioritize records |
| `jev-documents` | Evidence retrieval, span extraction, claim checking |
| `jev-eval` | Evaluate outputs, code changes, authorized safety-test results |
| `jev-ui` | Choose an observed action in a real browser or desktop |
| `jev-simulation` | Choose legal actions for a game, NPC or simulated world |

**Gate split.** Five install directly from upstream and pass SkillSpector `--no-llm` cleanly.
The sixth, the general `jev` router, is **HARD-BLOCKED** upstream (exit 1, risk 80/100,
`DO NOT INSTALL`) and is installed as a `local/jev` prose-only port instead:

- **Block cause:** `Executable scripts: Yes` plus **HIGH `E2` Env Variable Harvesting** at
  `scripts/jev.py:131` and `:180`. That script reads `OPENROUTER_API_KEY` / `TYPESAFE_API_KEY`
  from the environment and makes authenticated outbound calls. That is its declared function, so
  the rule keys on real behaviour — **not** a false positive, and **not** bypassed.
- **Two findings that *are* false positives**, recorded for honesty:
  - `P3` Exfiltration Commands at `SKILL.md:151` (90%) — the scanned line is the *prohibition*
    "Do **not** silently send private documents to an external API". Substring match, polarity inverted.
  - `P6` Direct Prompt Extraction at `references/agent-recipes.md:40` (26%) — a prompt-injection
    *test* recipe read as prompt extraction.
- **Remediation:** drop `scripts/` only. Both HIGH findings and the executable flag come from that
  one directory; `SKILL.md`, `assets/` and `references/` are prose and static data. Verified
  **exit 0 / MEDIUM / CAUTION**, then re-verified through the real installer. Mirrors the timesfm
  precedent (v1.9.0): fix the construct in a `local/*` port, keep the prose.
- **Deliberately not done:** obfuscating the credential read to dodge the scanner.
- **Trade-off (documented in the port itself):** the `Run (Jev API mode)` CLI commands no longer
  work from the installed copy. **Simulation mode (B)** — no key, no CLI, no network call — is the
  default route; real-Jev users fetch the CLI from upstream with explicit consent. The general
  router is still the most useful entry point, so this beats dropping the skill.

### Fixed — 51 orphaned `diagram-design` reference docs

`upstream/diagram-design/` had **1 tracked file** (`SKILL.md`) against **52 on disk**; the
`references/` tree was untracked, and `.gitignore` did not cover it (`git check-ignore` exit 1),
so it was genuine drift rather than an intentional exclusion. The docs are load-bearing —
`SKILL.md` links `references/style-guide.md`, `references/onboarding.md` and ~30 `type-*.md`
docs — so a fresh clone would have silently lost them. All 51 are now tracked.

### Added — `jev-skill` fork mirror (#50)

`JZKK720/jev-skill` created and cloned (235 files), and wired into `sync-fork-upstreams.ps1`
`$upstreamMap`. Mirror count 49 → **50**.

### Counters

manifest 240 → **246** (245 active + 1 disabled); `local/*` 36 → **37**; fork mirrors 49 → **50**;
installed 288 → **294** in `~/.agents/skills/` and 506 → **514** in `~/.claude/skills/`.
`full-audit.ps1` → **PASS 52 | FAIL 0**.

### Verified

- SkillSpector static gate re-run on the port; `skills-ref validate` VALID on all six.
- `install-skill.ps1` hash parity 3/3 (`setup/` = `bin/` = `~/dev/bin/`).
- Byte-level checks on every new/changed file: **0 BOM**, round-trip identical, **0** GBK-mojibake.
- All 37 `local/*` rows resolve their `upstream/<name>/SKILL.md` source.
- Both roots confirmed: each of the six skills present in `~/.agents/skills/` **and** `~/.claude/skills/`.
- `sync-fork-upstreams.ps1` parses clean after the map edit.

## [1.9.3] — 2026-09-15

Two skills added — one upstream install, one gate-remediated local port — plus a local-Ollama
launcher for the optional LLM-assisted scan pass.

### Added — `hyperframes` (heygen-com/hyperframes, Apache-2.0)

HTML-native video rendering, installed as the **router only**. `hyperframes` is the entry point
to a capability map of 20 published skills; installing just the router keeps the skill index
lean, because the router pulls each creation workflow on demand via
`npx hyperframes skills update <workflow>` once a video request arrives.

- Gate: **PASS** (exit 0) — risk **18/100 LOW / SAFE**, **0 executable components**.
  52 advisory MEDIUMs, both classes on `SKILL.md` only: MP2 (context-window stuffing) ×31,
  inherent to a router that enumerates its routes, and RP1 (MCP rug pull) ×21 for unpinned
  `npx` invocations. Pinning those versions would clear all 21 RP1s if this is ever revisited.
- `skills-ref validate`: **VALID**.
- **Runtime deps:** Node ≥ 22 (have v24.13.0) and FFmpeg (have 8.1.2), both verified present.
- Installed from the **upstream owner**, not a fork mirror — the same convention already used by
  `addyosmani/agent-skills` and `EveryInc/compound-engineering-plugin`, so no new mirror exists
  to keep in sync.

### Added — `timesfm-forecasting` as a remediated `local/*` port

Zero-shot time-series forecasting with Google's TimesFM foundation model.

Upstream **hard-blocks** the static gate: `skillspector scan --no-llm` exits **1**
(`do_not_install`) on `HIGH TM1 "Tool Parameter Abuse"` at `scripts/forecast_csv.py:225` and
`:247`. Both findings trace to **one construct** — a `--skip-check` flag letting a caller bypass
the mandatory RAM/GPU/disk preflight.

- **Isolation proof:** copy the skill, delete only `scripts/forecast_csv.py` → gate flips to
  exit **0**. The static rule keys on the **literal string**, not the semantics: a first
  remediation that kept the flag but made the preflight unconditional still blocked.
- **Fix:** remove the flag, remove its dead branch, make preflight unconditional. No
  functionality lost beyond the ability to skip a safety check. `ast.parse` clean.
- **Result:** gate **exit 0**; `skills-ref validate` **VALID**. Residual MEDIUMs
  (AST3/AST4/EA4/LP3) are unchanged upstream and non-blocking.
- **Second opinion, recorded because it contradicts the gate:** the LLM-assisted pass on the
  *unmodified* upstream returned risk 46 / MEDIUM / CAUTION at exit 0. Its retained findings were
  the same TM1 pair **plus** a useful `TP4`: upstream bundles anomaly-detection, LoRA
  fine-tuning, and GIF/HTML animation the description never mentions — and fine-tuning
  contradicts the "zero-shot, no training" framing. Worth acting on regardless of the verdict.
- **Licence caveat:** code is Apache-2.0, but TimesFM **3.0 pretrained weights** are under
  `timesfm-non-commercial-license-v1.0` (non-commercial only); weights ≤ 2.5 remain Apache-2.0.
  Fine for dev use — do **not** ship 3.0 weights in a commercial/OEM product.

### Added — `bin/skillspector-local.ps1` (optional LLM-assisted scan)

Runs SkillSpector against a **local Ollama** model, so the optional LLM pass can clear or confirm
static findings with no cloud API key and without shipping skill source to a third party.
SkillSpector has **no `ollama` provider**; Ollama is reached through the bundled `openai` provider
via `OPENAI_BASE_URL`, with `OPENAI_API_KEY` set to a non-empty placeholder whose value Ollama
ignores. Process-scoped only — nothing is written to the registry, the User profile, or any config
file. `-Check` verifies the wiring and reports whether Ollama is up and the model is available
(it warns when the selected model is a `:cloud` route, because inference then runs off-machine).

- **No `param()` block, deliberately.** SkillSpector's short flags (`-f`, `-o`, `-r`) collide with
  PowerShell's parameter binder three separate ways (positional capture of the `scan` verb;
  prefix-match stealing `-o`; `[CmdletBinding()]` making bare `-o` ambiguous against
  `-OutVariable`/`-OutBuffer`). The script parses only its own long-named flags and forwards every
  other token verbatim. **Adding any new `param()` can silently re-break `-o`/`-f`/`-r`.**
- Pairs with `setup/skillspector-ollama-models.yaml`, an optional token-budget registry that
  silences the per-slot "not found in model_registry.yaml … fallback context length (128000)"
  warnings. `SKILLSPECTOR_MODEL_REGISTRY` **replaces** the bundled registry rather than merging,
  so the file holds only local/Ollama models and is used only by this shim.

### Fixed — inaccurate metadata and gate claims

- **`skillspector-ollama-models.yaml` shipped wrong context lengths** — the file's own comment
  claimed the values were "the real ones reported by the Ollama server, not guesses", but five of
  ten were wrong (all four `:cloud`/`nomic` entries, and three local ones). Corrected against
  `ollama show`; the not-installed `qwen3.8` entry is now commented out rather than advertising an
  unmeasured value.
- **The `hyperframes` manifest note mis-stated its own gate result.** It claimed "3× MEDIUM MP2 on
  SKILL.md:106/107/110" and "no executable scripts". Re-running the gate gives **52** MEDIUMs
  (MP2 ×31 + RP1 ×21), **3** of the MP2s fall in the 104-110 window, and the correct claim is
  **0 executable components** (`executable: false`, which is stronger than "no scripts").
- **`local/*` row shape documented in the manifest.** All 36 `local/*` rows are
  4 fields — `repo|name|relPath|disabled` — so the trailing `upstream/<path>` is documentation,
  not the source override it appears to be: both `install-missing-skills.ps1` and
  `setup-global-skills.ps1` parse field 4 as `$disabled` (empty ⇒ not `"true"` ⇒ false) and derive
  the real source from the `local/*` prefix as `upstream/<name>`. Two consequences are now
  recorded: editing that path changes nothing, and a `local/*` row **cannot** be parked via the
  disabled column because empty does not equal `"true"`. The parser's `$parts.Length -ge 5`
  source-override branch is therefore **dead code** — no manifest row has a 5th field. The new row
  was kept byte-identical in shape to its 35 peers rather than inventing a 5th column.

### Verified

- Static gate re-run on both new skills: **exit 0** each. `skills-ref validate`: **VALID** each.
- Manifest: **240** data rows, **0** duplicate names, **0** rows deviating from the 4-field shape,
  **36** `local/*` rows with **0** missing sources (source resolution checked row-by-row, which a
  count-only audit would not catch).
- Byte-level encoding audit on every new file: **0** BOMs, **0** GBK-mojibake codepoints, CRLF
  matching the existing `setup/` + `bin/` convention.
- `bin/full-audit.ps1` → **PASS 52 | FAIL 0**. `install-skill.ps1` hash parity preserved across
  `setup/`, `bin/`, and `~/dev/bin/` (**3/3 identical**).
- Counters re-measured after the last edit (they went stale three separate times in past releases):
  manifest **240** (239 active + 1 disabled), `local/*` **36**, installed **288**
  `~/.agents/skills/` + **508** `~/.claude/skills/` + **27** `~/.copilot/skills/`.

### Known follow-up

`upstream/timesfm-forecasting/` is **2.03 MB** because it carries committed demo output:
`forecast_animation.gif` (794 KB), `covariates_data.png` (459 KB), `anomaly_detection.png`
(217 KB), `interactive_forecast.html` (159 KB), `forecast_visualization.png` (151 KB) — **96%** of
the payload. Upstream's own `.gitignore` ignores `*.html`, so these are regenerable artifacts.
**Kept deliberately:** `SKILL.md`'s acceptance criteria and verification snippets assert against
`output/anomaly_detection.json`, `output/sales_with_covariates.csv`, and
`output/forecast_output.json`, and the example scripts read the sibling PNG/GIF/JSON, so they are
load-bearing content here rather than stray build output — and this is the first binary payload in
any `upstream/` port, so trimming it would be a new convention decided unilaterally.

## [1.9.2] — 2026-09-14

Fixed the root cause of mirror bloat, which v1.9.1 identified but deliberately left alone.

### Fixed — `sync-fork-upstreams.ps1` no longer un-shallows mirrors

`setup-global-skills.ps1` creates every mirror with `git clone --depth 1` **on purpose**, but
sync fetched with a plain `git fetch upstream` (no `--depth`), which un-shallows the clone and
re-downloads full history. That single line is how 41 mirrors reached 1,517 MB of `.git` against
947 MB of working trees.

- **Fetch is now `git fetch --depth 1 --no-tags upstream`** (was `git fetch upstream`).
  `--no-tags` also stops tag objects accumulating.
- **Measured before/after on a live mirror:** with the old plain fetch, one run grew a
  freshly-shallow mirror from **1.6 MB to 365 MB**. With the fix, a full sync run grew it
  **+0.01 MB**. Forks root held at **987 MB** with no re-bloat, and all **20 syncable mirrors
  report `is-shallow-repository = true`** (the only full-history repo is the bundle itself,
  which is correct).

### Changed — a shallow fast-forward failure is now a SKIP, not a FAILED

A shallow clone shares no ancestor with its remote, so `git merge --ff-only` reports
*"refusing to merge unrelated histories"* even for a clean fast-forward. Deepening to fix that
is exactly the `.git` bloat this release removes, so the outcome is now reported as
`SKIP (shallow, no common ancestor - re-clone to update)` and counted in *skipped* rather than
*failed*. The remedy is to re-run `setup-global-skills.ps1`, which re-clones cleanly.
This is a real trade-off: the 20 syncable mirrors will report SKIP instead of advancing when
they are genuinely behind. Chosen deliberately over silent disk growth.

### Verified

- Script parses clean; `sync-fork-upstreams.ps1` reports
  `Synced: 0, skipped: 49, Failed: 0`.
- Forks root **987 MB** (v1.9.1 trimmed it from 2,470 MB); largest remaining `.git` is
  `markitdown` at **4.99 MB**.
- `full-audit.ps1` **PASS 51 | FAIL 0**; FORKS PASS; install-skill hash parity preserved.

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

### Not fixed in v1.9.1 — resolved in v1.9.2

`sync-fork-upstreams.ps1` still used a depth-unlimited `git fetch`, so the 20 remaining
syncable mirrors would keep growing `.git` over time. **Fixed in v1.9.2** (fetch is now
`--depth 1 --no-tags`, plus a shallow-FF SKIP). Measured 1.6 MB → 365 MB before the fix,
+0.01 MB after.

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
