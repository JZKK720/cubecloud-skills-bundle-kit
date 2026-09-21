# Jev pitfalls: better evidence before more calls

Checked September 21, 2026. This is integration guidance, not a claim that more
context, more votes or a particular threshold improves every task.

[Repeated judging](#repeat) · [Context](#context) · [Question design](#questions)
· [Batching](#batch) · [Probabilities](#probabilities) · [Native key](#native-key)
· [Sources and limits](#sources)

<a id="repeat"></a>
## 1. Repeated judge calls: decide what you are measuring

| What you change | What the experiment can tell you | What it cannot prove |
|---|---|---|
| Nothing: same state, questions and pinned model | repeatability and threshold crossings | accuracy or independent corroboration |
| Candidate order or equivalent wording | Sensitivity to representation | A new independent fact or a universally better prompt |
| Question dimension: outcome, evidence sufficiency, policy fit | Different aspects of the same case | Independent witnesses; model errors can be correlated |
| New source evidence or fresh tool receipts | A judgment about the updated situation | That the earlier verdict was trustworthy |

Do not resubmit until you get `selected`, take the highest probability, or hide
failed/uncertain runs. No evidence was added by asking again. If you deliberately
use a vote or mean, define the rule before the run and evaluate that aggregate
against held-out labels; averaging is not a calibration method by itself.

**Small diagnostic, not a deployment recommendation:** after approval, pick a
few fixed cases and repeat each three times. Save every raw answer, actual model,
provider, question/input version, cost and errors. Compare label agreement,
probability range and threshold crossings. Three repeats are only a quick check,
not a reliable estimate of rare errors. Evaluate accuracy on diverse separately
labeled cases; do not count repeats as additional unique test cases. If disagreement
changes the action, gather evidence or use an independent reviewer.

The official [Noul consistency cookbook][S1] uses 15 runs per condition, but also
adds a different `uid` to each state. It therefore mixes variation with sensitivity
to irrelevant input; it is not a bit-for-bit identical-request experiment.
[LangChain's study][S2] rejudges five fixed weather-agent examples 100 times each.
That is five unique examples, not 500 independent tasks. It separates human-label
agreement from score variance and does not record a resolved Jev service version.
These are external experiments, not results reproduced by this collection.

<a id="context"></a>
## 2. Give enough context, not the largest possible context

Jev does not receive the host agent's conversation automatically. Build a named
state containing the goal, current evidence, relevant history, constraints,
candidate meanings and missing information. All questions see that state, but
not one another's answers. [Official state contract][S3]

**Authored input-design example; no model output claimed:**

| Too little | Better evidence bundle | Still leave out |
|---|---|---|
| `"Still broken. Urgent?"` | Original request + affected workflow + last failed attempt + workaround status + deadline + your urgency rubric | Unrelated chat, secrets, duplicate tool dumps |
| One changed code line | Requirement + relevant surrounding invariant + diff + original test receipt | The whole unrelated repository |

Large relevant evidence can be necessary. Do not remove the decisive earlier turn
just to meet a token target. Retrieve the relevant material, preserve ordering and
source IDs, and mark gaps rather than guessing. Test a concise evidence bundle
against one with additional **relevant** context on the same labeled cases.
Measure quality, not token count as an end in itself.

<a id="questions"></a>
## 3. Describe the choices and separate the judgments

`route_easy` and `route_strong` are output IDs, not a policy. Describe what qualifies
for each and where borderline cases go. Ask “does the evidence support completion?”
separately from “what should happen next?” Question IDs also do not replace
`instructions`. Use an explicit `unknown` or `none` when no choice fits.

The [judge-audit router ablation][S4] reports improvement after replacing bare
option labels with descriptions. However, its 120 rows contain 61 distinct texts,
labels encode designed difficulty tiers, and it did not run the proposed cheap
model to establish capability. This supports testing label descriptions, not a
production-routing accuracy promise. The older [Reddit report][S5] describes the
bare-label failure; do not omit the later ablation when citing that failure.

<a id="batch"></a>
## 4. More questions and more records are different

Independent checks on one state can share a request. Independent conversations
can use separate self-contained requests with bounded concurrency. Dependent
steps must wait for the actual previous result. Scope every question to its record;
collect by ID, not arrival order. See [context and throughput](context-and-throughput.md).

[pg-jev's author][S6] reports worse results at 40/80 rows per state than at 1–20
on three structured-label tasks. This is an author report, not our reproduction
or a universal 20-row limit. Our suggested comparison is small/medium/larger
batches over the same labels, recording errors by record position as well as
whole-job cost and throughput. An API-valid request can still be a poor batch.

<a id="probabilities"></a>
## 5. Separate probability, confidence, score and permission

- Choice: inspect `probabilities[choice]`, not just its `confidence` summary.
- Noul: `noul` is P(true), even when the selected Boolean is false.
- Score: a rubric position is not a success probability or an exact measurement.
- Several agreeing questions are not guaranteed independent; logical identities
  between separately worded questions are not guaranteed either.

Do not transplant a 0.9 threshold from another domain or primitive. Evaluate
reliability and error/review tradeoffs on held-out data for the actual question.
Our [saved calibration experiment](https://github.com/wuyoscar/jev-skill/blob/main/evals/CALIBRATION_RESULTS.md) already
contains high-confidence mistakes. Review the [field definitions](api.md) and
[calibration protocol](calibration.md) before wiring a score to a consumer.

## 6. Test false alarms, not only attacks

The [September 20 practitioner post by @twid][S7] describes a guard flagging the
bot's own persona and a privacy rule firing on a harmless mention. Its performance
and fitted thresholds are author claims, not independently checked here.

Use paired fixtures: a real risk, a harmless mention of the same words, a quote,
a missing-evidence case and conflicting evidence. Inspect what gets blocked or
silently skipped. Tune on development labels and check separate holdouts; a tiny
fit or agreement with the replaced model is not proof of calibration. Keep a
host-controlled disable/review path instead of allowing the judge to rewrite policy.

## 7. Keep exact logic and execution outside Jev

Arithmetic, counts and date comparisons belong in code. Score interpolation is
not an exact numeric extractor. Fresh action IDs, permissions and postcondition
checks also stay with the host. An injection detector is advisory: suspicious
state can steer Jev itself. The official [known-limits page][S8] documents these
failure modes; typed output does not establish a correct or authorized action.

<a id="native-key"></a>
## 8. Match the key, provider and model

| Route | Key variable | Required selection | Pinned model |
|---|---|---|---|
| OpenRouter | `OPENROUTER_API_KEY` | `--provider openrouter` (CLI default) | `typesafe/jev-1.13` |
| Official TypeSafe | `TYPESAFE_API_KEY` | `--provider typesafe` | `jev-1.13.0` |

Setting `TYPESAFE_API_KEY` alone does **not** change the CLI destination. Neither
key is interchangeable. Direct TypeSafe uses `https://api.typesafe.ai/v1/systemone`;
OpenRouter uses its Decisions API, not chat completions. [Native API][S9]

Set the variable in the process that launches the agent. This stdlib CLI does not
auto-load `.env`. Restart/reload the host as needed; a shell export may not reach an
already running desktop app. `jev-decide setup` only checks presence; `--dry-run`
validates the request, not authentication or credits. Never paste keys in chat,
commit them, log request headers or upload private state merely to test setup.
[Setup commands](setup.md#local-key-setup)

## 9. Bound failures and preserve evidence

Our CLI does not retry automatically. TypeSafe's SDK documents default backoff,
so account for SDK retries separately if using it instead. [Model limits][S10]
Do not retry authentication or credit errors in a loop or silently switch provider.
For an explicitly approved host retry policy, cap attempts, elapsed time and cost;
keep 429/timeouts in the ledger and never re-execute downstream side effects.

## Copy to your agent

```text
Before judging, show the goal, relevant evidence, history, missing facts and
candidate definitions. Suggest separate outcome and evidence-sufficiency questions.
Do not silently repeat calls or send unrelated context. If repeated judging would
help diagnose instability, propose a fixed small budget and an aggregation rule,
then wait for approval. Preserve every answer and compare against independent labels.
Use my selected provider and key; no provider switch or simulation without consent.
```

<a id="sources"></a>
## Sources and verification scope

Official docs, the LangChain original, pinned GitHub READMEs/report, the original
X post and the Reddit discussion were inspected on September 21. These notes do
not add model calls, rerun upstream benchmarks, or validate their production claims.

[S1]: https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook
[S2]: https://www.langchain.com/blog/jev-agent-evals-langsmith
[S3]: https://docs.typesafe.ai/concepts/state
[S4]: https://github.com/kunko-ai-labs/judge-audit/blob/0911d27246cc56164bb18d908e1abcf790df2b57/docs/audit-jev-router-ablation.md
[S5]: https://www.reddit.com/r/machinelearningnews/comments/1wkogjx/your_ai_judge_says_98_confident_does_it_mean_it_i/
[S6]: https://github.com/realZachi/pg-jev/blob/afd11fa856d7a2b831a1bfd8ee7f869ce8efcd62/README.md#why-20-rows-per-request
[S7]: https://x.com/twid/status/2101642632837366105
[S8]: https://docs.typesafe.ai/model-jaggedness/jev-1.13
[S9]: https://docs.typesafe.ai/api
[S10]: https://docs.typesafe.ai/models
