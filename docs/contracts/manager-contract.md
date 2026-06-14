# Dokkaebi Manager Contract

This contract defines what any AI Manager implementation must do to serve as
Project Dokkaebi's Manager layer. Dokkaebi is an installable Manager
plugin/skillset that configures and manages GitHub Projects and issues while
preserving Human approval, credential, and evidence boundaries.

## Manager implementations

Initial target:

- Hermes Manager Adapter consuming the Dokkaebi plugin/skillset

Supported/future adapters:

- Codex/oh-my-codex Manager Adapter
- OpenClaw Manager Adapter
- Custom Manager Adapter

## Required capabilities

A Manager adapter must be able to:

1. Accept a Human request and preserve the original intent.
2. Clarify ambiguity before issuing Worker work when goals, non-goals, or
   approval boundaries are unclear.
3. Convert approved work into a GitHub Project/Dokkaebi Fire-ready ticket.
4. Attach acceptance criteria, constraints, validation requirements, permission
   level, and expected result packet.
5. Respect Human approval gates before high-impact actions.
6. Run a fail-closed preflight before dispatch when approval, credentials,
   infrastructure, deployment, project status, or Worker authority could be
   affected.
7. Read Dokkaebi Hammer progress/result packets from GitHub Project, workpad
   comments, PRs, logs, or other configured surfaces.
8. Summarize Hammer output back to the Human with evidence, blockers, residual
   risks, and next decisions.
9. Keep enough audit trail for another Manager adapter to resume.
10. Apply the Git governance policy when preparing branches, commits, pull
    requests, or submodule pointer updates.

## Stable contract artifacts

The preferred implementation surfaces are open and inspectable:

- Markdown guides and runbooks.
- Skill-style instruction folders, preferably with `SKILL.md` entrypoints where
  useful.
- CLI commands for deterministic local operations.
- MCP tools for structured stateful or external integrations.
- GitHub Project issue forms/templates.
- Result packet schemas.
- Toolchain bootstrap scripts or runbooks with preflight, install evidence, and
  rollback notes.

Required local artifacts:

