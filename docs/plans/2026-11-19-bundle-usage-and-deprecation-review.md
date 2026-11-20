# Bundle Review — Tool/CLI necessity, retirement candidates, deprecation ledger

Measured 2026-11-19 on this machine. Every number below is produced by a command recorded in the
method section, not estimated. Corpus: **39 sessions, 2026-07-29 → 2026-11-19, 34,216 tool calls,
21,183 shell commands**, from `~/.copilot/session-state/**/events.jsonl`.

---

## 1. Are we still using the tools/CLIs we install?

### 1.1 The honest framing

**Two of the three layers are in use, one is not, and the reason is not that it is unwanted — it
is that it was never wired up.**

`setup/mcp.json.template` declares 12 servers. The live VS Code `mcp.json` contains **one** server
(`TalkToFigma`, user-installed, nothing to do with this bundle). So for this machine the bundle's
Phase 5 never ran, and every skill that tells the agent to call `markitdown`, `firecrawl`,
`scrapling`, `gbrain`, `graphify`, `headroom`, `wave`, `wigolo`, `skillopt` or `rea` as an **MCP
tool** has been pointing at a server that does not exist in VS Code. Only the Copilot *CLI* has
them partly configured (`rea`, `headroom`, `loop-engineering`, `skillspector`, `wigolo`).

That distinction decides the whole retirement question, so it is the first table.

### 1.2 CLIs — invocation evidence vs. install cost

"strict" = the name actually starts a command (after `^`, `;`, `&&`, `|` or a path); "loose" =
appears anywhere in a command string, which over-counts prose. Install size is the real
on-disk cost from `uv tool dir` / npm / winget.

| CLI | strict | loose | install | Verdict |
| --- | ---: | ---: | --- | --- |
| `skillspector` | 39 | 74 | 179 MB | **Keep — the gate.** Non-negotiable |
| `skills-ref` | 3 | 17 | 3 MB | **Keep** — cheapest thing in the list, validates every install |
| `wigolo` | 24 | 105 | npm | **Keep** — genuinely used |
| `agent-reach` | 13 | 44 | 27 MB | **Keep** — genuinely used |
| `scrapling` | 12 | 41 | 276 MB | **Keep** — genuinely used |
| `rea` | 12 | 73 | npm | **Keep** — genuinely used |
| `firecrawl` | 7 | 83 | npm | **Keep** — genuinely used |
| `loop` | 7 | 170 | npm | **Keep** — used; 170 loose hits are prose noise |
| `graphify` | 5 | 49 | 178 MB | **Keep, flag cost** — 5 uses for 178 MB |
| `markitdown` | 5 | 42 | 292 MB | **Keep, flag cost** — 5 uses for 292 MB |
| `ocr` | 5 | 138 | npm | **Keep** — used, though most hits are the substring |
| `skillevaluator` | 4 | 19 | 69 MB | **Keep** — 4 invocations in the ~2 h since it was installed |
| `skillopt-eval` | 1 | 7 | 78 MB | **Borderline** — 1 real invocation for 78 MB |
| `watch-skill` | 1 | 10 | 29 MB | **Borderline** — 1 real invocation |
| `specify` | **0** | 8 | 15 MB | **Retirement candidate** — zero direct invocations |
| `uipro` | **0** | 6 | npm | **Retirement candidate** — zero direct invocations |
| `gbrain` | **0** | 11 | bun | **Retirement candidate (MCP-only)** — see caveat |
| `headroom` | **0** | 15 | **473 MB** | **Retirement candidate (MCP-only)** — see caveat |
| `semantica` | **0** | 7 | **365 MB** | **Retirement candidate** — zero invocations, largest unused install |
| `witr` | **0** | 35 | winget | **Retirement candidate** — zero direct invocations |
| `git-wt` | **0** | 10 | winget | **Retirement candidate** — zero direct invocations |

**The caveat that must not be skipped:** `gbrain` and `headroom` are *MCP-first* tools. `headroom`
is wired in the Copilot CLI config, and its whole job (compress/retrieve context) happens as tool
calls, not as a shell command — so a zero shell count is **not** proof it is unused. Both are
**candidates for a decision, not for deletion.** `semantica`, `specify`, `uipro`, `witr` and
`git-wt` have no such excuse: none of them is MCP-wired anywhere.

