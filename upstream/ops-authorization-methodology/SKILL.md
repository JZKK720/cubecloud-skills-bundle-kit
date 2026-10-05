---
name: ops-authorization-methodology
description: 'Authorization and scope methodology for security/penetration/red-team tasks. Read-only checklist: confirm scope.md, network_profile mode, in-scope/out-of-scope assets, deliverables, and stop/replan conditions. No scripts, no toolchain coupling.'
license: MIT
metadata:
  version: "1.0"
  source: reverse-skill (methodology extraction, no upstream toolchain coupling)
  port: >-
    Clean methodology-only port. No GPL/AGPL, no offensive toolchain, no client-specific
    script dependencies. Extracted from reverse-skill: ops/scope-contract.md, ops/role-map.md,
    ops/IDENTITY.md.
---
# Ops Authorization Methodology

## Scope Gate

### Confirm scope.md before any task start

- `scope.md` must exist under the current project root
- `auth.status` must be `granted`
- `network_profile.mode` must be set to one of:
  - `offline` — no external network, only local files / VMs
  - `lab_only` — only lab/CTF network segments
  - `authorized_target_only` — only in-scope assets listed in `in_scope.assets`
  - `unrestricted_lab` — only with written authorization for an isolated experiment network

If `scope.md` is missing or `auth.status != granted`, **STOP** and report scope deficiency. Do not proceed with any analysis or tool invocation.

## In-Scope and Out-of-Scope Assets

### in_scope.assets

List every host, domain, APK path, binary, URL, or service that is authorized for analysis.

- If `in_scope.assets` is empty **and** no offline sample path is set, **STOP** and report asset deficiency.
- Review `in_scope.assets` before any recon, reverse, or exploit activity.

### out_of_scope.assets

List activities and assets explicitly NOT authorized.

- Do not act on any asset not in `in_scope.assets` or `out_of_scope.assets`.
- If an activity would cross into `out_of_scope`, halt and re-evaluate scope.

## Network Profile

### network_profile.mode

Select the appropriate mode before any network-dependent step:

| Mode | Allowed | Prohibited |
|------|---------|------------|
| `offline` | Static analysis, local files, simulation | Any external network connection, public RPC |
| `lab_only` | Lab/CTF roach machine network segment | Production or unassigned IP addresses |
| `authorized_target_only` | Only assets listed in `in_scope.assets` | Any asset outside the in-scope list |
| `unrestricted_lab` | Isolated experiment network (written authorization only) | Production or any unisolated network |

**MUST NOT** use `unrestricted_lab` against production or any network without written authorization documentation.

## Deliverables

The following deliverables are expected for every completed task:

- `report` — a formal technical document in the user project directory (see docs-generator for templates)
- `field_journal` — a succinct journal entry recording 3 key Evidence IDs + commands, 1 core Finding, and 1 reusable Path pattern
- `diagrams` — any architecture or attack-path diagrams generated during the task
- `timeline` — optional timeline summary, linkable to `timeline.md`

If any required deliverable is missing, **pause** and note the gap before proceeding to the next deliverable.

## Constraints

### timebox

- If a timebox is set in `scope.md`, do not exceed it without explicit user consent.
- Report progress at the timebox boundary.

### stealth

- `stealth` level (`low` | `medium` | `high`) must match the authorized operation type.
- Higher stealth does not override authorization; it only changes observability.

### data_handling

- `data_handling` must be `anonymize` or `no_user_pii`.
- Do not store, log, or transmit real user PII, tokens, or passwords in any artifact, report, or journal entry.

## Signoff and Ready-for-Act

### ready_for_act

- `ready_for_act` must be `true` before any analysis step, tool invocation, or target engagement.
- If `ready_for_act` is `false`, **STOP** and either:
  - Complete the missing scope/auth fields in `scope.md`, or
  - Obtain explicit user consent to proceed despite gaps.

### checklist

Before setting `ready_for_act = true`, confirm every item:

- [ ] `auth.status = granted` in `scope.md`
- [ ] `in_scope.assets` non-empty OR offline sample path set
- [ ] `network_profile.mode` chosen and consistent with authorized scope
- [ ] `out_of_scope.assets` reviewed (no activity crosses into out-of-scope)
- [ ] `stealth` level appropriate for the operation type
- [ ] `data_handling = anonymize` or `no_user_pii`
- [ ] All required deliverables identified (report, field_journal, diagrams, timeline)

If any checklist item is `no`, update `scope.md` before setting `ready_for_act = true`.

## Minimal Viable Setup Command (read-only)

```bash
# Ensure scope.md exists and is valid
# If offline, confirm offline sample path is configured
# If lab, confirm lab network segment is set
# If authorized_target_only, confirm in_scope.assets lists only authorized targets
# If unrestricted_lab, confirm written authorization is on file

# Then set ready_for_act = true in scope.md
```

---
## Version History

- 1.0: Initial release. Extracted from reverse-skill: ops/scope-contract.md, ops/role-map.md, ops/IDENTITY.md. No scripts, no toolchain coupling. Designed as a clean methodology-only skill for VS Code Copilot.