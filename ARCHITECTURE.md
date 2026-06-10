# Project Dokkaebi Architecture

Project Dokkaebi is the upper AI Manager layer for a human-governed,
auditable project-management loop:

```text
Human
  -> Dokkaebi Manager plugin/skillset
  -> GitHub Project issues and Status
  -> Dokkaebi Fire
  -> Dokkaebi Hammer
  -> verifiable result packet
  -> Dokkaebi Manager review
  -> Human decision
```

Dokkaebi owns intent preservation, authority policy, work-contract quality, and
result review. Dokkaebi is installed into a Manager runtime as a plugin or
skillset that configures and manages GitHub Projects and issues. Dokkaebi Fire
is the long-running backend/orchestrator derived from Symphony. It watches a
GitHub Project, dispatches bounded Dokkaebi Hammer runs, and records progress
through issues, workpad comments, pull requests, logs, and project status.
Dokkaebi Hammer is the typed Worker target/runtime launched by Fire for one
bounded ticket.

GitHub Project `Status` is the lifecycle source of truth. Fire, Hammer, issue
comments, workpads, PRs, logs, and validation artifacts are evidence surfaces
that explain or prove lifecycle movement; they do not replace the project
Status field.

## Architectural goals

- Preserve Human intent while converting it into worker-ready contracts.
- Keep Manager implementations replaceable: Hermes first, but not Hermes-only.
- Route worker execution through Dokkaebi Fire and a visible tracker instead of
  ad-hoc direct Human-to-Worker conversations.
- Enforce authority boundaries before credentials, infrastructure, worker
  scaling, merge, deploy, or production-write actions.
- Require result packets with enough evidence for another Manager or Human to
  verify, resume, or reject the work.

## Components

### Human

The Human is the source of goals, non-goals, authority grants, and final
high-impact decisions. The Human may approve or reject tickets, broaden
permissions, merge/deploy work, or replace a Manager runtime.

### Dokkaebi Manager

The Manager translates Human requests into inspectable work contracts, manages
GitHub Project/issues for dispatch readiness, and reviews Worker results.
Dokkaebi is delivered to the Manager runtime as an installable Manager
plugin/skillset. Its stable duties are defined by
[`docs/contracts/manager-contract.md`](docs/contracts/manager-contract.md), not
by any single runtime.

Initial and candidate adapters:

- **Hermes Manager Adapter**: first baseline implementation for long-running,
  memory-aware Manager operation.
- **Codex/oh-my-codex Manager Adapter**: development, planning, maintenance,
  and alternate Manager path.
- **OpenClaw Manager Adapter**: future channel/UI-heavy candidate after the
  authority model is mature.
- **Future/custom adapters**: allowed only after implementing the same Manager
  Contract and safety gates.

### Dokkaebi Fire / GitHub Project control plane

Dokkaebi Fire is the lower orchestration backend for the first implementation
path. Fire is derived from Symphony and preserves Symphony's GitHub Project
tracker role while naming the Dokkaebi-owned backend surface. GitHub Project
issues are the durable dispatch queue and visible coordination surface. GitHub
Project `Status` is the lifecycle source of truth, while workpad comments, PRs,
commits, logs, and validation artifacts carry execution evidence. Fire consumes
approved tickets, starts isolated Hammer runs, and updates project/workpad/PR
state.

Dokkaebi must treat Fire as a backend adapter behind a stable work-contract
interface. A future backend may replace the Symphony-derived Fire backend
without changing the Manager's core responsibility to produce bounded,
auditable work.

Docker, `kubectl`, and Kubernetes are planned or eligible routing/bootstrap
targets for future Fire deployments. This milestone does not claim Docker or
Kubernetes dispatch support is implemented.

### Dokkaebi Hammer Worker runtime

Dokkaebi Hammer is the typed Worker target/runtime launched by Fire. A Hammer
executes one bounded ticket at a time in an isolated workspace. It must follow
ticket scope, permission level, acceptance criteria, validation requirements,
and result-packet expectations. Hammers do not receive broad Manager authority
by default and should not expand scope without Manager/Human approval.

A Hammer runtime may be local or remote only when the ticket and policy allow
that route. `dokkaebi-hammer` reset requests are bounded by
[`docs/operations/toolchain-bootstrap.md`](docs/operations/toolchain-bootstrap.md)
and do not authorize deleting repositories, credentials, Fire state, containers,
volumes, namespaces, or remote resources outside the approved reset target.

### Credential broker

The credential broker is the boundary between Manager intent and Hammer Worker
authority. It must issue only least-privilege, time-bound, task-scoped
credentials when a ticket explicitly allows them. Manager PATs, OAuth tokens,
SSH keys, and cloud credentials must not be copied directly into Hammer spaces.

### Approval gates

Approval gates are explicit stop points where automation must wait for a Human
decision or a documented policy grant. At minimum, approval is required for:

- cloud or Proxmox resource changes;
- secret or credential access;
- Hammer creation, scaling, or privilege elevation;
- Manager runtime replacement;
- PR merge, deployment, or production data/infrastructure writes unless a later
  ADR explicitly narrows and grants those actions.

See the companion policy document
`docs/policies/authority-and-safety.md` for the authoritative approval matrix.

## Trust boundaries

