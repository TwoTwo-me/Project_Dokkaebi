# Rejected Worker Result Packet Example: Missing Validation Evidence

This packet must be rejected because it does not include exact validation
commands and outcomes.

## Task identity

- **Task ID:** `issue-14`
- **Source ticket:** `https://github.com/TwoTwo-me/Project_Dokkaebi/issues/14`
- **Worker:** `local-worktree-docs`
- **Workspace:** `Project_Dokkaebi / docs/contract-conformance-examples`
- **Completion status:** `completed`

## Summary

Claims the goal was met, but omits validation evidence.

## Changed artifacts

- **Files changed:**
  - `docs/examples/result-packets/accepted.md` - accepted fixture.
- **Branch:** `docs/contract-conformance-examples`
- **Commit(s):** `N/A`
- **Commit rationale:** `N/A`
- **PR:** `N/A`
- **Other artifacts:** `N/A`

## Acceptance criteria evidence

| Criterion | Evidence | Status |
|---|---|---|
| Accepted and rejected result packets exist. | `docs/examples/result-packets/` contains examples. | pass |

## Blockers or missing permissions

- None.

## Residual risks

- Validation evidence is absent.

## Scope control

- **Stayed within ticket scope:** yes
- **Scope deviations:** none
- **Human approval gates reached:** PR merge approval required.

## Recommended Manager/Human next action

Request Worker follow-up with exact validation command output.
