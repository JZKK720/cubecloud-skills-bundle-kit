---
name: laya
description: 'Add fast, LOCAL, typed decisions to any project with Laya, an open-source non-generative decision model. Runs offline via `pip install laya`; classifies, routes, scores and answers yes/no questions about a piece of text, returning calibrated probabilities in ~20-35 ms on a laptop GPU, no LLM call, no data leaving the machine. Also use it when the user mentions Jev, a "System 1 model", "typed decisions" or a "decision model" for LOCAL/offline use, even if they never name Laya. Use when: routing text, triage tickets/emails, spam/phishing/toxicity/intent detection, guardrails in front of an agent or LLM, rubric scoring, replacing an LLM-based classifier to cut latency or cost. For HOSTED decisions use the `jev` skill instead; compose both via the cascade pattern in this skill.'
license: Apache-2.0
metadata:
  requirements: "RUNTIME DEPENDENT - real Laya calls need Python 3.10+ locally, `pip install laya` (pulls torch/transformers), and ~2.3 GB of open weights downloaded on first load. Calls run on the user's machine; nothing leaves it. No API key. No MCP server. Without the runtime installed, use the documented patterns as prose guidance only, or escalate decisions to the installed `jev` skill (hosted API, may incur charges and needs explicit consent)."
  author: brain function collapse
  source: https://brainfunctioncollapse.com/laya
  bundle: "clean-port v1.1 by brainfunctioncollapse; content preserved, frontmatter adapted for the CubeCloud bundle. Provenance: upstream skill MIT (playground repo wdobry/laya-playground); Laya model + weights Apache-2.0 by Nandakishor M (Convai Innovations, github.com/NandhaKishorM/laya). Not affiliated with or endorsed by TypeSafe AI. Cascade section added for composition with the bundle's `jev` skill."
---

# Integrating Laya

Laya answers typed questions about a piece of text. You give it a `state` (the text) and a dict
of questions; it returns a probability for every option of every question in one forward pass.
It never generates text, so it cannot answer off-schema, and it is small enough (322M-421M
parameters) to run inside the user's own process.

Reach for it when the project needs a **decision**, not a sentence: which queue, is this spam,
how urgent, should the agent stop. Do not reach for it when the task needs reasoning over
several steps, arithmetic, extraction of free-form values, or any generated text. For those,
keep the LLM and use Laya in front of it as a cheap first pass (see "Cascade" below).

## Install and first call

```bash
pip install laya        # pulls torch, transformers, safetensors, huggingface_hub
```

```python
import laya

agent = laya.load("convaiinnovations/laya")          # English checkpoint

result = agent.predict(
    {"subject": "Charged twice", "body": "Refund the duplicate today or we cancel."},
    {
        "department": {
            "type": "choice",
            "instructions": "Which department should handle this request?",
            "criteria": {
                "billing": "invoices, payments, refunds",
                "technical": "bugs, outages, system errors",
                "other": "everything else",
            },
        },
        "urgency": {
            "type": "score",
            "instructions": "How urgent is this request?",
            "criteria": ["not urgent", "soon", "critical deadline or blocking issue"],
        },
        "churn_risk": {"type": "noul", "instructions": "Does the user threaten to cancel or leave?"},
    },
)
answers = result["answers"]
```

`state` may be a string, a dict or a list; dicts and lists are serialised to JSON. Load the
model **once** at startup and reuse it. Loading takes 25-35 s; a call takes milliseconds.

## The three question types

| type | `criteria` | what comes back in `answers[id]` |
|---|---|---|
| `choice` | dict `{option: description}` or a list of option names | `choice` (the winner), `probabilities` per option, `confidence` |
| `score` | ordered list of level descriptions, lowest first | `score` (expected level, a float), `probabilities` per level, `legend`, `confidence` |
| `noul` | optional `{"true": "...", "false": "..."}` | `noul` = P(true), `confidence` |

Every answer also carries `action.act_probability` from the model's act-or-escalate head, and
`result["usage"]["input_tokens"]` reports the tokens consumed. `confidence` is one minus the
normalised entropy of the distribution, so it is low whenever probability is spread out, even
if the top option is right.

All questions in one `predict` call share a single forward pass, so ask everything you need
about a state in one call rather than looping.

## Writing questions that work

This matters more than anything else in the integration. Laya is an encoder doing something
close to textual entailment, and it rewards questions shaped like that.

- **Ask what the text says, not what to do about it.** "Where is the bird relative to the gap?"
  produced clean graded probabilities; "Which way must the bird move?" came out inverted on
  every checkpoint, because the option word "up" is pulled towards "above" in the state. Ask a
  perception question, then let your code map the answer to an action.
- **Put the state into words, never numbers.** Given "Bird altitude: 20. Gap altitude: 60." no
  checkpoint could tell which was lower. If a decision depends on a comparison, threshold or
  sum, compute it in code and hand Laya the conclusion ("the bird is far below the gap").
