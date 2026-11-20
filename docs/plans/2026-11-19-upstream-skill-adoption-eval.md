# Upstream Skill Adoption Evaluation — 2026-11-19

Scope: (1) refresh every installed skill from its upstream HEAD, (2) deep-dive the 13 candidate
repos proposed for this cycle, (3) decide whether `NVIDIA/SkillEvaluator` adds anything the
bundle's existing `skillspector` gate does not already cover.

Everything below is measured on this machine, not assumed. The gate used everywhere is
`skillspector scan <dir> --no-llm` (SkillSpector v2.12.0); a skill is installable only when it
exits **0**. Where a reviewed suppression baseline is applied, that is stated explicitly.

---

## 1. Refresh: every fork mirror was 21 commits behind

`bin/sync-fork-upstreams.ps1` was run for real (not `-DryRun`):

```
Done. Synced: 21, Already-up-to-date/skipped: 5, Failed: 0
```

`graphify` was skipped by design (upstream default branch moved `v4` → `v8`) and `caveman` is an
expected fork divergence. `bin/install-missing-skills.ps1 -Refresh` then refreshed **64** installed
skills from the synced mirrors (212 up-to-date/protected, 2 blocked).

Two audit defects were fixed in the same pass:

- **`bin/fast-audit.ps1` and `bin/full-audit.ps1` counted `~/.agents/skills/.backup-2026-10-31`
  as a skill.** That stray staging folder (holding one `executing-plans-SKILL.md.stub`) produced a
  permanent `SKILL-FILE FAIL` and, because Claude never mirrors a dot-directory, a permanent
  `MIRROR WARN`. Both audits now skip dot-directories when enumerating skills while still
  reporting the raw on-disk directory count. `fast-audit` also gained the extension-skill
  exemption logic that `full-audit` already had, so the two audits can no longer disagree.
  The stray folder was moved to `~/dev/upstream/backups/`, outside the discovery path.
- **`airunway-aks-setup` was installed but not mirrored.** Re-running `install-skill.ps1
  -SourcePath` restored the `~/.claude/skills` copy.

Result: `PASS=28 FAIL=0 WARN=0 ADVISORY=0 INFO=1` (from `PASS=27 FAIL=1 WARN=1 ADVISORY=0 INFO=1`).

---

## 2. The 13 candidate repos

`gh api` metadata, then a shallow clone, then `skillspector scan --no-llm`.

### 2.1 Adopted (4 repos, 9 skills)

| Repo | ★ | License | What it ships | Gate evidence | Decision |
| --- | --- | --- | --- | --- | --- |
| `kajisho5/ffmpeg-skill` | 8.1k | MIT | 42-tool FFmpeg skill + optional MCP server, stdlib Python only | Root: **exit 1**, 1 CRITICAL (YARA `php_webshell_known` on `docs/demos/lower_third_hindi.gif`), 160 HIGH, 544 MEDIUM — all in `tests/`, `.github/`, `docs/demos/`. Payload-only vendor: exit 1 → **exit 0** with `baselines/ffmpeg-skill.baseline.yaml` (141 suppressed, 0 remaining) | **Adopt**, vendored payload only |
| `obra/superpowers` | — | MIT | New in v7.0.2: `brainstorming`, `verification-before-completion`, `diagnosing-superpowers` | `brainstorming` exit 1 (HIGH P2 in `server.cjs`, HIGH TM1 in `stop-server.sh`, 7 MEDIUM) → **exit 0** with `baselines/brainstorming.baseline.yaml` (6 suppressed). Other two exit 0 clean | **Adopt `brainstorming`** |
| `google/elephant-goldfish-model` | 21.2k | Apache-2.0 | 8 EGM skills + 10-file `agents/` tree | `egm-lite` 7/100 LOW exit 0 · `egm-draft` 30/100 MEDIUM exit 0 · `egm-resolve` · `egm-drift-report` exit 0 · **`egm-bootstrap` exit 1 (HIGH AE1 ×4)** | **Adopt 4 self-contained** |
| `AgriciDaniel/claude-seo` | 30.7k | MIT | 29 skills + 11 paid-API extensions + 20 agents | `seo-plan` · `seo-competitor-pages` · `seo-hreflang` exit 0, 0 findings. 4 of the rest **FAIL** (`seo-agentic` 67, `seo-cluster` 77, `seo-google` 62, `seo-image-gen` 59 — all HIGH) | **Adopt 3 self-contained** |

