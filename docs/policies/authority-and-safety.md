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

- **Human**: defines goals, approves gates, and may replace Manager runtime
  choices.
- **Dokkaebi Manager**: clarifies, drafts tickets, reviews results, and updates
  tracking state. It may not perform high-impact writes without approval
  evidence.
- **Symphony-native execution layer**: dispatches approved Worker tickets and
  records progress inside a ProjectScope. It may not broaden task scope or
  bypass readiness gates.
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

## Human-origin terminal approvals

GitHub Project status transitions are the v0 approval interface, but the status
value is not enough to prove approval. The Manager may move complete Worker
results into `Human Review` for a Human decision. Terminal transitions out of
that state require human-origin provenance:

- `Human Review` → `Merging`
- `Human Review` → `Done`

Accepted provenance sources are GitHub Project status history with an
identifiable Human actor, a durable Human approval record, or a future approved
approval broker. A Manager-authored terminal transition is self-approval and is
forbidden. Unknown, ambiguous, missing, or contradictory provenance fails closed.

## Automation allowed by default

The Manager may automate these actions when scope and acceptance criteria are
clear:

- drafting or revising ProjectScope/Symphony-ready tickets;
- updating issue/project status, progress comments, and workpad notes;
- requesting Worker validation evidence;
- preparing commits or PRs for review;
- summarizing Worker results and residual risks for the Human.
- moving a complete result packet into `Human Review` without treating that move
  as terminal approval.

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
- actor identity, actor origin, and provenance source;
- source status and target status for status-transition approvals;
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
3. Verify the ProjectScope/Symphony status is dispatchable.
4. Verify the Worker capability tier, OS, provider, and tooling constraints match the ticket.
5. Verify approval evidence exists for every gated action.
6. Verify credentials, if any, are issued through a credential broker with least
   privilege and expiry.
7. Verify terminal status approvals are human-origin and not Manager
   self-approval.
8. Verify no policy item requires Human review before continuing.

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

Dokkaebi treats Symphony as the canonical execution layer inside a ProjectScope.
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

## Trusted automation gates

Full trusted automation is allowed only when every applicable gate is explicit,
durable, and auditable:

- versioned per-project policy file;
- credential broker only, with no broad raw credential transfer;
- durable Human approval record for gated action classes;
- validation gate before direct action;
- environment tiers with different thresholds for dev, staging, and production;
- audit trail and rollback/revert path;
- Human kill switch by project, Worker, Manager, environment, or action class.

If any gate is missing, ambiguous, expired, or contradictory, Dokkaebi must fail
closed and mark the work blocked.

Runtime provider authority is governed by
[`docs/contracts/runtime-provider-contract.md`](../contracts/runtime-provider-contract.md).
Worker capability routing is governed by
[`docs/contracts/worker-capability-model.md`](../contracts/worker-capability-model.md).

## Audit and review

A task is safe to close only when the Manager can reconcile:

- Human request and approval evidence;
- ticket scope, status, and assignment;
- Worker result packet and validation commands;
- commits, PRs, logs, or artifacts;
- residual risks and follow-up decisions.

Review failure does not authorize silent Worker continuation. The Manager should
request a scoped fix, create a follow-up ticket, or ask the Human for a decision.
