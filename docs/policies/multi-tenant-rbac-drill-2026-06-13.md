# Multi-Tenant RBAC Replay Drill

This document records a docs-only local replay of the multi-tenant RBAC model in
[`multi-tenant-rbac.md`](multi-tenant-rbac.md). It does not create tenants,
change GitHub organization membership, mutate GitHub Project schemas, grant
credentials, launch workers, touch remote hosts, run Docker or Kubernetes,
deploy services, or write production data.

The replay exercises representative project owner, tenant admin, issue
approver, Fire operator, Hammer operator, security admin, auditor, and
break-glass flows. It captures admission decision output, authorization decision
output, denied cross-tenant operation evidence, credential grant boundary
evidence, worker route boundary evidence, audit log evidence, access-review
evidence, approval-gate status, cleanup, residual risk, and next action.

Required exact terms: local replay; admission decision output; authorization
decision output; denied cross-tenant operation evidence; credential grant
boundary evidence; worker route boundary evidence; audit log evidence;
access-review evidence; approval-gate status; cleanup; residual risk; next
action; does not authorize.

## Replay Summary

The replay uses two fictional tenant scopes, `tenant-alpha` and `tenant-beta`.
The allowed repository for `tenant-alpha` is `TwoTwo-me/project-alpha`, and the
allowed repository for `tenant-beta` is `TwoTwo-me/project-beta`. No live API
write, credential grant, worker dispatch, remote command, container operation,
cluster operation, deployment, or GitHub Project control-plane mutation was
performed.

## Validation

Run:

```bash
bash scripts/validate-multi-tenant-rbac-drill.sh
```

The validator accepts this complete replay package and rejects empty content,
malformed replay data, missing actor flows, missing admission decision output,
missing authorization decision output, missing denied cross-tenant operation
evidence, missing credential grant boundary evidence, missing worker route
boundary evidence, missing audit log evidence, missing access-review evidence,
missing approval-gate status, missing cleanup, missing residual risk, missing
next action, wildcard grants, private local paths, secret-bearing wording, and
unauthorized credential, production, infrastructure, worker, remote host, Docker,
Kubernetes, deployment, or GitHub Project control-plane mutation wording.

