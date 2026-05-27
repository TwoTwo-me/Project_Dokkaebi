# Dokkaebi Manager Contract

This contract defines what any AI Manager implementation must do to serve as
Project Dokkaebi's Manager layer.

## Manager implementations

Initial target:

- Hermes Manager Adapter

Supported/future adapters:

- Codex/oh-my-codex Manager Adapter
- OpenClaw Manager Adapter
- Custom Manager Adapter

## Required capabilities

A Manager adapter must be able to:

1. Accept a Human request and preserve the original intent.
2. Clarify ambiguity before issuing Worker work when goals, non-goals, or
   approval boundaries are unclear.
3. Convert approved work into a GitHub Project/Symphony-ready ticket.
4. Attach acceptance criteria, constraints, validation requirements, permission
   level, and expected result packet.
5. Respect Human approval gates before high-impact actions.
6. Run a fail-closed preflight before dispatch when approval, credentials,
   infrastructure, deployment, project status, or Worker authority could be
   affected.
7. Read Worker progress/result packets from GitHub Project, workpad comments,
   PRs, logs, or other configured surfaces.
8. Summarize Worker output back to the Human with evidence, blockers, residual
   risks, and next decisions.
9. Keep enough audit trail for another Manager adapter to resume.

## Stable contract artifacts

The preferred implementation surfaces are open and inspectable:

- Markdown guides and runbooks.
- Skill-style instruction folders, preferably with `SKILL.md` entrypoints where
  useful.
- CLI commands for deterministic local operations.
- MCP tools for structured stateful or external integrations.
- GitHub Project issue forms/templates.
- Result packet schemas.

Required local artifacts:

- [`ARCHITECTURE.md`](../../ARCHITECTURE.md)
- [`WORKFLOW.md`](../../WORKFLOW.md)
- [`docs/policies/authority-and-safety.md`](../policies/authority-and-safety.md)
- [`docs/adapters/hermes.md`](../adapters/hermes.md)
- [`docs/templates/worker-ticket.md`](../templates/worker-ticket.md)
- [`docs/templates/worker-result-packet.md`](../templates/worker-result-packet.md)

## Authority levels

See [`docs/policies/authority-and-safety.md`](../policies/authority-and-safety.md)
for the binding safety policy.

### Always requires Human approval

- Cloud or Proxmox changes.
- Secret or credential access.
- Worker creation, scaling, or privilege elevation.
- Manager runtime replacement.
- PR merge, deployment, production data writes, or production infrastructure
  writes unless a later ADR grants a narrow exception.

### Automation candidates

- Drafting GitHub Project tickets.
- Updating workpad/progress comments.
- Posting validation evidence.
- Preparing PRs for review.

### Approval evidence minimum

Pre-execution Human approval must record:

- approver identity or Human decision source;
- approved action and explicit non-approved adjacent actions;
- ticket id;
- affected system;
- permitted actor/runtime;
- expiry or revocation condition;
- validation expectation;
- planned result-packet or Manager-review surface.

The actual result-packet or Manager-review link is closeout evidence, not a
pre-dispatch prerequisite. Missing pre-execution approval evidence blocks
dispatch.

## Fail-closed preflight

A Manager adapter must block dispatch when any required condition is unknown:

1. Source request and ticket are linked.
2. Acceptance criteria, non-goals, permission level, validation plan, and result
   packet requirements are present.
3. GitHub Project/Symphony status is mapped to a dispatchable semantic state.
4. Worker capability, OS, and tool constraints match the ticket.
5. Human approval evidence exists for every gated action.
6. Credential grants, if needed, are brokered, least-privilege, task-scoped, and
   time-bound.
7. No policy item requires Human review before continuing.

A failed preflight creates a blocked ticket with a specific missing condition. It
does not authorize best-effort Worker dispatch.

## Credential broker boundary

Managers and Workers must not exchange broad raw credentials through prompts or
hidden memory. A credential broker must issue task-scoped grants with
repository/service allowlists, branch or environment binding, expiry, and endpoint
proof. Grant metadata belongs in the audit trail; secret material should remain
outside ticket prose and Worker result summaries.

## Symphony compatibility

Dokkaebi treats Symphony as the first backend adapter behind the Manager Contract.
The Manager must support:

- **Greenfield Symphony projects:** propose the initial status fields, labels,
  templates, and admission rules; create them only under approved setup
  authority.
- **Brownfield Symphony projects:** map existing project statuses, labels, workpad
  conventions, and Worker metadata to the semantic state model in `WORKFLOW.md`
  before dispatch.

If the status mapping is missing or ambiguous, the ticket remains blocked until
the mapping is documented.

## Adapter conformance

Each Manager adapter must publish a conformance note that maps these contract
capabilities to concrete behavior:

| Capability | Evidence required |
| --- | --- |
| Human intake and clarification | Request notes, scope, non-goals, and stop condition. |
| Ticket drafting | Worker ticket with acceptance criteria, permission level, and validation plan. |
| Approval enforcement | Approval evidence or explicit blocked reason. |
| Symphony handoff | Project item/status/label/workpad linkage. |
| Worker result review | Result packet review with validation evidence and residual risks. |
| Resume portability | Request, ticket, approvals, result packet, PR/logs, and next decision links. |

Hermes baseline conformance is documented in
[`docs/adapters/hermes.md`](../adapters/hermes.md).

## Result packet minimum

A Worker result packet must include:

- task identifier and source ticket;
- summary of completed work;
- changed files or PR links;
- validation commands and outcomes;
- acceptance-criteria evidence and whether acceptance criteria were met;
- blockers or missing permissions;
- residual risks;
- scope-control statement and approval-gate status;
- recommended next action for the Manager/Human.

The normative template is
[`docs/templates/worker-result-packet.md`](../templates/worker-result-packet.md).
