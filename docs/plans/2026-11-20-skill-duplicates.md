# Duplicate skills — Tier 2 similarity findings

Measured 2026-11-20 with NVIDIA SkillEvaluator Tier 2 over every installed skill, using **local
Ollama embeddings** (`nomic-embed-text:latest`, 768-dim, no API key, no egress).

## Current state: 4 pairs, 0 critical

After parking `build-mcp` (see below), a re-run reports **critical=0, high=4**. Of those four,
**two are false positives** — embedding similarity compares text and cannot know that one skill is
step 2 of another.

| Pair | Score | Verdict |
| --- | --- | --- |
| `deslop` ↔ `stop-slop` | 0.916 | Real overlap — the bundle carries six anti-slop skills (`deslop`, `stop-slop`, `no-ai-slop`, `anti-slop`, `skill-deslop`, `ce-noslop`). Curation decision |
| `azure-deploy` ↔ `azure-prepare` | 0.910 | **False positive** — sequential phases of one workflow |
| `humanize` ↔ `humanizer` | 0.905 | Real overlap — one capability, two names (`humanizer` is the tracked skill) |
| `capacity` ↔ `preset` | 0.902 | **False positive** — nested phase files inside `microsoft-foundry/`, not top-level skills |

## Resolved: the one exact duplicate

| Pair | Score | Evidence | Action |
| --- | --- | --- | --- |
| `build-mcp` ↔ `mcp-builder` | **0.970** | `build-mcp` was **1 file**; `mcp-builder` is **6**. Identical section structure (Overview / High-Level Workflow / Documentation Library) — a condensed copy of a taller skill already installed | **PARKED 2026-11-20**: `skills._disabled/build-mcp/`, manifest row `disabled=true` |

Reproduce:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File bin/skillevaluator-tier2.ps1
```

Provider setup this run used (the script sets it automatically when Ollama is reachable):

```
SKILL_EVAL_EMBEDDING_PROVIDER = openai-compatible
SKILL_EVAL_LLM_API_KEY        = ollama-local
SKILL_EVAL_EMBEDDING_BASE_URL = http://localhost:11434/v1
SKILL_EVAL_LLM_BASE_URL       = http://localhost:11434/v1
```

## A false-clean bug this run exposed

`bin/full-audit.ps1` first reported **"0 pair(s)"** while the collection plainly had duplicates.
Root cause: reaching Ollama is not sufficient — SkillEvaluator only embeds when
`SKILL_EVAL_EMBEDDING_PROVIDER` and `SKILL_EVAL_LLM_API_KEY` are **set**. Without them the run
finishes as `incomplete` with zero findings, and the parser read those zero findings as "clean".

Fixed two ways:
1. The audit sets the provider env vars for the call (restoring them afterwards).
2. The parser now **refuses to report a count from a non-`complete` run** — it prints
   `run incomplete - no trustworthy count (<reason>)` instead. A gate must never turn
   "could not measure" into "nothing found".

## Tooling

- `bin/skillevaluator-tier2.ps1` — runnable now, uses Ollama automatically, exits 0 even when
  duplicates are found (they are advisory, never blocking).
- `bin/full-audit.ps1` `AUDIT 8` — reports quality grade distribution and the duplicate count as
  INFO.
- SkillEvaluator's similarity check needs the `openai` client inside its tool env; the script
  installs it on first run (`uv pip install --python <tool> openai`).