### 1.3 Skills — 3.9% ever invoked

Across 39 sessions and 256 recorded skill invocations, **14 distinct skills were invoked out of
333 on disk (4.2%)**.

| Skill | Invocations |
| --- | ---: |
| `using-superpowers` | 208 |
| `systematic-debugging` | 15 |
| `verification-before-completion` | 7 |
| `brainstorming` | 5 |
| `reverse-engineer-anything` | 4 |
| `agent-reach` | 4 |
| `karpathy-guidelines` | 3 |
| `test-driven-development` | 3 |
| `executing-plans` | 2 |
| `impeccable-audit` · `troubleshoot` · `performance-optimization` · `shipping-and-launch` · `search-first` | 1 each |
| everything else (319 skills) | **0** |

The context cost of that: the 333 `description:` fields total **115,496 characters ≈ 28,874
tokens** of always-on routing surface, at an average of 346 chars per skill.

**Read this honestly, though.** "Never invoked in 39 sessions" is not the same as "useless". The
corpus is dominated by four repos (`pacgate-ai-pr` 14 sessions, `neoclaw` 6, `hermes-agent` 6,
`agent-meow` 3) — product debugging work, which exercises a narrow band of skills. A GTM, SEO,
Azure-deployment or video skill could not have fired in that workload even if it were excellent.
What the data *does* prove is that **nothing is rotated out of the description budget**, and that
the marginal value of skill #200–#333 is unproven on this machine.

### 1.4 MCP servers — 0 of 12 verified reachable

12 declared in the template, 1 actually in VS Code, 5 in the Copilot CLI. The audit's own MCP row
is a FAIL for exactly this reason (`12 of 12 not configured`). This is the single largest gap
between "what the README advertises" and "what this machine can do", and it is a **configuration**
problem, not a curation problem — fixing it is running Phase 5, not removing servers.

---

## 2. What should be retired?

Retirement is only justified by one of four causes. Each candidate below is filed under exactly
one, with the evidence.

### 2.1 Superseded by something now installed — **highest confidence**

| Skill(s) | Cause | Evidence |
| --- | --- | --- |
| `idea-to-design` (1 row) | **Superseded on 2026-11-19** by the real upstream `brainstorming`, which I installed this session | Both are installed now. Their `description:` fields are near-verbatim: `idea-to-design` says *"Adapted from the brainstorming skill methodology (obra/superpowers) with the unsafe visual-companion browser server removed"* — and the reason it removed that server (SkillSpector blocking `stop-server.sh`) **no longer reproduces** (verified: exit 0 under a 6-finding reviewed baseline). Two skills now answer the same trigger; only one has the visual companion. `brainstorming` was invoked 5× in the corpus; `idea-to-design` 0×. **Recommend: retire `idea-to-design`**, or demote it to `_disabled` as the no-script fallback the manifest comment already calls it. |

### 2.2 Duplicate capability — pick one per cluster

These are **clusters, not individual skills**: the point is that the bundle carries 3–7 entries
for one job. Nothing is broken; the bundle is just paying 5× the description budget for one
capability.

| Cluster | Members installed | Why it is redundant |
| --- | --- | --- |
| Code review | 7 — `code-review-and-quality`, `requesting-code-review`, `receiving-code-review`, `open-code-review`, `review-local-changes`, `traiage-review`, `jev-eval` | Three of them (`requesting-`/`receiving-code-review`/`code-review-and-quality`) are the same review loop split by phase; `open-code-review` + `review-local-changes` both review the local diff |
| Eval / benchmarking | 5 — `eval-harness`, `agent-evaluation`, `agent-self-evaluation`, `harness-eval`, `spec-driven-eval` | Five eval skills, zero invocations in 39 sessions. `skillevaluator` (the CLI added today) now covers the mechanical part |
| Security | 6 — `security-review`, `security-scan`, `security-and-hardening`, `security-bounty-hunter`, `production-audit`, `safety-guard` | `security-review` vs `security-scan` overlap almost entirely (both from ECC) |
| Spec / planning | 5 — `spec-driven-development`, `spec-driven-eval`, `planning-and-task-breakdown`, `writing-plans`, `executing-plans` | `writing-plans`/`executing-plans` are the superpowers pair; `planning-and-task-breakdown` is addyosmani's version of the same step |
| Git commit / PR | 4 — `ce-commit`, `ce-commit-push-pr`, `create-pull-request`, `attach-review-to-pr` | `ce-commit-push-pr` subsumes `ce-commit` |
| Simplify | 2 — `code-simplification`, `ce-simplify-code` | Same operation, two vendors |
| Browser test | 3 — `browser-testing-with-devtools`, `ce-test-browser`, `webapp-testing` | Three entry points to one capability |
| Perf | 2 — `performance-optimization`, `impeccable-optimize` | The latter is UI-specific, so this one is defensible |