- [`ARCHITECTURE.md`](../../ARCHITECTURE.md)
- [`WORKFLOW.md`](../../WORKFLOW.md)
- [`docs/contracts/hammer-worker-contract.md`](hammer-worker-contract.md)
- [`docs/design/carbon-ui-baseline.md`](../design/carbon-ui-baseline.md)
- [`docs/policies/authority-and-safety.md`](../policies/authority-and-safety.md)
- [`docs/policies/credential-lifecycle-and-revocation.md`](../policies/credential-lifecycle-and-revocation.md)
- [`docs/policies/credential-revocation-access-review-drill-2026-06-13.md`](../policies/credential-revocation-access-review-drill-2026-06-13.md)
- [`docs/policies/multi-tenant-rbac.md`](../policies/multi-tenant-rbac.md)
- [`docs/policies/security-threat-model-and-prompt-injection-controls.md`](../policies/security-threat-model-and-prompt-injection-controls.md)
- [`docs/policies/project-governance-and-closeout-reconciliation.md`](../policies/project-governance-and-closeout-reconciliation.md)
- [`docs/policies/governance-settings-export-reconciliation-2026-06-14.md`](../policies/governance-settings-export-reconciliation-2026-06-14.md)
- [`docs/policies/git-governance.md`](../policies/git-governance.md)
- [`docs/operations/toolchain-bootstrap.md`](../operations/toolchain-bootstrap.md)
- [`docs/operations/dispatch-lease-recovery.md`](../operations/dispatch-lease-recovery.md)
- [`docs/operations/orchestration-recovery-gate.md`](../operations/orchestration-recovery-gate.md)
- [`docs/operations/sre-operating-baseline.md`](../operations/sre-operating-baseline.md)
- [`docs/operations/central-metrics-backend.md`](../operations/central-metrics-backend.md)
- [`docs/operations/central-metrics-sandbox-backend-2026-06-14.md`](../operations/central-metrics-sandbox-backend-2026-06-14.md)
- [`docs/operations/observability-metrics-alert-rules.md`](../operations/observability-metrics-alert-rules.md)
- [`docs/operations/on-call-paging-alerting.md`](../operations/on-call-paging-alerting.md)
- [`docs/operations/release-rollback-capacity-drills.md`](../operations/release-rollback-capacity-drills.md)
- [`docs/operations/runtime-quality-gate-exercise-2026-06-14.md`](../operations/runtime-quality-gate-exercise-2026-06-14.md)
- [`docs/operations/topology-backup-restore-dr.md`](../operations/topology-backup-restore-dr.md)
- [`docs/operations/sandbox-restore-drill-2026-06-13.md`](../operations/sandbox-restore-drill-2026-06-13.md)
- [`docs/operations/worker-route-health-bootstrap-2026-06-14.md`](../operations/worker-route-health-bootstrap-2026-06-14.md)
- [`docs/operations/durable-backup-restore-verification-2026-06-14.md`](../operations/durable-backup-restore-verification-2026-06-14.md)
- [`docs/compliance/control-map-and-evidence-package.md`](../compliance/control-map-and-evidence-package.md)
- [`docs/compliance/audit-review-2026-06-13.md`](../compliance/audit-review-2026-06-13.md)
- [`docs/compliance/immutable-audit-export.md`](../compliance/immutable-audit-export.md)
- [`docs/adapters/hermes.md`](../adapters/hermes.md)
- [`docs/templates/worker-ticket.md`](../templates/worker-ticket.md)
- [`docs/templates/worker-result-packet.md`](../templates/worker-result-packet.md)
- [`docs/examples/result-packets/accepted.md`](../examples/result-packets/accepted.md)
- [`docs/examples/result-packets/rejected-missing-acceptance-evidence.md`](../examples/result-packets/rejected-missing-acceptance-evidence.md)
- [`docs/examples/result-packets/rejected-missing-validation-evidence.md`](../examples/result-packets/rejected-missing-validation-evidence.md)
- [`docs/examples/result-packets/rejected-missing-scope-control.md`](../examples/result-packets/rejected-missing-scope-control.md)
- [`docs/examples/result-packets/rejected-missing-approval-status.md`](../examples/result-packets/rejected-missing-approval-status.md)
- [`docs/examples/replays/accepted-manager-fire-hammer.md`](../examples/replays/accepted-manager-fire-hammer.md)
- [`docs/examples/replays/rejected-missing-dispatch-readiness.md`](../examples/replays/rejected-missing-dispatch-readiness.md)
- [`docs/examples/replays/rejected-missing-approval-evidence.md`](../examples/replays/rejected-missing-approval-evidence.md)
- [`docs/examples/replays/rejected-missing-worker-route-result-metadata.md`](../examples/replays/rejected-missing-worker-route-result-metadata.md)
- [`docs/examples/replays/rejected-missing-closeout-review-evidence.md`](../examples/replays/rejected-missing-closeout-review-evidence.md)

## Authority levels

See [`docs/policies/authority-and-safety.md`](../policies/authority-and-safety.md)
for the binding safety policy.

### Always requires Human approval

- Cloud or Proxmox changes.
- Secret or credential access.
- Hammer creation, scaling, or privilege elevation.
- Remote host, Docker, `kubectl`, or Kubernetes mutation.
- Manager runtime replacement.
- PR merge, deployment, production data writes, or production infrastructure
  writes unless a later ADR grants a narrow exception.

### Automation candidates

- Drafting GitHub Project tickets.
- Updating workpad/progress comments.
- Posting validation evidence.
- Performing approved user-local Manager/Fire/Hammer tool bootstrap when
  read-only preflight passes and evidence/rollback notes are recorded.
- Preparing branches, commits, and PRs for review under
  [`docs/policies/git-governance.md`](../policies/git-governance.md).

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
3. GitHub Project/Dokkaebi Fire status is mapped to a dispatchable semantic state.
4. Hammer capability, OS, and tool constraints match the ticket.
5. Human approval evidence exists for every gated action.
6. Credential grants, if needed, are brokered, least-privilege, task-scoped, and
   time-bound.
7. Local vs remote bootstrap route is known, user-local installs are preferred,
   and any remote, Docker, `kubectl`, Kubernetes, or `dokkaebi-hammer` reset
   request is inside approved boundaries.
8. No policy item requires Human review before continuing.

A failed preflight creates a blocked ticket with a specific missing condition. It
does not authorize best-effort Worker dispatch.

## Credential broker boundary

Managers and Hammer Workers must not exchange broad raw credentials through
prompts or hidden memory. A credential broker must issue task-scoped grants with
repository/service allowlists, branch or environment binding, expiry, and endpoint
proof. Grant metadata belongs in the audit trail; secret material should remain
outside ticket prose and Worker result summaries.

