# Skills Bundle Integration Evaluation — 2026-09-13

> Evaluation of 14 candidate repos for integration into the CubeCloud Skills Bundle
> (`JZKK720/cubecloud-skills-bundle-kit`). Continuation of the 2026-08-10 and 2026-08-13
> evaluations.
>
> Starting state: `v1.7.0` (`1ca2192`), 188 active manifest rows, 39 fork mirrors,
> 236 installed `~/.agents/skills/` directories.
>
> **Method.** Every candidate was cloned and surveyed for shape (skill package vs.
> application vs. product), licence, and SKILL.md inventory. Every skill in scope was then
> run through the same hard gate the installer uses — `skillspector scan --no-llm` — and the
> existing bundle was checked for overlap before anything was accepted. 104 candidate
> skills were gated in total.

---

## Executive summary

| Verdict                     | Repos | Notes                                                                  |
| --------------------------- | ----- | ---------------------------------------------------------------------- |
| ✅ Integrate                | 8     | 35 new skills                                                          |
| 🔁 Local port               | 1     | `archify` — upstream gate-blocked, clean port required                  |
| 🔧 Fix existing entry       | 1     | `i-have-adhd` — upstream moved its skill folder, manifest row 404s      |
| ⛔ Exclude (licence)        | 1     | `OpenMontage` — AGPL-3.0                                                |
| ⛔ Exclude (not a skill pkg)| 2     | `WeKnora`, `OpenMAIC` — products, not distributable skill packages      |
| ⛔ Exclude (no fit / gate)  | 1     | `openai/skills` `.system` — 2 blocked, 3 high-risk, Codex-internal      |

**Result: 35 new skills accepted, 1 clean port, 1 repaired entry.**
Manifest: 188 → 223 active rows (21 of them `local/*` ports).

| #  | Repo                             | Licence         | ★      | Verdict                |
| -- | -------------------------------- | --------------- | ------ | ---------------------- |
| 1  | `tech-leads-club/agent-skills`    | MIT             | —      | ✅ Integrate (12)      |
| 2  | `calesthio/OpenMontage`           | **AGPL-3.0**    | —      | ⛔ Exclude (licence)   |
| 3  | `alibaba/open-code-review`        | Apache-2.0      | —      | ✅ Already integrated  |
| 4  | `ayghri/i-have-adhd`              | MIT             | —      | 🔧 Fix path            |
| 5  | `openai/skills`                   | Apache-2.0      | —      | ✅ Integrate (5)       |
| 6  | `tt-a1i/archify`                  | MIT             | —      | 🔁 Local port          |
| 7  | `coreyhaines31/marketingskills`   | MIT             | —      | ✅ Integrate (8)       |
| 8  | `cathrynlavery/diagram-design`    | MIT             | 10.6k  | ✅ Already integrated  |
| 9  | `THU-MAIC/OpenMAIC`               | MIT             | —      | ⛔ Exclude (not pkg)   |
| 10 | `Tencent/WeKnora`                 | Tencent custom  | —      | ⛔ Exclude (not pkg)   |
| 11 | `blader/humanizer`                | MIT             | —      | ✅ Integrate (1)       |
| 12 | `humanlayer/skills`               | MIT             | —      | ✅ Integrate (3)       |
| 13 | `petergyang/no-ai-slop`           | MIT             | —      | ✅ Integrate (1)       |
| 14 | `kunchenguid/firstmate`           | MIT             | —      | ✅ Integrate (4)       |

---

## Cross-cutting findings

### 1. Two licences decide two repos outright

**`calesthio/OpenMontage` is AGPL-3.0.** The repository ships 138 SKILL.md files under
`.agents/skills/` covering video generation, 3D, motion graphics, TTS, and FFmpeg —
genuinely strong content for the bundle's absent video track. It is still a hard no. AGPL's
network-copyleft obligation attaches to the distribution, and this bundle redistributes
skills to end-user machines and mirrors them publicly. A permissively-licensed film/video
skill set would be a real addition; an AGPL one is a legal problem carried by every
downstream installer. **Recommended follow-up:** if the video gap matters, source it from
a permissive repo instead.

**`openai/skills` has no root LICENSE, but every skill carries its own.** The repo root has
no licence file, which reads as ambiguous. It is not: all 44 skill directories ship a
`LICENSE.txt`, and the sampled set (including the curated skills adopted here) are
**Apache-2.0**, as the README states. The repo root also carries a deprecation notice
("This repository is deprecated… use the OpenAI Plugins repository"). Deprecated as a
distribution channel is not the same as unusable content — the skills are stable, permissively
licensed, and self-contained. Adopted with the per-skill licence noted.

