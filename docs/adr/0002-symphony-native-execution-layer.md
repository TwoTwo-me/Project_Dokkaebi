# ADR 0002: Symphony-native execution layer

## Status
Accepted

## Context
Project Dokkaebi previously described Symphony as the first replaceable worker
orchestration backend. The clarified product direction moves the replacement
boundary: **Manager runtimes remain replaceable**, while **Symphony is the
canonical project-scope execution layer**.

OpenAI's Symphony specification defines a long-running service that reads work
from an issue tracker, creates an isolated workspace per issue, and runs a
coding-agent session in that workspace. It also makes an important boundary
explicit: Symphony is a scheduler/runner and tracker reader; ticket writes,
comments, PR links, and workflow-specific business logic normally live in the
coding agent's tools and workflow contract.

Dokkaebi therefore should not redefine Symphony as a generic backend hidden
behind an adapter. Dokkaebi should sit one layer above Symphony and manage Human
intent, Manager contracts, project scopes, environment-provider policy, Worker
capability requirements, result review/evaluation, and trusted automation gates.

## Decision
Dokkaebi adopts a **Symphony-native execution architecture**:

```text
Human
  -> replaceable Dokkaebi Manager runtime
  -> ProjectScope / worker-ready ticket
  -> Symphony-native scheduler-runner-worker loop
  -> Worker result packet / evidence
  -> Dokkaebi Manager review and evaluation
  -> Human summary or policy-gated trusted action
```

Symphony is canonical for project-scope execution orchestration. Backend
replaceability is intentionally reduced at that layer. Manager runtime
replaceability is preserved through the Dokkaebi Manager Contract.

GitHub Project remains the v0 scheduler/tracker substrate. Non-GitHub scheduler
substrates are deferred and must be introduced by a future ADR-approved runtime
that conforms to the Symphony scheduler/runner/tracker-reader contract, not as a
reason to dilute the Symphony-native execution boundary today.

## Decision drivers
- Align Dokkaebi with the official Symphony scheduler/runner/tracker-reader
  boundary instead of a local implementation accident.
- Preserve Manager runtime replaceability for Hermes, Codex/OMX, OpenClaw, and
  future custom Managers.
- Keep Human review, project policy, Worker capability routing, environment
  provisioning, audit, rollback, and kill-switch concerns above Symphony.
- Avoid runtime implementation, infrastructure mutation, UI work, repository
  restructuring, and test execution in this architecture milestone.

## Boundaries

### Dokkaebi owns
- Human request intake, clarification, and intent preservation.
- The Manager Contract and Manager adapter conformance requirements.
- ProjectScope/SymphonyScope inventory and multi-project coordination.
- Worker environment/provider contracts.
- Worker capability taxonomy and policy requirements.
- Result packet review, evaluation, Human summaries, and follow-up ticketing.
- Trusted automation gates, audit records, rollback posture, and kill switches.

### Symphony owns within a ProjectScope
- Polling the configured tracker/project.
- Reading tracker state and normalizing dispatch candidates.
- Scheduling/routing eligible work to capable Workers.
- Starting or supervising Worker execution attempts in isolated workspaces.
- Reconciling active runs with tracker state.
- Emitting operator-visible logs/status for scheduler and Worker activity.

### Manager runtimes implement
- The Dokkaebi Manager Contract.
- Worker-ready ticket creation.
- Approval and policy preflight.
- ProjectScope mapping and dispatch-readiness classification.
- Worker result-packet review and Human-facing summaries.
- Durable audit trail preservation so another Manager can resume.

## ProjectScope / SymphonyScope model
A `ProjectScope` (also called a `SymphonyScope` when emphasizing the execution
layer) is one configured tracker/project/workflow boundary watched by Symphony,
or by a future ADR-approved runtime that explicitly conforms to the Symphony
scheduler/runner/tracker-reader contract.

A ProjectScope includes:
- tracker kind and project identifier;
- workflow/status mapping;
- admission labels and readiness rules;
- allowed repositories and environments;
- Worker capability requirements;
- credential broker policy;
- result packet and review surfaces;
- audit, rollback, and kill-switch policy.

For v0, Dokkaebi proves one GitHub Project loop. Multi-project support is modeled
as Dokkaebi managing multiple ProjectScopes or Symphony instances above the
execution layer. A single GitHub Project may still include multiple repositories
when policy, credentials, and validation requirements allow it.

## Runtime / provider contract summary
Dokkaebi, not Symphony, owns environment-provider policy. The detailed contract
is `docs/contracts/runtime-provider-contract.md`.

Provider-neutral flow:

```text
Dokkaebi Environment Controller
  -> provision or lease Worker environment
  -> bootstrap Worker runtime
  -> register Worker and capabilities
  -> Symphony routes eligible work
  -> drain/destroy/revoke after lease or completion
```