### 2.2 Rejected, with the reason that decides it

| Repo | ★ | Gate / fit | Verdict |
| --- | --- | --- | --- |
| `erkamyaman/rust-anything` | 3.7k | exit **0** (44/100 MEDIUM, 1 finding: unpinned `npx jest`) | **Park** — needs `cargo install rust-anything` plus a `rust-anything setup` per project. The skill is a thin wrapper over a CLI the bundle does not provision; installing the prose alone would give the agent instructions for a binary that is not on PATH |
| `cloudflare/kitesurf` | 2.4k | 1 skill (`triage`), exit 0 | **Reject** — `triage` is Kitesurf-repo maintenance ("reproduce it in Kitesurf and in Chrome, check WPT"), not general-purpose |
| `meta/astryx` | 30.7k | exit 0, but HIGH P2 @ `SKILL.md:6–20` (70% confidence, HTML-comment block) | **Reject** — the skill is a one-page stub that instructs `npm i -g @astryxdesign/cli`; it requires the Astryx runtime and duplicates the bundle's existing `design-md-library` + `baseline-ui` + `improve-ui` coverage |
| `sherlock-project/sherlock` | 114k | **no SKILL.md** — it is a Python OSINT CLI | **Reject** — nothing agent-shaped to install |
| `punkpeye/awesome-mcp-servers` | 98k | **no SKILL.md** — a link list | **Reject** — a directory, not a skill. The bundle's `mcp-builder` and `setup/mcp.json.template` already cover the authoring/curation side |
| `google-research/paper-orchestra` | 4.5k | **no SKILL.md** — Python framework + web frontend | **Reject** — would need a vendored port; no agent-facing surface today |
| `ag-ui-protocol/ag-ui` | 20.5k | 23 SKILL.md, all repo-internal (`agui-dotnet-*`, `.github/skills/`, `sdks/dotnet/plugins/`) | **Reject** — every skill exists to maintain the AG-UI SDKs themselves |
| `cloudflare/security-audit-skill` | 75.4k | exit **1**, 12 findings, CRITICAL (HIGH MP3, PE3 ×5, AE1 ×5) | **Reject as-is** — the findings are false positives on a defensive guide (the "credential access" matches are prose like *"Hardcoded secrets … in logs, error messages"*), but making it installable needs a 12-fingerprint reviewed baseline. Deferred, not disproven — see §4 |
| `Vincentwei1021/video-shotcraft` | 21.4k | exit **1**, HIGH P2 ×3 @ `gallery/index.html` | **Reject** — Remotion/`npx` pipeline with an unpinned toolchain, and `hyperframes` already covers HTML-native video |
| `NVIDIA/SkillEvaluator` | 3.8k | skill itself exit **1** (2 HIGH AE1) | **Adopt the CLI only** — see §3 |

---

## 3. Do we need `NVIDIA/SkillEvaluator` when we already have SkillSpector?

**Short answer: not as a replacement, and not as a gate. Yes as an optional quality/advisory
CLI, which is what was added.**

They are not competing products; SkillEvaluator *consumes* SkillSpector.

- SkillSpector is a scanner. One question — *is this skill safe to install?* — 500+ static
  rules, a hard exit-1 block, and baseline suppression. That is exactly what a gate needs, and it
  is what every row in this bundle is gated with.
- SkillEvaluator is a three-tier framework. **Tier 1** wraps SkillSpector (plus Gitleaks, Bandit,
  Semgrep, pip-audit) alongside **its own** schema/version/PII/license/Unicode/script-lint checks
  and a 4-category quality score. Tier 2 is semantic deduplication across a collection. Tier 3 is
  live agent evaluation (Skill Lift, pass@k) in Docker against an LLM provider.

Measured here, with the CLI installed (`skillevaluator 1.0.1`, Python 3.13):

```
seo-aeo-audit   tier1 --no-llm:
  QUALITY                 PASS   quality B 84.5/100  (Correctness 70 / Discoverability 90 /
                                                      Reliability 90 / Efficiency 100)
  Harness Compatibility   PASS
  PII / License / Code Risk / Unicode   PASS
  Security Scan           INCOMPLETE  (skillspector did not complete — nested invocation)
  Secrets Detection       INCOMPLETE  (gitleaks not installed)
  Semantic Version        FAIL        (no version pin)
  Code Integrity          FAIL        (no Python test files)
```