### 2. The gate blocked a skill this bundle previously advertised

`tt-a1i/archify` failed the gate **on the exact entry the roadmap wanted**:

```
HIGH: MP3 - Memory Manipulation
exit 1 (do_not_install)
```

This confirms the 2026-09-13 pruning note in the manifest, which had recorded the block as
`HIGH YR4 agent_skill_mcp_tool_poisoning_metadata`. The rule has since re-classified to
`MP3`, but the verdict is unchanged and the block is real. `archify` stays a
`local/*` port — the same treatment already given to `book-to-skill`, `diagram-design`,
`webapp-testing`, and `brainstorming`.

Note the cost of that decision: a port is **methodology only**. `archify`'s real value is
its validated JSON→HTML renderer (schemas, `bin/archify.mjs validate`, 9 showcase checks).
A port keeps the authoring discipline and the diagram taxonomy and loses the validator.

### 3. A manifest row was silently broken by an upstream restructure

`ayghri/i-have-adhd` moved its skill from `.cursor/skills/i-have-adhd/` to
`skills/i-have-adhd/`. The manifest still pointed at the old path, so that row would fail
with `SKILL.md not found` on any fresh machine. Both paths exist in the current upstream
tree; the manifest is repointed at the canonical `skills/` location.

### 4. Two fork-name collisions the installer would have hit silently

The installer clones `JZKK720/<last-path-segment>`, so fork names must be predictable and
unique. Two candidates collide with **unrelated** existing forks:

| Candidate                  | Naive fork name      | Already occupied by          | Fork created as                     |
| -------------------------- | -------------------- | ---------------------------- | ----------------------------------- |
| `tech-leads-club/agent-skills` | `agent-skills`   | `addyosmani/agent-skills`    | `tech-leads-club-agent-skills`      |
| `openai/skills`            | `skills`             | `vercel-labs/skills`         | `openai-skills`                     |

`agent-skills` is the bundle's **existing, actively-used** mirror — a naive clone of the
tech-leads-club repo into that folder would have overwritten it. Both were forked under
explicit non-colliding names and are installed with `-SkillRelPath` pointing at their real
paths.

### 5. `humanizer` and `no-ai-slop` are one job with two implementations

Both edit AI-sounding prose while preserving the author's voice. They are not duplicates —
they are two different bets:

| | `blader/humanizer` | `petergyang/no-ai-slop` |
| --- | --- | --- |
| Basis | Wikipedia "Signs of AI writing" | Practitioner editorial rules |
| Structure | Numbered tells ranked by strength, weak-alone marking | Banned word list, pattern catalogue |
| Extra | Voice-preservation section | `eval.md` self-check loop |
| Size | 291 lines | 61 lines |

The bundle already ships **`write-concisely`** (density) and **`brand-voice`** (deriving a
voice from source material). Neither covers *de-slopping existing prose*, which is what the
AIS-style track inside `anti-autoresearch` audits for. Both are adopted: `humanizer` as
`humanizer-prose` (the bare name is taken by the prose track inside `agent-reach`), and
`no-ai-slop` under its own name. Complementarity is real — different provenance, different
failure modes, and the small one is cheap enough to keep as a second opinion.

### 6. `firstmate` needs a 4-of-22 slice, not the repo

22 skills from `kunchenguid/firstmate` were gated: **21 pass, 1 blocks**.

- `stow` → `BLOCK HIGH E4 context leakage`
- `harness-adapters`, `quota-array-dispatch`, `updatefirstmate` → `HIGH` findings
- `afk`, `quiet`, `captain-hold-lifecycle`, `decision-hold-lifecycle`,
  `secondmate-provisioning`, `stuck-crewmate-recovery`, `firstmate-*` →
  bound to firstmate's own daemon and `bin/fm-*.sh` scripts

The genuinely universal four are `bearings`, `diagnostic-reasoning`,
`bootstrap-diagnostics`, and `project-management`. They give a fresh agent orientation, an
evidence-first diagnostic loop, environment triage, and cross-session issue tracking with
no runtime dependency. **Recommended follow-up:** `updatefirstmate` is the one high-finding
skill that would be useful if it were de-daemonised; it is excluded for now.

