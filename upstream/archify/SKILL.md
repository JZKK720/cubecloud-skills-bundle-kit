---
name: archify
description: Create polished, validated architecture, workflow, sequence, data-flow, and lifecycle/state diagrams as explorable standalone HTML with inline SVG, dark/light themes, optional trace motion, and PNG/JPEG/WebP/SVG/WebM export. Accept plain-language requirements or pasted Mermaid flowchart, sequenceDiagram, and stateDiagram input; inspect repository evidence when the diagram must reflect real code. Use when the user asks to visualize system architecture, infrastructure, cloud/security/network topology, technical workflows, API call sequences, request lifecycles, data pipelines, ETL/ELT, data lineage, state machines, or to convert/beautify Mermaid.
license: MIT
metadata:
  version: "2.17"
  author: tt-a1i
  based_on: Cocoon-AI/architecture-diagram-generator (MIT, v1.0)
  port_note: Methodology-only port. See "About this port" below.
---

# Archify

Create a self-contained, interactive HTML diagram from a small typed JSON specification. Static
output is the default; enable motion only when the user asks for a demo or presentation.

The core discipline is **artifact first**: author one small typed JSON candidate, validate it,
and let the validator's own diagnostics drive each repair. Do not plan coordinates in prose.

## About this port

This is a **methodology-only port**. Upstream `tt-a1i/archify` is blocked by the bundle's
SkillSpector hard gate (`HIGH MP3` memory manipulation, reported against its bundled MCP
metadata), so the renderer, schemas, examples, and brand-mark database are **not** installed
here. What is preserved is the part that carries the judgement: the authoring contract, the
type router, the invariant list, the Mermaid conversion rules, and the validate-→-deliver-→
visual-check sequence.

To run the commands referenced below, use an upstream checkout:

```
~/dev/forks/JZKK720/archify/archify/     # fork mirror (gitignored, re-cloned)
```

Read `schemas/<type>.schema.json`, `schemas/common.schema.json`, and one matching file in
`examples/` from that checkout before authoring. If the checkout is absent, the method below
still applies — author the JSON by hand against the type router and invariants, and skip the
CLI steps rather than inventing them. Never describe a validation or delivery step as having
passed when the command was not run.

## Fast authoring path

Use this bounded path for ordinary generation. Read the optional Viewer Runtime reference only
when the user asks about those features.

1. Choose `architecture`, `workflow`, `sequence`, `dataflow`, or `lifecycle` from the question.

2. Read one matching schema, `schemas/common.schema.json`, and one matching JSON example. Read
   only those files. Fresh authorship means new stable IDs, domain wording, and layout; use the
   example for field shape, not facts. New workflow sources use `schema_version: 2` and its
   readable layout contract; keep `schema_version: 1` only when preserving an existing
   workflow's fixed geometry. When real product identity matters, query
   `node bin/archify.mjs brands "<name>" --json`; read `references/brand-marks.md` only for an
   unknown brand with a user-provided URL.

3. **Artifact first: the next tool action must write the candidate.** Write the candidate before
   inspecting renderer internals. Do not plan exact coordinates in prose. Start with one clear
   main path, short side branches, sparse labels, and at most 12 primary nodes. Set
   `meta.quality_profile` to `"showcase"` unless the user explicitly requests a dense
   `standard` map. Start with automatic routes and labels. Do not add `via`, `channelX`,
   `channelY`, or `labelAt` before a diagnostic calls for one; apply at most one diagnosed
   geometry control per repair.

4. Validate after every candidate edit and immediately before handoff:

   ```bash
   node bin/archify.mjs validate <type> <candidate.json> --quality showcase --json
   ```

   A receipt with only 4 artifact checks is basic validation, never showcase acceptance. A
   showcase pass must report all 9 artifact checks with 0 composition errors and 0 warnings. If
   the candidate omits or misspells the exact `meta.quality_profile` field, fix it before
   geometry. For a workflow v2 geometry diagnosis, run
   `node bin/archify.mjs validate workflow <candidate.json> --layout-json` and use the stable
   compiler receipt; solver internals are not authoring controls. **A passing final validation
   freezes the candidate: never edit it afterward.**

5. For a delivered HTML, `deliver` is the final acceptance command:

   ```bash
   node bin/archify.mjs deliver <type> <candidate.json> <output.html> --quality showcase --json
   ```

   A non-zero exit can never be described as success. A failed delivery preserves any previous
   output, so do not run `visual-check` on that path: it would inspect the stale last-good
   artifact, not the failed candidate. If validation fails, change only the diagnosed `subject`,
   verify `evidence`, choose from `supportedFixes`, and rerun. Continue focused correction while
   the objective error count reaches a new minimum. If two consecutive rounds do not improve that
   best count, stop and report the unresolved diagnostics truthfully.

## Type router