<!-- multi-tenant-rbac-drill:begin -->
```json
{
  "version": 1,
  "drillId": "rbac-local-replay-2026-06-13",
  "date": "2026-06-13",
  "permissionLevel": "docs-only-local-replay",
  "sourcePolicy": "docs/policies/multi-tenant-rbac.md",
  "tenantScopes": [
    {
      "tenantId": "tenant-alpha",
      "repositories": [
        "TwoTwo-me/project-alpha"
      ],
      "githubProjects": [
        "project-alpha-board"
      ],
      "allowedWorkerRoutes": [
        "local_worktree"
      ]
    },
    {
      "tenantId": "tenant-beta",
      "repositories": [
        "TwoTwo-me/project-beta"
      ],
      "githubProjects": [
        "project-beta-board"
      ],
      "allowedWorkerRoutes": [
        "local_worktree"
      ]
    }
  ],
  "actorFlowResults": [
    {
      "actorRole": "project_owner",
      "tenant": "tenant-alpha",
      "requestedPermission": "admit_issue_for_dispatch",
      "admissionDecision": "allow: tenant, project, repository, status, acceptance criteria, permission level, and approval evidence are present",
      "authorizationDecision": "allow: project owner may admit tenant-scoped issue for dispatch",
      "auditEvidenceId": "audit-rbac-001"
    },
    {
      "actorRole": "tenant_admin",
      "tenant": "tenant-alpha",
      "requestedPermission": "manage_tenant_membership",
      "admissionDecision": "allow: tenant assignment and repository scope match tenant-alpha",
      "authorizationDecision": "allow: tenant admin may update tenant-scoped membership proposal",
      "auditEvidenceId": "audit-rbac-002"
    },
    {
      "actorRole": "issue_approver",
      "tenant": "tenant-alpha",
      "requestedPermission": "approve_sensitive_gate",
      "admissionDecision": "allow: issue scope, acceptance criteria, and result evidence are complete",
      "authorizationDecision": "allow: issue approver may approve sensitive gate but not dispatch own work",
      "auditEvidenceId": "audit-rbac-003"
    },
    {
      "actorRole": "fire_operator",
      "tenant": "tenant-alpha",
      "requestedPermission": "dispatch_admitted_ticket",
      "admissionDecision": "allow: dispatchable status and tenant-scoped worker route are present",
      "authorizationDecision": "allow: Fire operator may dispatch admitted tenant-alpha ticket",
      "auditEvidenceId": "audit-rbac-004"
    },
    {
      "actorRole": "hammer_operator",
      "tenant": "tenant-alpha",
      "requestedPermission": "execute_worker_route",
      "admissionDecision": "allow: local_worktree route is tenant-scoped and no credential grant is requested",
      "authorizationDecision": "allow: Hammer operator may execute assigned local_worktree route only",
      "auditEvidenceId": "audit-rbac-005"
    },
    {
      "actorRole": "security_admin",
      "tenant": "tenant-alpha",
      "requestedPermission": "approve_credential_grant",
      "admissionDecision": "deny: replay request has no explicit credential approval record",
      "authorizationDecision": "deny: security admin review evidence exists, but no grant is issued in docs-only-local-replay",
      "auditEvidenceId": "audit-rbac-006"
    },
    {
      "actorRole": "auditor",
      "tenant": "tenant-alpha",
      "requestedPermission": "review_audit_package",
      "admissionDecision": "allow: audit package contains tenant, actor role, requested permission, decisions, approval-gate status, and residual risk",
      "authorizationDecision": "allow: auditor may review evidence without runtime mutation",
      "auditEvidenceId": "audit-rbac-007"
    },
    {
      "actorRole": "break_glass_operator",
      "tenant": "tenant-alpha",
      "requestedPermission": "execute_emergency_action_with_explicit_approval",
      "admissionDecision": "deny: no incident id, expiration, or Human approver was supplied",
      "authorizationDecision": "deny: break-glass cannot create standing access and remains blocked",
      "auditEvidenceId": "audit-rbac-008"
    }
  ],
  "admissionDecisionOutput": [
    "allow tenant-alpha project_owner admit_issue_for_dispatch when tenant, project, repository, status, acceptance criteria, permission level, and approval evidence are present",
    "allow tenant-alpha fire_operator dispatch_admitted_ticket when the ticket is dispatchable and the worker route is tenant-scoped",
    "deny tenant-alpha security_admin approve_credential_grant because the replay has no explicit credential approval record",
    "deny tenant-alpha break_glass_operator execute_emergency_action_with_explicit_approval because incident id, expiration, and Human approver are absent"
  ],
  "authorizationDecisionOutput": [
    "allow role project_owner permission admit_issue_for_dispatch inside tenant-alpha project scope",
    "allow role hammer_operator permission execute_worker_route on tenant-alpha worker route local_worktree only",
    "deny role tenant_admin permission cross-tenant repository access into tenant-beta",
    "deny role security_admin permission credential grant issuance because no live worker route or credential grant is authorized"
  ],
  "deniedCrossTenantOperationEvidence": {
    "sourceTenant": "tenant-alpha",
    "targetTenant": "tenant-beta",
    "requestedRepository": "TwoTwo-me/project-beta",
    "requestedPermission": "read_audit_evidence",
    "decision": "deny",
    "reason": "tenant-alpha actor lacks documented cross-tenant approval naming tenant-beta, repository scope, expiration, and closeout evidence"
  },
  "credentialGrantBoundaryEvidence": {
    "grantRequest": "simulated tenant-alpha contents:read request",
    "decision": "deny",
    "reason": "docs-only-local-replay does not issue credential material",
    "requiredShape": "brokered, task-scoped, tenant-scoped, time-bound, least-privilege, expiration, revocation, approval evidence",
    "secretMaterialIncluded": false
  },
  "workerRouteBoundaryEvidence": {
    "local_worktree": "allow only for assigned tenant-alpha repository and worktree",
    "ssh": "deny because no approved target, tenant, and command boundary was supplied",
    "docker": "deny because no approved disposable target and image boundary was supplied",
    "kubernetes_job": "deny because no approved cluster, namespace, service account, and cleanup boundary was supplied",
    "routeExpansion": "deny without a new approval record and result evidence"
  },
  "auditLogEvidence": [
    {
      "id": "audit-rbac-001",
      "tenant": "tenant-alpha",
      "actorRole": "project_owner",
      "requestedPermission": "admit_issue_for_dispatch",
      "admissionDecision": "allow",
      "authorizationDecision": "allow",
      "approvalGateStatus": "no live approval-gated mutation reached",
      "credentialBroker": "none",
      "workerRoute": "none",
      "residualRisk": "runtime enforcement not yet implemented"
    },
    {
      "id": "audit-rbac-002",
      "tenant": "tenant-alpha",
      "actorRole": "tenant_admin",
      "requestedPermission": "manage_tenant_membership",
      "admissionDecision": "allow",
      "authorizationDecision": "allow tenant-scoped membership proposal",
      "approvalGateStatus": "no live approval-gated mutation reached",
      "credentialBroker": "none",
      "workerRoute": "none",
      "residualRisk": "runtime tenant membership enforcement not yet implemented"
    },
    {
      "id": "audit-rbac-003",
      "tenant": "tenant-alpha",
      "actorRole": "issue_approver",
      "requestedPermission": "approve_sensitive_gate",
      "admissionDecision": "allow",
      "authorizationDecision": "allow sensitive-gate approval record only",
      "approvalGateStatus": "no live approval-gated mutation reached",
      "credentialBroker": "none",
      "workerRoute": "none",
      "residualRisk": "runtime approval-gate enforcement not yet implemented"
    },
    {
      "id": "audit-rbac-004",
      "tenant": "tenant-alpha",
      "actorRole": "fire_operator",
      "requestedPermission": "dispatch_admitted_ticket",
      "admissionDecision": "allow",
      "authorizationDecision": "allow admitted tenant-alpha dispatch only",
      "approvalGateStatus": "no live approval-gated mutation reached",
      "credentialBroker": "none",
      "workerRoute": "local_worktree",
      "residualRisk": "runtime dispatch enforcement not yet implemented"
    },
    {
      "id": "audit-rbac-005",
      "tenant": "tenant-alpha",
      "actorRole": "hammer_operator",
      "requestedPermission": "execute_worker_route",
      "admissionDecision": "allow",
      "authorizationDecision": "allow local_worktree only",
      "approvalGateStatus": "no live approval-gated mutation reached",
      "credentialBroker": "none",
      "workerRoute": "local_worktree",
      "residualRisk": "runtime route enforcement not yet implemented"
    },
    {
      "id": "audit-rbac-006",
      "tenant": "tenant-alpha",
      "actorRole": "security_admin",
      "requestedPermission": "approve_credential_grant",
      "admissionDecision": "deny",
      "authorizationDecision": "deny credential grant issuance",
      "approvalGateStatus": "no live approval-gated mutation reached",
      "credentialBroker": "none",
      "workerRoute": "none",
      "residualRisk": "runtime credential denial evidence not yet captured"
    },
    {
      "id": "audit-rbac-007",
      "tenant": "tenant-alpha",
      "actorRole": "auditor",
      "requestedPermission": "review_audit_package",
      "admissionDecision": "allow",
      "authorizationDecision": "allow evidence review without mutation",
      "approvalGateStatus": "no live approval-gated mutation reached",
      "credentialBroker": "none",
      "workerRoute": "none",
      "residualRisk": "runtime audit export linkage not yet implemented"
    },
    {
      "id": "audit-rbac-008",
      "tenant": "tenant-alpha",
      "actorRole": "break_glass_operator",
      "requestedPermission": "execute_emergency_action_with_explicit_approval",
      "admissionDecision": "deny",
      "authorizationDecision": "deny break-glass without incident approval",
      "approvalGateStatus": "no live approval-gated mutation reached",
      "credentialBroker": "none",
      "workerRoute": "none",
      "residualRisk": "runtime break-glass enforcement not yet implemented"
    },
    {
      "id": "audit-rbac-deny-cross-tenant",
      "tenant": "tenant-alpha",
      "actorRole": "tenant_admin",
      "requestedPermission": "read_audit_evidence",
      "admissionDecision": "deny",
      "authorizationDecision": "deny cross-tenant repository access",
      "approvalGateStatus": "no live approval-gated mutation reached",
      "credentialBroker": "none",
      "workerRoute": "none",
      "residualRisk": "runtime cross-tenant enforcement remains follow-up"
    }
  ],
  "accessReviewEvidence": {
    "reviewId": "access-review-tenant-alpha-2026-q2",
    "tenant": "tenant-alpha",
    "reviewer": "auditor",
    "cadence": "quarterly",
    "roleAssignments": [
      "project_owner",
      "tenant_admin",
      "issue_approver",
      "fire_operator",
      "hammer_operator",
      "security_admin",
      "auditor",
      "break_glass_operator"
    ],
    "highRiskGrants": [
      "high-risk break_glass_operator blocked without incident approval"
    ],
    "credentialGrants": [
      "none issued in replay"
    ],
    "workerRouteGrants": [
      "worker route local_worktree tenant-alpha only"
    ],
    "revokedMembers": [
      "stale external reviewer removed from replay roster"
    ],
    "decision": "approve model evidence for local replay only",
    "nextAction": "next action: implement runtime multi-tenant RBAC enforcement gates in issue #74"
  },
  "approvalGateStatus": "No live approval-gated mutation reached; credential, production, infrastructure, worker, remote host, Docker, Kubernetes, deployment, and GitHub Project control-plane mutation remain not authorized.",
  "cleanup": {
    "status": "complete",
    "receipt": "No tenants, credentials, workers, remote hosts, containers, clusters, deployments, or GitHub Project settings were created or changed."
  },
  "residualRisk": [
    "Runtime admission and authorization enforcement are not implemented.",
    "GitHub Project tenant field export and reconciliation are not captured.",
    "Credential broker and worker route checks are replayed, not enforced live.",
    "Access-review output is documented but not generated from runtime state."
  ],
  "nextAction": "Implement runtime multi-tenant RBAC enforcement gates in issue #74.",
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/74"
}
```
<!-- multi-tenant-rbac-drill:end -->