- **Describe each option.** `{"billing": "invoices, payments, refunds"}` beats a bare
  `["billing", ...]`, because the description is what the model matches the text against.
- **Keep option lists short.** Each option is truncated to 48 tokens and all options for a
  question share a budget (192 tokens on the English checkpoint, 256 on the others). Upstream
  reports accuracy degrading past roughly 20 options. If a question raises
  `ValueError: ... options exceed head_max_len`, shorten the descriptions or split the question.
- **Keep the state short and front-loaded.** The English checkpoint reads 512 tokens in total,
  the others 1024, and an over-long state is cut from the end. Put what matters first. For
  emails, `laya.email_state(subject, body, sender=...)` strips quoted replies and signatures.
- **Try two or three phrasings and measure.** Small wording changes move results a lot. One
  concrete case: "blocked by a barrier" separated lanes far better than "blocked by a train".

Ready-made question sets exist for common jobs: `laya.triage_questions()`,
`laya.email_questions()`, `laya.guard_questions()`, `laya.moderation_questions()`,
`laya.router_questions()`. Use them as starting points and read what they contain before
relying on them.

## Choosing a checkpoint

```python
agent    = laya.load("convaiinnovations/laya")                              # English, 421M
agent_ml = laya.load("convaiinnovations/laya", subfolder="multilingual")    # 100+ languages, 322M, ~1.6x faster
agent_td = laya.load("convaiinnovations/laya", subfolder="typed-decisions") # fine-tuned on four upstream workflows
```

Use the English checkpoint for English text. It is the best general performer and its
probabilities are temperature-calibrated. Use `multilingual` for anything else. It ships
**uncalibrated** (temperature 1.0), so expect it to report 100% and 0% readily; do not read
those as certainty. It also missed explicit cancellation threats that the English checkpoint
caught. `typed-decisions` only helps if your questions resemble the workflows it was tuned on.

`laya.Router` picks a checkpoint per request from the script and language of the state:

```python
from laya import Router
router = Router(preload=True)                       # all three resident, ~4.6 GB in fp32
res = router.predict(state, questions)              # res["routing"] says which model and why
res = router.predict(state, questions, lang="pl")   # force the language when you know it
```

**Pass `lang=` whenever the application knows the language.** As of laya 0.3.4 the detector
only recognises English, French, German, Spanish, Portuguese, Italian and Dutch among
Latin-script languages. Polish, Czech, Turkish, Swedish and others are silently sent to the
English checkpoint, which then answers confidently and wrongly. Non-Latin scripts route
correctly.

## Acting on probabilities

The probabilities are the product. Decide per question what happens at each confidence level,
and make the threshold reflect the cost of being wrong:

```python
a = answers["department"]
if a["probabilities"][a["choice"]] >= 0.85:
    route(a["choice"])
else:
    send_to_review(a)            # a person, a slower model, or a queue
```

For yes/no gates compare `answers[id]["noul"]` against a threshold chosen on real data, not
0.5 by default. For a guardrail, where a miss is expensive, set it low; for an auto-action,
where a false alarm is expensive, set it high.

**Cascade with an LLM.** A good default architecture: Laya handles every request, and only the
ones below the threshold go to the LLM or a person. The share that escalates is what you pay
LLM latency and cost on, so measure it.

