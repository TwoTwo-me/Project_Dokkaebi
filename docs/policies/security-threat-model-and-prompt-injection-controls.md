# Security Threat Model And Prompt-Injection Controls

This docs-only baseline defines Project Dokkaebi's enterprise security threat
model for Manager, Fire, Hammer, GitHub Project, credential broker, worker route,
and Human approval surfaces. It covers threat actors, trust boundaries, assets,
abuse cases, prompt-injection paths, data exfiltration paths,
credential-broker misuse paths, worker-route escalation paths, GitHub Project
control-plane risks, mitigations, detection evidence, fail-closed behavior,
owner review cadence, residual risk, and next action for issue #94.
The required coverage includes GitHub Project control-plane risks as an explicit
review class.

This baseline does not authorize runtime, worker, credential, infrastructure,
Docker, Kubernetes, remote host, deployment, production, or GitHub Project
control-plane mutation.

## Control Summary

| Surface | Primary threat | Required fail-closed behavior |
| --- | --- | --- |
| Manager prompt intake | Prompt-injection or hidden instruction override | Block dispatch until source intent, authority, and validation are explicit |
| GitHub Project control plane | Unauthorized project field/schema mutation | Require setup approval and GraphQL state confirmation |
| Credential broker | Broad or unscoped grant request | Deny grants without owner, scope, expiry, and audit evidence |
| Worker route | Route escalation or wrong provider selection | Deny dispatch when route capability or isolation evidence is missing |
| Data and evidence | Secret or private-state exfiltration | Redact and fail review when result packets contain unsafe evidence |
| Human approval | Spoofed or stale approval claim | Require recorded approver, scope, expiry, and revocation condition |
| Fire dispatch | Status/admission confusion | Confirm Project state and admission fields before dispatch |
| Result packet | Tampered validation or missing closeout evidence | Reject result packet and request fix evidence |

Expected targeted validation output:

```text
PASS Dokkaebi security threat model validation passed
```

## Residual Risk And Next Action

This baseline documents controls and deterministic validation. Runtime
multi-tenant RBAC enforcement, generated access-review output, credential grant
checks, and worker-route gates are captured in
[`runtime-multi-tenant-rbac-2026-06-14.md`](runtime-multi-tenant-rbac-2026-06-14.md).
Live identity-provider rollout, live credential backend issuance, and live
worker-fleet enforcement remain approval-gated.

