# Multi-Tenant RBAC Model

This document defines the docs-only multi-tenant RBAC model for Project
Dokkaebi. It does not create tenants, change GitHub organization membership,
provision identity providers, mutate GitHub Project schemas, grant credentials,
launch workers, touch remote hosts, run Docker or Kubernetes, deploy services,
or write production data.

The goal is to make tenant isolation, role separation, admission decisions,
authorization decisions, credential boundaries, worker route boundaries, access
review, and audit evidence reviewable before runtime enforcement work starts.
A later enforcement and access-review drill must prove the model with local
replay, approved sandbox validation, or runtime policy tests before this
capability can be treated as operational.

The validation contract for this docs-only baseline explicitly covers tenant
boundaries, role taxonomy, permission matrix, admission checks, authorization
checks, GitHub Project scope mapping, repository scope mapping, credential
boundary, worker route boundary, break-glass path, access review, audit
evidence, onboarding and offboarding, failure handling, remaining operational
gaps, permission level, and control-plane authority boundaries.

Required exact terms: tenant boundaries; role taxonomy; permission matrix; admission checks; authorization checks; GitHub Project scope mapping; repository scope mapping; credential boundary; worker route boundary; break-glass path; access review; audit evidence; onboarding and offboarding; failure handling; remaining operational gaps; permission level; docs-only; control-plane.

## Enterprise Standard

A multi-tenant Dokkaebi deployment must:

- bind every project item, repository, worker route, credential grant, and audit
  package to one explicit tenant scope;
- separate project ownership, tenant administration, issue approval, Fire
  operation, Hammer operation, security administration, auditing, and break-glass
  authority;
- deny cross-tenant reads or writes unless a documented role and approval record
  grants that exact scope;
- use GitHub Project state as lifecycle source of truth while treating workpad
  comments, labels, PRs, logs, and result packets as evidence surfaces;
- keep broad credentials, production writes, infrastructure mutation, worker
  privilege expansion, remote host mutation, Docker, Kubernetes, deployment, and
  GitHub Project control-plane changes outside the docs-only baseline.

## Tenant Boundaries

Each tenant is a bounded operating unit with:

- tenant id and display name;
- owning organization or team;
- allowed GitHub Projects;
- allowed repositories;
- allowed environments;
- credential broker scope;
- worker route allowlist;
- evidence retention owner;
- audit reviewer.

Tenant identity must not be inferred only from free-form issue text. A ticket is
dispatchable only when the tenant can be resolved from an approved project,
repository, project item field, or issue intake field.

Cross-tenant work requires a written approval record naming both tenants, the
reason, the permitted actor, the allowed repositories/projects, the expiration,
and the closeout evidence expected.

## Role Taxonomy

Required roles:

| Role | Purpose | Must not do by default |
| --- | --- | --- |
| Project owner | Owns project lifecycle fields, admission rules, and closeout policy | Run workers or approve credentials alone |
| Tenant admin | Manages tenant membership and tenant-scoped configuration | Override security or audit review |
| Issue approver | Approves issue scope, acceptance criteria, and sensitive gates | Dispatch their own unreviewed sensitive work |
| Fire operator | Operates dispatch and recovery inside admitted scope | Change tenant policy or broaden worker authority |
| Hammer operator | Runs bounded worker routes and records result packets | Self-approve scope, tenant, or credential expansion |
| Security admin | Reviews credential, break-glass, and high-risk authority | Merge or close work without result evidence |
| Auditor | Reviews evidence, retention, and control coverage | Mutate runtime state or grant credentials |
| Break-glass operator | Executes emergency action under explicit approval | Create standing access or skip post-incident review |

One person may hold multiple roles only when the issue records the separation
risk and the Human accepts it for the named scope.

## Permission Matrix

Minimum permissions:

