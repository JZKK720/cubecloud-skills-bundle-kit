# Deprecations, Removals and Parked Skills

The one place that answers "what did we deprecate, and why". Until 2026-11-19 this history lived
scattered across `setup/skills-list.csv` comments, `CHANGELOG.md` sections and two README tables;
answering it took a 30-command dig. Record it here from now on.

Rules: **retirement ≠ deletion.** A row is removed only for one of the four causes below, and the
skill directory is parked (`~/.agents/skills._disabled/`) rather than deleted, so the decision is
reversible by a directory move + file rename. Blocked rows stay in the manifest as comments so the
gate result remains visible.

Review that produced this file:
[docs/plans/2026-11-19-bundle-usage-and-deprecation-review.md](plans/2026-11-19-bundle-usage-and-deprecation-review.md).

---

## 1. Removed upstream (row survived, skill did not)

| Skill | What happened | Verified |
| --- | --- | --- |
| `jev-ui`, `jev-simulation` | Deleted upstream. Purpose folded into the new `jev-act`, which passes the gate cleanly and replaced both rows (manifest 275 → 274) | 2026-10-28 against `JZKK720/jev-skill@main` and `wuyoscar/jev-skill@main` |
| `crucible` | Renamed upstream in commit `a027430` (2026-09-06, *"rebrand: crucible → claudex-loop"*). `skills/crucible` → `skills/claudex-loop`; the legacy `/crucible` trigger survives only as a string in the new description. The old path 404s | 2026-09-06 |
| `huashu-design` | `SKILL.md` sits at repo ROOT, not `skills/` (path bug, fixed with `SkillRelPath=.`), **and** a real block: HIGH SC4 on `sharp==0.34.5` (2 advisories). Pruned so the install pass stops retrying | 2026-09-13 |

## 2. Parked, not deleted

Directory lives in `~/.agents/skills._disabled/<name>/` with `SKILL.md` renamed to
`SKILL.md.disabled`, so Copilot does not discover it. Reverse with a directory move + rename, or
re-install with `setup/install-skill.ps1 -Disabled`.

| Skill | Parked | Reason |
| --- | --- | --- |
| `caveman` | — | Upstream-disabled. Manifest row flagged `disabled=true` |
| `build-mcp` | 2026-11-20 | **Tier 2 exact duplicate (0.970)** of `mcp-builder`: 1 file vs 6, identical section structure. Copilot must not see both |
| `unlazy` | 2026-09-22 | Upstream divergence |
| `crucible` (pre-rename snapshot) | 2026-09-22 | Superseded by `claudex-loop`, which answers the legacy trigger. **Not present on this install** |

Earlier releases also parked 12 research-integrity forensics skills. Those are **not** on this
machine — verify before assuming; the on-disk count is the only truth.

## 3. Dropped during porting (never shipped)

| Skill | What happened |
| --- | --- |
| `document` | Ported, then dropped: it carried 28 references to upstream-only artifacts and the "live panel". Removed rather than shipped |
| `typeset`, `polish`, `craft` | Script-coupled; `craft` was additionally a deprecated alias. Of 28 candidates, 22 met the bar, 6 were already ported, 1 (`document`) was dropped |

## 4. Permanently blocked by the gate

These are commented out in `setup/skills-list.csv` with the finding that blocked them, so the
decision stays auditable instead of silently forgotten. Check the row's comment before assuming a
skill "does not exist" — and check `baselines/` first, because a reviewed suppression baseline can
legitimately unblock one (that is how `diagram-design` went from exit 1 to exit 0).

Scope-level exclusions (not blocked — deliberately curated out) are recorded in the README
blocked-skills tables: `rails-patterns`, `master-agreement-generator`, `esign-field-placement`,
`tasteforge-video`, the whole `Gskills` GCP set, AGPL `OpenMontage`, the `(gtm)` category, and
`openai/skills` `.system`.

## 5. Retired bundle tooling

| Artifact | What happened |
| --- | --- |
| `bin/retest-mcp.ps1` | Superseded by `bin/mcp-smoke-test.ps1`; removed |

## 6. Open retirement candidates (not executed)

Recorded by the 2026-11-19 review. **Nothing here has been removed** — these change what users get,
and the usage measurement is partly confounded by the MCP wiring gap (§7).

