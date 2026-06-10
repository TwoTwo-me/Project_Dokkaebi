# Project Dokkaebi Workflow

This workflow defines how Dokkaebi converts Human intent into GitHub Project
work, routes approved tickets through Dokkaebi Fire, and receives Dokkaebi
Hammer output as verifiable evidence.

```text
Human request
  -> Manager intake and clarification
  -> worker-ready ticket
  -> approval/status gate
  -> Dokkaebi Fire dispatch
  -> Dokkaebi Hammer execution
  -> result packet
  -> Manager review
  -> Human decision / closeout
```

## Workflow principles

- Human intent, constraints, and approval boundaries must survive translation
  into tickets.
- Work enters the Hammer queue only as an inspectable GitHub Project issue or
  equivalent work contract.
- Hammer Workers execute bounded tasks; they do not negotiate broad scope
  directly with the Human by default.
- Progress and results flow through tracker/workpad/PR/test artifacts so they
  can be audited and resumed.
- High-impact actions stop at approval gates even if a tool can technically
  perform them.

## Phase 1: Manager intake

The Manager accepts a Human request and records:

- original goal in the Human's terms;
- desired outcome and stop condition;
- non-goals and known constraints;
- urgency and sequencing dependencies;
- affected repositories, systems, or data;
- likely permission level;
- validation expectations.

If the request is ambiguous, the Manager asks targeted clarification before
dispatch. Clarification is required when ambiguity affects scope, safety,
credentials, infrastructure, merge/deploy authority, production data, or Worker
permissions.

## Phase 2: Work-contract drafting

The Manager converts approved intent into a worker-ready ticket. A ticket is not
ready for Dokkaebi Fire dispatch until it contains enough detail for an isolated
Dokkaebi Hammer runtime to complete and verify the task without hidden context.

Required ticket sections:

1. **Goal**: one concrete outcome.
2. **Context**: files, links, prior decisions, related tickets, and current
   system behavior.
3. **Acceptance criteria**: observable pass/fail conditions.
4. **Scope and non-goals**: what the Hammer may and may not change.
5. **Permission level**: allowed tools, network, credentials, write authority,
   and approval requirements.
6. **Validation plan**: tests, lint, typecheck, build, smoke checks, or manual
   verification expected from the Hammer.
7. **Result packet requirements**: exact evidence the Hammer must return.
8. **Escalation triggers**: when to stop and report instead of improvising.
9. **Git plan**: base branch, branch naming, commit authority, PR expectation,
   and submodule handling when repository writes are in scope.

## Phase 3: Approval and readiness gate

Before dispatch, the Manager classifies the ticket:

| Classification | Dispatch rule |
| --- | --- |
| Documentation / planning only | May dispatch when scope and acceptance criteria are clear. |
| Local code change | May dispatch when validation and write scope are clear. |
| Credentialed work | Requires explicit credential approval and brokered least-privilege access. |
| Cloud / Proxmox / infrastructure | Requires explicit Human approval before any create/update/delete. |
| Hammer scaling or privilege elevation | Requires explicit Human approval. |
| Manager runtime replacement | Requires explicit Human approval. |
| PR merge, deployment, production write | Requires explicit Human approval unless a later ADR grants a narrow exception. |
| Remote or container orchestration route | Requires explicit setup authority before mutating remote hosts, Docker, `kubectl`, or Kubernetes. |

Dispatch readiness should be represented by GitHub Project Status, agent,
authorization, authorized-by, admission fields, and any approved fallback labels,
not by private Manager memory alone.

Backend-facing fields or labels may use project-specific names, but they must
map to the semantic status model and admission contract below before Fire
dispatch.

Local toolchain bootstrap may be automated only when the ticket grants it and
the process follows [`docs/operations/toolchain-bootstrap.md`](docs/operations/toolchain-bootstrap.md):
prefer user-local installs, run read-only preflight first, capture scripted
install evidence, record rollback notes, and respect `dokkaebi-hammer` reset
request boundaries.

## Phase 4: Dokkaebi Fire dispatch

Dokkaebi Fire watches the configured GitHub Project and dispatches tickets that
match its admission rules, such as Status, Agent, Authorization, Authorized By,
Dokkaebi Fire or Symphony Admission, approved fallback labels, Hammer OS
metadata, and capability constraints. Fire is the Symphony-derived
long-running backend/orchestrator.

On dispatch, Fire should provide the Hammer:

- source ticket and acceptance criteria;
- isolated workspace;
- route type and provider evidence when the ticket requests `local_worktree`,
  `ssh`, `docker`, or `kubernetes_job`;
- declared write scope;
- allowed tools and network mode;
- scoped credentials, if policy approved and brokered;
- expected progress/reporting surfaces;
- result-packet schema.

If the ticket cannot be safely dispatched, Fire or the Manager should mark it
blocked with the missing condition rather than starting a best-effort Hammer.
Docker and Kubernetes Job routes require containerizable work plus an approved
image/profile; Kubernetes also requires an explicit context and namespace.
Absent or mismatched route metadata is a blocker, not a reason to fall back to a
less isolated worker.

## Phase 5: Dokkaebi Hammer execution

The Hammer follows the ticket, not adjacent discoveries. The expected execution
loop is:

1. inspect only the context needed for the ticket;
2. make the smallest correct change;
3. run the requested validation;
4. fix failures within scope;
5. stop and escalate when blocked by missing approval, missing credentials,
   destructive action, scope expansion, or contradictory instructions;
6. return a result packet through the configured tracker/workpad/PR surfaces.

