# Rejected Replay Fixture: Missing Dispatch Readiness

This replay fixture is rejected because Fire dispatch readiness is absent.

## Replay identity

- **Replay ID:** `replay-37-rejected-dispatch`
- **Contract version:** `manager-fire-hammer-contract-v1`
- **Source ticket:** `https://github.com/TwoTwo-me/Project_Dokkaebi/issues/37`
- **Expected replay result:** reject

## Manager intake

- **Source request preserved:** yes
- **Goal:** add replay fixtures and validation for the Manager-Fire-Hammer
  boundary.
- **Non-goals:** no live GitHub Project mutation, credential use, deployment, or
  infrastructure change.
- **Acceptance criteria:** accepted and rejected replay fixtures exist.
- **Permission level:** repo-local write with PR preparation.
- **Result packet surface:** pull request body and validation transcript.

## Approval gate state

- **Approval evidence:** docs-only work does not require pre-dispatch approval;
  PR merge remains Human-approved unless a later ADR narrows that gate.
- **PR merge approval:** required before merge.
- **Credential/infrastructure/deployment gates:** not reached.
- **Worker authority:** local documentation and validation only.

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

- **Review decision:** reject
- **Closeout evidence:** dispatch readiness is missing.
- **Residual risk:** cannot prove Fire admitted the work from complete ticket
  evidence.
- **Next state:** Blocked

## Replay decision

- **Expected replay result:** reject
- **Reason:** Fire dispatch readiness is missing.
