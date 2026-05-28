# Project Dokkaebi Workflow

This workflow defines how Dokkaebi converts Human intent into Symphony-native
ProjectScope work and how Worker output returns as verifiable evidence.

```text
Human request
  -> Manager intake and clarification
  -> worker-ready ticket
  -> approval/status gate
  -> ProjectScope / Symphony dispatch
  -> Worker execution
  -> result packet
  -> Manager review
  -> Human decision / closeout
```

## Workflow principles

- Human intent, constraints, and approval boundaries must survive translation
  into tickets.
- Work enters the Worker queue only as an inspectable ProjectScope ticket,
  GitHub Project issue, or equivalent work contract.
- Workers execute bounded tasks; they do not negotiate broad scope directly with
  the Human by default.
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
ready for Symphony dispatch until it contains enough detail for an isolated
Worker to complete and verify the task without hidden context.

Required ticket sections:

1. **Goal**: one concrete outcome.
2. **Context**: files, links, prior decisions, related tickets, and current
   system behavior.
3. **Acceptance criteria**: observable pass/fail conditions.
4. **Scope and non-goals**: what the Worker may and may not change.
5. **Permission level**: allowed tools, network, credentials, write authority,
   and approval requirements.
6. **ProjectScope and capability requirements**: target scope, Worker tier, OS,
   tools, network mode, and provider constraints.
7. **Validation plan**: tests, lint, typecheck, build, smoke checks, or manual
   verification expected from the Worker.
8. **Result packet requirements**: exact evidence the Worker must return.
9. **Escalation triggers**: when to stop and report instead of improvising.

## Phase 3: Approval and readiness gate

Before dispatch, the Manager classifies the ticket:

| Classification | Dispatch rule |
| --- | --- |
| Documentation / planning only | May dispatch when scope and acceptance criteria are clear. |
| Local code change | May dispatch when validation and write scope are clear. |
| Credentialed work | Requires explicit credential approval and brokered least-privilege access. |
| Cloud / Proxmox / infrastructure | Requires explicit Human approval before any create/update/delete. |
| Worker scaling or privilege elevation | Requires explicit Human approval. |
| Manager runtime replacement | Requires explicit Human approval. |
| PR merge, deployment, production write | Requires explicit Human approval unless a later ADR grants a narrow exception. |

Dispatch readiness should be represented by status/labels in the GitHub Project,
not by private Manager memory alone.

Symphony-facing labels may use project-specific names, but they must map to the
semantic status and capability model below before Symphony dispatch.


## ProjectScope model

A ProjectScope is one configured tracker/project/workflow boundary watched by
Symphony, or by a future ADR-approved runtime that explicitly conforms to the
Symphony scheduler/runner/tracker-reader contract. For v0, a ProjectScope is a
GitHub Project with documented status fields, labels, Worker capability metadata,
credential policy, and result-packet surfaces. Multi-project operation means
Dokkaebi coordinates multiple ProjectScopes above Symphony; it does not require a
single v0 Symphony process to poll every project.

A ticket is dispatchable only when its ProjectScope mapping is known and its
required Worker capabilities are available. Capability terms are defined in
[`docs/contracts/worker-capability-model.md`](docs/contracts/worker-capability-model.md).
Runtime provider boundaries are defined in
[`docs/contracts/runtime-provider-contract.md`](docs/contracts/runtime-provider-contract.md).

## Phase 4: Symphony dispatch

Symphony watches the configured ProjectScope and dispatches tickets that match
its admission rules, such as status, labels, Worker OS metadata, capability
constraints, credential policy, and validation expectations.

On dispatch, Symphony should provide the Worker:

- source ticket and acceptance criteria;
- isolated workspace;
- declared write scope;
- allowed tools and network mode;
- scoped credentials, if policy approved and brokered;
- expected progress/reporting surfaces;
- result-packet schema.

If the ticket cannot be safely dispatched, Symphony or the Manager should mark
it blocked with the missing condition rather than starting a best-effort Worker.

## Phase 5: Worker execution

The Worker follows the ticket, not adjacent discoveries. The expected execution
loop is:

1. inspect only the context needed for the ticket;
2. make the smallest correct change;
3. run the requested validation;
4. fix failures within scope;
5. stop and escalate when blocked by missing approval, missing credentials,
   destructive action, scope expansion, or contradictory instructions;
6. return a result packet through the configured tracker/workpad/PR surfaces.

Workers may recommend follow-up work, but recommendations are not implicit
authorization to perform it.

## Phase 6: Result packet

A Worker result packet must be evidence-dense and reusable by another Manager.
Minimum fields:

- ticket id and Worker id;
- summary of completed work;
- changed files, PRs, commits, or artifact links;
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
- Are residual risks acceptable or do they require follow-up tickets?
- Is Human approval needed for merge, deploy, production writes, credentials,
  infrastructure, or broader Worker authority?
- Are project status, issue comments, PR state, and artifact links consistent?

If evidence is insufficient, the Manager returns the ticket for Worker fixup or
creates a follow-up ticket with clear acceptance criteria.

## Status model

Dokkaebi should use explicit statuses so Human, Manager, Symphony, and Workers
share the same state machine. The exact GitHub Project field names may vary, but
the semantic states should remain stable.

