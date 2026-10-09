"""MCP handshake probe for the skillopt server (used by mcp-smoke-test.ps1).

The server ignores --help and reads stdin until EOF, so a plain invocation
hangs. This probe sends a real MCP initialize request and checks the
serverInfo name in the response.
"""

import json
import os
import subprocess
import sys

SERVER = os.path.join(
    os.environ["USERPROFILE"],
    "dev", "forks", "JZKK720", "SkillOpt", "plugins", "copilot", "skillopt", "mcp_server.py",
)

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


def main() -> int:
    p = subprocess.Popen(
        [sys.executable, SERVER],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )
    try:
        p.stdin.write((json.dumps(INIT) + "\n").encode())
        p.stdin.flush()
        line = p.stdout.readline().decode()
    finally:
        p.kill()
    ok = "skillopt" in line
    print("MCP_OK" if ok else "MCP_FAIL:" + line[:120])
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())