Credential lifecycle and revocation dry runs must follow
[`docs/policies/credential-lifecycle-and-revocation.md`](../policies/credential-lifecycle-and-revocation.md).
The Manager must treat missing token classes, owners, storage, rotation cadence,
revocation triggers, audit evidence, narrow development/sandbox auth exception,
dry-run revocation checklist, approval-gate status, cleanup receipt, residual
risk, or next action as a security-authority readiness gap.

Approved credential revocation and access-review drills must follow
[`docs/policies/credential-revocation-access-review-drill-2026-06-13.md`](../policies/credential-revocation-access-review-drill-2026-06-13.md)
or a later dated drill package.
The Manager must treat missing owner approval, grant scope, expiration,
revocation trigger, denial output, sandbox or runtime revocation output,
access-review output, audit evidence, approval-gate status, cleanup receipt,
residual risk, or next action as a security-authority readiness gap.

Multi-tenant RBAC designs must follow
[`docs/policies/multi-tenant-rbac.md`](../policies/multi-tenant-rbac.md).
Local RBAC replay drills must follow
[`docs/policies/multi-tenant-rbac-drill-2026-06-13.md`](../policies/multi-tenant-rbac-drill-2026-06-13.md)
or a later dated drill package.
The Manager must treat missing tenant boundaries, role taxonomy, permission matrix,
admission checks, authorization checks, GitHub Project scope mapping, repository
scope mapping, credential boundary, worker route boundary, break-glass path,
access review, audit evidence, onboarding and offboarding, failure handling,
remaining operational gaps, or permission level as an authority readiness gap.

Security threat models and prompt-injection controls must follow
[`docs/policies/security-threat-model-and-prompt-injection-controls.md`](../policies/security-threat-model-and-prompt-injection-controls.md).
The Manager must treat missing threat actors, trust boundaries, assets, abuse
cases, prompt-injection paths, data exfiltration paths, credential-broker misuse
paths, worker-route escalation paths, GitHub Project control-plane risks,
mitigations, detection evidence, fail-closed behavior, owner review cadence,
residual risk, or next action as a security-authority readiness gap.

GitHub Project governance and closeout reconciliation packages must follow
[`docs/policies/project-governance-and-closeout-reconciliation.md`](../policies/project-governance-and-closeout-reconciliation.md).
Read-only governance settings export and closeout reconciliation evidence must follow
[`docs/policies/governance-settings-export-reconciliation-2026-06-14.md`](../policies/governance-settings-export-reconciliation-2026-06-14.md)
or a later dated package.
The Manager must treat missing project owner, approver, Fire operator, Hammer
operator, security reviewer, auditor, stale Human Review handling, issue status,
pull request review/check/merge state, result packet, workpad comment,
GitHub Project Status, mismatch handling, fail-closed behavior, residual risk,
next action, branch protection export, repository rulesets export, required
checks export, PR review rule export, GitHub Project field/settings export, or
closeout reconciliation report as a management-governance readiness gap.

Human-facing UI surfaces must follow
[`docs/design/carbon-ui-baseline.md`](../design/carbon-ui-baseline.md).
Reusable Carbon component inventory and visual regression evidence must follow
[`docs/design/carbon-component-library-visual-regression.md`](../design/carbon-component-library-visual-regression.md),
or a later component-library gate with equivalent artifact validation.
The Manager must treat missing theme choice, role-based token mapping, layering
model, interaction states, focus requirements, contrast thresholds, data
visualization rules, status color rules, component state inventory, visual QA checklist,
desktop and mobile visual artifact coverage, CI visual regression gate evidence,
approval-gate status, cleanup receipt, remaining operational gaps, or permission
level as a design readiness gap.

Role-based onboarding and troubleshooting guides must follow
[`docs/product/onboarding-troubleshooting.md`](../product/onboarding-troubleshooting.md).
The Manager must treat missing admin journey, approver journey, operator journey,
auditor journey, worker-author journey, install walkthrough, GitHub
Project setup checks, repository setup checks, approval and review actions,
result-packet closeout actions, Fire failure troubleshooting, worker failure
troubleshooting, GitHub failure troubleshooting, credential failure
troubleshooting, validation failure troubleshooting, project-field failure
troubleshooting, PR failure troubleshooting, result-packet failure
troubleshooting, clear next actions, approval boundary, or permission level as a
productization readiness gap.

## Symphony compatibility and Dokkaebi Fire lineage

Dokkaebi Fire is the long-running backend/orchestrator derived from Symphony.
Dokkaebi treats Fire/Symphony as the first backend adapter behind the Manager
Contract. The Manager must support:

- **Greenfield Fire/Symphony projects:** propose the initial status fields,
  fallback labels, templates, and admission rules; create them only under
  approved setup authority.
- **Brownfield Fire/Symphony projects:** map existing project statuses, agent,
  authorization, authorized-by, admission fields, fallback labels, workpad
  conventions, and Worker metadata to the semantic state model in `WORKFLOW.md`
  before dispatch.

If the status or admission mapping is missing or ambiguous, the ticket remains
blocked until the mapping is documented.

GitHub Project `Status` is the lifecycle source of truth. Fire may use
additional labels, admission fields, logs, or workpad comments as evidence, but
those surfaces must not silently replace the lifecycle state.

Manager adapters must distinguish routine project-item mutations from
control-plane mutations:

- `updateProjectV2ItemFieldValue` may update mapped status/admission fields for
  an admitted ticket.
- `addProjectV2ItemById` may add an authorized issue or PR to an approved
  project.
- `createProjectV2`, field/workflow mutation, deletion, archive, destructive
  backfill, and cross-project migration require setup approval.
- `projects_v2_item` webhooks are optional wake-up signals only. Because GitHub
  marks project webhook events as public preview, Fire must confirm current
  project state through GraphQL before dispatch, retry, or closeout.

Docker and Kubernetes Hammer providers are implemented through typed routes,
fake command/manifest verification, and isolated live-routing smoke evidence for
approved test targets. Live Docker, `kubectl`, or Kubernetes mutation remains
approval-gated outside those approved targets and must be re-proven through the
toolchain bootstrap path before production or shared infrastructure use.

Fire dispatch must follow the durable lease and restart recovery contract in
[`docs/operations/dispatch-lease-recovery.md`](../operations/dispatch-lease-recovery.md).
The Manager must treat missing lease store, owner identity, retry persistence,
recovery behavior, lease token, idempotency key, stale lease handling, or
missing evidence for no duplicate dispatch after restart as a blocked
orchestration condition.
Local deterministic validation is required before the contract can be cited as
readiness evidence; live GitHub Project residual risks remain approval-gated
until a later runtime gate proves them.

Fault-injected orchestration recovery evidence must follow
[`docs/operations/orchestration-recovery-gate.md`](../operations/orchestration-recovery-gate.md).
The gate must reject duplicate dispatch, early stale lease recovery, retry loss after restart,
and closeout without route result evidence before a Manager cites the recovery path as
readiness evidence.
Sandbox issue processing transcript evidence must follow
[`docs/operations/sandbox-issue-processing-transcript-2026-06-14.md`](../operations/sandbox-issue-processing-transcript-2026-06-14.md)
or a later dated transcript package. The Manager must treat missing discovery,
admission, dispatch readiness, Worker result evidence, Manager review,
closeout, approval-gate status, authority boundary, replay instructions,
cleanup receipt, private-memory exclusion, or residual risk as a core
orchestration readiness gap.

SRE operating evidence must follow
[`docs/operations/sre-operating-baseline.md`](../operations/sre-operating-baseline.md).
The Manager must treat missing dispatch SLO, recovery SLO, review-age SLO,
incident commander, communication, mitigation, postmortem, or resolved on-call
decision as an operations readiness gap.
Approved incident response drill and postmortem evidence must follow
[`docs/operations/incident-response-drill-postmortem-2026-06-14.md`](../operations/incident-response-drill-postmortem-2026-06-14.md)
or a later dated drill package. The Manager must treat missing detection input,
severity declaration, commander assignment, communication timeline, mitigation
decision, rollback or recovery decision, alert routing decision, validation
output, approval-gate status, cleanup receipt, postmortem evidence, residual
risk, or next action as an incident-response readiness gap.

Service-level objective evidence must follow
[`docs/operations/service-level-objectives.md`](../operations/service-level-objectives.md).
The Manager must treat missing SLO target, measurement source, fallback
evidence, error-budget policy, review cadence, owner action, availability
posture, external SLA approval boundary, residual risk, or next action as an
SLO/SLA readiness gap.

