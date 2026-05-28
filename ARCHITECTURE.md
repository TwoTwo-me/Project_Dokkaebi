# Project Dokkaebi Architecture

Project Dokkaebi is the upper AI Manager layer for a human-governed,
Symphony-native project-management loop:

```text
Human
  -> Dokkaebi Manager
  -> ProjectScope / Symphony control plane
  -> isolated AI Worker
  -> verifiable result packet
  -> Dokkaebi Manager review
  -> Human decision or policy-gated trusted action
```

Dokkaebi owns intent preservation, authority policy, work-contract quality,
project-scope coordination, Worker capability requirements, environment-provider
contracts, and result review/evaluation. Symphony is the canonical scheduler /
runner / tracker-reader execution layer inside a ProjectScope. GitHub Project is
the first v0 scheduler/tracker substrate.

This architecture is accepted in
[`docs/adr/0002-symphony-native-execution-layer.md`](docs/adr/0002-symphony-native-execution-layer.md).

## Architectural goals

- Preserve Human intent while converting it into worker-ready contracts.
- Keep Manager implementations replaceable: Hermes first, but not Hermes-only.
- Use Symphony-native ProjectScopes for visible, auditable Worker execution.
- Route Worker dispatch through explicit status, policy, capability, and approval
  gates instead of ad-hoc direct Human-to-Worker conversations.
- Enforce authority boundaries before credentials, infrastructure, Worker
  scaling, merge, deploy, or production-write actions.
- Require result packets with enough evidence for another Manager or Human to
  verify, resume, or reject the work.

## Components

### Human

The Human is the source of goals, non-goals, authority grants, and final
high-impact decisions. The Human may approve or reject tickets, broaden
permissions, merge/deploy work, or replace a Manager runtime.

### Dokkaebi Manager

The Manager translates Human requests into inspectable work contracts and
reviews Worker results. Its stable duties are defined by
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

### ProjectScope / Symphony control plane

A ProjectScope is one configured tracker/project/workflow boundary watched by
Symphony, or by a future ADR-approved runtime that explicitly conforms to the
Symphony scheduler/runner/tracker-reader contract. Symphony owns polling,
scheduling, routing, isolated Worker execution attempts, reconciliation, and
operator-visible status inside that scope.

Dokkaebi manages ProjectScopes above Symphony. Multi-project operation is modeled
as Dokkaebi coordinating multiple ProjectScopes or Symphony instances. For v0,
GitHub Project is the first scheduler/tracker substrate.

### Runtime providers

Runtime providers create or lease Worker environments for ProjectScopes. The
provider boundary is defined in
[`docs/contracts/runtime-provider-contract.md`](docs/contracts/runtime-provider-contract.md).
Dokkaebi owns provider policy and environment lifecycle decisions; Symphony only
routes to registered capable Workers.

The first planned provider direction is Host Docker through a narrow host helper
daemon. A broad host Docker socket is not a default Dokkaebi authority surface.

### AI Worker

A Worker executes one bounded ticket at a time in an isolated workspace. It must
follow ticket scope, permission level, acceptance criteria, validation
requirements, capability constraints, and result-packet expectations. Workers do
not receive broad Manager authority by default and must not expand scope without
Manager/Human approval.

Worker capability routing is defined in
[`docs/contracts/worker-capability-model.md`](docs/contracts/worker-capability-model.md).

### Credential broker

The credential broker is the boundary between Manager intent and Worker
authority. It must issue only least-privilege, time-bound, task-scoped
credentials when a ticket explicitly allows them. Manager PATs, OAuth tokens,
SSH keys, and cloud credentials must not be copied directly into Worker spaces.

### Approval and trusted automation gates

Approval gates are explicit stop points where automation must wait for a Human
decision or a documented policy grant. Full trusted automation additionally
requires per-project policy, credential broker enforcement, durable approval
records, validation gates, environment tiers, audit/rollback posture, and kill
switches.

See [`docs/policies/authority-and-safety.md`](docs/policies/authority-and-safety.md)
for the authoritative approval matrix.

## Trust boundaries