```text
Human authority
  | approval / goals / constraints
  v
Dokkaebi Manager boundary
  | worker-ready ticket, status review, evidence review
  v
GitHub Project / Dokkaebi Fire boundary
  | dispatch, isolated workspace, scoped credentials
  v
Dokkaebi Hammer boundary
  | code/docs/artifacts/tests/logs
  v
Repository / PR / result-packet boundary
```

Key boundary rules:

1. **Human to Manager**: the Manager may clarify and draft, but may not infer
   high-impact approval from vague intent.
2. **Manager to Fire**: only approved, worker-ready tickets enter the
   dispatchable queue.
3. **Fire to Hammer**: Hammer Workers receive only the workspace, tools, labels,
   credentials, and permissions declared by the ticket and policy.
4. **Hammer to repository/PR**: Workers may prepare changes and validation
   evidence, but merge/deploy/production-write authority remains gated.
5. **Hammer to Human**: direct Human conversation is not the default result path;
   Workers report through tracker/workpad/PR/test artifacts for Manager review.

## Authority flow

Authority flows downward only through explicit artifacts:

1. Human states a goal and any known constraints.
2. Manager clarifies ambiguity and classifies permission level.
3. Manager writes or updates a GitHub Project ticket with acceptance criteria,
   non-goals, permission level, validation, and expected result packet.
4. Human approval is recorded for any gated action before dispatch.
5. Dokkaebi Fire dispatches a Hammer only when Status, agent, authorization,
   admission, fallback labels, and policy allow it.
6. Credential broker grants only the scoped capabilities required by the ticket.
7. Hammer returns evidence; Manager reviews it before asking the Human for any
   next high-impact decision.

Authority does not flow by implication from tool availability, local filesystem
access, credential presence, or a Hammer discovering adjacent work.

## Result flow

The result path is evidence-first:

```text
Hammer changes/logs/tests
  -> workpad comment, PR, artifact, or project update
  -> result packet
  -> Manager review
  -> Human summary and decision
```

A minimum result packet includes:

- source ticket and task identifier;
- summary of completed work;
- changed files, PR links, or artifact links;
- validation commands and outcomes;
- acceptance-criteria evidence and whether acceptance criteria were met;
- blockers or missing permissions;
- residual risks and known gaps;
- scope-control statement and approval-gate status;
- recommended next action.

## Durable audit surfaces

Dokkaebi should prefer surfaces another Manager adapter can inspect:

- GitHub Project fields and status history, especially the lifecycle `Status`;
- issue body, comments, and workpad comments used as execution evidence;
- PR descriptions, review threads, commits, and checks;
- Hammer logs and validation artifacts;
- repository documents and versioned policies;
- Manager summaries that cite evidence instead of relying on memory.

Manager memory may help continuity, but it is not the durable source of truth.

## Adapter portability

The Manager runtime is replaceable only if core state is stored in open,
inspectable artifacts. Adapter-specific behavior must be documented as adapter
behavior, not as Dokkaebi core architecture.

Portability requirements:

- ticket templates must be readable without one Manager runtime;
- safety policy must be runtime-neutral;
- result packets must be structured enough for another Manager to resume;
- CLI/MCP integrations must not bypass the Manager Contract;
- Hermes memory, Codex session state, or future channel state must not be the
  only copy of an approval, blocker, or validation result.

## Toolchain bootstrap boundary

Tool installation is part of the authority model. Dokkaebi prefers user-local
installs for Manager plugins, Fire helpers, and Hammer runtimes. Any bootstrap
work must begin with read-only preflight, use scripted install steps when
changes are approved, record install evidence, and include rollback notes in
the result packet.

Remote hosts, Docker, `kubectl`, and Kubernetes require explicit setup
authority before mutation. They are eligible routing or bootstrap targets, not
implemented support guarantees in this milestone. See
[`docs/operations/toolchain-bootstrap.md`](docs/operations/toolchain-bootstrap.md)
for local/remote install policy and `dokkaebi-hammer` reset boundaries.

## Critical risks and mitigations

| Risk | Failure mode | Mitigation |
| --- | --- | --- |
| Authority leakage | Manager or Hammer uses broad credentials beyond task scope. | Use approval gates, credential broker, least privilege, and explicit permission levels. |
| Tracker drift | GitHub Project status, issue comments, PR state, and workspace state disagree. | Require result packets and Manager reconciliation before completion. |
| Scope inflation | Hammer expands into adjacent work without approval. | Ticket non-goals, acceptance criteria, and escalation rules. |
| Manager ambiguity | Manager emits vague tickets that Hammers cannot safely execute. | Clarify before dispatch and require worker-ready fields. |
| Backend coupling | Dokkaebi becomes Fire/Symphony-specific. | Keep Fire behind a Manager work-contract adapter boundary. |
| Human review bypass | Merge, deploy, infra, or production writes happen without approval. | Treat high-impact actions as approval-required unless policy explicitly grants a narrow exception. |
| Bootstrap overreach | Local setup mutates shared, remote, Docker, or Kubernetes resources without approval. | Prefer user-local installs, require read-only preflight, scripted evidence, rollback notes, and explicit setup authority for remote routes. |

## Milestone 1 boundary

Milestone 1 is a repository-contract milestone. It documents the architecture,
workflow, authority policy, Manager contract, and ticket/result templates. It
does not grant production authority, create infrastructure, replace the Manager
runtime, or enable unattended merge/deploy automation.
