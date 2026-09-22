---
name: wigolo
description: Local-first web intelligence — search, fetch, crawl, extract, research, and monitor web content. Use when gathering information from the web, fetching pages as markdown, crawling sites, extracting structured data, researching topics, or monitoring pages for changes. MCP server via `wigolo` (stdio) or `wigolo serve` (HTTP).
---

# Wigolo

Local-first web intelligence MCP server — search the web, fetch pages as
markdown, crawl sites, extract structured data, research topics, and monitor
pages for changes. All operations run locally with a built-in knowledge cache.

## When to use

- Searching the web for information
- Fetching web pages as clean markdown
- Crawling sites to build a local knowledge base
- Extracting structured data from pages
- Conducting multi-step research on a topic
- Monitoring pages for changes over time
- Finding similar content to a known page
- Diffing a page against its cached copy

## Core tools

| Tool | Purpose |
|------|---------|
| `search <query>` | Search the web |
| `fetch <url>` | Fetch a page as markdown |
| `crawl <url>` | Crawl a site into the cache |
| `extract <url>` | Extract structured data from a page |
| `research <question>` | Multi-step research brief |
| `agent <prompt>` | Autonomous data gathering |
| `find-similar <url>` | Find related pages |
| `diff <url>` | Diff a page against cached copy |
| `watch <subcommand>` | Manage change-watch jobs |
| `cache <subcommand>` | Query the local knowledge cache |

## MCP integration

Start the MCP server:
```bash
wigolo                    # stdio transport (default)
wigolo serve --port N     # HTTP daemon
```

Setup and diagnostics:
```bash
wigolo init               # First-time setup
wigolo doctor --fix        # Diagnose and repair
wigolo health --json       # Health check
wigolo verify --json       # End-to-end smoke check
```

## Related skills

- **agent-reach**: Multi-platform internet research (13 platforms)
- **deep-research**: Multi-source deep research with firecrawl + exa
- **search-first**: Research-before-coding workflow
- **research-ops**: Evidence-first current-state research
- **firecrawl**: Web scraping and crawling (alternative backend)
- **scrapling**: Web scraping MCP (Python, alternative backend)
