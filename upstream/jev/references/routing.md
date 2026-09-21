# Choose a tool, model or specialist

Use this mode through `jev`. Adapt [the request template](../assets/routing.json)
to the actual evidence and criteria, then follow the parent skill's setup and runtime instructions.

## Workflow

1. Inventory actual available capabilities, allowed spending and task constraints. Do not infer access from a model name or prestige tier.
2. Describe each candidate by what it can and cannot do. Supply the current subtask and relevant preceding state, not an entire unrelated transcript.
3. Separate selection from invocation. Show a recommendation unless the user already authorized the handoff and the host has an invocation tool.
4. Preserve fallback routes for unavailable, uncertain or failed candidates. A recommendation does not authorize sharing data with another provider.
5. Evaluate routing regret and completed work along with total cost, cache loss and retries. This skill is not the upstream Codex Router service.

## Context and parallelism

Jev does not inherit the agent's history. Give every request sufficient context:
the subtask and goal, relevant prior attempts, data constraints, budget, and real
candidate capability/availability descriptions. Model names alone are not enough;
omit unrelated conversation and secrets, not facts needed to choose a useful route.

Batch independent routing and suitability questions over shared state instead of
serial LLM calls. Route independent queued tasks with bounded concurrency, stable
task/question IDs, rate limits and a cost/time budget. The host schedules calls;
the CLI has no parallel scheduler. Questions cannot read other answers in the same
request: wait for a delegated result before deciding its dependent next route.
Use Jev's low latency for selection; retain a reasoning model for open-ended work.

## Make it yours

Replace the example's evidence, candidate IDs and criteria together. Preserve a
no-match route when the real task can fall outside the labels. Agree on how the
host or person consumes each answer before enabling any automatic effect.

## Precedent

[Related project or author example](https://github.com/0xNatoshi/jev-codex-router). Our workflow is an adaptation,
not that project's code, an automatic installer, or a reproduced benchmark.
[OpenRouter request contract](https://openrouter.ai/docs/api/api-reference/alphadecisions/submit-a-decisions-questions-and-answers-request).