```text
Human authority
  | approval / goals / constraints
  v
Dokkaebi Manager boundary
  | worker-ready ticket, status review, evidence review
  v
ProjectScope / Symphony boundary
  | dispatch, isolated workspace, scoped credentials, capability routing
  v
Worker boundary
  | code/docs/artifacts/tests/logs
  v
Repository / PR / result-packet boundary
```

Key boundary rules:

1. **Human to Manager**: the Manager may clarify and draft, but may not infer
   high-impact approval from vague intent.
2. **Manager to ProjectScope**: only approved, worker-ready tickets enter the
   dispatchable queue.
3. **Symphony to Worker**: Workers receive only the workspace, tools, labels,
   capabilities, credentials, and permissions declared by the ticket and policy.
4. **Worker to repository/PR**: Workers may prepare changes and validation
   evidence, but merge/deploy/production-write authority remains gated.
5. **Worker to Human**: direct Human conversation is not the default result path;
   Workers report through tracker/workpad/PR/test artifacts for Manager review.

## Authority flow

Authority flows downward only through explicit artifacts:

1. Human states a goal and any known constraints.
2. Manager clarifies ambiguity and classifies permission level.
3. Manager writes or updates a ProjectScope ticket with acceptance criteria,
   non-goals, permission level, validation, capability requirements, and expected
   result packet.
4. Human approval is recorded for any gated action before dispatch.
5. Symphony dispatches a Worker only when status, labels, capability, credential,
   and policy gates allow it.
6. Credential broker grants only the scoped capabilities required by the ticket.
7. Worker returns evidence; Manager reviews it before asking the Human for any
   next high-impact decision.

Authority does not flow by implication from tool availability, local filesystem
access, credential presence, environment access, or a Worker discovering adjacent
work.

## Result flow

The result path is evidence-first:

```text
Worker changes/logs/tests
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

- GitHub Project fields and status history;
- issue body, comments, and workpad comments;
- PR descriptions, review threads, commits, and checks;
- Worker logs and validation artifacts;
- repository documents and versioned policies;
- Manager summaries that cite evidence instead of relying on memory.

Manager memory may help continuity, but it is not the durable source of truth.

## Manager portability

The Manager runtime is replaceable only if core state is stored in open,
inspectable artifacts. Runtime-specific behavior must be documented as adapter
behavior, not as Dokkaebi core architecture.

Portability requirements:

- ticket templates must be readable without one Manager runtime;
- safety policy must be runtime-neutral;
- result packets must be structured enough for another Manager to resume;
- CLI/MCP integrations must not bypass the Manager Contract;
- Hermes memory, Codex session state, or future channel state must not be the
  only copy of an approval, blocker, or validation result.

## Critical risks and mitigations

| Risk | Failure mode | Mitigation |
| --- | --- | --- |
| Authority leakage | Manager or Worker uses broad credentials beyond task scope. | Use approval gates, credential broker, least privilege, and explicit permission levels. |
| Tracker drift | GitHub Project status, issue comments, PR state, and workspace state disagree. | Require result packets and Manager reconciliation before completion. |
| Scope inflation | Worker expands into adjacent work without approval. | Ticket non-goals, acceptance criteria, and escalation rules. |
| Manager ambiguity | Manager emits vague tickets that Workers cannot safely execute. | Clarify before dispatch and require worker-ready fields. |
| Symphony coupling confusion | Future contributors try to make Managers own scheduler behavior or treat Symphony as generic plumbing again. | Cite ADR 0002, keep Manager replaceability separate from Symphony execution ownership, and model multi-project support as ProjectScopes above Symphony. |
| Provider authority leakage | Environment providers expose broad Docker, VM, cloud, or Proxmox power. | Use the runtime provider contract, host helper daemon boundaries, approval gates, audit, rollback, and kill switches. |
| Human review bypass | Merge, deploy, infra, or production writes happen without approval. | Treat high-impact actions as approval-required unless policy explicitly grants a narrow exception. |

## Current milestone boundary

The current milestone is a repository-contract milestone. It documents the
architecture, workflow, authority policy, Manager contract, runtime-provider
contract, Worker capability model, and ticket/result templates. It does not
grant production authority, create infrastructure, replace the Manager runtime,
implement Worker providers, design a UI, or enable unattended merge/deploy
automation.