| Candidate | Cause | Evidence | Status |
| --- | --- | --- | --- |
| `build-mcp` | **Genuine exact duplicate** (Tier 2 similarity 0.970) | 1 file vs `mcp-builder`'s 6; byte-identical section structure (Overview / High-Level Workflow / Documentation Library); 13900 bytes of condensed prose vs 9227 + 5 reference files | **PARKED 2026-11-20** — `skills._disabled/build-mcp/`, manifest row `disabled=true` |
| `idea-to-design` | **Genuinely superseded** 2026-11-19 by the real upstream `brainstorming` | Near-verbatim description; 0 invocations vs. `brainstorming`'s 5; the scanner block that forced the port no longer reproduces | Open |
| `ce-commit` | Duplicate of the strictly broader `ce-commit-push-pr` | `ce-commit-push-pr` does everything `ce-commit` does plus push and PR creation | Open |
| `humanize` | Duplicate of `humanizer` (Tier 2 similarity 0.905) | Two names for one capability; `humanizer` is the tracked skill | Open |
| `deslop` | Overlaps `stop-slop` (0.916) | Six anti-slop skills installed; `deslop` and `stop-slop` are the closest pair | Open |
| `security-scan` | Overlaps `security-review`, but is **not** an outright duplicate | `security-scan` audits the agent's own config (`.claude/`, MCP servers, hooks) via AgentShield; `security-review` is an application-security checklist. Defensible to keep both | Open |
| `semantica` | 365 MB, 0 invocations, not MCP-wired, 0 skills reference it | — | Open |
| ~~`agent-self-evaluation`~~ | **Withdrawn** — not a duplicate | Rates the agent's own output post-hoc on 5 axes; `eval-harness` is an EDD framework that defines evals *before* coding. Different jobs | Withdrawn |
| ~~`planning-and-task-breakdown`~~ | **Withdrawn** — not a duplicate | Spec → ordered, estimable task list; `writing-plans` is spec → implementation plan. Different artifacts | Withdrawn |
| ~~`azure-deploy`/`azure-prepare`~~ | **Withdrawn** — false positive (0.910) | Sequential phases of one workflow; similarity compares text and cannot see ordering | Withdrawn |
| ~~`capacity`/`preset`~~ | **Withdrawn** — false positive (0.902) | Nested phase files inside `microsoft-foundry/`, not top-level skills | Withdrawn |

## 7. Disk: what was reclaimed, and what is safe to reclaim next

Measured 2026-11-19. **Nothing here was deleted without a check that nothing reads it.**

| Area | Size | Verdict |
| --- | --- | --- |
| Fork mirrors `~/dev/forks/JZKK720` | **1.76 GB** (27 mirrors) | **Keep.** Every one is installer-provisioned by design; they are the offline fallback when `-Refresh` cannot reach upstream |
| — of which `.git` | 0.94 GB | **Keep.** `bin/sync-fork-upstreams.ps1` is the only thing that reads it — that is what lets 21 mirrors fast-forward in one command instead of re-cloning |
| uv tools (`~/AppData/Roaming/uv/tools`, 2.70 GB) | Largest: `rembg` **677 MB**, `headroom-ai` 473 MB, `semantica` 365 MB, `markitdown` 292 MB, `scrapling` 276 MB, `skillspector` 179 MB, `graphifyy` 178 MB | **`headroom-ai` … `skillspector` keep** — each backs a declared CLI/MCP server. **`rembg` is not bundle-managed**: 677 MB, referenced by zero skills, zero installer lines, zero template entries. It is a personal tool; remove it yourself with `uv tool uninstall rembg` if you do not use it |
| `ast-grep-cli` (98 MB) | A **dependency of `headroom-ai`**, not a bundle CLI | Keep — uninstalling breaks `headroom` |
| uv cache | 1.38 GB → **1.06 GB** | **Pruned** with `uv cache prune` (8555 files, 321 MB). Safe by construction: it only drops entries no installed tool references. All 21 CLIs re-verified after |
| `~/.agents/skills` + `~/.claude/skills` | 0.04 GB | Needed — this is the product |

**Reclaimed this session: ~443 MB** (321 MB cache + 81 MB of orphaned `skill_install_*` temp clones
from earlier scans + 54 empty `omnigent-skill-bundle-*` stubs, plus **113 MB** from removing the
duplicate user-scoped Node install), plus 30 MB from `git gc` across all 27 mirrors.

**What I did *not* delete, and why:**

- **No skills were retired.** The retirement candidates in §6 are recorded but untouched. Two of
  the four "duplicates" I first flagged did **not** survive inspection: `agent-self-evaluation`
  (rates the agent's own output post-hoc on 5 axes) is a different job from `eval-harness` (an
  EDD framework that defines evals *before* coding), and `planning-and-task-breakdown` (spec →
  ordered task list) is a different job from `writing-plans` (spec → implementation plan). Both
  pairs stay. The only genuine redundancy confirmed is `idea-to-design` vs `brainstorming`, and
  `ce-commit` vs `ce-commit-push-pr`.
