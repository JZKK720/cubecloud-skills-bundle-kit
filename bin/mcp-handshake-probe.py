"""Real MCP handshake probe (used by mcp-smoke-test.ps1).

`<server> --help` is NOT a valid liveness probe for a stdio MCP server: many of them
(rea, markitdown-mcp, the copilot skillopt server) ignore argv entirely and block on
stdin, so the probe can only time out. This sends an actual JSON-RPC `initialize`
followed by `tools/list` and reports what came back.

Usage:
    python mcp-handshake-probe.py <seconds> <cmd> [args...]

Exit 0 when a well-formed initialize response names a server; 1 otherwise.
Prints MCP_OK <name> <tool-count> on success, or MCP_FAIL:<diagnosis>.
"""

import json
import subprocess
import sys
import time

INIT = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "probe", "version": "1.0"},
    },
}
INITED = {"jsonrpc": "2.0", "method": "notifications/initialized"}
LIST_TOOLS = {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}


def diagnose(stderr: str) -> str:
    """Turn the common startup failures into the one line that names the fix."""
    low = stderr.lower()
    if "requires node.js" in low or "install a supported release" in low:
        return "node-version:" + stderr.strip().splitlines()[0][:160]
    if "module not found" in low or "modulenotfounderror" in low:
        return "missing-dependency:" + stderr.strip().splitlines()[0][:160]
    if "network" in low or "proxy" in low or "econn" in low or "enotfound" in low:
        return "network-or-proxy:" + stderr.strip().splitlines()[0][:160]
    if not stderr.strip():
        return "no-response-no-stderr"
    return "stderr:" + stderr.strip().splitlines()[0][:160]


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: mcp-handshake-probe.py <seconds> <cmd> [args...]")
        return 2
    timeout = float(sys.argv[1])
    argv = sys.argv[2:]

    payload = (
        json.dumps(INIT) + "\n"
        + json.dumps(INITED) + "\n"
        + json.dumps(LIST_TOOLS) + "\n"
    )

    start = time.time()
    proc = subprocess.Popen(
        argv,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        shell=(sys.platform == "win32"),
    )
    try:
        out, err = proc.communicate(payload, timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        out, err = proc.communicate()
        print(f"MCP_FAIL:timeout-after-{timeout:.0f}s {diagnose(err)}")
        return 1

    elapsed = time.time() - start
    name = None
    tools = 0
    for line in out.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        result = msg.get("result") or {}
        info = result.get("serverInfo") or {}
        if info.get("name"):
            name = info["name"]
        if isinstance(result.get("tools"), list):
            tools = len(result["tools"])

    if name:
        print(f"MCP_OK {name} tools={tools} {elapsed:.1f}s")
        return 0
    print("MCP_FAIL:no-initialize-response " + diagnose(err))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
