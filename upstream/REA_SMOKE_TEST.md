# REA smoke test — 2026-10-12

Scope: verify the three REA pieces bundled in v1.9.18/v1.9.19 actually work on this machine, and
record how to use them from VS Code Copilot Chat.

## Verdict

| Piece | Result | Evidence |
|---|---|---|
| `rea` CLI | **PASS** | `rea@6.4.0` — 100+ subcommands (native / JS-ASAR / Android APK / firmware / PE / EVM / browser) |
| `rea` MCP server | **PASS** | stdio `initialize` → `serverInfo {name: rea, version: 6.4.0}`, protocol `2024-11-05`, capabilities: `completions, prompts, tools` |
| `reverse-engineer-anything` skill | **installed** | `~/.agents/skills/reverse-engineer-anything/` (7 files), `SCAN_LOG.md` `pass (exit 0)`, `ref:valid` |
| Functional analysis | **PASS** | `inspect-pe-resources notepad.exe` → evidence `ev_f13a3ffd…`, sha256 `468ffe12…`, `pe32-plus`, machine 34404, **39 directories / 31 resources / 4 icon groups** |

The MCP handshake used `npx.cmd` (the `.cmd` shim is required on Windows when spawning from
Python; `npx` without the extension is not an executable file and fails with `WinError 2`).

## `rea doctor` findings (informational, not blockers)

`healthy: false` is expected on a stock Windows box — it reflects **missing optional analysis
engines**, not a broken install:

| Check | State | Meaning |
|---|---|---|
| `node`, `host` | ok | runtime is fine — the JS/Electron/PE/EVM/browser paths all work |
| `hopper`, `ghidra`, `ida-registration` | `missing_analysis_engine` | only needed for **native binary decompilation**. Install Ghidra/IDA/Hopper if you need that; nothing else depends on it |
| `skill:identity` | `config_drift` | the skill copy predates a newer `rea` release; harmless unless you want the very latest skill text |
| `registration:claude_code / codex / copilot_cli / gemini_cli / hermes / opencode / vscode` | `config_drift` | REA's own `rea setup` registration records. VS Code Copilot is already wired via `%APPDATA%\Code\User\mcp.json`, so this does not affect Copilot |

To clear the drift entries (optional): `npx -y rea-agents@latest setup`, then restart VS Code.
That command only rewrites REA's own registration; it does not install Ghidra/IDA/Node/etc.

## How to use REA from VS Code Copilot Chat

**Prerequisite:** the `rea` server must be registered (it is, in `%APPDATA%\Code\User\mcp.json`).
Restart VS Code after any `mcp.json` change. In Copilot Chat, type `#` to confirm the REA tools
appear, or open the tools picker and look for `rea`.

### 1. Invoke the methodology (the skill)

```
#reverse-engineer-anything analyze why this shipped Electron app opens a blank window
```

or simply describe the target — the skill's routing rules pick the tool:

```
use REA to inspect C:\Path\to\App.exe and tell me what it does
```

### 2. Point it at a real target

| You have… | Say something like | REA route |
|---|---|---|
| A Windows `.exe` / `.dll` | "inspect this binary's metadata and imports" | `open_binary` → `binary_overview` |
| An Electron app / `.asar` | "analyze this app's JavaScript tree" | `analyze_javascript_application` |
| An Android `.apk` | "what permissions and classes does this APK declare?" | `inspect_android_package` |
| A `.zip` / `.msix` / `.ipa` | "list what's inside this package" | `open_binary` / `inspect_artifact` |
| A firmware image | "what's in this firmware?" | `inspect_firmware_regions` |
| A running page/app | "watch what this app does at runtime" | `list_browser_targets` / `list_electron_targets` |

### 3. From the terminal instead

```powershell
npx -y rea-agents@latest doctor                    # readiness
npx -y rea-agents@latest --help                    # all subcommands
npx -y rea-agents@latest inspect-pe-resources "C:\Windows\System32\notepad.exe"
npx -y rea-agents@latest analyze-javascript-application "C:\path\to\app"
npx -y rea-agents@latest capabilities              # providers + side effects
```

Every analysis emits an **evidence id** (`ev_…`) and the target's SHA-256 — cite those when you
report a conclusion, and distinguish observation from inference.

### 4. What to keep in mind

- **Source repos don't need REA.** For a normal source tree, use ordinary code search. REA is for
  *shipped artifacts* and runtime behaviour you can't read from source.
- `analysis_profile: null` and `runtime evidence` are separate concerns — static analysis never
  proves execution.
- Native decompilation needs an engine (Ghidra/IDA/Hopper). Without one, the JS/Electron/APK/PE/
  EVM/browser routes all still work.