What that buys the bundle, and what it does not:

| Capability | SkillSpector | SkillEvaluator | Worth adopting? |
| --- | --- | --- | --- |
| Security block on install | **yes** (exit 1) | delegates to SkillSpector | no — nothing new |
| **Quality score (0–100, graded)** | no | yes | **yes** — the one thing the bundle lacks |
| **Harness compatibility** (will Copilot actually load it?) | no | yes | **yes** — directly relevant to a multi-harness bundle |
| **Semantic overlap / deduplication** (Tier 2) | no | yes | **yes** — 287 manifest rows make duplicates likely |
| PII / license / Unicode / script lint | partial (Unicode, AST) | yes, separate checks | marginal — advisory |
| Live Skill Lift (Tier 3) | no | yes (Docker + LLM key) | no — Docker daemon is not healthy here and every row would cost tokens |

**Decision:** install the `skillevaluator` CLI as an *optional advisory* tool (`uv tool install
skillevaluator --python 3.13`) and do **not** put it in the install gate. `skillspector` stays the
gate because it is the one tool whose verdict is a blocking exit code, and because it runs without
a model key or Docker. `skillevaluator tier1` inherits SkillSpector anyway, so making it the gate
would add a second failure surface without adding a safety decision.

Its own upstream skill (`skills/skillevaluator/SKILL.md`) stays uninstalled: it gates at **exit 1**
with 2 HIGH AE1 findings, and it is a usage manual for a CLI that `--help` already documents.

**Caveat that decided the "advisory only" call:** on this machine `tier1` reports `Security Scan:
INCOMPLETE` even on skills `skillspector` alone passes cleanly, because the nested invocation does
not complete in-process. A gate that answers "incomplete" cannot be a gate.

---

## 4. What was installed

Manifest went **278 → 287** rows (`+9`); `~/.agents/skills` went **325 → 333**.

| Skill | Source | Baseline |
| --- | --- | --- |
| `ffmpeg-skill` | `upstream/ffmpeg-skill` (payload of kajisho5/ffmpeg-skill) | `baselines/ffmpeg-skill.baseline.yaml` — 90 fingerprints + 10 rules |
| `brainstorming` | `upstream/brainstorming` (obra/superpowers v7.0.2) | `baselines/brainstorming.baseline.yaml` — 6 fingerprints |
| `egm-lite`, `egm-draft`, `egm-resolve`, `egm-drift-report` | `upstream/<name>` (google/elephant-goldfish-model) | none needed — exit 0 |
| `seo-plan`, `seo-competitor-pages`, `seo-hreflang` | `upstream/<name>` (AgriciDaniel/claude-seo) | none needed — exit 0 |

All nine pass `skills-ref validate`. Three of the vendored ports needed frontmatter
normalisation: `argument-hint`, `user-invocable` and `disable-model-invocation` are Claude Code
keys that `skills-ref` rejects at top level, so they were nested under `metadata:`. (The bundle's
own installer already adds `argument-hint:` at install time as an accepted advisory.)

**Why vendored rather than `local/*` → straight clone:** `ffmpeg-skill` scans differently from its
repo root than from its own payload (CRITICAL YARA on a demo GIF vs. zero CRITICAL), and the EGM /
claude-seo ports needed frontmatter rewrites. Vendoring under `upstream/` keeps the exact bytes
that were scanned and reviewed identical to the bytes that get installed.

---

## 5. Deliberately not done

- **`ag-ui`, `kitesurf`, `awesome-mcp-servers`, `sherlock`, `paper-orchestra`** — no general-purpose
  agent surface (see §2.2). Nothing to install without inventing a port.
- **`rust-anything`** — parked, not rejected. It becomes adoptable the moment the bundle decides to
  provision `cargo install rust-anything`. The skill is exit-0 clean.
- **`cloudflare/security-audit-skill`** — the strongest remaining candidate. It is a genuinely
  good defensive-audit methodology that would extend `security-review` / `security-and-hardening`,
  and every one of its 12 findings is a static-analyser false positive on prose. Adopting it means
  committing a reviewed baseline, which is an operator decision, not an evaluation result. It also
  overlaps the existing `security-review` + `security-audit` coverage closely enough that the
  marginal value needs its own argument.
- **`video-shotcraft`, `astryx`** — both need their own runtime (`npx remotion`, `@astryxdesign/cli`)
  and both duplicate coverage the bundle already has.