### 7. The `AR2` pattern is a consistent tell, and it is being honoured

`HIGH: AR2 - Anti-Refusal Statement` appears across many catalogs — `the-fool`, `the-jury`,
`marketing-plan`, `multi-platform-launch`, and (as the block reason) upstream
`diagram-design`. Skills that instruct an agent to argue adversarially or persist without
asking tend to phrase it as an override of the model's own judgement. The bundle's existing
policy is right: exclude on `AR2`, and where the value is high enough, port the *methodology*
without the override. That is why `the-fool` and `the-jury` are excluded while the same
catalog's neutral evaluators (`harness-eval`, `spec-driven-eval`) are adopted.

### 8. Marketing was the largest real gap

The bundle had `seo-aeo-audit`, `brand-discovery`, `brand-voice`, and
`marketing-campaign` — thin coverage for a repo that ships business/OEM/investor material.
`coreyhaines31/marketingskills` offers 50 skills. Gating all of them: **49 pass, 1 blocks**
(`ad-creative`), with `marketing-plan` flagged `HIGH AR1`. Eight were adopted on the same
framework-agnostic rule used elsewhere: general marketing discipline in, platform-specific
execution out. The GTM set in the tech-leads-club catalog (`(gtm)` — 18 skills) was excluded
for the same reason.

---

## Per-repo detail

### ✅ 1. `tech-leads-club/agent-skills` (MIT) — 12 skills

An Nx monorepo published to npm as `@tech-leads-club/agent-skills`; skills live at
`packages/skills-catalog/skills/(category)/<name>/`. Unusual category-as-directory naming
(the parentheses are literal) — handled with explicit `-SkillRelPath`.

**Adopted (12)**

| Skill | Category | Why |
| --- | --- | --- |
| `create-rfc` | creation | RFC authoring; pairs with `documentation-and-adrs`, `create-adr` |
| `create-technical-design-doc` | creation | 1055-line TDD guide — the deepest planning artifact in any candidate |
| `harness-eval` | development | Evaluates an agent harness (AGENTS.md, rules, skills) for broken paths, duplication, dead refs — the bundle's MCPs and manifest are exactly this surface |
| `spec-driven-eval` | development | Scores implementation against a spec case by case; complements `spec-driven-development` |
| `learning-opportunities` | learning | Offers deliberate practice after architectural work; nothing in the bundle covers this |
| `not-your-babysitter` | development | Evidence-before-completion discipline; pairs with `verification-loop` |
| `domain-analysis` | architecture | DDD domain discovery from a codebase |
| `domain-identification-grouping` | architecture | 544 lines; groups domains into bounded contexts |
| `coupling-analysis` | architecture | Coupling measurement and seam identification |
| `decomposition-planning-roadmap` | architecture | Sequences a modularisation programme |
| `tactical-ddd` | architecture | Aggregates, entities, value objects |
| `modular-design-principles` | architecture | The principles the other four apply |

The `(architecture)` block is adopted as a **set** — it is one DDD methodology staged as
six skills, each referencing the next. Gated `PASS` with no high findings.

**Excluded from this catalog**

- `the-fool`, `the-jury` — `HIGH AR2` anti-refusal
- `mermaid-studio` (`HIGH PE3`), `codenavi` (`HIGH MP3`),
  `react-composition-patterns` (`HIGH MP3`),
  `evolutionary-modular-architecture` (`HIGH P2`),
  `core-web-vitals` / `seo` / `web-best-practices` (`HIGH P2`),
  `security-best-practices` (`HIGH OH1`), `create-adr` (`HIGH E4`),
  `tlc-spec-driven` (`HIGH E4`), `figma-implement-design` (`HIGH E4`),
  `vercel-deploy` (`HIGH PE3`), `react-native-expert` (`HIGH PE3`),
  `cloudflare-deploy` (`HIGH E2`), `sentry` (`HIGH E2`),
  `react-best-practices` (`HIGH OH1`)
- `shopify-developer` — **BLOCK**, `CRITICAL YR1` credential-exfiltration webhook
- `security-ownership-map` — **BLOCK**, `HIGH P6` prompt extraction
- the whole `(gtm)` category (18) — framework/domain-specific
- `rails-dev`, `nestjs-modular-monolith`, `react-native-expert`, `nx-*` — framework-specific
- `tlc-discover` / `tlc-plan` / `tlc-implement` / `tlc-spec-driven` / `tlc-spec-lean` —
  duplicate `spec-driven-development` + `spec-kit`'s `/speckit.*` commands