| State | Owner | Meaning | Allowed next states |
| --- | --- | --- | --- |
| Intake | Manager | Human request captured; not yet worker-ready. | Clarifying, Ready, Cancelled |
| Clarifying | Manager / Human | Manager is resolving ambiguity or approval boundaries. | Ready, Blocked, Cancelled |
| Ready | Manager | Ticket has acceptance criteria, scope, validation, and permission level. | Dispatchable, Blocked, Cancelled |
| Dispatchable | Symphony | Ticket matches Symphony admission rules. | In Progress, Blocked |
| In Progress | Worker | Worker has accepted the ticket and is executing. | Needs Review, Blocked, Failed |
| Needs Review / Human Review | Manager / Human | Worker returned evidence; review or approval is pending. | Fix Requested, Merging, Done, Blocked |
| Fix Requested | Worker | Follow-up correction is required inside the same ticket scope. | In Progress, Needs Review, Failed |
| Merging | Human / approved automation | Merge is explicitly authorized and checks are being finalized. | Done, Blocked, Failed |
| Done | Manager | Acceptance criteria and required approvals are satisfied. | Reopened |
| Reopened | Manager | Closed work is intentionally returned to intake with new evidence or scope. | Intake, Ready, Cancelled |
| Blocked | Manager / Worker | Progress requires approval, credentials, scope decision, or external state. | Clarifying, Ready, In Progress, Cancelled |
| Failed | Manager | Work cannot be completed under current constraints. | Reopened, Cancelled |
| Cancelled | Human / Manager | Work is intentionally stopped. | Reopened |

The human-visible GitHub Project `Status` field must expose the same option set
as the Dokkaebi state field and mirror its value on every item. Project board
views should group by `Status` for humans while Symphony reads the configured
Dokkaebi state field. Any mismatch is drift and must be repaired with
`scripts/dokkaebi-project-status-sync.py --apply` only when the repair is
non-terminal, otherwise it must be blocked before dispatch until Human approval
provenance is verified.
The Manager preflight now runs the sync helper in bidirectional observed mode:
it records a local snapshot, then applies the side that changed since the last
clean snapshot. For continuous operation run
`scripts/dokkaebi-project-status-sync.py --direction bidirectional --watch --apply --record-state`.
The equivalent long-running wrapper is
`scripts/dokkaebi-project-status-sync-loop.sh`.
If both fields changed, neither side changed, a mismatched item lacks a prior
snapshot, or `dokkaebi/KILL_SWITCH` exists, the sync fails closed instead of
guessing. `Status` → `Dokkaebi Status` sync is automatic only for non-gated
status movement; approval-gated transitions such as `Human Review` → `Merging`
or `Human Review` → `Done` remain blocked until a trusted provenance verifier
supplies the required Human approval evidence. Before any mutation, the helper
re-reads the Project item and aborts if either status field changed after
planning.

## Status transition provenance

GitHub Project status is the first v0 approval surface, but a status value alone
is not proof of Human approval. The Manager may move a complete Worker result to
`Human Review`; that action asks for review and does not authorize merge,
deployment, terminal closeout, or adjacent high-impact work.

These terminal approval transitions require human-origin provenance:

- `Human Review` → `Merging`
- `Human Review` → `Done`

GitHub issue closeout is also terminal closeout and requires the same approval
class. The approval record must identify the actor, actor origin, source
transition, target transition, approved action, linked ticket/project item,
linked Worker result packet or Manager review, trusted provenance verifier,
source-specific record id, verification method, and an enabled provenance
source. In this bootstrap v0 policy only `durable_human_approval_record` is
enabled; GitHub status-history and broker sources stay listed as planned
sources but fail closed until their adapters can authenticate API output or
broker signatures. Caller-supplied `actor_origin: human` JSON is not approval
by itself. A Manager-authored `Human Review` → `Merging`,
`Human Review` → `Done`, or GitHub issue close transition is self-approval and
must be rejected. Unknown, untrusted, or ambiguous provenance fails closed.

## Exception and escalation rules

Escalate to Manager/Human instead of continuing when:

- the ticket requires a file, system, or repository outside declared scope;
- a credential, secret, token, or admin account is needed;
- cloud, Proxmox, infrastructure, deployment, production data, merge, or release
  action is required;
- Worker privileges, parallelism, network authority, or runtime need expansion;
- acceptance criteria conflict with safety policy;
- validation cannot run and no equivalent evidence is available;
- tracker state and actual repository/workspace state disagree.
- `dokkaebi/KILL_SWITCH` is present;
- terminal status approval or GitHub issue closeout provenance is missing,
  untrusted, ambiguous, or Manager-authored.

## End-to-end example

1. Human: "Add a worker-ready bugfix template for frontend regressions."
2. Manager clarifies target repository, non-goals, and whether the Worker may
   edit templates only.
3. Manager creates a GitHub Project ticket with acceptance criteria, template
   path, validation expectations, and no merge/deploy authority.
4. Human or policy marks it Ready.
5. Symphony dispatches one Worker with a scoped workspace.
6. Worker edits the template, runs markdown checks, and opens a PR.
7. Worker posts a result packet with changed files, commands, outcomes, and
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
- approval-gated actions are either approved and recorded or not performed;
- Manager review has reconciled ticket, PR, workpad, and status state;
- any remaining risks are accepted or converted into follow-up tickets.
