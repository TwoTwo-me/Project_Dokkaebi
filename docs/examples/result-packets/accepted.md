# Accepted Worker Result Packet Example

This packet is accepted because it includes task identity, changed artifacts,
acceptance-criteria evidence, validation evidence, blocker status, residual
risk, scope-control, approval-gate status, and a recommended next action.

## Task identity

- **Task ID:** `issue-14`
- **Source ticket:** `https://github.com/TwoTwo-me/Project_Dokkaebi/issues/14`
- **Worker:** `local-worktree-docs`
- **Workspace:** `Project_Dokkaebi / docs/contract-conformance-examples`
- **Completion status:** `completed`

## Summary

Added result-packet conformance examples and validation so Manager review can
accept complete packets and reject packets that omit required evidence.

## Changed artifacts

- **Files changed:**
  - `docs/examples/result-packets/accepted.md` - accepted result-packet fixture.
  - `docs/examples/result-packets/rejected-missing-acceptance-evidence.md` - rejected fixture.
  - `scripts/validate-contract-docs.sh` - conformance fixture validation.
- **Branch:** `docs/contract-conformance-examples`
- **Commit(s):** `N/A before PR commit`
- **Commit rationale:** examples and validation are one contract boundary change.
- **PR:** `N/A before PR creation`
- **Other artifacts:** `N/A`

## Acceptance criteria evidence

| Criterion | Evidence | Status |
|---|---|---|
| Accepted and rejected result packets exist. | `docs/examples/result-packets/` contains accepted and rejected examples. | pass |
| Validation catches missing required evidence. | `bash scripts/validate-contract-docs.sh` rejects malformed fixtures. | pass |
| Adapter conformance is documented. | `docs/contracts/manager-contract.md` explains conformance proof. | pass |

## Validation evidence

```text
bash scripts/validate-contract-docs.sh
PASS Dokkaebi contract docs are present, linked, and structurally aligned
```

## Blockers or missing permissions

- None.

## Residual risks

- End-to-end Manager-Fire-Hammer replay fixtures are still a follow-up readiness
  gap.

## Scope control

- **Stayed within ticket scope:** yes
- **Scope deviations:** none
- **Human approval gates reached:** PR merge approval required; no credential,
  infrastructure, worker-scaling, deployment, or production gate reached.

## Recommended Manager/Human next action

Accept result and close ticket after PR checks pass and the PR is merged.