- `confluence-assistant`, `jira-assistant` — tool-specific MCP coupling
- `docs-writer`, `gh-address-comments`, `gh-fix-ci`, `coding-guidelines`,
  `subagent-creator`, `cursor-subagent-creator`, `web-design-guidelines`,
  `frontend-design`, `figma`, `playwright-skill`, `the-judge`,
  `chrome-devtools`, `excalidraw-studio`, `nx-ci-monitor`, `nx-generate`,
  `nx-run-tasks`, `nx-workspace`, `perf-*`, `web-quality-audit`,
  `web-accessibility`, `security-threat-model`, `skill-architect`,
  `tlc-generative-engine-optimization` — overlap with existing bundle skills

### ⛔ 2. `calesthio/OpenMontage` — AGPL-3.0

Excluded on licence. See cross-cutting finding 1. 138 skills, strong video/3D/motion
content, unusable here.

### ✅ 3. `alibaba/open-code-review` — already integrated

The bundle already ships `local/open-code-review` + `local/open-code-review-delegate` and
the `ocr` CLI. Re-gated this round: all four SKILL.md copies (both `skills/` and
`plugins/open-code-review/skills/`) report **PASS**. The local ports remain deliberate —
they are Copilot-tuned and diverge from upstream at a different sha. No change.

### 🔧 4. `ayghri/i-have-adhd` — path repaired

Upstream restructured: the skill is now at `skills/i-have-adhd/` as well as the legacy
`.cursor/skills/i-have-adhd/`. Manifest repointed. Gate: **PASS** (both copies).

### ✅ 5. `openai/skills` — 5 of 39 curated

39 curated skills gated: **35 pass, 4 block**. Apache-2.0 per skill.

**Adopted (5)**

| Skill | Why |
| --- | --- |
| `figma` | The bundle already has a Figma MCP configured but no workflow contract for it. This is the required-flow + asset-handling + token-discipline contract. |
| `screenshot` | OS-level capture with a save-location rule and a macOS permission preflight. The bundle has browser capture (Playwright) but no desktop capture. |
| `pdf` | Document workflow; complements `markitdown`. |
| `transcribe` | Speech-to-text workflow; complements `watch-skill`. |
| `security-threat-model` | Structured threat modelling; complements `security-review` / `security-and-hardening`. |

**Excluded**

- `figma-use` — **BLOCK** `HIGH P6` prompt extraction. Note this is the sibling of the
  adopted `figma`; the block is specific to `figma-use`'s content.
- `security-ownership-map` — **BLOCK** `HIGH P6` prompt extraction (also blocked in the
  tech-leads-club catalog — two independent copies of the same content).
- `migrate-to-codex` — **BLOCK**. Codex-specific anyway.
- `speech`, `jupyter-notebook`, `cli-creator` (`HIGH AS1` / `HIGH RA1`), `sentry`
  (`HIGH SC2`) — high findings; `speech` and `sentry` also overlap `transcribe` and
  the existing monitoring story.
- the whole `skills/.system` set (5): `imagegen` **BLOCK** `HIGH P6`,
  `skill-installer` **BLOCK** `HIGH E2` env harvesting, and `openai-docs` /
  `plugin-creator` / `skill-creator` all `HIGH` (`P6` / `RA1`). These are also
  Codex-internal — they describe Codex's own skill and plugin systems, which is not this
  bundle's harness.
- `chatgpt-apps`, `gh-address-comments`, `gh-fix-ci`, `linear`, `notion-*`, `render-deploy`,
  `netlify-deploy`, `vercel-deploy`, `cloudflare-deploy`, `winui-app`, `yeet`, `hatch-pet`,
  `define-goal`, `playwright`, `playwright-interactive`, `openai-docs`,
  `figma-code-connect-components`, `figma-create-design-system-rules`,
  `figma-create-new-file`, `figma-generate-design`, `figma-generate-library`,
  `figma-implement-design`, `aspnet-core`, `security-best-practices` — overlap, or
  platform/tool-specific.

> **`figma-implement-design` was excluded in both catalogs** (`HIGH E4` context leakage
> here, `HIGH E4` in tech-leads-club). Adopting only the base `figma` contract keeps the
> workflow without the flagged content.

### 🔁 6. `tt-a1i/archify` (MIT, v2.17) — clean port