| Type | Use for |
|---|---|
| `architecture` | Components, services, cloud/security boundaries, infrastructure |
| `workflow` | Processes, approval gates, tool calls, runbooks, CI/CD |
| `sequence` | API call chains, request lifecycles, async traces, returns |
| `dataflow` | Pipelines, ETL/ELT, lineage, governance, consumers |
| `lifecycle` | State/status transitions, retries, waiting and terminal states |

When ambiguous, run `node bin/archify.mjs guide "<scenario>" --json`. Scenario proof examples
are structural references, not facts to copy.

## Mermaid input

Read Mermaid for topology and meaning, then author fresh Archify JSON; do not mechanically
render Mermaid styling.

- `flowchart` / `graph` → `workflow`, or `architecture` for a component map.
- `sequenceDiagram` → `sequence`; participants become semantic participants and arrows become
  messages.
- `stateDiagram` → `lifecycle`; states and transitions retain meaning, not Mermaid style.

## Authoring invariants

- **One obvious main path**; side branches leave the nearest main-path node. Remove low-value
  edges before adding routing controls.
- **Omit `meta.visual_preset` by default** so every diagram opens in `classic`, regardless of
  whether its resolved color mode is light or dark. Color mode and visual preset are
  independent: switching Light / Dark must preserve the current preset. Set `signal-flow`,
  `blueprint`, or `editorial` only when the user explicitly requests that visual style.
- **Omit `meta.subtitle` by default.** Never invent a subtitle that restates the title, nodes, or
  cards; include one short supporting line only when the user explicitly asks for it.
- **Treat the standalone desktop viewer as a first-screen artifact**, not a shallow strip.
  Generate one responsive artifact for laptops and external displays — never device-specific
  HTML or alternate topology. The viewer may adapt only the outer reading width from the live
  viewport height; it must preserve the authored SVG/viewBox, proportions, semantic geometry,
  and normal document flow. On a wide or tall desktop, use enough authored vertical rhythm that
  the diagram panel and its necessary conclusion cards occupy the screen as a balanced whole;
  runtime scaling cannot repair an over-compressed Y layout or an undersized explicit
  `meta.viewBox`. Before handoff, open the real HTML at 1440×900, 1600×1000, and 1920×1080;
  additionally check 2048×1320 whenever the composition targets a large desktop display.
  Require `document.documentElement.scrollWidth <= window.innerWidth` and
  `scrollHeight <= window.innerHeight` at every checked size, while visually checking that the
  diagram remains comfortably readable and vertically balanced at the largest checked viewport.
  Repair overflow by removing genuinely redundant content or compacting spacing before shrinking
  nodes, labels, or the main panel. If the largest viewport still has a conspicuous empty lower
  band at the viewer's width cap, redistribute authored Y positions and increase the viewBox
  height proportionally; do not add filler copy or decorative cards. Never counterfeit a pass
  with `overflow: hidden`, clipped content, an internal diagram scroller, stretched SVG height,
  or smaller typography. Narrow/mobile layouts may scroll vertically when containment requires it.
- **Omit `meta.legend`** for the truthful `auto` default. When needed, use only
  `mode: auto|all|hidden` and renderer-supported `entries.<kind>.label|visible`; labels never
  change semantics.
- **Choose one primary authored language** from an explicit user choice; otherwise follow the
  request or the conversation's dominant language. `meta.locale` controls only renderer-owned
  Viewer UI: use `"en"` or `"zh-CN"` for the corresponding supported primary language. For every
  other language, omit `meta.locale` and explicitly disclose that the fixed Viewer UI and
  `<html lang>` fall back to English. The renderer never translates authored content.
- **Preserve exact product names, code identifiers, commands, protocols, API paths, and
  environment names.** They may remain English inside localized copy, but never justify leaving
  the surrounding explanatory prose in another language.
- **Brand identity is optional and explicit.** Put a canonical built-in ID in `brand` when the
  node names that real product. If no preset matches and the user supplied the official HTTP(S)
  URL, first run `node bin/archify.mjs brands capture "<url>" --json`, then author the returned
  digest-pinned `brand` object. Render and validate never perform an unpinned capture. Otherwise
  omit `brand`. Never infer a brand from a vague role such as "database", and never let a badge
  replace the semantic `type`, label, or relationship facts.
- **For sequence diagrams**, omit `meta.column_fit` for the stable `fixed` layout. Set it to
  `"spread"` when a wide viewBox would otherwise leave unused horizontal space or when
  meaningful participant labels do not fit the fixed boxes; do not shorten semantic labels
  before trying `spread`.
- **Component types** are `frontend`, `backend`, `database`, `cloud`, `security`, `messagebus`,
  and `external`; **variants** are `default`, `emphasis`, `security`, and `dashed`.
- **Relationship labels are semantic data.** When one collides, move the label, adjust the route
  or spacing, then shorten the wording while preserving meaning. Omit only wording that is
  already fully implied by both endpoints and contains no protocol, action, direction,
  synchronous/asynchronous behavior, or cross-boundary mechanism. Preserve every meaningful
  label; deleting it is not a geometry repair. If a relationship starts unlabeled because its
  endpoints fully imply it, explain why the wording is redundant; this is a semantic authoring
  choice, not a geometry repair.
