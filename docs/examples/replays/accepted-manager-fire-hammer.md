# Accepted Manager-Fire-Hammer Replay Fixture

This replay fixture is accepted because it preserves the Human request through
Manager intake, Fire dispatch readiness, Hammer result reporting, and Manager
review without relying on hidden adapter memory.

## Replay identity

- **Replay ID:** `replay-37-accepted`
- **Contract version:** `manager-fire-hammer-contract-v1`
- **Source ticket:** `https://github.com/TwoTwo-me/Project_Dokkaebi/issues/37`
- **Expected replay result:** accept

## Manager intake

- **Source request preserved:** yes
- **Goal:** add replay fixtures and validation for the Manager-Fire-Hammer
  boundary.
- **Non-goals:** no live GitHub Project mutation, credential use, deployment, or
  infrastructure change.
- **Acceptance criteria:** accepted and rejected replay fixtures exist; targeted
  replay validation passes and fails deterministically; readiness evidence is
  reassessed.
- **Permission level:** repo-local write with PR preparation.
- **Result packet surface:** pull request body, validation transcript, and Worker
  result packet equivalent.

## Approval gate state

- **Approval evidence:** docs-only work does not require pre-dispatch approval;
  PR merge remains Human-approved unless a later ADR narrows that gate.
- **PR merge approval:** required before merge.
- **Credential/infrastructure/deployment gates:** not reached.
- **Worker authority:** local documentation and validation only.

## Fire dispatch readiness

- **Semantic status:** Dispatchable
- **Project source of truth:** GitHub Project Status
- **Ticket link:** `https://github.com/TwoTwo-me/Project_Dokkaebi/issues/37`
- **Route metadata:** provider=`local_worktree`, isolation=`git branch`,
  workspace=`Project_Dokkaebi`, permission=`repo-local write`.
- **Admission check:** scope, acceptance criteria, validation, permission level,
  approval gates, and expected result packet are present.

## Hammer work result

- **Worker route metadata:** provider=`local_worktree`,
  branch=`docs/contract-replay-suite`, workspace=`Project_Dokkaebi`.
- **Result packet:** Worker result packet equivalent is supplied through the PR
  closeout body.
- **Acceptance criteria evidence:** replay fixtures cover accepted and rejected
  Manager-Fire-Hammer flows.
- **Validation evidence:** `bash scripts/validate-contract-docs.sh` validates the
  accepted fixture and rejects malformed replay fixtures for the intended reason.
- **Scope control:** changes stay within docs, readiness criteria, and validation
  scripts.
- **Approval-gate status:** no credential, infrastructure, worker-scaling,
  deployment, or production gate reached; PR merge approval remains required.

## Manager review and closeout

- **Review decision:** accept
- **Closeout evidence:** PR checks pass, accepted fixture validates, rejected
  fixtures fail for deterministic reasons, and issue #37 closes after merge.
- **Residual risk:** live GitHub Project and Worker runtime mutation remain
  approval-gated and are outside this replay fixture.
- **Next state:** Done

## Replay decision

- **Expected replay result:** accept
- **Reason:** every Manager, Fire, Hammer, and closeout contract stage contains
  inspectable evidence with explicit approval boundaries.