- **No mirror or `.git` was removed.** All 27 mirrors stay.

- **The 16 non-manifest mirrors** (`gbrain`, `gstack`, `headroom`, `firecrawl`, `markitdown`,
  `Scrapling`, `graphify`, `spec-kit`, `Gskills`, `EverOS`, `llm_wiki`, `last30days-skill`,
  `agentskills`, `awesome-design-md`, `reverse-skill`, `SkillOpt`) look like orphans against the
  manifest, but all but one are referenced by `setup-global-skills.ps1` and several back a live
  MCP server (`gbrain`, `headroom`, `markitdown`, `Scrapling`, `graphify`, `SkillOpt`).
  `reverse-skill` is the sole genuine oddity — 13 MB, not in the installer. Not worth the risk.
- **Deleting every `.git`** would reclaim ~0.94 GB and would permanently break
  `sync-fork-upstreams.ps1` and `-Refresh` for those mirrors. If you accept re-cloning on demand,
  this is the single biggest reclaimable block — that is your call, not a cleanup.

## 8. Closed: `-Refresh` drifted, five installs repaired

`bin/install-missing-skills.ps1 -Refresh` rewrites only `SKILL.md`; auxiliary files
(`references/`, `scripts/`, `assets/`, `agents/`) are never refreshed, so an install can drift
arbitrarily far from its mirror while still reporting "Refreshed".

Measured 2026-11-20 at the start of this pass: **14 of 116** installs were missing files. Twelve
were reinstalled; seven went clean, and the remaining **five are now all repaired and fully
synced**:

| Skill | Mirror → installed | New baseline | Gate |
| --- | --- | --- | --- |
| `taste-skill` | 1631 → **1631** | `baselines/taste-skill.baseline.yaml` (43 fps + 2 rules) | exit 0 |
| `subagent-driven-development` | 15 → **15** | `…/subagent-driven-development.baseline.yaml` (3 fps + 1 rule) | exit 0 |
| `writing-skills` | 10 → **10** | `…/writing-skills.baseline.yaml` (13 fps + 3 rules) | exit 0 |
| `ce-explain` | 11 → **11** | `…/ce-explain.baseline.yaml` (5 fps + 1 rule) | exit 0 |
| `security-and-hardening` | 2 → **2** | `…/security-and-hardening.baseline.yaml` (7 fps + 2 rules) | exit 0 |

Every finding behind those baselines was read before being suppressed, and all were **false
positives on defensive prose** — the clearest being `security-and-hardening`'s `SSRF1` hit, which
is the skill explaining that `169.254.169.254` is the #1 SSRF target *and* that its range check
covers it, and its `PE3` hit, which is a `.gitignore` diagram showing `.env` must not be committed.

**The design flaw itself is still open:** `-Refresh` should refresh the whole tree. Until it does,
re-run `setup/install-skill.ps1 -SourcePath` after any upstream sync.

## 9. Before retiring anything: check the wiring
12 MCP servers are declared in `setup/mcp.json.template`. **They are now merged into the live VS
Code `mcp.json` (verified 2026-11-19: `verify-state.ps1` → "all 12 bundle MCP servers present")**,
so the earlier confound — tools that looked unused because they were never configured — no longer
applies to the MCP layer.

Two servers still do not handshake, for reasons that are **environment, not curation**:

| Server | Cause | Fix |
| --- | --- | --- |
| `rea` | Node 24.18.0 < required 24.22.1 | `winget install OpenJS.NodeJS` **in an elevated shell** — verified 2026-11-19 that a non-elevated session cannot write `C:\Program Files\nodejs`, so the upgrade cannot be completed by an agent |
| `headroom` | needs a provider key | supply a key, or leave it out of the keyless set |

Still true, and it is the reason to re-measure rather than trust the 2026-11-19 usage table: a tool
can be correctly installed, correctly wired, and still have zero shell invocations because it is
MCP-first. Judge those on the handshake, not on `tool.execution_start.arguments.command`.

## 10. Closed: machine-wide Node raised to 26.13.1

Opened 2026-11-20 because `C:\Program Files\nodejs` was **24.18.0** and sat ahead of the
user-scoped install on PATH, so `rea` (which needs 22.x>=22.23.4 / 24.x>=24.22.1 / 26.12.1+) could
not start. That session could not fix it — HKLM writes denied, `C:\Program Files\nodejs` not
writable, and `whoami /groups` showed Administrators as *"Group used for deny only"*.