| Permission | Project owner | Tenant admin | Issue approver | Fire operator | Hammer operator | Security admin | Auditor | Break-glass operator |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Configure project policy proposal | yes | tenant-scoped | no | no | no | review | read | no |
| Admit issue for dispatch | yes | tenant-scoped | yes | verify | no | review gated | read | emergency only |
| Approve sensitive gate | no | no | yes | no | no | yes for security gates | read | emergency only |
| Dispatch admitted ticket | no | no | no | yes | no | no | read | emergency only |
| Execute worker route | no | no | no | no | yes | no | read | emergency only |
| Grant credential bundle | no | no | no | no | no | approve/revoke | read | emergency only |
| Merge PR | Human approval gate | Human approval gate | Human approval gate | no | no | review only | read | emergency only |
| Review audit package | read | read | read | read | result evidence | review | yes | post-incident |

No role receives wildcard authority. Every permission is constrained by tenant,
repository, project, environment, branch, worker route, credential scope, and
expiration where applicable.

## Admission Checks

Before a ticket is dispatchable, the Manager and Fire must verify:

1. tenant id is present and maps to the project/repository;
2. project item lifecycle status is dispatchable;
3. admission or authorization fields are present when the project uses them;
4. requested role is permitted to request the action;
5. acceptance criteria, validation, permission level, and result evidence are
   present;
6. sensitive gates have explicit approval evidence;
7. repository and branch are inside tenant scope;
8. worker route is allowed for the tenant;
9. credential request, if any, is brokered and tenant-scoped;
10. cross-tenant access is either absent or explicitly approved.

Missing or ambiguous admission evidence fails closed.

## Authorization Checks

Every action must be authorized against:

- tenant scope;
- GitHub Project scope;
- repository scope;
- branch or environment scope;
- actor role;
- permission matrix;
- approval-gate status;
- credential broker grant;
- worker route allowlist;
- result-packet and audit evidence expectations.

Authorization denial must record the denied actor role, requested permission,
tenant, repository/project, reason, and next action without leaking secrets or
private machine state.

## GitHub Project Scope Mapping

The GitHub Project scope mapping must identify:

- project id or stable project slug;
- tenant field or tenant derivation rule;
- status field and dispatchable values;
- admission field names, if used;
- authorized-by or approval evidence field, if used;
- agent/route field, if used;
- fallback labels and workpad conventions;
- cross-project movement policy.

GitHub Project field creation, deletion, workflow mutation, project migration,
auto-add workflow changes, and broad backfills remain control-plane writes and
require explicit Human approval under
[`authority-and-safety.md`](authority-and-safety.md).

## Repository Scope Mapping

The repository scope mapping must identify:

- allowed owner/name pairs for each tenant;
- protected branches and branch class;
- required PR checks;
- submodule ownership boundaries;
- deployment environments;
- repository-level secrets or credential broker bindings;
- evidence retention surface.

Repository access must not be inferred from the ability to clone a repository or
from a worker's local filesystem access.

## Credential Boundary

Credential grants remain brokered, task-scoped, tenant-scoped, time-bound, and
least-privilege. The Manager must not pass broad PATs, OAuth tokens, SSH keys,
cloud credentials, kubeconfig files, Proxmox credentials, or GitHub App private
keys through ticket prose, prompts, logs, or result summaries.

A credential request must include tenant, repository/service allowlist, actor
role, permission, branch/environment, expiration, revocation condition, and
approval evidence.

## Worker Route Boundary

Worker routes are tenant-scoped:

- `local_worktree` routes are limited to the assigned repository/worktree;
- `ssh` routes require approved target, tenant, and command boundary;
- `docker` routes require approved disposable target and image boundary;
- `kubernetes_job` routes require approved cluster, namespace, service account,
  and cleanup boundary;
- route expansion requires a new approval record and result evidence.

Hammer Workers must not self-approve tenant expansion, credential expansion,
route expansion, merge, deploy, production write, infrastructure mutation, or
control-plane changes.

## Break-Glass Path

Break-glass is emergency-only and must record:

- incident id;
- Human approver;
- permitted actor;
- affected tenant, repository, project, environment, and credential scope;
- allowed action and explicitly non-approved adjacent actions;
- expiration;
- communication channel;
- rollback or revocation expectation;
- post-incident review owner;
- audit package link.

Break-glass access is not standing access.

## Access Review

Access review must run at least quarterly for each tenant and immediately after
break-glass use, tenant offboarding, credential incident, or role conflict.

Review evidence must include tenant, role assignments, high-risk grants,
credential grants, worker route grants, stale members, revoked members,
exceptions, reviewer, decision, and next action.

