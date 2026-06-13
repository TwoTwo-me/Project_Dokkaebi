# Credential Lifecycle And Revocation Dry Run

This document defines the docs-only credential lifecycle and revocation dry-run
for Project Dokkaebi. It covers token classes and credential-bearing grant
classes, owners, storage surfaces, rotation cadence, revocation triggers, audit
evidence, and the narrow development/sandbox auth exception without exposing
secret values.

This dry run does not use, issue, rotate, revoke, copy, export, or inspect live
credentials. Credential use, broker mutation, infrastructure, workers, remote
hosts, Docker, Kubernetes, deployment, production, or GitHub Project
control-plane mutation requires explicit Human approval under
[`authority-and-safety.md`](authority-and-safety.md).

## Credential Classes

| Class | Owner | Storage | Rotation | Revocation trigger | Audit evidence |
| --- | --- | --- | --- | --- | --- |
| Manager GitHub credential | Security owner | credential broker or GitHub App installation boundary | 90 days or provider policy | owner change, suspected exposure, scope change, failed audit | owner, approval record, scope, expiry, revocation condition |
| Broker grant bundle | Credential broker owner | broker-managed short-lived grant | per task or shorter | task closeout, route denial, tenant mismatch, expired approval | owner, approval record, scope, expiry, revocation condition, safe grant identifier |
| Worker route credential | Worker route owner | route-scoped broker bundle | per route assignment | worker route disabled, route mismatch, ticket closeout | owner, approval record, scope, expiry, revocation condition, route identifier, cleanup receipt |
| SSH worker access | Infrastructure owner | approved SSH config and brokered host access | 90 days or host owner policy | host owner change, suspected exposure, key rotation window | owner, approval record, scope, expiry, revocation condition, host alias, cleanup receipt |
| Future cloud or container credential | Platform owner | approved secret manager only | provider policy or 90 days | environment change, provider incident, deployment rollback | owner, approval record, scope, expiry, revocation condition, environment, retention decision |

Raw secret values, auth file contents, cookies, tokens, SSH private keys,
kubeconfig content, cloud secret material, and private machine state must never
be retained in repository evidence.

## Development And Sandbox Auth Exception

The development and sandbox auth exception is narrow. It permits auth
propagation only for trusted Project Dokkaebi development and approved sandbox
worker targets, only for the named task, and only when the target, owner,
duration, cleanup, and approval evidence are recorded. It does not authorize
production access, broad worker access, infrastructure mutation, deployment, or
GitHub Project control-plane mutation.

## Dry-Run Revocation Checklist

The dry-run revocation checklist below is executable as a repository-only review
without touching live credential systems.

1. Identify the credential class and owner.
2. Confirm the target is docs-only, local, or explicitly approved sandbox.
3. Record requested scope, allowed repositories/projects, duration, expiry, and
   revocation condition.
4. Confirm no raw secret value, auth file content, cookie, token, SSH private
   key, kubeconfig content, cloud secret material, or private machine state is
   retained.
5. Simulate revocation decision without touching live credential systems.
6. Record expected broker response, denial or revocation reason, audit evidence,
   approval-gate status, cleanup receipt, residual risk, and next action.
7. Fail closed if owner, scope, expiry, revocation trigger, audit evidence,
   cleanup, or approval-gate status is missing.

Expected targeted validation output:

```text
PASS Dokkaebi credential lifecycle validation passed
```

## Residual Risk And Next Action

Runtime broker denial, live revocation, generated access-review output, and
worker-route credential gate evidence are not captured by this docs-only dry
run. Next action: complete issue #92 with runtime or explicitly approved
sandbox evidence.

