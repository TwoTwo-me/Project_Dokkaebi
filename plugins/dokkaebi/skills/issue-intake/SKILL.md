---
name: issue-intake
description: Create Dokkaebi worker-ready GitHub Project issues from Human requests. Use when Codex must intake intent, clarify vague work, draft dispatch-ready tickets, set admission fields, record Human approval gates, define validation and result packet expectations, or keep GitHub Project Status as the lifecycle source of truth before Fire/Hammer dispatch.
---

# Issue Intake

Use this skill to convert a Human request into a worker-ready issue. GitHub Project Status is the lifecycle source of truth; workpad notes, labels, PR links, logs, and comments are evidence surfaces.

## Intake Flow

1. Preserve the original Human goal, desired outcome, stop condition, urgency, dependencies, affected repo or system, and known constraints.
2. Ask targeted questions when goal/scope, acceptance criteria, validation, permission level, approvals, credentials, infrastructure, merge/deploy authority, or production data are unclear.
3. Classify the narrowest permission level: read-only, repo-local write, PR preparation, or external write.
4. Record Human approval gates before any credential, cloud, Proxmox, Worker privilege, remote host, Docker, Kubernetes, merge, deploy, production write, or Manager runtime replacement action.
5. Draft the issue so an isolated Worker can finish without hidden chat context.
6. Keep the issue blocked instead of dispatchable when required fields, admission mapping, or approval evidence are missing.

## Worker-Ready Issue

Include these sections before dispatch:

- Goal/scope: one concrete outcome, explicit non-goals, allowed files/systems, and stop conditions.
- Context: source request, related issues, workpad links, prior decisions, affected branches, and constraints.
- acceptance criteria: observable pass/fail results with expected evidence.
- validation: exact tests, lint, typecheck, build, smoke checks, or manual checks to run; explain next-best evidence if a check cannot run.
- permission level: allowed tools, network, write authority, credential boundary, and any approval-gate status.
- admission fields: GitHub Project Status, agent, authorization, authorized-by, Fire/Symphony admission, fallback labels, Worker OS/capability needs, and their mapping to the semantic lifecycle state.
- Human approval gates: approval source, approved action, non-approved adjacent actions, actor/runtime, expiry or revocation, validation expectation, and planned review surface.
- git plan: base branch, branch naming, commit authority, PR expectation, merge gate, and submodule boundary when repo writes are in scope.
- result packet expectation: changed files, branch/commits/PR/artifacts, validation outcomes, acceptance criteria evidence, blockers, skipped checks, residual risks, scope-control statement, approval-gate status, and next Manager/Human action.
- Escalation triggers: missing permission, missing approval, credential need, scope expansion, destructive action, unclear project state, or validation that cannot be proven.

## Dispatch Rule

Do not dispatch vague work. Missing scope, acceptance criteria, validation, permission level, result packet surface, admission fields, or approval evidence means the issue remains `Clarifying` or `Blocked`, not `Dispatchable`.