**Recommendation:** this is a *decision list*, not a deletion list. Cutting the review and eval
clusters alone would free ~10 slots of the 28.9k-token routing budget and remove the ambiguity that
makes an agent pick the wrong one of five eval skills. I first listed four of these as "true duplicates". **On inspection only two survive**
(`idea-to-design`, `ce-commit`): `agent-self-evaluation` rates the agent's own output post-hoc
while `eval-harness` defines evals *before* coding, and `planning-and-task-breakdown` produces an
ordered task list while `writing-plans` produces an implementation plan — different jobs, both
kept. `security-scan` (audits the agent's own `.claude/` config via AgentShield) only partially
overlaps `security-review` (application-security checklist); keeping both is defensible.

### 2.3 Never used AND expensive to keep

| Candidate | Evidence |
| --- | --- |
| `semantica` (CLI + 1 row) | **365 MB** installed, **0** invocations, not MCP-wired. Largest unused install on the machine |
| `specify` (CLI) | 0 invocations; `spec-driven-development` already covers the workflow |
| `uipro` · `witr` · `git-wt` | 0 strict invocations each, none MCP-wired |
| `agent-platform-deploy` | On disk, **not a manifest row**, 0 invocations, absent from `skills-unmanaged.txt` (it is one of the 21 "undocumented skill" FAILs) |

### 2.4 What must **not** be retired, despite looking unused

| Skill | Why it stays |
| --- | --- |
| `brainstorming`, `using-superpowers`, `systematic-debugging`, `verification-before-completion` | The four most-invoked skills in the corpus — 235 of 256 invocations |
| Every `azure-*` / `entra-*` / `gcp` / `hyperframes` extension skill | **0 invocations here is expected**: they are provisioned by VS Code extensions and are absent from the manifest by design. Removing them would be undone on the next extension update |
| Every remaining `impeccable-*` (21 installed) | Only `impeccable-audit` fired once, but the family is one design methodology split into lenses — this is the same "cluster" problem as §2.2, not a dead-weight problem |

---

## 3. What have we already deprecated?

This is the ledger the bundle never had in one place. Sources: `setup/skills-list.csv` comments,
`CHANGELOG.md`, README's disposition tables, and `~/.agents/skills._disabled/`.

### 3.1 Removed upstream (the row survived, the skill did not)

| Skill | What happened |
| --- | --- |
| `jev-ui`, `jev-simulation` | **Deleted upstream.** Verified against `JZKK720/jev-skill@main` + `wuyoscar/jev-skill@main` on 2026-10-28. Their purpose was folded into the new `jev-act`, which passes the gate cleanly and replaced both. Manifest 275 → 274 |
| `crucible` | **Renamed upstream** in commit `a027430` (2026-09-06, *"rebrand: crucible → claudex-loop"*). `skills/crucible` → `skills/claudex-loop`; the legacy `/crucible` trigger survives only as a string in the new description. The old path 404s |
| `huashu-design` | Path bug (`SKILL.md` sits at repo root, not `skills/`) **and** a real block: HIGH SC4 on `sharp==0.34.5`. Pruned 2026-09-13 so the install pass stops retrying |

### 3.2 Parked, not deleted (reversible by a directory move)

| Skill | State | Reason |
| --- | --- | --- |
| `caveman` | `~/.agents/skills._disabled/caveman/SKILL.md.disabled` ✓ verified | Upstream-disabled; the only manifest row flagged `disabled=true` |
| `unlazy` | `~/.agents/skills._disabled/unlazy/SKILL.md.disabled` ✓ verified | Parked 2026-09-22 |
| `crucible` (pre-rename snapshot) | Parked 2026-09-22, **not present on this install** | Superseded by `claudex-loop` |

Earlier releases also parked 12 research-integrity forensics skills; those are **not** on this
machine. The README's claim of "2 parked folders" matches reality — checked.

### 3.3 Dropped during porting (never shipped)

| Skill | What happened |
| --- | --- |
| `document` | Ported then **dropped**: it carried 28 references to upstream-only artifacts and the "live panel". Removed rather than shipped |
| `typeset`, `polish`, `craft` | `craft` was a **deprecated alias**; all three were script-coupled and did not survive the port. 6 skills were already ported, 22 of 28 met the bar, 1 was dropped |

### 3.4 Permanently blocked by the gate (documented, not hidden)

These are rows commented out in the manifest with the finding that blocked them, so the decision
stays auditable rather than silently forgotten. The README records the scope-level exclusions
(`rails-patterns`, `master-agreement-generator`, `esign-field-placement`, `tasteforge-video`, the
whole `Gskills` GCP set, AGPL `OpenMontage`, the `(gtm)` category, `openai/skills` `.system`).

### 3.5 Retired bundle tooling

| Artifact | What happened |
| --- | --- |
| `bin/retest-mcp.ps1` | Superseded by `bin/mcp-smoke-test.ps1`; removed |

### 3.6 The gap this review found

There is **no single `DEPRECATIONS.md`**. The history is correct but scattered across manifest
comments, CHANGELOG sections and two README tables — which is why this question needed a
30-command dig to answer. §3 above is that ledger, written down. It should live in the repo, not in
a chat.

---

## 4. Recommendation, in priority order

1. **Fix the MCP wiring before retiring anything.** 12 of 12 bundle servers are absent from VS
   Code. Until Phase 5 runs, every "unused" verdict on an MCP-first tool is measuring a
   misconfiguration, not a preference.
2. **Retire `idea-to-design`** (1 row) — genuinely superseded this session, 0 uses, duplicate
   trigger.
3. **Retire 4 duplicates** — `agent-self-evaluation`, `security-scan`, `ce-commit`,
   `planning-and-task-breakdown`. Four rows, no capability lost.
4. **Drop `semantica`** (365 MB, 0 uses, not MCP-wired) and put `specify`, `uipro`, `witr`,
   `git-wt` on a one-release watch.
5. **Write `DEPRECATIONS.md`** from §3 so the next review does not have to rebuild it.

None of this was executed — items 2–4 change what users get, and §1.1 shows the measurement is
partly confounded by the MCP gap. They are decisions for you.

---

## Method (reproducible)

```powershell
# 1. Corpus
(Get-ChildItem "$env:USERPROFILE\.copilot\session-state" -Recurse -File -Include *.jsonl |
  Measure-Object Length -Sum).Sum / 1MB      # 468 MB

# 2. Skills actually invoked (authoritative event, not text matching)
#    parse skill.invoked_ref from every events.jsonl  -> 256 invocations, 14 distinct

# 3. CLI invocations, strict = name starts a command segment
#    regex: (?:^|[;&|(]|&&|\|\|)\s*(?:[\w\\.-]*[\\/])?<cli>(?:\.exe|\.cmd)?\s  in tool.execution_start.arguments.command

# 4. Install cost
uv tool dir; Get-ChildItem <dir> -Directory | % { size }

# 5. Description budget
#    sum of len(description) over ~/.agents/skills/*/SKILL.md  -> 115,496 chars ~ 28,874 tokens

# 6. MCP reality
(Get-Content setup\mcp.json.template -Raw | ConvertFrom-Json).servers.PSObject.Properties.Name
(Get-Content "$env:APPDATA\Code\User\mcp.json" -Raw | ConvertFrom-Json).servers.PSObject.Properties.Name
```

