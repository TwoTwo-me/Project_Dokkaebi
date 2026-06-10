---
name: manager-review
description: Review Dokkaebi Worker result packets before closeout. Use when Codex must reconcile GitHub Project Status, workpad notes, PR state, checks, logs, result packet evidence, residual risks, and approval-gate status to decide accept, fix request, Human review, blocked, failed, or follow-up.
---

# Manager Review

Use this skill to decide whether Worker output is safe to close. GitHub Project Status is the lifecycle source of truth; workpad notes, PRs, checks, logs, commits, and artifacts are evidence surfaces.

## Review Flow

1. Collect the source issue, GitHub Project Status, admission fields, workpad thread, PR, commits, checks, logs, artifacts, and result packet.
2. Reconcile the result packet against the original goal/scope, non-goals, acceptance criteria, validation plan, permission level, Human approval gates, and git plan.
3. Verify each acceptance criterion has direct evidence and a pass, fail, or blocked state.
4. Verify validation commands and checks were run as requested, or that skipped checks have a specific reason and next-best evidence.
5. Confirm changed files, systems, branch, commits, PR, and submodule state stayed inside declared scope.
6. Confirm approval-gate status for credentials, infrastructure, Worker privilege, merge, deploy, production writes, remote/container routes, and Manager runtime changes.
7. Decide the next lifecycle state from the evidence, then update GitHub Project Status and leave a durable review note.

## Closeout Decision

Choose one outcome:

- `Done`: all acceptance criteria pass, required validation evidence is present, approval gates are satisfied, and residual risks are accepted.
- `Fix Requested`: evidence is close but needs bounded Worker correction within the same scope.
- `Human Review`: a Human decision is needed for approval-gate status, residual risks, merge, deploy, production write, or policy exception.
- `Blocked`: approval, credential, project mapping, admission, validation, or external dependency is missing.
- `Failed`: the ticket cannot be completed under the current constraints.
- `Follow-up Issue`: the original scope is complete, but new work needs its own worker-ready issue.

## Review Note

Record a concise closeout note with:

- source issue and current GitHub Project Status;
- result packet link or pasted evidence;
- acceptance criteria evidence;
- validation commands and outcomes;
- skipped checks and rationale;
- changed files, branch, commits, PR, logs, and artifacts reviewed;
- residual risks and owner;
- scope-control finding;
- approval-gate status;
- final decision and next Manager/Human action.

Do not close work from private memory alone. If project state, workpad, PR, checks, logs, or result packet disagree, reconcile the mismatch or mark the issue `Blocked` with the missing condition.
