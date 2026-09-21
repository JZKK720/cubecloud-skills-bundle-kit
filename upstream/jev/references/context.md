# Review context relevance

Use this mode through `jev`. Adapt [the request template](../assets/context.json)
to the actual evidence and criteria, then follow the parent skill's setup and runtime instructions.

## Workflow

1. Keep the original tool output retrievable before proposing reduction. Preserve source paths, IDs, errors, open tasks and user constraints independently.
2. Ask one relevance question per named block; leave uncertain and unjudged blocks visible. An apparent duplicate may contain a changed identifier or error.
3. Start in advisory/shadow use: report what would be hidden, where it can be recalled and why it matters to the current task. Do not modify transcript files.
4. Treat compaction timing as a separate question from what to retain. A completed phase does not prove future turns no longer need earlier details.
5. Only a supported native host operation can compact, and only with the required authorization. Pressure-dependent thresholds are policy choices to test on later continuations.

## Context and parallelism

Jev does not inherit the agent's history. Give every request sufficient context:
the active goal, unresolved dependencies, planned next work, original named blocks
and their source/version IDs. Do not ask whether an isolated block matters without
showing what the agent is trying to do. Omit unrelated content and secrets, but
preserve evidence that could change a keep/drop decision.

Batch independent per-block relevance questions over shared task context instead
of serial LLM calls. Use bounded concurrency for independent requests, with stable
block/question IDs, rate limits and a cost/time budget. The host schedules calls;
the CLI has no parallel scheduler. Questions cannot read other answers in the same
request: do not judge the sufficiency of a retained set until that set exists.
Use Jev's low latency to review many blocks, not to discard context without checks.

## Make it yours

Replace the example's evidence, candidate IDs and criteria together. Preserve a
no-match route when the real task can fall outside the labels. Agree on how the
host or person consumes each answer before enabling any automatic effect.

## Precedent

[Related project or author example](https://github.com/GhalebDweikat/winnow). Our workflow is an adaptation,
not that project's code, an automatic installer, or a reproduced benchmark.
[OpenRouter request contract](https://openrouter.ai/docs/api/api-reference/alphadecisions/submit-a-decisions-questions-and-answers-request).