Central metrics backend designs must follow
[`docs/operations/central-metrics-backend.md`](../operations/central-metrics-backend.md).
The Manager must treat missing metric taxonomy, ingestion path, storage backend
assumptions, retention, label and cardinality controls, dashboard and alert
integration, SLO linkage, ownership, security boundary, rollout phases,
validation steps, failure handling, remaining operational gaps, or permission
level as an observability readiness gap.
Central metrics sandbox backend evidence must follow
[`docs/operations/central-metrics-sandbox-backend-2026-06-14.md`](../operations/central-metrics-sandbox-backend-2026-06-14.md)
or a later dated package. The Manager must treat missing approved local sandbox
backend selection, ingestion output, storage/query output, dashboard rows,
alert-rule evaluation, retention/cardinality checks, approval-gate status,
cleanup receipt, validation output, residual risk, or next action as an
observability readiness gap.

Observability metrics catalogs and alert-rule baselines must follow
[`docs/operations/observability-metrics-alert-rules.md`](../operations/observability-metrics-alert-rules.md).
The Manager must treat missing dispatch latency, queue depth, worker health,
retry, failure, credential denial, review age, audit export metric, alert
severity, operator action, trace correlation, redaction, retention, dashboard
panel, remaining operational gap, or permission level as an observability
readiness gap.

On-call paging and alerting baselines must follow
[`docs/operations/on-call-paging-alerting.md`](../operations/on-call-paging-alerting.md).
The Manager must treat missing alert taxonomy, severity mapping, escalation
roster shape, paging backend decision, quiet-hours behavior, notification routing,
test evidence shape, SLO linkage, metrics linkage, ownership, failure handling,
approval boundary, remaining operational gaps, or permission level as an
operations readiness gap.

Release rollback capacity evidence must follow
[`docs/operations/release-rollback-capacity-drills.md`](../operations/release-rollback-capacity-drills.md).
Local release rollback drill evidence must follow
[`docs/operations/release-rollback-drill-2026-06-13.md`](../operations/release-rollback-drill-2026-06-13.md)
or a later dated drill package.
The Manager must treat missing staged rollout, rollback trigger, operator,
evidence, communication, queue threshold, worker threshold, retry threshold,
review-age threshold, local validation path, drill evidence shape, or approval
boundary as an operations readiness gap.

Topology backup restore and disaster recovery evidence must follow
[`docs/operations/topology-backup-restore-dr.md`](../operations/topology-backup-restore-dr.md).
Credential-free sandbox restore drill evidence must follow
[`docs/operations/sandbox-restore-drill-2026-06-13.md`](../operations/sandbox-restore-drill-2026-06-13.md)
or a later dated drill package.
The Manager must treat missing environment tier, HA assumption, backup target,
restore step, RPO, RTO, measured RPO/RTO, DR role, evidence retention, drill
evidence shape, sandbox target, cleanup receipt, or approval boundary as an
infrastructure readiness gap.
Durable backup restore verification evidence must follow
[`docs/operations/durable-backup-restore-verification-2026-06-14.md`](../operations/durable-backup-restore-verification-2026-06-14.md)
or a later dated verification package. The Manager must treat missing project
exports, lease/retry state, route-result summaries, evidence packages,
executable restore verification, source/restored hash comparison, measured
RPO/RTO, retention policy checks, redaction checks, approval-gate status,
cleanup receipt, residual risk, or next action as an infrastructure readiness
gap.
Worker route health and bootstrap rebuild evidence must follow
[`docs/operations/worker-route-health-bootstrap-2026-06-14.md`](../operations/worker-route-health-bootstrap-2026-06-14.md)
or a later dated route-health package. The Manager must treat missing local,
SSH, Docker, or Kubernetes route capability detection, dispatch eligibility,
skip reasons, cleanup rules, approval-gate status, validation output, or named
bootstrap rebuild proof as an infrastructure readiness gap.

