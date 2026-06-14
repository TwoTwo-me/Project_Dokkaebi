# Durable Backup Restore Verification 2026-06-14

This evidence package records the issue #86 executable local durable backup
restore verification. It extends the local backup restore drill and the
credential-free sandbox restore drill with an automated verification path for
project exports, lease/retry state, route-result summaries, and evidence
packages.

The verification is local and deterministic. It creates sanitized fixture
classes, writes them to a temporary source area, stages a backup bundle,
restores the bundle into a temporary restore area, compares SHA-256 values,
checks retention and redaction policy, and removes the temporary areas before
the validator exits.

It does not mutate runtime systems, remote hosts, Docker, Kubernetes, Proxmox,
credentials, production data, deployments, infrastructure, or GitHub Project
control-plane settings. Those operations require explicit Human approval for
the exact target and permitted operations.

Expected targeted validation output:

```text
PASS Dokkaebi durable backup restore verification passed
```

## Verification Summary

| Field | Value |
| --- | --- |
| Verification ID | issue-86-2026-06-14-durable-backup-restore-verification |
| Issue | https://github.com/TwoTwo-me/Project_Dokkaebi/issues/86 |
| Permission level | docs-and-local-validation |
| Backup classes | project exports, lease/retry state, route-result summaries, evidence packages |
| Measured RPO | 0 seconds against a 24-hour local export target |
| Measured RTO | 1 second against a 4-hour local restore target |
| Approval-gate status | local temporary fixture only; no approval-gated mutation reached |

## Validation

Run:

```bash
bash scripts/validate-durable-backup-restore-verification.sh
bash scripts/validate-sandbox-restore-drill.sh
bash scripts/validate-backup-restore-drill.sh
bash scripts/validate-topology-backup-restore-dr.sh
bash scripts/validate-readiness-criteria.sh
bash scripts/validate-contract-docs.sh
```

The targeted validator rejects missing backup classes, mismatched source and
restored hashes, failed RPO/RTO, missing retention checks, missing redaction
checks, missing approval-gate status, missing cleanup receipt, unsafe authority
wording, private local paths, and secret-bearing evidence.

## Cleanup Receipt

Cleanup receipt: PASS. The validator creates only a temporary local fixture
tree and confirms it is removed before reporting success. Retained evidence is
limited to this checked-in package, validator output, pull request evidence, and
issue closeout evidence.

## Residual Risk And Next Action

This closes the durable backup automation gap for local verification and the
backup/restore critical capability. Infrastructure readiness still needs
separate multi-provider worker route health and remote bootstrap rebuild
evidence for local, SSH, Docker, and Kubernetes routes, tracked by issue #103.

