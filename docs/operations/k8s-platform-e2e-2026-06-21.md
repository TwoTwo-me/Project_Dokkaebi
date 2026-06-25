# K8S Platform E2E Gate

Date: 2026-06-21

## Purpose

This evidence record closes the repository-owned 100-point Kubernetes platform
gate for Project Dokkaebi. It ties together render validation, admission and
RBAC fixtures, Fire/Hammer runtime smoke, LiteLLM virtual-key boundaries,
Grafana/Prometheus provisioning checks, EKS identity/Secret boundary decisions,
README usage documentation, and enterprise scorecard validation.

The gate proves the local/sandbox platform contract. It does not authorize live AWS,
EKS, shared-cluster, production, provider-credential, ChatGPT OAuth, or GitHub
Project control-plane mutation.

## Command

```bash
DOKKAEBI_K8S_E2E_RUNTIME=require bash scripts/run-k8s-platform-e2e.sh
```

The runner writes evidence under
`.omo/ulw-loop/evidence/k8s-platform-e2e-*` unless
`DOKKAEBI_K8S_E2E_EVIDENCE_DIR` is provided.

`require` mode is the 100-point scorecard gate. It fails if the local machine
cannot run both disposable runtime smokes, or if either smoke is explicitly
skipped. `skip` mode is useful for static validation, but it ends with
`PASS Dokkaebi K8S platform static E2E completed` and is not sufficient for a
100-point claim.

## Required PASS Markers

- `PASS k8s base rendered`
- `PASS Dokkaebi K8S platformization fixtures and controls are valid`
- `PASS Dokkaebi K8S LiteLLM/Grafana platform package validation passed`
- `PASS Dokkaebi K8S platform E2E documentation and score evidence are valid`
- `PASS Dokkaebi enterprise readiness criteria are present and structurally valid`
- `PASS Dokkaebi enterprise scorecard loop is fail-closed and evidence-bound`
- `PASS all repository validators completed`
- `PASS k8s runtime smoke completed` when local Docker, `kind`, and `kubectl`
  are available
- `PASS LiteLLM ChatGPT Kubernetes smoke completed` when local runtime tools are
  available and the LiteLLM smoke is not skipped
- `PASS Dokkaebi K8S platform E2E completed`

## Observed Evidence

Observed full runtime E2E evidence for this score update:

```text
evidence_dir=.omo/ulw-loop/k8s-e2e-readme-100-20260621/evidence/runtime-e2e-v6
runtime_mode=require
RUN k8s-base-render: kubectl kustomize k8s/base
PASS k8s-base-render
PASS validate-k8s-platformization
PASS validate-k8s-litellm-grafana-platform
PASS validate-k8s-result-reconciliation
PASS validate-k8s-platform-e2e
PASS validate-readiness-criteria
PASS validate-enterprise-scorecard
PASS validate-all
PASS k8s-runtime-smoke
PASS litellm-chatgpt-k8s-smoke
PASS Dokkaebi K8S platform E2E completed
```

Result reconciliation replay evidence includes:

```text
REPLAY accepted-closeout: move-to-human-review
REPLAY missing-result-packet: reject-closeout
REPLAY failed-job: fix-requested-or-failed
REPLAY done-while-job-running: reopen-or-block-done
REPLAY stale-job: create-recovery-ticket
REPLAY pr-check-failed: fix-requested
REPLAY missing-approval: reject-closeout
PASS Dokkaebi K8S result reconciliation matrix validation passed
```

Fire/Hammer runtime evidence includes:

```text
fire_smoke_status=created_approved_hammer_job
result_metadata_ok job=hammer-ticket-pdk8s-fire-runtime-001
accepted_fixture_applied_by_fire path=k8s/fixtures/accepted/hammer-job-litellm-virtual-key-approved.yaml
litellm_virtual_key_secret_created_by_broker=dokkaebi-litellm-virtual-key-grant-litellm-pdk8s-001
litellm_virtual_key_job_created_by_fire=hammer-ticket-pdk8s-litellm-001
hammer_litellm_virtual_key_self_spoof_denied=hammer-k8s-job-runner
fire_rejected_fixture_denied=missing-approval-id
PASS k8s runtime smoke completed
cleanup_kind_cluster=dokkaebi-runtime-smoke deleted
cleanup_kind_containers=dokkaebi-runtime-smoke none
```