**Cascade with Jev (composition with the bundle's `jev` skill).** Laya and Jev answer the same
typed questions, so they compose cleanly: route every decision through local Laya first at zero
cost and latency, and let only the low-confidence cases fall through to the Jev API (routes A/B
in `jev`'s Setup — real Jev via a key, or agent simulation when none exists). Thresholds map
directly because both return `confidence` for Choice/Score. Keep the two question dicts in sync
per decision type, and record which model answered each decision (`laya` vs `jev` vs
`simulation`) in the audit trail. This is an application-level architecture, not a new skill
surface: `jev` stays the hosted route, `laya` stays the local-first default.

**Calibrate on the user's own data before trusting the numbers.** Temperatures live on the
agent: `agent.temperature` is `[choice, score, noul]` and `agent.temperature_by_options` holds
per-option-count overrides (keys like `"choice:3-5"`, `"noul:2"`) that take precedence. To
refit: set `agent.temperature = [1.0, 1.0, 1.0]` and `agent.temperature_by_options = {}` to
read raw probabilities `p`, fit a scalar `T` per question type that minimises negative
log-likelihood of `p ** (1 / T)` (renormalised) on a labelled set, then write the fitted values
back. A few hundred labelled examples are enough to see whether it helps.

## Wiring it into a project

- **Python service:** build one agent (or `Router`) at startup and share it. Guard `predict`
  with a lock or a single worker queue; one GPU serves one forward pass at a time, and
  concurrent calls from several threads only interleave badly.
- **Anything else (Node, Go, a front end):** run Laya as a small local HTTP sidecar and call it
  over loopback. Bind to `127.0.0.1`, enable keep-alive, and return the `predict` result as
  JSON. A minimal version:

  ```python
  import threading, laya
  from fastapi import FastAPI
  app, lock = FastAPI(), threading.Lock()
  agent = laya.load("convaiinnovations/laya")

  @app.post("/predict")
  def predict(body: dict):
      with lock:
          return agent.predict(body["state"], body["questions"])
  ```

- **Device:** Laya picks CUDA, then Apple MPS, then CPU, and falls back to CPU if the GPU runs
  out of memory. Pass `device="cpu"` to force it. Measured for one question: about 34 ms
  (English) and 21 ms (multilingual) on an M1 Max GPU, 139 ms and 58 ms on its CPU. Ten
  questions in one call cost about 7-16 ms each.
- **Warm up.** The first call at a new batch shape compiles kernels and can take several times
  longer. Make one throwaway `predict` call at startup with a representative question set.
- **Downloads.** Weights come from the Hugging Face Hub on first load. The root repo bundles all
  three checkpoints, and loading the English one without a `subfolder` fetches the whole bundle
  (about 2.3 GB); a `subfolder=` load fetches only that checkpoint (650-850 MB). If a download hangs at
  0 bytes, set `HF_HUB_DISABLE_XET=1` to fall back to plain HTTPS. Once cached, set
  `HF_HUB_OFFLINE=1` to skip network checks. Set `USE_TF=0` if `transformers` stalls on import.

## Evaluate before shipping

Zero-shot quality varies a lot by task. Upstream's own notes report the base checkpoints near
chance on their typed-decisions benchmark without fine-tuning, ordinal `score` questions as
the weakest type, and moderation not holding up on held-out data.

An independent run on 500 labelled examples (English checkpoint, no tuning, September 2026)
shows where the line falls. Simple classification is strong: 93% on news topic (a dataset in
Laya's training mix) and 96% on SMS spam, level with a hosted commercial model. Subtler or graded
questions are not: 45% on six-way emotion, 65% on prompt-injection detection and 35% on a
five-level star rating, where the hosted model scored 53%, 71% and 70%. Expected calibration
error was 0.05-0.06 on the easy tasks and 0.34-0.40 on the hard ones. Latency was 35-66 ms per
question. So expect Laya to work out of the box for clear-cut categories and yes/no checks, and
plan to rephrase, fine-tune or cascade for ordinal scores and nuanced judgements. Measure:

1. Collect 50-200 real examples with the correct answers.
2. Run them through `predict` and record accuracy per question, plus how often the top
   probability clears your threshold and how often it is right when it does.
3. Try alternative phrasings and checkpoints on the same set, and keep the best.
4. If accuracy is still short, fine-tune. The upstream repository
   (github.com/NandhaKishorM/laya) ships a fine-tuning notebook that runs on free Kaggle GPUs.

Tell the user the measured numbers and the escalation rate, not just that it works.

## Checklist

- [ ] Model loaded once, warmed up, and guarded by a lock or queue
- [ ] Questions ask what the text says; numbers and comparisons resolved in code first
- [ ] Every option has a description; option lists are short
- [ ] `lang=` passed wherever the language is known
- [ ] Thresholds chosen from labelled data, with a path for low-confidence cases
- [ ] Accuracy and escalation rate measured on the user's own examples and reported to them

---
Skill by brain function collapse (https://brainfunctioncollapse.com/laya). Laya itself is created by
Nandakishor M, Convai Innovations, and released under Apache-2.0 (https://github.com/NandhaKishorM/laya).

## Local sidecar mode (CubeCloud bundle)

If the machine runs the Laya sidecar, skip pip install laya and model loading entirely:
call the always-hot decision API instead.

- **Base URL:** `http://127.0.0.1:8770` (loopback only; AMD 8060S via ROCm)
- **Health:** `GET http://127.0.0.1:8770/api/health` -> `{"ok": true, "ready": true, "device": "...", "requests": N}`
- **Predict:** `POST http://127.0.0.1:8770/predict` (`/api/predict` also accepted)
  - body: `{"state": <str|dict|list>, "questions": {id: {type, instructions, criteria}}, "lang": optional}`
  - response: `{"latency_ms": <int>, "answers": {...}, "usage": {...}, "version": ...}`
  - lock-guarded server-side: one forward pass at a time; expect ~30-60 ms per call
  - no warm-up cost for clients; server boots hot (warm-up paid once at service start)

Write tool code that POSTs JSON to `/predict` and consumes `answers` exactly as the
in-process contract above. If health says `ready: false` or the port is unreachable, fall
back to the in-process pattern in the sections above, or report the sidecar as down.
Start/stop: `laya-serve.cmd` / `laya-serve-stop.cmd` (on PATH).
