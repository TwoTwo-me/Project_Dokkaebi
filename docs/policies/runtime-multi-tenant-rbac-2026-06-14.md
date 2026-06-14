# Runtime Multi-Tenant RBAC Evidence

This document records the approved local sandbox runtime multi-tenant RBAC
evidence for issue #74. The runtime implementation lives in the
`symphony-github-project-tracker` submodule and is merged through submodule PRs
#21, #22, and #23. The evidence covers dispatch admission, repository and project scope,
cross-tenant denial, role and permission checks, wildcard and broad grant
rejection, credential grant pre-dispatch, worker route pre-dispatch, redacted
audit output, generated access-review output, trusted issue metadata for worker
tool authorization, validation output, approval-gate status, cleanup receipt,
residual risk, and next action. This is the redacted audit evidence baseline for
runtime RBAC.

This evidence does not authorize live credentials, remote hosts, Docker,
Kubernetes, deployment, production, infrastructure, worker privilege expansion,
or GitHub Project control-plane mutation.

Run:

```bash
bash scripts/validate-runtime-multi-tenant-rbac.sh
```

Optional local sandbox proof when the submodule is checked out:

```bash
cd symphony-github-project-tracker/elixir
mise exec -- mix tenant_rbac.sandbox
```

<!-- runtime-multi-tenant-rbac:begin -->
```json
{
  "version": 1,
  "evidenceId": "runtime-multi-tenant-rbac-2026-06-14",
  "date": "2026-06-14",
  "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/74",
  "permissionLevel": "approved-local-sandbox-runtime-rbac",
  "approvalRecord": {
    "approvedTarget": "local Elixir pure-function sandbox in the Project Dokkaebi development environment",
    "scope": "validate merged runtime tenant RBAC gates and sanitized sandbox output only",
    "deniedTargets": [
      "live credentials",
      "remote host",
      "Docker",
      "Kubernetes",
      "deployment",
      "production",
      "infrastructure",
      "worker privilege expansion",
      "GitHub Project control-plane"
    ],
    "evidence": "approval is limited to local sandbox runtime RBAC evidence for issue #74; no approval-gated live mutation reached"
  },
  "submoduleEvidence": {
    "path": "symphony-github-project-tracker",
    "repository": "https://github.com/TwoTwo-me/symphony-github-project-tracker",
    "pullRequest": "https://github.com/TwoTwo-me/symphony-github-project-tracker/pull/23",
    "runtimeCommit": "e516aeacb7d52d206a13033cd4f371a3c2d7264f",
    "mergeCommit": "33896e2cc82ba936e5b765a23b33bfcefe070218",
    "mergedAt": "2026-06-14T05:23:36Z",
    "supportingPullRequests": [
      {
        "pullRequest": "https://github.com/TwoTwo-me/symphony-github-project-tracker/pull/21",
        "implementationCommit": "8259438315e939309f085feec4741ec7c08da0a1",
        "mergeCommit": "a6cf3eda1422653d51305a9b6cff113c0c05a94f"
      },
      {
        "pullRequest": "https://github.com/TwoTwo-me/symphony-github-project-tracker/pull/22",
        "implementationCommit": "53e2f390850f3bde9afda37719f66af8a2a54ed3",
        "mergeCommit": "3d59edbe2e567a2f96cd95aa1978657148087f83"
      }
    ],
    "checks": [
      "git-governance pass",
      "make-all pass",
      "validate-pr-description pass"
    ]
  },
  "runtimeSurfaces": [
    {
      "surface": "dispatch admission",
      "enforcementPoint": "SymphonyElixir.ProjectAdmission.verify/1 and SymphonyElixir.TenantRbac.verify_dispatch/2",
      "allowScenarios": [
        "allow_least_privilege_dispatch"
      ],
      "denyScenarios": [
        "deny_missing_tenant",
        "deny_out_of_scope_repository",
        "deny_out_of_scope_project",
        "deny_cross_tenant_without_approval",
        "deny_role_permission_mismatch",
        "deny_permission_mismatch",
        "deny_missing_approval_evidence",
        "deny_secret_like_evidence",
        "deny_private_path_evidence"
      ],
      "auditEvidence": "tenant id, repository, actor role, requested permission, approval-gate status, decision, reason, and secret_material_included false"
    },
    {
      "surface": "credential grant pre-dispatch",
      "enforcementPoint": "SymphonyElixir.CredentialBroker.OperationGateway.authorize_operation/3 and SymphonyElixir.TenantRbac.verify_credential_grant/3",
      "allowScenarios": [
        "allow_tenant_scoped_credential_grant"
      ],
      "denyScenarios": [
        "deny_missing_credential_grant",
        "deny_broker_policy_before_rbac",
        "deny_broad_credential_permissions",
        "deny_broad_repository_selection",
        "deny_prefixed_raw_graphql_mutation_without_policy",
        "deny_worker_supplied_tenant_authority"
      ],
      "auditEvidence": "tenant id, repository, credential_grant, actor role, requested permission, approval-gate status, decision, reason, trusted issue metadata boundary, and secret_material_included false"
    },
    {
      "surface": "worker route pre-dispatch",
      "enforcementPoint": "SymphonyElixir.WorkerPool.select_route/4 and SymphonyElixir.TenantRbac.verify_worker_route/2",
      "allowScenarios": [
        "allow_tenant_worker_route"
      ],
      "denyScenarios": [
        "deny_missing_worker_route",
        "deny_out_of_scope_worker_route"
      ],
      "auditEvidence": "tenant id, worker route, actor role, requested permission, approval-gate status, decision, reason, and secret_material_included false"
    }
  ],
  "accessReviewOutput": {
    "source": "SymphonyElixir.TenantRbac.access_review/2",
    "tenantId": "tenant-alpha",
    "roleAssignments": [
      "auditor",
      "fire_operator",
      "hammer_operator",
      "security_admin"
    ],
    "repositories": [
      "org/repo"
    ],
    "projects": [
      "PVT_alpha"
    ],
    "credentialGrants": [
      "repo.contents.read",
      "repo.pr.write"
    ],
    "workerRouteGrants": [
      "local-worktree",
      "ssh-alpha"
    ],
    "reviewer": "runtime-rbac",
    "cadence": "quarterly",
    "decision": "reviewable-runtime-state",
    "secretMaterialIncluded": false,
    "nextAction": "continue scheduled access review"
  },
  "sandboxCommand": {
    "path": "symphony-github-project-tracker/elixir",
    "command": "mise exec -- mix tenant_rbac.sandbox",
    "outputContract": "JSON with dispatch, credentialGrant, workerRoute, accessReview, approvalGateStatus, cleanup, and residualRisk"
  },
  "validationOutput": [
    "submodule PR #21 git-governance pass",
    "submodule PR #21 make-all pass",
    "submodule PR #21 validate-pr-description pass",
    "submodule PR #22 git-governance pass",
    "submodule PR #22 make-all pass",
    "submodule PR #22 validate-pr-description pass",
    "submodule PR #23 git-governance pass",
    "submodule PR #23 make-all pass",
    "submodule PR #23 validate-pr-description pass",
    "cd symphony-github-project-tracker/elixir && mise exec -- make all",
    "cd symphony-github-project-tracker/elixir && mise exec -- mix tenant_rbac.sandbox",
    "bash scripts/validate-runtime-multi-tenant-rbac.sh",
    "bash scripts/validate-multi-tenant-rbac.sh",
    "bash scripts/validate-multi-tenant-rbac-drill.sh",
    "bash scripts/validate-readiness-criteria.sh",
    "bash scripts/validate-contract-docs.sh"
  ],
  "approvalGateStatus": "approved local sandbox only; no live credential, worker, remote host, Docker, Kubernetes, deployment, production, infrastructure, or GitHub Project control-plane mutation reached this evidence and those targets remain not authorized",
  "cleanup": {
    "status": "complete",
    "receipt": "local pure-function sandbox and validator only; temporary parser files removed; no servers, tmux sessions, ports, browsers, containers, credentials, remote hosts, Docker daemon, Kubernetes cluster, production targets, deployments, infrastructure, or GitHub Project settings were created or changed"
  },
  "residualRisk": [
    "production identity-provider integration remains separately approval-gated",
    "live credential backend issuance remains separately approval-gated",
    "live worker fleet route enforcement remains separately approval-gated"
  ],
  "readinessDecision": {
    "security_authority": 100,
    "multi_tenant_rbac": 100,
    "basis": "merged runtime code, approved local sandbox output, trusted worker tool metadata boundary, submodule PR checks, root evidence validator, and no live approval-gated mutation"
  },
  "nextAction": "continue with remaining readiness issues #76, #82, #88, and #100"
}
```
<!-- runtime-multi-tenant-rbac:end -->