<!-- durable-backup-restore-verification:begin -->
```json
{
  "version": 1,
  "verificationId": "issue-86-2026-06-14-durable-backup-restore-verification",
  "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/86",
  "date": "2026-06-14",
  "permissionLevel": "docs-and-local-validation",
  "approvalBoundary": "This verification permits repository-local temporary fixture creation, backup staging, restore replay, hash comparison, retention checks, redaction checks, and cleanup only; it does not authorize runtime, remote host, SSH, Docker, Kubernetes, Proxmox, credential, production, deployment, infrastructure, or GitHub Project control-plane mutation without explicit Human approval",
  "backupClasses": [
    {
      "id": "project_exports",
      "description": "sanitized project fields, issue state, and repository export metadata",
      "sourceSha256": "6fb6eb89f275b6e99554e7295eaed007c0014d8cf1d9ce152144f846c31bd36b",
      "restoredSha256": "6fb6eb89f275b6e99554e7295eaed007c0014d8cf1d9ce152144f846c31bd36b",
      "restoreVerified": true,
      "retentionDays": 30,
      "redactionCheck": "no raw sensitive values, authentication material, private machine state, or private local paths"
    },
    {
      "id": "lease_retry_state",
      "description": "sanitized dispatch lease, idempotency, retry, and completion state",
      "sourceSha256": "1138e2cbfa9e371bc8051c9fbe6fccf1c8eb644e5ffab0edf3e8a8e4cba8d6fa",
      "restoredSha256": "1138e2cbfa9e371bc8051c9fbe6fccf1c8eb644e5ffab0edf3e8a8e4cba8d6fa",
      "restoreVerified": true,
      "retentionDays": 30,
      "redactionCheck": "sanitized lease token only; no credential material"
    },
    {
      "id": "route_result_summaries",
      "description": "sanitized worker route selection, skip reason, and result-packet summary",
      "sourceSha256": "47ef9ac714774db09e3062ba8e50524fb740d1f1867aa0d568f4255e3d6b48f9",
      "restoredSha256": "47ef9ac714774db09e3062ba8e50524fb740d1f1867aa0d568f4255e3d6b48f9",
      "restoreVerified": true,
      "retentionDays": 30,
      "redactionCheck": "route inventory contains capabilities and skip reasons only"
    },
    {
      "id": "evidence_packages",
      "description": "sanitized validation output, approval-gate status, and cleanup receipt package",
      "sourceSha256": "b35ae715e0250ef0a5c09de533314105a804e5787152d25a21295750224ca637",
      "restoredSha256": "b35ae715e0250ef0a5c09de533314105a804e5787152d25a21295750224ca637",
      "restoreVerified": true,
      "retentionDays": 30,
      "redactionCheck": "evidence package explicitly excludes raw sensitive values and private paths"
    }
  ],
  "verificationRun": {
    "command": "bash scripts/validate-durable-backup-restore-verification.sh",
    "localExecutable": true,
    "fixtureRoot": "temporary local fixture created by the validator and removed before success",
    "backupBundleSha256": "88fd25ef392a251ee37838f7387b7825a4b5ed818cc4e95ad90e688aa4d8686e",
    "restorePointTimestamp": "2026-06-14T01:07:00Z",
    "restoreStartedAt": "2026-06-14T01:07:01Z",
    "restoreCompletedAt": "2026-06-14T01:07:02Z",
    "rpoObservedSeconds": 0,
    "rpoTargetSeconds": 86400,
    "rtoObservedSeconds": 1,
    "rtoTargetSeconds": 14400,
    "output": [
      "project_exports restored hash matched",
      "lease_retry_state restored hash matched",
      "route_result_summaries restored hash matched",
      "evidence_packages restored hash matched",
      "retention policy checks passed",
      "redaction checks passed",
      "cleanup receipt recorded as complete"
    ]
  },
  "retentionPolicyChecks": [
    {
      "backupClass": "project_exports",
      "minimumRetentionDays": 30,
      "actualRetentionDays": 30,
      "status": "passed"
    },
    {
      "backupClass": "lease_retry_state",
      "minimumRetentionDays": 30,
      "actualRetentionDays": 30,
      "status": "passed"
    },
    {
      "backupClass": "route_result_summaries",
      "minimumRetentionDays": 30,
      "actualRetentionDays": 30,
      "status": "passed"
    },
    {
      "backupClass": "evidence_packages",
      "minimumRetentionDays": 30,
      "actualRetentionDays": 30,
      "status": "passed"
    }
  ],
  "redactionChecks": {
    "rawSensitiveValuesIncluded": false,
    "authenticationMaterialIncluded": false,
    "privateMachineStateIncluded": false,
    "privateLocalPathsIncluded": false,
    "redactionManifest": [
      "project export fixture is sanitized",
      "lease token value is synthetic and sanitized",
      "route result summary excludes command output with credentials",
      "evidence package excludes private machine paths"
    ]
  },
  "approvalGateStatus": "Closed for repository-local temporary fixture verification: no runtime, remote host, SSH, Docker, Kubernetes, Proxmox, credential, production, deployment, infrastructure, or GitHub Project control-plane mutation reached",
  "cleanupReceipt": {
    "status": "complete",
    "receipt": "temporary source, backup, and restore fixture directories are removed before the validator reports success",
    "retainedEvidence": "checked-in sanitized evidence package, validator output, pull request evidence, and issue closeout evidence only"
  },
  "residualRisk": [
    "No production DR or external SLA claim is made by this local verification.",
    "Live or remote restore verification still requires explicit Human approval for the exact target and operations.",
    "Infrastructure route-health readiness remains tracked by issue #103."
  ],
  "nextAction": "Use issue #103 to prove multi-provider worker route health and remote bootstrap rebuild evidence for infrastructure readiness."
}
```
<!-- durable-backup-restore-verification:end -->
