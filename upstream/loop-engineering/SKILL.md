---
name: loop-engineering
description: Design, scaffold, score, schedule, and govern autonomous agent loops. Use when building loop infrastructure — the mechanism layer that runs, monitors, and recovers agent loops. Complements loopy (loop content/design) with loop execution infrastructure. Covers loop scaffolding, health scoring, cron scheduling, governance policies, and failure recovery patterns.
---

# Loop Engineering

Build and operate the infrastructure that runs autonomous agent loops — the
mechanism layer that schedules, monitors, scores, and recovers loops. This is
the engineering counterpart to loopy (which designs loop content and
boundaries).

## When to use

- Building a new autonomous agent loop from scratch
- Adding scheduling, monitoring, or recovery to an existing loop
- Auditing loop infrastructure for reliability gaps
- Setting up loop governance (rate limits, budgets, approval gates)
- Debugging a loop that stalls, spins, or silently fails

## Core concepts

### Loop anatomy

Every loop has:
- **Trigger**: What starts it (cron, webhook, event, manual)
- **Body**: The work it does (triage → act → verify)
- **Gate**: What stops it (budget, time, approval, success signal)
- **Recovery**: What happens on failure (retry, escalate, pause, alert)

### Loop health scoring

Score loops on:
- **Completion rate**: % of runs that reach a terminal state
- **Budget adherence**: % of runs within token/cost budget
- **Action rate**: % of runs that produce a meaningful action (not just "no-op")
- **Recovery rate**: % of failures that self-recover without human intervention

### Governance patterns

- **Budget caps**: Hard limits on tokens, cost, or wall-clock time per run
- **Approval gates**: Human-in-the-loop for high-impact actions
- **Rate limits**: Max runs per hour/day, cooldown between runs
- **Audit trail**: Every run logs its trigger, actions, and outcome

## MCP integration

The loop-engineering MCP server (`@cobusgreyling/loop-mcp-server`) provides:
- Loop scaffolding and templating
- Health scoring and monitoring
- Cron-based scheduling
- Governance policy enforcement

Start the MCP server via `npx @cobusgreyling/loop-mcp-server` (stdio transport).

## Related skills

- **loopy**: Loop content design, discovery, and publication
- **loop-triage**: Triage recent changes for loop consumption
- **loop-constraints**: Enforce binding constraints before loop runs
- **loop-verifier**: Independent verification of loop-produced changes
- **loop-budget**: Token budget enforcement for loop runs
- **minimal-fix**: Produce smallest possible fix for loop-identified issues
- **continuous-agent-loop**: Patterns for long-running autonomous loops
- **autonomous-loops**: Architecture patterns for multi-agent loop systems