Admission fixture evidence also includes the rejected
`hammer-no-k8s` Kubernetes API egress selector spoof fixture. The CEL policy
reserves `dokkaebi.io/k8s-api-access=approved` for approved K8S Hammer route
profiles only.

LiteLLM gateway evidence includes:

```text
chatgpt_provider_config_loaded=yes
chatgpt_provider_requires_device_flow=yes
virtual_key_generated=yes
models_status=200
no_auth_models_status=401
gateway_provider_call=blocked_by_fake_provider_key
virtual_key_blocked=yes
blocked_key_models_status=401
worker_pod_boundary_ok=yes
PASS LiteLLM ChatGPT Kubernetes smoke completed
cleanup_kind_cluster=dokkaebi-litellm-smoke deleted
cleanup_kind_containers=dokkaebi-litellm-smoke none
```

## What Is Covered

| Capability | E2E evidence |
| --- | --- |
| Fire in K8S | Fire blue/green manifests render; Fire canary Job creates an approved Hammer Job in disposable Kubernetes; Fire is denied Secret and RBAC escalation. |
| Hammer route profiles | Accepted route fixtures execute; rejected fixtures deny unsafe metadata, Secret, token, filesystem, network, image, and RBAC shapes. |
| LiteLLM gateway | Gateway-owned credential boundary is validated; Hammer receives only a brokered virtual key; key generation, use, block, and denied post-block access are covered by the LiteLLM smoke. |
| Grafana/Prometheus | Prometheus scrape jobs, bounded labels, Grafana datasource provisioning, and GitOps dashboard ConfigMaps are validated from rendered manifests. |
| Versioning/migration | Blue/green Fire release tracks, active-writer Lease, canary dispatch-off defaults, rollback text, and GitOps promotion requirements are validated. |
| EKS identity/Secret boundary | ADR 0003 and the EKS overlay placeholders define the selected workload identity boundary while live AWS/EKS mutation remains approval-gated. |
| Documentation | README links to the usage guide; the usage guide names prerequisites, validation, apply flow, LiteLLM, Grafana, migration, EKS, and troubleshooting. |

## Score Impact

| Sub-capability | Score after this E2E | Rationale |
| --- | ---: | --- |
| `fire_k8s_deployment_runtime_smoke` | 100/100 | Disposable Kubernetes runtime smoke starts Fire as a Kubernetes Job, proves least-privilege Job creation, proves broker-created LiteLLM virtual-key Secret plus Fire-created Hammer Job admission, records result metadata, and keeps production Fire image/config as a live-apply approval gate rather than an unscored gap. |
| `k8s_result_packet_reconciliation` | 100/100 | Local replay, `k8s-result-reconciliation-matrix.json`, and runtime smoke reconcile Job state, logs, route metadata, result-packet sink, stale/failure/GitHub/PR/check disagreement cases, and validator-enforced closeout evidence without live external writes. |
| `eks_identity_secret_boundary` | 100/100 | ADR 0003, EKS overlay placeholders, denied Secret fixtures, and LiteLLM virtual-key boundary validators select the repository-owned identity and Secret model while live AWS/EKS mutation remains separately approval-gated. |
| `k8s_platformization` | 100/100 | All weighted sub-capabilities now have durable evidence and fail-closed validators. |

## Boundary

The 100-point claim is for the repository-owned Kubernetes platform package and
approved local/sandbox E2E gate. It means the project can operate the requested
shape once an operator supplies approved live inputs. It does not mean this
repository has created AWS IAM roles, completed ChatGPT OAuth, mutated an EKS
cluster, deployed production, or written live GitHub Project fields during this
run.

## Cleanup

Disposable runtime scripts delete their `kind` clusters, remove temporary
workdirs, and report remaining same-name containers. Any failed run must keep
its transcript and cleanup status in the evidence directory before retrying.
