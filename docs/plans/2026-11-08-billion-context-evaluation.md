# billion-context — integration evaluation (2026-11-08)

Two requests were handled in this session: (1) sync the kit with upstream, and
(2) deep-research [`ranxianglei/billion-context`](https://github.com/ranxianglei/billion-context)
and decide whether it can be brought into the bundle. This report records the
evaluation and the decision; the sync itself is recorded in the CHANGELOG + merge
commit `f4ae3e3`.

## Decision

**Do not integrate.** `billion-context` is a poor fit for a SkillSpector-gated,
globally-installed skill bundle. No code was added. Revisit only as an **opt-in,
off-by-default CLI** behind an explicit (non-SkillSpector) security review of its
CA/MITM code, with MIT attribution — not as a `SKILL.md` skill or an `mcp.json`
server.

> Autopilot note: the integration decision was offered to the maintainer; with no
> response available, the recommended "do not integrate" option was taken because
> the only build paths require installing a root CA + rewriting agent `settings.json`
> globally, which must not happen without explicit approval.

## What it is

- A TypeScript/Node.js **context-compression proxy** (CLI name `bili`, npm
  `billion-context` v0.1.x) that sits between an AI coding agent and its model API,
  rewriting Anthropic/OpenAI streams with model-driven hierarchical compression
  ("~5× token savings"). Compression engine is a vendored `acp-kernel` sub-package.
- It injects four context tools (`compress`, `decompress`, `search_context`,
  `acp_status`) the model calls as context grows.
- **Not** a `SKILL.md` agent-skill (zero `SKILL.md` files in the repo) and **not** a
  standalone MCP server (its `plugins/codex/mcp-server.mjs` is a *companion* that
  needs a running `bili` proxy + `BILI_MCP_PROXY`/`BILI_CONVERSATION_ID`).
- Bilingual English + Chinese; ships a research preprint.

## Why it does not fit the kit's integration slots

| Kit slot | Exposed? |
| --- | --- |
| `SKILL.md` row in `skills-list.csv` | No — nothing to install; would need a brand-new wrapper skill |
| MCP server in `mcp.json` | No standalone server — the MCP entry requires the live proxy |
| CLI on PATH | Yes (`npm i -g billion-context`), but see runtime behavior below |
| clean-port under `upstream/` | Impractical — ~30 MB TS monorepo incl. MITM CA code |

## Runtime / security posture (the blocking concern)

- Runs a **persistent local proxy**, spawns children, installs `SessionStart`/
  `SubagentStart` hooks, and **rewrites agent `settings.json`** (pins
  `ANTHROPIC_BASE_URL` to the proxy, sets `DISABLE_AUTO_COMPACT=1`).
- For ~13 clients it performs **certificate-based HTTPS MITM**: generates a local CA
  and injects it via `NODE_EXTRA_CA_CERTS`/`SSL_CERT_FILE`/`REQUESTS_CA_BUNDLE` +
  `HTTPS_PROXY` to TLS-terminate whitelisted model hosts.
- **Polls a remote announcements feed ~every 3 minutes** by default; ships an
  auto-update policy.
- Sits in the critical path of **all model traffic and API keys**.
- SkillSpector scans *skill content*; it is the **wrong gate** for a binary proxy —
  real coverage would require a full software/security review. This is the opposite
  of the passive, static, gated skills the bundle installs globally.

## Health & license

- Very active: 4,682★, ~8,000 commits, 213 releases in ~3 months; single-maintainer;
  **pre-1.0** (v0.1.213) with a large open issue/PR backlog → unstable surface.
- Windows is first-class and CI-tested (requires an AV exclusion for its data dir).
- License is **MIT + a custom "Attribution on Product Surfaces" term** (GitHub flags
  it `NOASSERTION`). Redistribution/vendoring is permitted **but** any user-facing
  product must display visible attribution to `billion-context` **and** `acp-kernel`.

## If it is ever pursued

1. **Opt-in CLI (preferred):** add behind a new installer switch, off by default,
   gated on a manual security review of `src/ca.ts` / the remote-feed + auto-update
   logic, with the MIT attribution added to the kit's README/credits. Value only
   materializes once a user *activates* it (which reconfigures their agents).
2. **Thin wrapper `SKILL.md`:** cheap and SkillSpector-clean, but the gate would
   inspect only the wrapper, not the externally-installed proxy — a false sense of
   security with little real value.