## Audit Evidence

RBAC result evidence must include:

- tenant id and scope source;
- actor role;
- requested permission;
- admission decision;
- authorization decision;
- approval-gate status;
- credential broker grant id or "none";
- worker route decision;
- audit reviewer;
- residual risk and next action.

Secret values, raw credential material, private home-directory paths, and raw
worker command text must not be stored in audit evidence.

## Onboarding And Offboarding

Onboarding requires tenant assignment, role assignment, repository/project scope,
training acknowledgement, credential policy acknowledgement, and initial access
review date.

Offboarding requires role removal, credential revocation, worker route grant
removal, project/repository access removal, audit note, and follow-up review.

## Failure Handling

RBAC evidence fails closed when tenant mapping is missing, role mapping is
missing, permission mapping is missing, admission evidence is missing,
authorization evidence is missing, credential boundary is missing, worker route
boundary is missing, break-glass evidence is missing, access review is missing,
or the design claims sensitive operational authority that was not explicitly
approved.

## Validation

Run:

```bash
bash scripts/validate-multi-tenant-rbac.sh
```

The validator rejects empty design content, malformed RBAC data, missing tenant
boundaries, missing role taxonomy, missing permission matrix, missing admission
checks, missing authorization checks, missing GitHub Project scope mapping,
missing repository scope mapping, missing credential boundary, missing worker
route boundary, missing break-glass path, missing access review, missing audit
evidence, missing onboarding/offboarding, missing failure handling, missing
remaining operational gaps, missing permission level, or unauthorized credential,
production, infrastructure, worker, remote host, Docker, Kubernetes, deployment,
or GitHub Project control-plane mutation wording.

