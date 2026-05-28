# Worker Result Packet Template

Workers use this packet to return verifiable results to the Dokkaebi
Manager through GitHub Project, Symphony workpad comments, PRs, or another
configured tracker surface.

Managers can ingest and pre-review a completed packet with
[`../../scripts/dokkaebi-worker-result-review.py`](../../scripts/dokkaebi-worker-result-review.py).
The review output can route the ticket to `Human Review`, `Fix Requested`, or
`Blocked`, but it never authorizes merge, deploy, or terminal `Done` closeout.

## Task identity

- **Task ID:** `<GitHub issue / project item / manager task id>`
- **Source ticket:** `<link to ticket or workpad>`
- **Worker:** `<worker id or run id>`
- **ProjectScope:** `<scope id / project link>`
- **Capability tier used:** `<basic | container-capable | testbed | other>`
- **Workspace:** `<repo / branch / isolated workspace>`
- **Completion status:** `<completed | blocked | failed | partial>`

## Summary

Briefly state what changed and whether the ticket goal was met.

## Changed artifacts

- **Files changed:**
  - `<path>` — `<short reason>`
- **Commit(s):** `<sha or N/A>`
- **PR:** `<link or N/A>`
- **Other artifacts:** `<logs, screenshots, generated files, or N/A>`

## Acceptance criteria evidence

Map each original acceptance criterion to evidence.

| Criterion | Evidence | Status |
|---|---|---|
| `<criterion>` | `<file, command, PR, log, or explanation>` | `<pass | fail | blocked>` |

## Validation evidence

Record exact commands/checks and outcomes.

```text
<command>
<relevant output or PASS/FAIL summary>
```

If a check was not run, explain why and provide the next-best evidence.

## Blockers or missing permissions

- `<none, or specific blocker / approval / credential / dependency needed>`

## Residual risks

- `<none, or remaining risk and expected owner>`

## Scope control

- **Stayed within ticket scope:** `<yes | no>`
- **Scope deviations:** `<none, or Manager-approved deviation with link>`
- **Human approval gates reached:** `<none, or approval gate and status>`
- **Environment/provider gates reached:** `<none, or provider gate and status>`

## Recommended Manager/Human next action

Choose one and add a short rationale:

- Accept result and close ticket.
- Request Worker follow-up.
- Start Human review.
- Approve/deny a blocked action.
- Create a follow-up ticket.