<!-- credential-lifecycle:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only credential lifecycle and revocation dry-run",
  "approvalBoundary": "This dry run does not authorize credential use, broker mutation, infrastructure, workers, remote hosts, Docker, Kubernetes, deployment, production, or GitHub Project control-plane mutation without explicit Human approval",
  "credentialClasses": [
    {
      "id": "manager_github_credential",
      "name": "Manager GitHub credential",
      "owner": "Security owner",
      "storage": "credential broker or GitHub App installation boundary",
      "rotationCadence": "90 days or provider policy",
      "revocationTriggers": [
        "owner change",
        "suspected exposure",
        "scope change",
        "failed audit"
      ],
      "auditEvidence": [
        "owner",
        "approval record",
        "scope",
        "expiry",
        "revocation condition"
      ],
      "rawSecretRetained": false
    },
    {
      "id": "broker_grant_bundle",
      "name": "Broker grant bundle",
      "owner": "Credential broker owner",
      "storage": "broker-managed short-lived grant",
      "rotationCadence": "per task or shorter",
      "revocationTriggers": [
        "task closeout",
        "route denial",
        "tenant mismatch",
        "expired approval"
      ],
      "auditEvidence": [
        "owner",
        "approval record",
        "scope",
        "expiry",
        "revocation condition",
        "safe grant identifier",
        "ticket"
      ],
      "rawSecretRetained": false
    },
    {
      "id": "worker_route_credential",
      "name": "Worker route credential",
      "owner": "Worker route owner",
      "storage": "route-scoped broker bundle",
      "rotationCadence": "per route assignment",
      "revocationTriggers": [
        "worker route disabled",
        "route mismatch",
        "ticket closeout",
        "failed result packet review"
      ],
      "auditEvidence": [
        "owner",
        "approval record",
        "scope",
        "expiry",
        "revocation condition",
        "route identifier",
        "ticket",
        "result packet",
        "cleanup receipt"
      ],
      "rawSecretRetained": false
    },
    {
      "id": "ssh_worker_access",
      "name": "SSH worker access",
      "owner": "Infrastructure owner",
      "storage": "approved SSH config and brokered host access",
      "rotationCadence": "90 days or host owner policy",
      "revocationTriggers": [
        "host owner change",
        "suspected exposure",
        "key rotation window",
        "sandbox approval expiry"
      ],
      "auditEvidence": [
        "owner",
        "scope",
        "expiry",
        "revocation condition",
        "host alias",
        "approval record",
        "revocation receipt",
        "cleanup receipt"
      ],
      "rawSecretRetained": false
    },
    {
      "id": "future_cloud_or_container_credential",
      "name": "Future cloud or container credential",
      "owner": "Platform owner",
      "storage": "approved secret manager only",
      "rotationCadence": "provider policy or 90 days",
      "revocationTriggers": [
        "environment change",
        "provider incident",
        "deployment rollback",
        "owner review rejection"
      ],
      "auditEvidence": [
        "owner",
        "approval record",
        "expiry",
        "revocation condition",
        "environment",
        "scope",
        "retention decision"
      ],
      "rawSecretRetained": false
    }
  ],
  "developmentSandboxException": {
    "status": "narrow and explicitly approved",
    "scope": "trusted Project Dokkaebi development and approved sandbox worker targets only",
    "duration": "named task duration only",
    "requiredEvidence": [
      "target",
      "owner",
      "duration",
      "cleanup",
      "approval evidence"
    ],
    "notAuthorized": [
      "production access",
      "broad worker access",
      "infrastructure mutation",
      "deployment",
      "GitHub Project control-plane mutation"
    ]
  },
  "dryRunRevocationChecklist": [
    "identify credential class and owner",
    "confirm target is docs-only, local, or explicitly approved sandbox",
    "record requested scope, allowed repositories or projects, duration, expiry, and revocation condition",
    "confirm no raw secret value or private machine state is retained",
    "simulate revocation decision without touching live credential systems",
    "record expected broker response, denial or revocation reason, audit evidence, approval-gate status, cleanup receipt, residual risk, and next action",
    "fail closed when owner, scope, expiry, revocation trigger, audit evidence, cleanup, or approval-gate status is missing"
  ],
  "auditEvidence": [
    "owner",
    "credential class",
    "scope",
    "storage surface",
    "rotation cadence",
    "revocation trigger",
    "approval-gate status",
    "cleanup receipt",
    "residual risk",
    "next action"
  ],
  "residualRisk": [
    "runtime broker denial evidence is not captured",
    "live revocation output is not captured",
    "generated access-review output is not captured",
    "worker-route credential gate evidence is not captured"
  ],
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/92"
}
```
<!-- credential-lifecycle:end -->
