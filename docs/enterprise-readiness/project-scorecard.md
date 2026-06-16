# Project Dokkaebi Program Scorecard

Date: 2026-06-14

This scorecard is the program-facing view of
[`criteria.json`](criteria.json). It supports the 100-point loop requested for
Project Dokkaebi: keep testing real repository surfaces, add criteria when a
gap is found, improve the loop, and repeat until every readiness item reaches
100 from evidence.

The scorecard must not mark a score 100 from intent, issue prose, Manager
memory, or tool availability. A 100 score requires durable evidence, validator
coverage, reviewable result evidence, and no open gap for that item.
The scorecard table must match criteria.json exactly; score drift in this
Markdown view is a validation failure, not an editorial inconsistency.
The K8S `currentEvidence` list is additionally locked by
[`k8s-platformization-current-evidence.json`](k8s-platformization-current-evidence.json),
so adding, removing, or reordering K8S evidence must update the lock and
validators in the same change.

## Scoring Rules

| Rule | Required evidence |
| --- | --- |
| 100-point loop | `targetPercent` is 100 for every readiness area and critical capability. |
| Below 100 | The item must name gaps and publish dispatch-ready `nextIssues` or capability acceptance criteria. |
| Score increase | The change must cite new evidence, run targeted validators, and preserve Human approval boundaries. |
| Loop self-improvement | Capture RED evidence before changing criteria or validators, then run GREEN validation. |
| Regression gate | `bash scripts/validate-all.sh` must pass before claiming a loop iteration is complete. |

## Current Program Scores

| Area | Score | Gate |
| --- | ---: | --- |
| architecture_contracts | 100/100 | `bash scripts/validate-contract-docs.sh` |
| core_orchestration | 100/100 | `bash scripts/validate-orchestration-recovery-gate.sh` |
| infrastructure_platform | 100/100 | `bash scripts/validate-topology-backup-restore-dr.sh` |
| development_quality | 100/100 | `bash scripts/validate-enterprise-scorecard.sh` |
| security_authority | 100/100 | `bash scripts/validate-security-threat-model.sh` |
| management_governance | 100/100 | `bash scripts/validate-project-governance-reconciliation.sh` |
| logging_observability | 100/100 | `bash scripts/validate-central-metrics-backend.sh` |
| operations_sre | 100/100 | `bash scripts/validate-sre-operating-baseline.sh` |
| compliance_audit | 100/100 | `bash scripts/validate-compliance-package.sh` |
| productization_ux | 100/100 | `bash scripts/validate-onboarding-troubleshooting.sh` |
| design_system | 100/100 | `bash scripts/validate-carbon-ui-baseline.sh` |
| k8s_platformization | 55/100 | `bash scripts/validate-k8s-platformization.sh` |

## Critical Capability Scores

| Capability | Score | Gate |
| --- | ---: | --- |
| incident_response | 100/100 | `bash scripts/validate-incident-response-runbook.sh` |
| on_call_paging_alerting | 100/100 | `bash scripts/validate-on-call-paging-alerting.sh` |
| slo_sla | 100/100 | `bash scripts/validate-service-level-objectives.sh` |
| backup_restore_dr | 100/100 | `bash scripts/validate-backup-restore-drill.sh` |
| compliance_package | 100/100 | `bash scripts/validate-compliance-package.sh` |
| production_release_rollback_runbook | 100/100 | `bash scripts/validate-release-rollback-sandbox-gate.sh` |
| central_metrics_backend | 100/100 | `bash scripts/validate-central-metrics-backend.sh` |
| immutable_audit_export | 100/100 | `bash scripts/validate-immutable-audit-export.sh` |
| multi_tenant_rbac | 100/100 | `bash scripts/validate-multi-tenant-rbac.sh` |

## K8S Remaining Issue Gates

`k8s_platformization` remains 55/100 because live or approved-sandbox runtime
proof is still missing. The remaining score increase is blocked on the five
candidate issues below, which preserve the docs-only approval boundary until a
Human explicitly approves a live target.

| Issue gate | Required proof |
| --- | --- |
| `k8s-admission-policy-gate` | Admission policy installation or approved-sandbox proof fails closed for unsafe Hammer Jobs, including missing or empty authority labels, missing result packet sink, repo-local wrong apiVersion or kind fixture schema, unapproved image/profile, empty resources, invalid, duplicate, bare, initContainer, or ephemeralContainer result sink, privileged/capability escalation, hostNetwork, hostPort, hostPID, hostIPC, shareProcessNamespace, broad volume mount, default-root security contexts, ephemeral debug bypass, imagePullSecrets, projected token/Secret material, unsafe overlay traversal, RBAC expansion, Secret access, and `hammer-no-k8s` token override. |
| `fire-k8s-deployment-smoke` | Fire starts in Kubernetes and creates only approved Hammer Jobs with least privilege. |
| `hammer-job-profile-smoke` | Each Hammer profile proves route metadata, result evidence, and can/cannot boundaries. |
| `k8s-result-packet-reconciliation` | GitHub Project state, Kubernetes Job state, logs, PR/checks, and result packets reconcile before closeout. |
| `eks-identity-and-secret-boundary` | EKS workload identity and Secret access remain least privilege, approved, and auditable. |

## Validation

Required local validation:

```bash
bash scripts/validate-enterprise-scorecard.sh
bash scripts/validate-readiness-criteria.sh
bash scripts/validate-k8s-platformization.sh
bash scripts/validate-all.sh
```