<!-- multi-tenant-rbac:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only design and local validation",
  "securityBoundary": "This design does not authorize credential, production, infrastructure, worker, remote host, Proxmox, Docker, Kubernetes, SSH, deployment, metrics service, alerting service, or GitHub Project control-plane mutation without explicit Human approval",
  "tenantBoundaries": {
    "tenantIdentity": "tenant id, display name, owning organization or team",
    "projectBinding": "allowed GitHub Projects and tenant field or derivation rule",
    "repositoryBinding": "allowed repository owner/name pairs",
    "environmentBinding": "allowed environments and branch classes",
    "credentialScope": "credential broker grants are tenant-scoped",
    "workerRouteScope": "worker routes are tenant-scoped",
    "crossTenantRule": "cross-tenant access requires explicit approval naming both tenants and expiration"
  },
  "roleTaxonomy": [
    "project_owner",
    "tenant_admin",
    "issue_approver",
    "fire_operator",
    "hammer_operator",
    "security_admin",
    "auditor",
    "break_glass_operator"
  ],
  "permissionMatrix": {
    "project_owner": [
      "configure_project_policy_proposal",
      "admit_issue_for_dispatch",
      "read_audit_evidence"
    ],
    "tenant_admin": [
      "manage_tenant_membership",
      "review_tenant_configuration",
      "read_audit_evidence"
    ],
    "issue_approver": [
      "approve_issue_scope",
      "approve_sensitive_gate",
      "read_audit_evidence"
    ],
    "fire_operator": [
      "verify_admission",
      "dispatch_admitted_ticket",
      "record_progress"
    ],
    "hammer_operator": [
      "execute_worker_route",
      "produce_result_packet"
    ],
    "security_admin": [
      "approve_security_gate",
      "approve_credential_grant",
      "revoke_credential_grant",
      "review_break_glass"
    ],
    "auditor": [
      "review_audit_package",
      "review_retention",
      "read_audit_evidence"
    ],
    "break_glass_operator": [
      "execute_emergency_action_with_explicit_approval",
      "produce_post_incident_evidence"
    ]
  },
  "admissionChecks": [
    "tenant id maps to project and repository",
    "project lifecycle status is dispatchable",
    "admission fields are present when configured",
    "requesting role is allowed for the action",
    "acceptance criteria and validation are present",
    "permission level and result evidence are present",
    "sensitive gates have explicit approval evidence",
    "repository and branch are inside tenant scope",
    "worker route is allowed for the tenant",
    "cross-tenant access is absent or explicitly approved"
  ],
  "authorizationChecks": [
    "tenant scope",
    "GitHub Project scope",
    "repository scope",
    "branch or environment scope",
    "actor role",
    "permission matrix",
    "approval-gate status",
    "credential broker grant",
    "worker route allowlist",
    "result-packet and audit evidence expectations"
  ],
  "scopeMappings": {
    "githubProject": [
      "project id or stable slug",
      "tenant field or derivation rule",
      "status field and dispatchable values",
      "admission fields",
      "authorized-by field",
      "agent or route field",
      "fallback labels and workpad conventions",
      "cross-project movement policy"
    ],
    "repository": [
      "allowed owner/name pairs",
      "protected branch class",
      "required PR checks",
      "submodule ownership boundaries",
      "deployment environments",
      "credential broker binding",
      "evidence retention surface"
    ]
  },
  "credentialBoundary": {
    "grantModel": "brokered, task-scoped, tenant-scoped, time-bound, least-privilege",
    "requestFields": [
      "tenant",
      "repository or service allowlist",
      "actor role",
      "permission",
      "branch or environment",
      "expiration",
      "revocation condition",
      "approval evidence"
    ],
    "forbiddenMaterial": [
      "Manager PAT",
      "OAuth token",
      "SSH key",
      "cloud credential",
      "kubeconfig",
      "Proxmox credential",
      "GitHub App private key"
    ]
  },
  "workerRouteBoundary": {
    "local_worktree": "assigned repository and worktree only",
    "ssh": "approved target, tenant, and command boundary",
    "docker": "approved disposable target and image boundary",
    "kubernetes_job": "approved cluster, namespace, service account, and cleanup boundary",
    "expansionRule": "route expansion requires a new approval record and result evidence"
  },
  "breakGlassPath": {
    "requiredFields": [
      "incident id",
      "Human approver",
      "permitted actor",
      "affected tenant",
      "affected repository",
      "affected project",
      "affected environment",
      "credential scope",
      "allowed action",
      "explicit non-approved adjacent actions",
      "expiration",
      "communication channel",
      "rollback or revocation expectation",
      "post-incident review owner",
      "audit package link"
    ],
    "standingAccess": "not allowed"
  },
  "accessReview": {
    "cadence": "quarterly and after break-glass, tenant offboarding, credential incident, or role conflict",
    "reviewers": [
      "tenant admin",
      "security admin",
      "auditor"
    ],
    "evidence": [
      "tenant",
      "role assignments",
      "high-risk grants",
      "credential grants",
      "worker route grants",
      "stale members",
      "revoked members",
      "exceptions",
      "reviewer",
      "decision",
      "next action"
    ]
  },
  "auditEvidence": [
    "tenant id and scope source",
    "actor role",
    "requested permission",
    "admission decision",
    "authorization decision",
    "approval-gate status",
    "credential broker grant id or none",
    "worker route decision",
    "audit reviewer",
    "residual risk and next action"
  ],
  "onboardingOffboarding": {
    "onboarding": [
      "tenant assignment",
      "role assignment",
      "repository and project scope",
      "training acknowledgement",
      "credential policy acknowledgement",
      "initial access review date"
    ],
    "offboarding": [
      "role removal",
      "credential revocation",
      "worker route grant removal",
      "project and repository access removal",
      "audit note",
      "follow-up review"
    ]
  },
  "failureHandling": [
    "missing tenant mapping fails closed",
    "missing role mapping fails closed",
    "missing permission mapping fails closed",
    "missing admission evidence fails closed",
    "missing authorization evidence fails closed",
    "missing credential boundary fails closed",
    "missing worker route boundary fails closed",
    "missing break-glass evidence fails closed",
    "missing access review fails closed",
    "unauthorized sensitive authority wording fails closed"
  ],
  "remainingOperationalGaps": [
    "runtime enforcement is not implemented",
    "access-review drill evidence is not captured",
    "cross-tenant denial replay is not captured",
    "credential grant denial replay is not captured",
    "GitHub Project field mapping export is not captured",
    "tenant lifecycle integration with identity provider is not selected"
  ],
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/59"
}
```
<!-- multi-tenant-rbac:end -->
