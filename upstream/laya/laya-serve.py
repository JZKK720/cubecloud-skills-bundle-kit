"""Laya decision-model sidecar - loopback-only HTTP API for Copilot-written tools.

API (mirrors the upstream laya-playground server + the skill's FastAPI snippet):
  GET  http://127.0.0.1:8770/api/health   -> status (ready flag, device, request count)
  POST http://127.0.0.1:8770/predict      (also /api/predict)
       body: {"state": <str|dict|list>, "questions": {id: {type, instructions, criteria}}, "lang": optional}
       resp: {"latency_ms": int, + full laya result (answers, usage, routing)}

Start persistent (no console window): pythonw.exe laya-serve.py  (log + pid beside this file)
Stop: laya-serve-stop.cmd
"""
import logging
import os
import threading
import time

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("USE_TF", "0")

from fastapi import FastAPI
from pydantic import BaseModel
from typing import Any, Optional

import uvicorn

import laya

HERE = os.path.dirname(os.path.abspath(__file__))
HOST, PORT = "127.0.0.1", 8770
LOG = os.path.join(HERE, "laya-serve.log")

logging.basicConfig(
    filename=LOG,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("laya-serve")

LOCK = threading.Lock()
STATE = {"ready": False, "device": None, "version": laya.__version__, "requests": 0}

app = FastAPI(title="Laya sidecar", docs_url=None, redoc_url=None)


class PredictBody(BaseModel):
    state: Any
    questions: dict
    lang: Optional[str] = None


@app.get("/api/health")
def health():
    return {"ok": STATE["ready"], "port": PORT, **STATE}


@app.post("/predict")
@app.post("/api/predict")
def predict(body: PredictBody):
    if not STATE["ready"]:
        return {"error": "model still loading, retry shortly"}
    with LOCK:  # one forward pass at a time (skill: guard predict with a lock)
        t0 = time.perf_counter()
        kwargs = {"lang": body.lang} if body.lang else {}
        res = AGENT.predict(body.state, body.questions, **kwargs)
        ms = round((time.perf_counter() - t0) * 1000)
    STATE["requests"] += 1
    log.info("predict %s ms (total %s)", ms, STATE["requests"])
    return {"latency_ms": ms, **res}


AGENT = laya.load("convaiinnovations/laya", device="cuda")
try:
    import torch
    STATE["device"] = (
        f"cuda:{torch.cuda.get_device_name(0)}" if torch.cuda.is_available() else "cpu"
    )
except Exception as exc:  # keep serving even if device detection hiccups
    STATE["device"] = f"unknown ({exc})"

# Warm-up at a representative shape so callers never pay compile cost (skill guidance)
WARM_Q = {
    "q_c": {
        "type": "choice",
        "instructions": "Which is it?",
        "criteria": {"a": "first", "b": "second", "c": "third"},
    },
    "q_s": {
        "type": "score",
        "instructions": "How much?",
        "criteria": ["low", "mid", "high"],
    },
    "q_n": {"type": "noul", "instructions": "Is this true?"},
}
t0 = time.perf_counter()
AGENT.predict("warm up", WARM_Q)
STATE["ready"] = True
log.info("sidecar ready: device=%s warmup=%.1fs pid=%d", STATE["device"], time.perf_counter() - t0, os.getpid())

with open(os.path.join(HERE, "laya-serve.pid"), "w", encoding="ascii") as f:
    f.write(str(os.getpid()))


if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT, log_level="warning", access_log=False)