The first runtime direction is a Host Docker provider controlled through a narrow
host helper daemon. Dokkaebi must not receive a broad Docker socket by default.
Future providers may include VMs, Kubernetes, IaC-backed templates, cloud, and
Proxmox, but this ADR does not implement any provider.

## Worker capability model summary
Worker routing must use explicit capability metadata. The detailed model is
`docs/contracts/worker-capability-model.md`.

Minimum capability tiers:
- `basic`: code/docs/light local validation;
- `container-capable`: Docker/Podman/Compose-capable development and integration
  checks;
- `testbed`: clean independent verification;
- future provider-specific capabilities for VM/Kubernetes/IaC/cloud/Proxmox
  environments.

Docker/Compose support is a schedulable Worker capability, not something deferred
only to testbed. A testbed remains an independent verification environment, not a
replacement for Worker-local development feedback.

## Trusted automation gates
Full trusted automation is allowed only when every applicable gate is explicit
and auditable:

- versioned per-project policy file;
- credential broker only, with no broad raw credential transfer;
- durable Human approval record for gated action classes;
- validation gate before direct action;
- environment tiers with different thresholds for dev, staging, and production;
- audit trail and rollback/revert path;
- Human kill switch by project, Worker, Manager, environment, or action class.

If any gate is missing, ambiguous, expired, or contradictory, Dokkaebi and the
Manager must fail closed and mark the work blocked rather than dispatching a
best-effort Worker.

## OpenAI vs TwoTwo reuse matrix

| Source | Use as conceptual source of truth | Use as implementation evidence | Refactor before reuse |
| --- | --- | --- | --- |
| Official OpenAI Symphony repo/spec | Scheduler/runner/tracker-reader boundary; issue-tracker control-plane model; isolated workspace model; workflow-policy layering; observability expectations; app-server/reference direction. | Elixir reference behavior and spec examples. | Do not copy Linear-specific assumptions into Dokkaebi's GitHub Project v0 model. |
| Local TwoTwo GitHub Project tracker fork | No. Treat as a prototype/substrate, not as Dokkaebi's conceptual authority. | GitHub Project adapter, OAuth Device Login, credential broker, WorkerPool/Registry, observability/status API, Docker Compose packaging evidence. | SSH transport assumptions, Docker Compose fleet coupling, single-project config, local workflow assumptions, and any direct Docker control surface must be placed behind provider/transport contracts. |

## Validation requirements
This ADR pack documents validation requirements; editing
`scripts/validate-contract-docs.sh` is an optional tooling follow-up and must not
be required unless a later execution lane explicitly expands scope to tooling
edits.

Future docs validation should:
- require this ADR file;
- require links to `runtime-provider-contract.md` and
  `worker-capability-model.md`;
- require Symphony-native framing and Manager runtime replaceability;
- require ProjectScope/SymphonyScope language;
- require trusted automation gates;
- require `basic`, `container-capable`, and `testbed` capability terms;
- forbid stale backend-adapter phrases unless clearly labeled as superseded
  history, including:
  - `Symphony is treated as the first worker orchestration backend`;
  - `Symphony is the first worker orchestration backend`;
  - `Dokkaebi must treat Symphony as an adapter behind a stable work-contract interface`;
  - unqualified `Symphony/backend` as a core architecture label.

## Alternatives considered

### Keep Symphony as a replaceable backend adapter
Rejected. This preserves the wrong replacement boundary and conflicts with the
clarified Symphony-native direction. Manager runtimes should be replaceable;
Symphony should be the canonical execution layer for v0.

### Make Dokkaebi directly own scheduling/running
Rejected for v0. It duplicates Symphony's scheduler/runner/tracker-reader role
and weakens the intended layer separation.

### Full TwoTwo fork migration first
Rejected. The TwoTwo fork is useful implementation evidence, but migration before
contract alignment would turn prototype details into architecture too early.

### Multi-ADR pack for every boundary
Deferred. Separate ADRs would improve traceability, but this milestone favors one
canonical ADR plus small contract docs to avoid document sprawl and roadmap
creep.

## Consequences

### Positive
- Dokkaebi's product boundary is clearer: it manages agentic work above
  Symphony, not below it.
- Manager replaceability remains explicit and durable.
- Future provider/runtime work has a contract boundary before implementation.
- The TwoTwo fork can be reused selectively without becoming the conceptual
  source of truth.

### Tradeoffs
- Symphony execution-layer replaceability is reduced by design.
- ADR 0002 carries several related boundary decisions, so linked contract docs
  are required to keep it readable.
- Validation script updates are deferred unless a later tooling scope is opened.

## Follow-ups
- Update root docs and contracts to cite this ADR.
- Align policy language with trusted automation gates.
- Keep validation script editing as a later optional tooling follow-up.
- Later planning may target the single GitHub Project runnable loop.
- Later implementation may decide whether to refactor the TwoTwo fork behind
  provider and transport interfaces.