**Closed 2026-11-20: the operator installed Node 26.13.1 machine-wide.** Verified:

| Check | Value |
| --- | --- |
| `node` on PATH | **v26.13.1** |
| `C:\Program Files\nodejs\node.exe` | **v26.13.1** |
| `Get-Command node` resolves to | `C:\Program Files\nodejs\node.exe` |
| MSI registration | Node.js **26.13.1** |
| REA floor (26.12.1+) met | **yes** |
| `rea` MCP handshake | **`MCP_OK rea tools=255`** |

**The workaround was removed, not left behind.** `setup/mcp.json.template` had pinned the stale
user-scoped directory (`…node-v26.8.1-win-x64`, whose files were 26.12.1) in the `rea` server's
`env.PATH`. That pin is now deleted from both the template and the live `mcp.json`, because it
would have kept pointing at an older build even after the machine-wide upgrade. Verified after
removal: `mcp-smoke-test` **PASS 12 / FAIL 0** with `rea` passing on the plain inherited PATH.

**Single Node install now.** The duplicate user-scoped install (files 26.12.1, registered in winget
as `OpenJS.NodeJS` 26.8.1) was removed with `winget uninstall --id OpenJS.NodeJS --scope user`.
Verified afterwards: `node` on PATH still **v26.13.1**, its package directory and User PATH entry
both gone, `winget list` shows **one** Node package (`OpenJS.NodeJS.LTS 26.13.1`), `rea` still
handshakes on the plain inherited PATH (`MCP_OK rea tools=263`), and **all 21 CLIs resolve** with
every npx-based one responding. 113 MB reclaimed. Nothing referenced the removed directory — its
path was absent from `setup/mcp.json.template`, the live `mcp.json` and the Copilot CLI
`mcp-config.json` before deletion.

## 11. Closed: the MCP probe graded a healthy server as `WARN` because of stdin

Not a retirement, but it belongs here because it explains a WARN row a reader will otherwise
keep re-discovering.

**Symptom.** `bin/full-audit.ps1` phase 1 intermittently graded 5 of 6 daemon probes
`WARN … Exited early, no output within 15–25s` — `markitdown`, `skillspector`, `firecrawl`,
`scrapling`, `graphify` — while `bin/mcp-smoke-test.ps1` reported **PASS 12 / FAIL 0** on the same
machine, minutes apart. The obvious suspects (a dead `HTTP_PROXY`, a broken `uvx`/`npx` launcher,
npm registry outage) were each ruled out: no proxy variable was set in a fresh process and
`fetch('https://registry.npmjs.org/-/ping')` returned **200**.

**Root cause.** The probe builds a `System.Diagnostics.ProcessStartInfo` and starts
`cmd /c "<cmd> > out 2> err"` **without** setting `RedirectStandardInput`. The server therefore
inherits the *audit's* stdin. A stdio MCP server reads stdin, and **stdin EOF means "the client
has gone away"**, so it shuts down — cleanly, with `rc=0`. Whenever the audit itself is launched
with a redirected stdin — under a pipeline, a task runner, a CI shell, or Copilot's own shell,
where `[Console]::IsInputRedirected` is `True` — every server exited in ~5 s and was graded as a
failure to start.

**Evidence.** Isolated with a two-way probe of the same command:

| stdin handed to `skillspector mcp` | Result |
| --- | --- |
| `subprocess.DEVNULL` (EOF immediately) | **EXITED** `rc=0` after **4.7 s** |
| open pipe (blocks, like a TTY) | **STILL ALIVE** at 12 s |

**Fix.** One line: `$psi.RedirectStandardInput = $true`. An open pipe that is never written to
blocks reads exactly as VS Code's stdin does, so the probe no longer depends on how the audit was
invoked. Verified afterwards: `skillspector`, `graphify` and `scrapling` each **alive at 15–20 s**,
and real JSON-RPC handshakes answer in seconds — markitdown 5.8 s, skillspector 5.1 s,
firecrawl 3.0 s (28 tools), scrapling 1.6 s (13 tools), graphify 1.5 s (10 tools).

**Lesson worth keeping.** A probe that measures "did it stay up" must control *every* stream the
server reads. Both prior MCP-probe bugs in this bundle were stream-grading mistakes — grading
stderr instead of stdout, and now omitting stdin. `bin/mcp-smoke-test.ps1` was right both times
because it performs a real `initialize` + `tools/list` exchange; a liveness probe that only waits
is the weaker instrument.