- **Omit `meta.engineering_profile` by default.** Region, cluster, and security-boundary wording
  do not by themselves enable it. Enable `deployment-ownership` only when the user explicitly
  asks for a production deployment topology, ownership handoff, or fail-closed deployment review
  and the source facts are known. Once enabled, do not remove the engineering profile merely to
  pass validation; repair the facts or report the diagnostics truthfully.
- **Spacing means clear gap, not center distance.** For a relationship label, clear gap must
  exceed its measured mask width; follow the label-preserving repair order.
- **Automatic routes own their endpoint sides.** A side is a direction contract: the first and
  final segment must leave/enter perpendicular to that side.
- **Automatic Port Spread** is a default renderer behavior for architecture, workflow, data-flow,
  and lifecycle. It skips single relationships and explicit `via`, `channelX`, `channelY`,
  `labelAt`, or non-`auto` routes. Near-parallel ports use an outside bridge so automatic routing
  cannot create a sub-8px segment or sub-16px interior turn. Architecture separately keeps
  unobstructed facing automatic ports (`left`/`right` or `top`/`bottom`) on one shared axis when
  their offset is under 16px and both ports retain corner clearance. If exactly one endpoint was
  spread, only the unshared endpoint may move onto that axis; if both endpoints were spread, keep
  the outside bridge so competing ports remain distinct.
- **Never accept** an edge crossing an unrelated opaque node, an ambiguous shared corridor, or a
  relationship label masking another route.

Read `references/authoring-contract.md` only when you need field enums, spacing math, geometry
repair rules, repository evidence, or mode-specific placement.

## Validation and delivery are three separate claims

Do not conflate them, and never let one imply another:

1. **`deliver`** proves deterministic artifact checks and byte identity. It reads the
   specification once, writes those exact bytes to a private same-directory snapshot, renders
   that snapshot, runs the complete artifact checker, and only replaces the target after all
   checks pass. The JSON receipt includes SHA-256 and byte counts for both `specification` and
   `artifact`. A renderer, checker, receipt, or commit failure exits non-zero, removes private
   state, preserves the previous trusted artifact, and never invokes an opener.
2. **`visual-check`** collects automated browser evidence from the exact delivered artifact:

   ```bash
   node bin/archify.mjs visual-check <output.html> --json
   ```

   The zero-dependency command uses Chrome/Chromium through the DevTools pipe. It measures
   light-theme containment at 1440×900, 1600×1000, 1920×1080, and 2048×1320, then captures
   light/dark screenshots at 1440×900 and 2048×1320. It writes PNG sidecars, a relative-path HTML
   contact sheet, and a JSON receipt beside the artifact. `visualReview` is always
   `"pending"` — automated browser evidence cannot claim perceptual review.

   Map the outcome exactly: exit 0 + `status: "pass"` → `passed`; exit 1 + `status: "fail"` →
   `failed`; exit 2 + `status: "skipped"` (Chrome/Chromium unavailable) → `skipped`. A runtime or
   capture failure is **incomplete evidence** — never normalise it to `skipped`. A failed or
   skipped capture does not invalidate an already-successful deterministic delivery, and it does
   not turn a perceptual review into passed or failed.
3. **Perceptual visual review** records a human or image-capable reviewer's judgement. Passing
   one claim never implies either of the others. Never claim the deterministic receipt includes
   visual review; it does not include browser evidence either.

Run `visual-check` **only after `deliver` exits zero for the current candidate.** If delivery
failed and the output path already exists, that path still names the previous trusted artifact;
running `visual-check` then would measure stale output, not the rejected candidate.

**Optional opening.** Add `--open` only when the user wants an immediate local preview. It runs
after the atomic commit, uses one argument-array OS opener with a five-second bound, and records
`open.status`. Keep it off for CI, unattended agents, and non-interactive environments. Failure
or unsupported opening does not invalidate delivery.

**Last-good live preview** (active desktop authoring loop only):

```bash
node bin/archify.mjs preview <type> <input>.json <output>.html --quality showcase
```

Preview watches one explicit input on loopback, binds each stable digest to a private snapshot,
and advances only after the verified delivery pipeline passes. Invalid, half-written, deleted, or
superseded input leaves the previous verified revision on screen and on disk. **Never start it by
default.** Do not use it for CI, unattended agents, remote sharing, or mobile use. Stop it with
Ctrl-C before handoff. Server state, port, source path, diagnostics, error text, and reload tokens
must never enter the generated artifact or any export.

## Handoff

Report the artifact path, the diagram type, and the outcome of each of the three claims
separately. State plainly which commands actually ran and which did not. If the renderer was
unavailable, say so and present the authored JSON as the deliverable rather than describing an
unrun validation as a pass.