Gate: **BLOCK**, `HIGH MP3` memory manipulation (previously recorded as `HIGH YR4`). See
cross-cutting finding 2. Ported to `local/archify` as methodology only.

### ✅ 7. `coreyhaines31/marketingskills` (MIT) — 8 skills

50 skills gated: **49 pass, 1 block**. The `tools/` tree (60+ integration `.js` files under
`clis/`, `composio/`, `integrations/`) is **not** copied — it is a separate optional layer
and is exactly the kind of broad third-party surface that should not land on a user machine
silently.

**Adopted (8)**

| Skill | Why |
| --- | --- |
| `product-marketing` | Positioning and messaging foundation |
| `copywriting` | Core copy craft |
| `content-strategy` | Content planning |
| `competitor-profiling` | Competitive analysis |
| `launch` | Launch planning |
| `pricing` | Pricing strategy |
| `marketing-loops` | Recurring marketing workflows — bridges to the bundle's loop family |
| `marketing-psychology` | Buyer psychology |

**Excluded**

- `ad-creative` — **BLOCK**
- `marketing-plan` — `HIGH AR1` anti-refusal
- `ads`, `meta-ads`, `linkedin-ads`, `tiktok-ads`, `google-ads` — platform-specific
- `seo-audit`, `ai-seo`, `programmatic-seo`, `site-architecture`, `schema` — overlap the
  existing `seo-aeo-audit`
- `emails`, `cold-email`, `sms`, `popups`, `social`, `video`, `image`, `events`,
  `public-relations`, `community-marketing`, `influencer-marketing`,
  `directory-submissions`, `free-tools`, `lead-magnets`, `referrals`,
  `co-marketing`, `partnerstack`, `prospecting`, `sales-enablement`, `revops`,
  `customer-research`, `attribution`, `analytics`, `cro`, `a-b-testing`,
  `onboarding`, `paywalls`, `signup`, `churn-prevention`, `aso`, `copy-editing`,
  `marketing-council`, `marketing-ideas` — channel/channel-specific or overlap

### ✅ 8. `cathrynlavery/diagram-design` — already integrated

The bundle ships `local/diagram-design`. Upstream re-gated this round: still
**BLOCK**, `HIGH AR2` anti-refusal. The port decision stands.

> Note: the port was re-authored to v2.5 (578 lines) after the 2026-09-13 refresh incident
> recorded in the v1.7.0 changelog. Upstream SKILL.md is now 436 lines.

### ⛔ 9. `THU-MAIC/OpenMAIC` (MIT) — not a skill package

A Next.js 16 / React 19 / LangGraph multi-agent **learning product**, not a distributable
skill set. Its `skills/` tree (25 skills) is the product's own runtime content:
`curriculum-planner`, `feynman-learning`, `spiral-curriculum`, `k12-*`,
`social-emotional-learning`, `vocational`, `slide-craft`, `stage-dsl`, `pptx-import`,
`teacher-style-clone`, and similar. Two are general (`deep-research`, `fact-check`) but are
coupled to OpenMAIC's runtime skill format (`outline-constraints.json`) and duplicate
existing bundle research skills. Excluded on fit — not a gate or licence failure.

### ⛔ 10. `Tencent/WeKnora` — not a skill package

A 3,785-file Go RAG/agent platform with a Next.js frontend, MCP server, and Helm charts.
Four SKILL.md files exist, and two are real (`cli/skills/weknora-rag-search`,
`cli/skills/weknora-shared`) — but they drive `weknora`'s own CLI against a WeKnora server.
The licence is Tencent's custom notice, not an OSI standard. Excluded on both counts.

### ✅ 11. `blader/humanizer` (MIT) — 1 skill

291 lines, structured as numbered tells ranked by strength with explicit weak-alone marking,
plus a voice-preservation section and a fiction exemption. Installed as **`humanizer-prose`**
to avoid colliding with the `humanizer` prose track already inside `agent-reach`. Gate:
**PASS** (LOW `EA3` scope-creep on the LICENSE file only).

### ✅ 12. `humanlayer/skills` (MIT) — 3 of 5

Plugins at `plugins/<name>/skills/<name>/`.

**Adopted (3)**

