# Dokkaebi Authority and Safety Policy

This policy is the default authority boundary for Project Dokkaebi. It applies to
any AI Manager adapter, including Hermes, Codex/oh-my-codex, OpenClaw, and future
custom managers.

## Policy goals

- Keep the Human as the source of goals and high-impact authority.
- Make every Worker action traceable to a ticket, approval, and validation
  record.
- Fail closed when approval, credential scope, project status, or Worker
  capability is unclear.
- Preserve Manager replaceability by enforcing safety at the Manager Contract
  boundary rather than inside one runtime.

## Authority model

- **Human**: defines goals, approves gates, and may replace Manager/backend
  choices.
- **Dokkaebi Manager**: clarifies, drafts tickets, reviews results, and updates
  tracking state. It may not perform high-impact writes without approval
  evidence.
- **Symphony/backend**: dispatches approved Worker tickets and records progress.
  It may not broaden task scope or bypass readiness gates.
- **AI Worker**: executes one bounded ticket in an isolated workspace. It may not
  expand permissions, access secrets, merge/deploy, or mutate infrastructure.

## Human approval required

Dokkaebi must obtain explicit Human approval before any of these actions:

- cloud or Proxmox create/update/delete operations;
- secret, credential, token, SSH key, admin-account, or production-account access;
- Worker creation, scaling, privilege elevation, or broader network/tool access;
- Manager runtime replacement or switching the active root Manager adapter;
- PR merge, deployment, production data writes, or production infrastructure
  writes unless a later ADR grants a narrow exception.

Approval is specific to the task, scope, actor, and time window. Approval for one
ticket does not grant standing authority to future tickets.

## Automation allowed by default

The Manager may automate these actions when scope and acceptance criteria are
clear:

- drafting or revising GitHub Project/Symphony-ready tickets;
- updating issue/project status, progress comments, and workpad notes;
- requesting Worker validation evidence;
- preparing branches, commits, or PRs for review under
  [`git-governance.md`](git-governance.md);
- summarizing Worker results and residual risks for the Human.

## Forbidden default actions

Without a later explicit policy and approval mechanism, Dokkaebi must not:

- expose raw long-lived secrets to Workers;
- let a Worker self-approve scope expansion or privilege escalation;
- dispatch work when the ticket lacks acceptance criteria, permission level, or
  validation requirements;
- continue after a credential, infrastructure, deployment, production, or
  destructive-operation gate is reached;
- treat private Manager memory as the only audit trail.

## Approval evidence record

Every approval-gated action must leave durable pre-execution evidence. Minimum
fields:

- approver identity or Human decision source;
- approved action and explicit non-approved adjacent actions;
- ticket/project item or request id;
- affected repository, environment, infrastructure, data, or credential scope;
- permitted actor and runtime;
- expiration or revocation condition;
- validation and rollback expectations;
- planned result-packet or Manager-review surface.

The actual Worker result packet or Manager review link is required at closeout,
not before dispatch. If the pre-execution approval record is missing or ambiguous,
the Manager must fail closed and ask for a new approval.

## Fail-closed preflight

Before dispatching or executing an approval-sensitive task, the Manager runs a
preflight:

1. Verify the source request and ticket are linked.
2. Verify acceptance criteria, non-goals, permission level, validation plan, and
   result packet requirements are present.
3. Verify the GitHub Project/Symphony status is dispatchable.
4. Verify the Worker capability/OS/tooling constraints match the ticket.
5. Verify approval evidence exists for every gated action.
6. Verify credentials, if any, are issued through a credential broker with least
   privilege and expiry.
7. Verify no policy item requires Human review before continuing.

Any failed or unknown check blocks dispatch. The blocked state must name the
missing condition rather than starting best-effort work.

## Credential broker boundary

Credentials are never part of the Manager's conversational memory. The credential
broker must issue task-scoped, time-limited, least-privilege grants and record
only metadata needed for audit. Workers receive only the scoped bundle necessary
for the approved ticket and must not receive the Manager's broad credentials.

Credential requests require:

- ticket id and approved capability;
- repository or external service allowlist;
- branch/environment binding where applicable;
- expiration and revocation condition;
- proof that the Worker and endpoint match the approved scope.

## Symphony compatibility policy

Dokkaebi treats Symphony as the first backend, not as an inseparable core.
Manager tickets must remain compatible with both:

- **Greenfield projects:** Dokkaebi proposes the initial project fields,
  statuses, labels, templates, and admission rules. It creates them only under
  approved setup authority before dispatch.
- **Brownfield projects:** Dokkaebi maps existing statuses/labels to the semantic
  state model in `WORKFLOW.md` before enabling Worker dispatch.

GitHub Project schema changes, field creation, label creation, template updates,
admission-rule changes, and auto-add workflow changes are control-plane writes.
They require approved setup authority. Routine progress comments and status
updates remain automation candidates when the ticket is already approved.

If project status fields, labels, workpad conventions, or Worker metadata cannot
be mapped, the Manager must mark the ticket blocked and request a mapping or
project setup change.

## Git governance boundary

Branch, commit, pull-request, and submodule-pointer work follows
[`git-governance.md`](git-governance.md). Preparing reviewable commits or PRs is
an automation candidate only when the ticket grants repository write or PR
preparation authority. PR merge, direct protected-branch writes, deployment,
production writes, destructive history rewriting, and release publication remain
Human approval gates unless a later ADR grants a narrow exception.

## Audit and review

A task is safe to close only when the Manager can reconcile:

- Human request and approval evidence;
- ticket scope, status, and assignment;
- Worker result packet and validation commands;
- commits, PRs, logs, or artifacts;
- residual risks and follow-up decisions.

Review failure does not authorize silent Worker continuation. The Manager should
request a scoped fix, create a follow-up ticket, or ask the Human for a decision.