Hammer Workers may recommend follow-up work, but recommendations are not implicit
authorization to perform it.

When a Hammer creates branches, commits, PRs, or submodule pointer updates, it
must follow [`docs/policies/git-governance.md`](docs/policies/git-governance.md).

## Phase 6: Result packet

A Worker result packet must be evidence-dense and reusable by another Manager.
Minimum fields:

- ticket id and Hammer id;
- summary of completed work;
- changed files, branch, PRs, commits, or artifact links;
- validation commands and pass/fail outcomes;
- acceptance-criteria evidence and whether acceptance criteria were met;
- blockers, missing approvals, or skipped checks;
- residual risks and regression concerns;
- scope-control statement and approval-gate status;
- recommended next action.

Validation evidence should quote command names and concise outcomes. Raw logs
may be linked or attached when lengthy.

## Phase 7: Manager review

The Manager reviews the result packet before closing work or asking the Human
for the next decision.

Review checklist:

- Does the result satisfy every acceptance criterion?
- Are changes inside the declared scope?
- Were required tests, lint, typecheck, build, or smoke checks run?
- Are skipped checks justified?
- Does commit/PR evidence follow the Git governance policy when repository
  writes were in scope?
- Are residual risks acceptable or do they require follow-up tickets?
- Is Human approval needed for merge, deploy, production writes, credentials,
  infrastructure, or broader Worker authority?
- Are project status, issue comments, PR state, and artifact links consistent?

If evidence is insufficient, the Manager returns the ticket for Worker fixup or
creates a follow-up ticket with clear acceptance criteria.

## Status model

Dokkaebi should use explicit statuses so Human, Manager, Dokkaebi Fire, and
Dokkaebi Hammer share the same state machine. The exact GitHub Project field
names may vary, but the semantic states should remain stable.

GitHub Project `Status` is the lifecycle source of truth for this state machine.
Workpad comments, PRs, commits, logs, and validation artifacts are evidence
surfaces that explain or prove the state; they should not silently override the
project lifecycle state.

| State | Owner | Meaning | Allowed next states |
| --- | --- | --- | --- |
| Intake | Manager | Human request captured; not yet worker-ready. | Clarifying, Ready, Cancelled |
| Clarifying | Manager / Human | Manager is resolving ambiguity or approval boundaries. | Ready, Blocked, Cancelled |
| Ready | Manager | Ticket has acceptance criteria, scope, validation, and permission level. | Dispatchable, Blocked, Cancelled |
| Dispatchable | Dokkaebi Fire | Ticket matches Fire/Symphony admission rules. | In Progress, Blocked |
| In Progress | Dokkaebi Hammer | Hammer has accepted the ticket and is executing. | Needs Review, Blocked, Failed |
| Needs Review / Human Review | Manager / Human | Hammer returned evidence; review or approval is pending. | Fix Requested, Merging, Done, Blocked |
| Fix Requested | Dokkaebi Hammer | Follow-up correction is required inside the same ticket scope. | In Progress, Needs Review, Failed |
| Merging | Human / approved automation | Merge is explicitly authorized and checks are being finalized. | Done, Blocked, Failed |
| Done | Manager | Acceptance criteria and required approvals are satisfied. | Reopened |
| Reopened | Manager | Closed work is intentionally returned to intake with new evidence or scope. | Intake, Ready, Cancelled |
| Blocked | Manager / Hammer | Progress requires approval, credentials, scope decision, or external state. | Clarifying, Ready, In Progress, Cancelled |
| Failed | Manager | Work cannot be completed under current constraints. | Reopened, Cancelled |
| Cancelled | Human / Manager | Work is intentionally stopped. | Reopened |

## Exception and escalation rules

Escalate to Manager/Human instead of continuing when:

- the ticket requires a file, system, or repository outside declared scope;
- a credential, secret, token, or admin account is needed;
- cloud, Proxmox, infrastructure, deployment, production data, merge, or release
  action is required;
- Hammer privileges, parallelism, network authority, or runtime need expansion;
- a remote host, Docker, `kubectl`, Kubernetes, or `dokkaebi-hammer` reset
  action exceeds the approved bootstrap boundary;
- acceptance criteria conflict with safety policy;
- validation cannot run and no equivalent evidence is available;
- tracker state and actual repository/workspace state disagree.

## End-to-end example

1. Human: "Add a worker-ready bugfix template for frontend regressions."
2. Manager clarifies target repository, non-goals, and whether the Worker may
   edit templates only.
3. Manager creates a GitHub Project ticket with acceptance criteria, template
   path, validation expectations, and no merge/deploy authority.
4. Human or policy marks it Ready.
5. Dokkaebi Fire dispatches one Hammer with a scoped workspace.
6. Hammer edits the template, runs markdown checks, and opens a PR.
7. Hammer posts a result packet with changed files, commands, outcomes, and
   residual risks.
8. Manager verifies the packet, checks project/PR consistency, and asks the
   Human for merge approval if required.
9. After approval and checks, the ticket moves through Merging to Done.

## Completion criteria for a Dokkaebi-managed task

A task is complete only when:

- acceptance criteria are satisfied;
- changes stayed inside declared scope;
- required validation has passed or skipped checks are explicitly justified;
- result packet evidence is available in durable surfaces;
- commit, PR, and submodule evidence follows Git governance when repository
  writes were in scope;
- approval-gated actions are either approved and recorded or not performed;
- Manager review has reconciled ticket, PR, workpad, and status state;
- any remaining risks are accepted or converted into follow-up tickets.
