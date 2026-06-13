# Rejected Worker Result Packet Example: Missing Acceptance Evidence

This packet must be rejected because it does not map the original acceptance
criteria to evidence and pass, fail, or blocked status.

## Task identity

- **Task ID:** `issue-14`
- **Source ticket:** `https://github.com/TwoTwo-me/Project_Dokkaebi/issues/14`
- **Worker:** `local-worktree-docs`
- **Workspace:** `Project_Dokkaebi / docs/contract-conformance-examples`
- **Completion status:** `completed`

## Summary

Claims the goal was met, but omits acceptance-criteria evidence.

## Changed artifacts

- **Files changed:**
  - `docs/examples/result-packets/accepted.md` - accepted fixture.
- **Branch:** `docs/contract-conformance-examples`
- **Commit(s):** `N/A`
- **Commit rationale:** `N/A`
- **PR:** `N/A`
- **Other artifacts:** `N/A`

## Validation evidence

```text
bash scripts/validate-contract-docs.sh
PASS Dokkaebi contract docs are present, linked, and structurally aligned
```

## Blockers or missing permissions

- None.

## Residual risks

- Acceptance evidence is absent.

## Scope control

- **Stayed within ticket scope:** yes
- **Scope deviations:** none
- **Human approval gates reached:** PR merge approval required.

## Recommended Manager/Human next action

Request Worker follow-up with acceptance-criteria evidence.
