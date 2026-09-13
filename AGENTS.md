# CubeCloud Skills Bundle — Copilot Instructions

## Post-merge workflow

After merging from `origin/main` or installing any new skills batch:
1. Run `bin/full-audit.ps1` and report PASS / FAIL / WARN counts.
2. Verify active skill count in `~/.agents/skills/` against the README badge. If they diverge, flag it before claiming completion.

## Counter verification

After any skill install or removal, the README badge and SETUP_GUIDE counters must match reality. Check:
- `(Get-ChildItem ~/.agents/skills -Directory).Count` vs README badge
- `skills-list.csv` line count vs README claimed total
- If stale, update the counters inline before reporting "done."

## `install-missing-skills.ps1 -WhatIf` does NOT prevent installs

Verified 2026-09-13. `-WhatIf` only gates the **refresh** path (via
`$PSCmdlet.ShouldProcess`). The **install** path calls `install-skill.ps1` as a child process
with no `-WhatIf` propagation, so it **really installs everything**.

Do not treat `-WhatIf` as a dry run. It is not safe to run for a preview. If you want a
preview, read `skills-list.csv` directly instead — the rows are the plan. To genuinely verify
without installing, check source-path existence for each row.

## Two fork names are deliberately NOT the upstream repo name

`install-skill.ps1` clones `JZKK720/<last-path-segment>`. Two candidates collided with
unrelated pre-existing forks, so both were forked under a new name:

| Upstream | Naive name (already taken by) | Actual fork |
| --- | --- | --- |
| `tech-leads-club/agent-skills` | `agent-skills` (addyosmani/agent-skills — **this bundle's active mirror**) | `tech-leads-club-agent-skills` |
| `openai/skills` | `skills` (vercel-labs/skills) | `openai-skills` |

Never "simplify" these names. A naive clone of the tech-leads-club repo into `agent-skills`
would overwrite the addyosmani mirror that 23 manifest rows depend on.

## Escaped-dollar in `git clone` lines is a silent failure

`setup-global-skills.ps1` had two clone lines written as `` `$"var`" `` (backtick-dollar = an
escaped literal `$`). Those interpolated nothing, so the clone command received a literal
`$<path>` argument and failed silently under `>nul 2>nul`. Effect: `archify` and `book-to-skill`
mirrors were never created by the installer. Fixed 2026-09-13.

When adding a clone line, confirm the variable is `"$var"` (no backtick) and that the
directory actually appears afterward — `>nul 2>nul` hides every error.

## Large install batches (10+ skills)

When installing 10+ skills in one session, start each batch in its own sub-process invocation so a single skill failure doesn't orphan the rest. If the batch exceeds ~20 skills, suggest a fresh chat or `/compact` to avoid context exhaustion mid-batch.