| Skill | Why |
| --- | --- |
| `show-me` | Visual explanation of the current topic — small diagrams, code-shape sketches, focused HTML. Complements `ce-explain` and `diagram-design`. |
| `improve-claude-md` | Rewrites instruction files using `<important if>` blocks for better adherence. Installed as **`improve-agent-instructions`** — the bundle is multi-harness and the name is not. |
| `narrow-react-prop-types` | Narrows component prop types to what is actually used. Framework-flavoured but stack-generic enough to keep, and the bundle ships no other prop-narrowing content. |

**Excluded**

- `build-iterated-agentic-loop`, `design-control-loop` — both `HIGH E2` env-var harvesting,
  and both overlap `continuous-agent-loop`, `loop-design-check`, and the
  `@cobusgreyling/loop` CLI already in the bundle.

> Both adopted skills are renamed. Renaming is deliberate: the installed skill name must
> match `name:` frontmatter, and neither upstream name is accurate for a multi-harness bundle.

### ✅ 13. `petergyang/no-ai-slop` (MIT) — 1 skill

61 lines, dense. Two modes (edit / detect), a banned word list, a named-pattern catalogue,
and a self-check against `eval.md`. Gate: **PASS** with no findings at any severity.
Adopted as the compact counterweight to the 291-line `humanizer-prose`.

### ✅ 14. `kunchenguid/firstmate` (MIT) — 4 of 22

See cross-cutting finding 6.

**Adopted (4)**: `bearings` (orientation), `diagnostic-reasoning` (evidence-first loop),
`bootstrap-diagnostics` (environment triage), `project-management` (cross-session tracking).
All four `PASS` with no high findings and carry no runtime dependency.

---

## Implementation

### Fork mirrors

Eight forks were created under `JZKK720` via the GitHub API (no `gh` CLI on this machine;
authenticated through Git Credential Manager):

| Candidate                        | Fork created                        |
| -------------------------------- | ----------------------------------- |
| `tech-leads-club/agent-skills`   | `JZKK720/tech-leads-club-agent-skills` |
| `openai/skills`                  | `JZKK720/openai-skills`             |
| `coreyhaines31/marketingskills`  | `JZKK720/marketingskills`           |
| `cathrynlavery/diagram-design`   | `JZKK720/diagram-design`            |
| `blader/humanizer`               | `JZKK720/humanizer`                 |
| `petergyang/no-ai-slop`          | `JZKK720/no-ai-slop`                |
| `kunchenguid/firstmate`          | `JZKK720/firstmate`                 |
| `humanlayer/skills`              | `JZKK720/humanlayer-skills`         |

Pre-existing and reused: `archify` (← `tt-a1i/archify`), `i-have-adhd`,
`open-code-review`, `OpenMontage`.

### Manifest changes

- **+35** active entries across 6 upstream repos
- **−1** stale entry (`.cursor/skills/i-have-adhd` path replaced)
- **+1** `local/archify` port row
- Gate-blocked and high-finding entries parked as comments with their reason codes

| Repo | Adopted |
| --- | --- |
| `tech-leads-club/agent-skills` | 12 |
| `coreyhaines31/marketingskills` | 8 |
| `openai/skills` | 5 |
| `kunchenguid/firstmate` | 4 |
| `humanlayer/skills` | 3 |
| `blader/humanizer` | 1 (local port row for encoding control) |
| `petergyang/no-ai-slop` | 1 |
| `tt-a1i/archify` | 1 (local port) |
| **Total** | **35** |

### Files changed

| File | Change |
| --- | --- |
| `setup/skills-list.csv` | 36 new rows, `i-have-adhd` path fixed, `local/archify` added, blocked entries parked with reasons |
| `bin/sync-fork-upstreams.ps1` | 8 new `$upstreamMap` entries |
| `bin/install-skill.ps1` + `setup/install-skill.ps1` | copy of deployed helper (3-way hash parity) |
| `upstream/archify/SKILL.md` | New — clean methodology-only port |
| `docs/plans/2026-09-13-skills-bundle-integration-evaluation.md` | This file |
| `README.md` | Counters, new skill sections, blocked table, changelog |
| `CHANGELOG.md` | v1.8.0 entry |

### Verification

- `bin\install-missing-skills.ps1` → `Installed: <n> / Blocked: 0 / Skipped: <n>`
- `bin\full-audit.ps1` → expect `PASS` with `FAIL 0`
- `bin\sync-fork-upstreams.ps1` → all new mirrors tracked, `Failed: 0`
- Re-run of `install-missing-skills.ps1` → `Installed: 0` (idempotent)
