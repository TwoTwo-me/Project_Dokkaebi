# Project Dokkaebi Program Scorecard

Date: 2026-06-21

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
K8S fixture coverage is additionally locked by
[`k8s-platformization-fixture-coverage.json`](k8s-platformization-fixture-coverage.json),
which maps every accepted route and denied unsafe class to a concrete fixture
and expected validation result.

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
| k8s_platformization | 100/100 | `bash scripts/validate-k8s-platformization.sh` |

## K8S Sub-Capability Scores

`k8s_platformization` is weighted from the granular capabilities below. A
sub-capability reaches 100 only when its evidence exists and validators enforce
the evidence shape.

| Capability | Score | Gate |
| --- | ---: | --- |
| k8s_loop_contract | 100/100 | `bash scripts/validate-readiness-criteria.sh` |
| k8s_base_controls_static | 100/100 | `bash scripts/validate-k8s-platformization.sh` |
| k8s_admission_fixture_matrix | 100/100 | `bash scripts/validate-k8s-platformization.sh` |
| k8s_accepted_route_profile_fixtures | 100/100 | `bash scripts/validate-k8s-platformization.sh` |
| k8s_disposable_api_server_admission_rbac | 100/100 | `docs/operations/k8s-disposable-api-server-smoke-2026-06-16.md` |
| fire_k8s_deployment_runtime_smoke | 100/100 | `docs/operations/k8s-platform-e2e-2026-06-21.md` |
| hammer_job_profile_runtime_smoke | 100/100 | `docs/operations/k8s-runtime-smoke-2026-06-18.md` |
| k8s_result_packet_reconciliation | 100/100 | `docs/operations/k8s-platform-e2e-2026-06-21.md` |
| eks_identity_secret_boundary | 100/100 | `docs/adr/0003-k8s-identity-secret-boundary.md` |

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

## Repository-Owned K8S Continuous Improvement Gates

`k8s_platformization` is 100/100 for the repository-owned local/sandbox
platform gate after render, admission/RBAC, route-profile fixtures, disposable
API server proof, Fire/Hammer runtime smoke, Fire/broker/admission LiteLLM
virtual-key Job evidence, LiteLLM gateway key lifecycle smoke,
stale/failed/GitHub/PR/check reconciliation replay, Grafana/Prometheus
validation, EKS identity/Secret boundary decision, and README usage
documentation all have durable evidence. The 100 score is bounded to approved local/sandbox runtime evidence and does not authorize live AWS, EKS, shared-cluster, production, provider credentials, ChatGPT OAuth, or GitHub Project control-plane mutation.

| Issue gate | Required proof |
| --- | --- |
| `k8s-admission-policy-gate` | Keep the fixture coverage matrix and disposable API server admission proof current when new deny classes, route profiles, images, result packet sinks, or `hammer-no-k8s` token override paths are added. |
| `fire-k8s-deployment-smoke` | Keep Fire runtime smoke current when the production image digest, API-server egress patch, or GitHub Project configuration changes. |
| `hammer-job-profile-smoke` | Each approved Hammer profile proves route metadata, result evidence, can/cannot boundaries, and cleanup in a disposable local Kubernetes run. |
| `k8s-result-packet-reconciliation` | Keep local replay, runtime Job/log/result metadata, and `k8s-result-reconciliation-matrix.json` current when new closeout states, PR/check gates, or result-packet sinks are added. |
| `eks-identity-and-secret-boundary` | Keep ADR 0003, EKS overlay placeholders, denied Secret fixtures, and live-apply approval gates current before any AWS/EKS mutation. |

## Validation

Required local validation:

```bash
bash scripts/validate-enterprise-scorecard.sh
bash scripts/validate-readiness-criteria.sh
bash scripts/validate-k8s-platformization.sh
bash scripts/validate-k8s-litellm-grafana-platform.sh
bash scripts/validate-k8s-result-reconciliation.sh
bash scripts/validate-k8s-platform-e2e.sh
bash scripts/run-k8s-platform-e2e.sh
bash scripts/validate-all.sh
```
