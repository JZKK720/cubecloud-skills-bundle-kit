---
name: evidence-graph-review
description: Evidence Graph Review — audit evidence-to-finding-to-path traceability, confidence grading, scope gating, and stop/replan conditions when authorization or evidence quality is insufficient. Methodology-only; no scripts, no tool execution.
license: MIT
metadata:
  version: "1.0"
  source: reverse-skill (methodology extraction, no upstream toolchain coupling)
  port: >-
    Clean methodology-only port. No GPL/AGPL, no offensive toolchain, no client-specific script dependencies.
    Methodology extracted from reverse-skill: ops/scope-contract.md, ops/evidence-finding-path.md,
    ops/analysis-decision-framework.md. Rewritten as read-only checklist/playbook.
---
# Evidence Graph Review

## Scope and Authorization Gate

**MUST** confirm `scope.md` before any analysis step:
- `scope.md` must exist under the current case root
- `auth.status` must be `granted`
- `network_profile.mode` must be set (offline | lab_only | authorized_target_only | unrestricted_lab)

If `scope.md` is missing or `auth.status != granted`, **STOP** and report scope deficiency. Do not proceed with any analysis or tool invocation.

## Evidence Discipline

### Evidence Records (E-xxx)

- Each evidence record is a self-contained Markdown file under the case root
- Must contain: `title`, `observed_at`, `source_type`, `source_ref`, `repro_command`, `raw_excerpt`, `linked_workitem`, `supersedes`
- `content_hash` and `artifact_path` are optional but MUST be recorded if a local artifact is referenced
- `repro_command` must be a real command that a third party can run, or explicitly marked `n/a` with documentation of the offline limitation

### Finding Records (F-xxx)

- Every Finding must reference at least one Evidence ID in `evidence_ids`
- When `status=validated`, `confidence` must be `high` or `medium`; `low` is only allowed with an explicit `residual_risk` note
- Findings without linked Evidence must be marked `status=candidate` and promoted only after additional Evidence is gathered

### Finding Sufficiency (R4*)

- `preliminary / candidate` → >=1 Evidence (unchanged)
- `validated` → SHOULD >=2 independent Evidence (best: 1 static + 1 dynamic). A single Evidence alone MUST NOT silently promote to validated — keep `candidate`, or record residual risk + human confirm
- `blocked promotion` → record `E-insufficient-evidence`

### Traceability

- All `F-xxx` records must have `evidence_ids` pointing to actual `E-xxx` records in the same case root
- `P-xxx` (Path) records must reference at least one `E-xxx` per step
- When reviewing scope, evidence, findings, or paths, the review is read-only and does not modify the case or any target

### Confidence Grading

- `high` → Evidence from multiple independent sources or a single well-anchored static/dynamic source
- `medium` → One source with corroborating context, or secondary source confirming a candidate
- `low` → single weak signal, cannot stand alone for validated promotion; residual_risk must be documented

## Path Contract

### Path Records (P-xxx)

- `path_type`: `attack` | `callflow` | `solve`
- Each step must have `action` and either `evidence` or `finding` reference
- `start` and `goal` must be concrete (file:line, URL, or well-scoped description)
- `residual_risks` must be listed if any step has uncertain outcomes

### Evidence Chain in Generated Reports

When `docs-generator` produces a report, it MUST include:
1. Scope summary linked to case `scope.md`
2. Evidence table or chapter
3. Findings list (with `evidence_ids`)
4. At least one Path (attack/callflow/solve) with steps, evidence, and finding references
5. Timeline summary (optional, linkable to `timeline.md`)

## Stop and Replan Conditions

**Stop** and report if any of the following hold:

1. `auth.status` in `scope.md` is not `granted`
2. No `scope.md` exists under the case root
3. A Finding has no linked Evidence IDs after a scope sweep
4. Confidence is `low` without an explicit `residual_risk` note
5. A Path step references an Evidence ID that does not exist in the same case root
6. A hash verification failure is detected when `--verify-hashes --strict` is requested

**Replan** if:

1. Additional independent Evidence can be gathered without violating scope
2. The user requests re-evaluation of confidence with new data
3. A scope or activity boundary shift is requested (update `scope.md` first)

## Recommended Review Procedure

1. Read `scope.md` and confirm `auth.status = granted`
2. List all `E-xxx` records; confirm each `F-xxx` references at least one `E-xxx`
3. Grade confidence per Finding
4. Verify all `P-xxx` steps have concrete `start`/`goal` and at least one evidence/finding reference
5. If `--verify-hashes` is requested, validate `content_hash` matches the artifact at `artifact_path`
6. Generate a concise review summary: scope OK, evidence count, findings count, path count, hash status
7. Stop: do not proceed to analysis, tool invocation, or report generation until all stop conditions are resolved

## Minimal Viable Review Command (read-only)

```bash
python3 skills/case-review/scripts/review_case.py work/<case> --format markdown
```

Or, if Python is unavailable, a pure prose checklist with the same gate logic.

---
## Version History

- 1.0: Initial release. Extracted from reverse-skill methodology docs (ops/scope-contract.md, ops/evidence-finding-path.md, ops/analysis-decision-framework.md). No scripts, no toolchain coupling.