<!-- security-threat-model:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only security threat model and prompt-injection controls",
  "approvalBoundary": "This baseline does not authorize runtime, worker, credential, infrastructure, Docker, Kubernetes, remote host, deployment, production, or GitHub Project control-plane mutation without explicit Human approval",
  "threatActors": [
    "untrusted requester",
    "compromised worker",
    "over-privileged operator",
    "stale automation",
    "malicious repository content"
  ],
  "trustBoundaries": [
    "Human to Manager request",
    "Manager to Fire ticket",
    "Fire to Hammer worker route",
    "Worker to credential broker",
    "Manager or Fire to GitHub Project",
    "Worker result packet to Manager review"
  ],
  "assets": [
    "GitHub Project lifecycle state",
    "approval evidence",
    "credential broker grants",
    "worker route isolation",
    "repository and PR history",
    "audit evidence packages"
  ],
  "surfaces": [
    {
      "id": "manager_prompt_injection",
      "threatActor": "untrusted requester or malicious repository content",
      "trustBoundary": "Human to Manager request",
      "asset": "source intent and approval boundary",
      "abuseCase": "hidden instruction attempts to override approval or validation requirements",
      "promptInjectionPath": "request prose, issue body, PR comment, repository file, or result packet text",
      "dataExfiltrationPath": "prompt asks Manager or worker to reveal credentials, private paths, or hidden memory",
      "credentialBrokerMisusePath": "prompt asks for broad grants without owner, scope, expiry, or ticket binding",
      "workerRouteEscalationPath": "prompt asks to route work to a more privileged provider than the ticket allows",
      "githubProjectControlPlaneRisk": "prompt asks to mutate project schema or statuses without setup approval",
      "mitigations": [
        "preserve source request separately from derived instructions",
        "require fail-closed preflight",
        "require explicit approval evidence for gated actions"
      ],
      "detectionEvidence": [
        "blocked dispatch reason",
        "approval-gate status",
        "result-packet rejection evidence"
      ],
      "failClosedBehavior": "block dispatch until source intent, authority, and validation are explicit",
      "ownerReviewCadence": "security owner reviews quarterly and after high-risk prompt failures",
      "residualRisk": "novel prompt-injection patterns may require additional fixtures",
      "nextAction": "add runtime prompt-injection fixtures when worker dispatch tests are extended"
    },
    {
      "id": "github_project_control_plane",
      "threatActor": "over-privileged operator or stale automation",
      "trustBoundary": "Manager or Fire to GitHub Project",
      "asset": "GitHub Project lifecycle and admission fields",
      "abuseCase": "unauthorized field creation, deletion, archive, schema mutation, or cross-project migration",
      "promptInjectionPath": "issue or workpad request claims setup approval without evidence",
      "dataExfiltrationPath": "project metadata is copied into public evidence without redaction review",
      "credentialBrokerMisusePath": "project mutation credential is requested for unrelated repository scope",
      "workerRouteEscalationPath": "worker route is asked to perform control-plane mutation instead of mapped item status update",
      "githubProjectControlPlaneRisk": "schema mutation bypasses GitHub Project Status as lifecycle source of truth",
      "mitigations": [
        "separate routine item field updates from control-plane mutations",
        "require setup approval for project schema changes",
        "confirm current project state through GraphQL before dispatch or closeout"
      ],
      "detectionEvidence": [
        "GraphQL state confirmation",
        "setup approval record",
        "blocked control-plane mutation reason"
      ],
      "failClosedBehavior": "deny control-plane mutation without setup approval and current state confirmation",
      "ownerReviewCadence": "project owner reviews field schema changes before rollout and quarterly",
      "residualRisk": "live project webhook semantics remain subject to GitHub preview behavior",
      "nextAction": "keep ProjectV2 control-plane mutation approval-gated; routine runtime admission is covered by runtime-multi-tenant-rbac-2026-06-14.md"
    },
    {
      "id": "credential_broker_misuse",
      "threatActor": "compromised worker or untrusted requester",
      "trustBoundary": "Worker to credential broker",
      "asset": "task-scoped credential grants",
      "abuseCase": "worker asks for broad raw credentials or grant scope outside the ticket",
      "promptInjectionPath": "task text asks worker to ignore broker boundaries",
      "dataExfiltrationPath": "worker result attempts to include secret material or private machine state",
      "credentialBrokerMisusePath": "grant request lacks owner, scope, expiry, branch/environment binding, or audit evidence",
      "workerRouteEscalationPath": "worker asks another route to reuse a grant",
      "githubProjectControlPlaneRisk": "project mutation grant is requested without mapped item authorization",
      "mitigations": [
        "deny raw credential exchange",
        "issue only task-scoped grants",
        "record grant metadata without secret material"
      ],
      "detectionEvidence": [
        "broker denial output",
        "grant metadata audit record",
        "cleanup receipt"
      ],
      "failClosedBehavior": "deny grants without owner, scope, expiry, and audit evidence",
      "ownerReviewCadence": "security owner reviews broker denials monthly and after incidents",
      "residualRisk": "live credential backend rollout remains approval-gated after local runtime gate proof",
      "nextAction": "use runtime-multi-tenant-rbac-2026-06-14.md as the local gate baseline before any approved live credential backend rollout"
    },
    {
      "id": "worker_route_escalation",
      "threatActor": "compromised worker or stale automation",
      "trustBoundary": "Fire to Hammer worker route",
      "asset": "worker route capability and isolation",
      "abuseCase": "ticket is routed to SSH, Docker, or Kubernetes provider without matching capability and approval",
      "promptInjectionPath": "ticket content asks Fire to bypass route constraints",
      "dataExfiltrationPath": "worker returns host paths, logs, or secret-bearing output",
      "credentialBrokerMisusePath": "worker route requests a grant for a different route or provider",
      "workerRouteEscalationPath": "low-privilege route attempts remote host, Docker, Kubernetes, or production action",
      "githubProjectControlPlaneRisk": "worker route writes project state without Manager review",
      "mitigations": [
        "match worker capability and isolation before dispatch",
        "require approval for remote, Docker, Kubernetes, or production routes",
        "require result packet with scope-control statement"
      ],
      "detectionEvidence": [
        "route selection reason",
        "blocked route reason",
        "result packet scope-control evidence"
      ],
      "failClosedBehavior": "deny dispatch when route capability or isolation evidence is missing",
      "ownerReviewCadence": "Fire operator reviews route capability inventory monthly",
      "residualRisk": "live remote, Docker, and Kubernetes route enforcement remains approval-gated after local runtime gate proof",
      "nextAction": "use runtime-multi-tenant-rbac-2026-06-14.md as the local gate baseline before any approved live worker fleet rollout"
    },
    {
      "id": "evidence_exfiltration",
      "threatActor": "malicious repository content or compromised worker",
      "trustBoundary": "Worker result packet to Manager review",
      "asset": "audit evidence packages and private operational state",
      "abuseCase": "result packet includes credentials, private paths, hidden memory, or unredacted logs",
      "promptInjectionPath": "test output or file content asks reviewer to paste secrets",
      "dataExfiltrationPath": "result packet, PR body, issue comment, or audit export includes unsafe evidence",
      "credentialBrokerMisusePath": "secret material is embedded instead of broker metadata",
      "workerRouteEscalationPath": "worker claims cleanup but leaves route artifacts with sensitive output",
      "githubProjectControlPlaneRisk": "unsafe evidence is attached to public project item comments",
      "mitigations": [
        "validate result packet evidence shape",
        "scan public metadata for private paths and internal labels",
        "require redaction and cleanup receipts"
      ],
      "detectionEvidence": [
        "metadata hygiene scan",
        "redaction review",
        "result-packet rejection reason"
      ],
      "failClosedBehavior": "reject evidence and request fix when unsafe output is present",
      "ownerReviewCadence": "auditor reviews evidence packages quarterly",
      "residualRisk": "new secret formats may require additional scanner fixtures",
      "nextAction": "extend evidence scanners as new secret classes are introduced"
    },
    {
      "id": "human_approval_spoofing",
      "threatActor": "untrusted requester or stale automation",
      "trustBoundary": "Human to Manager request",
      "asset": "approval evidence and gated action authority",
      "abuseCase": "issue text claims approval without recorded approver, scope, expiry, or revocation condition",
      "promptInjectionPath": "request says approval is implied by tool availability",
      "dataExfiltrationPath": "approval evidence references private memory instead of durable record",
      "credentialBrokerMisusePath": "grant is requested from alleged approval without audit record",
      "workerRouteEscalationPath": "worker route is escalated from an unverified approval claim",
      "githubProjectControlPlaneRisk": "control-plane change is justified by stale approval",
      "mitigations": [
        "record approver identity or decision source",
        "require explicit non-approved adjacent actions",
        "require expiry or revocation condition"
      ],
      "detectionEvidence": [
        "approval evidence record",
        "blocked preflight reason",
        "Manager review summary"
      ],
      "failClosedBehavior": "block gated action when approval evidence is missing or stale",
      "ownerReviewCadence": "approver reviews stale approval queues weekly",
      "residualRisk": "external approval systems require later integration evidence",
      "nextAction": "keep approval evidence linked to runtime admission gates and review stale approvals during access review"
    }
  ],
  "validationOutput": [
    "PASS Dokkaebi security threat model validation passed",
    "PASS Dokkaebi enterprise readiness criteria are present and structurally valid",
    "PASS Dokkaebi contract docs are present, linked, and structurally aligned"
  ],
  "residualRisk": [
    "live identity-provider rollout remains approval-gated",
    "live credential backend issuance remains approval-gated",
    "live remote, Docker, and Kubernetes worker-route enforcement remains approval-gated"
  ],
  "nextAction": "Continue approved local runtime gate validation through runtime-multi-tenant-rbac-2026-06-14.md and require separate approval for live rollout.",
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/74"
}
```
<!-- security-threat-model:end -->