Compliance evidence packages must follow
[`docs/compliance/control-map-and-evidence-package.md`](../compliance/control-map-and-evidence-package.md).
The Manager must treat missing approval control, access control, change
management control, logging control, incident control, credential control,
retention, redaction, integrity, ownership, export design, package contents,
sample evidence chain, or approval boundary as a compliance readiness gap.
Compliance audit review packages must follow
[`docs/compliance/audit-review-2026-06-13.md`](../compliance/audit-review-2026-06-13.md).
The Manager must treat missing completed-change reference, reviewer, control
coverage, evidence links, exceptions, retention decision, redaction decision,
integrity check, approval-gate status, residual risk, or next action as a
compliance package readiness gap.
Immutable audit export designs must follow
[`docs/compliance/immutable-audit-export.md`](../compliance/immutable-audit-export.md).
The Manager must treat missing manifest hash, source links, redaction manifest,
retention metadata, ownership, verification steps, failure handling, approval
boundary, remaining operational gaps, or permission level as an immutable audit
export readiness gap.
Signed immutable audit export key-management evidence must follow
[`docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md`](../compliance/signed-immutable-audit-export-key-management-2026-06-13.md).
The Manager must treat missing signed manifest storage, signing-key ownership,
rotation cadence, revocation triggers, verification cadence, retention
enforcement, redaction review, owner review, signature verification, cleanup,
residual risk, or next action as an immutable audit export readiness gap.
Runtime quality gates must follow
[`docs/enterprise-readiness/runtime-quality-gate-matrix.md`](../enterprise-readiness/runtime-quality-gate-matrix.md).
Routine runtime quality gate exercise evidence must follow
[`docs/operations/runtime-quality-gate-exercise-2026-06-14.md`](../operations/runtime-quality-gate-exercise-2026-06-14.md)
or a later dated exercise package.
The Manager must treat missing orchestration, credential, GitHub adapter,
worker provider, or UI risk-surface coverage, missing required tests, missing
failure-injection checks, missing end-to-end issue processing, missing measured
soak evidence, missing release-candidate evidence, missing rollback evidence,
missing accepted risk, missing approval-gate status, missing cleanup receipt, or
missing next action as a development-quality readiness gap.

## Toolchain bootstrap contract

Manager adapters must follow
[`docs/operations/toolchain-bootstrap.md`](../operations/toolchain-bootstrap.md)
when installing or resetting local/remote Dokkaebi tools. The contract minimum
is:

- prefer user-local installs over system-wide or shared paths;
- run read-only preflight before changing any host;
- use scripted install steps when changes are approved;
- record installed versions, paths, command output, and validation evidence;
- include rollback notes in the result packet;
- treat remote hosts, Docker, `kubectl`, Kubernetes, and `dokkaebi-hammer`
  reset outside the approved target as blocked until Human approval exists.

## Adapter conformance

Each Manager adapter must publish a conformance note that maps these contract
capabilities to concrete behavior:

| Capability | Evidence required |
| --- | --- |
| Human intake and clarification | Request notes, scope, non-goals, and stop condition. |
| Ticket drafting | Worker ticket with acceptance criteria, permission level, and validation plan. |
| Approval enforcement | Approval evidence or explicit blocked reason. |
| Fire/Symphony handoff | Project item/status/label/workpad linkage. |
| Hammer result review | Result packet review with validation evidence and residual risks. |
| Resume portability | Request, ticket, approvals, result packet, PR/logs, and next decision links. |

Hermes baseline conformance is documented in
[`docs/adapters/hermes.md`](../adapters/hermes.md).

### Adapter conformance proof

A new Manager adapter proves conformance by publishing an adapter note like
[`docs/adapters/hermes.md`](../adapters/hermes.md) and by producing replayable
evidence for the contract surfaces it claims to support. The proof must include:

1. A Worker ticket generated from
   [`docs/templates/worker-ticket.md`](../templates/worker-ticket.md).
2. One accepted result packet equivalent to
   [`docs/examples/result-packets/accepted.md`](../examples/result-packets/accepted.md).
3. Rejected result-packet evidence equivalent to the missing acceptance,
   validation, scope-control, and approval-gate examples under
   [`docs/examples/result-packets/`](../examples/result-packets/).
4. Validator output showing accepted packets pass and rejected packets fail for
   the intended reason.
5. A Manager review summary that links request, ticket, approval state, Worker
   result, validation evidence, residual risk, and next decision.
6. A Manager-Fire-Hammer replay suite equivalent to
   [`docs/examples/replays/accepted-manager-fire-hammer.md`](../examples/replays/accepted-manager-fire-hammer.md)
   and the rejected replay fixtures under
   [`docs/examples/replays/`](../examples/replays/). The suite must prove
   dispatch readiness, approval evidence, Worker route metadata, result
   evidence, and Manager closeout evidence are accepted or rejected
   deterministically.

Hidden adapter memory is not conformance evidence. Another Manager adapter must
be able to inspect the artifacts and reach the same accept or reject decision.

## Result packet minimum

A Worker result packet must include:

- task identifier and source ticket;
- summary of completed work;
- changed files, branch, commits, or PR links;
- validation commands and outcomes;
- acceptance-criteria evidence and whether acceptance criteria were met;
- blockers or missing permissions;
- residual risks;
- scope-control statement and approval-gate status;
- recommended next action for the Manager/Human.

The normative template is
[`docs/templates/worker-result-packet.md`](../templates/worker-result-packet.md).
