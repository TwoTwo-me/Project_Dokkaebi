# Rejected Worker Result Packet Example: Missing Scope Control

This packet must be rejected because it does not state whether the Worker stayed
inside the approved ticket scope.

## Task identity

- **Task ID:** `issue-14`
- **Source ticket:** `https://github.com/TwoTwo-me/Project_Dokkaebi/issues/14`
- **Worker:** `local-worktree-docs`
- **Workspace:** `Project_Dokkaebi / docs/contract-conformance-examples`
- **Completion status:** `completed`

## Summary

Claims the goal was met, but omits scope-control evidence.

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

## Validation evidence

```text
bash scripts/validate-contract-docs.sh
PASS Dokkaebi contract docs are present, linked, and structurally aligned
```

## Blockers or missing permissions

- None.

## Residual risks

- Scope-control evidence is absent.

## Recommended Manager/Human next action

Request Worker follow-up with scope-control evidence.
