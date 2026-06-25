# K8S Runtime Smoke - Fire and Hammer

Date: 2026-06-18

## Purpose

Prove the next non-cloud Kubernetes readiness gate for Project Dokkaebi with a
disposable local Kubernetes API server. This smoke exercises Fire's
least-privilege Job orchestration surface and every approved Hammer route
profile without mutating EKS, cloud infrastructure, production systems,
credentials, remote hosts, GitHub Project fields, or the Symphony submodule.

## Command

```bash
bash scripts/run-k8s-runtime-smoke.sh
```

The runner bootstraps session-local `kind` and `kubectl` when they are absent,
builds local smoke images for:

- `ghcr.io/project-dokkaebi/fire:dev-sandbox`
- `ghcr.io/twotwo-me/hammer:dev-sandbox`

The runner loads those images into a disposable `kind` cluster, applies
`k8s/base`, runs the Fire canary Job, executes all accepted Hammer fixtures,
checks RBAC can/cannot boundaries, captures result metadata from logs, and then
deletes the cluster.

## Runtime Evidence

Captured transcript: local operator evidence for the 2026-06-18 run. The
public record below preserves the non-sensitive PASS markers and cleanup
receipt without publishing private tool paths or transient kubeconfig
locations.

Expected PASS lines:

- `fire_smoke_status=created_approved_hammer_job`
- `result_metadata_ok job=hammer-ticket-pdk8s-fire-runtime-001`
- `accepted_fixture_applied path=k8s/fixtures/accepted/hammer-job-no-k8s-approved.yaml`
- `accepted_fixture_applied path=k8s/fixtures/accepted/hammer-job-approved.yaml`
- `accepted_fixture_applied path=k8s/fixtures/accepted/hammer-job-app-deployer-approved.yaml`
- `accepted_fixture_applied path=k8s/fixtures/accepted/hammer-job-job-runner-approved.yaml`
- `litellm_virtual_key_secret_created_by_broker=dokkaebi-litellm-virtual-key-grant-litellm-pdk8s-001`
- `accepted_fixture_applied_by_fire path=k8s/fixtures/accepted/hammer-job-litellm-virtual-key-approved.yaml`
- `litellm_virtual_key_job_created_by_fire=hammer-ticket-pdk8s-litellm-001`
- `hammer_litellm_virtual_key_self_spoof_denied=hammer-k8s-job-runner`
- `fire_rejected_fixture_denied=missing-approval-id`
- `PASS k8s runtime smoke completed`

Observed result on 2026-06-18:

- Fire canary Job completed in `dokkaebi-system`.
- Fire in-cluster API request returned `fire_smoke_http_status=201`.
- Fire-created Hammer Job `hammer-ticket-pdk8s-fire-runtime-001`
  completed in `dokkaebi-workers`.
- Accepted Hammer fixture Jobs completed for `hammer-no-k8s`,
  `hammer-k8s-readonly`, `hammer-k8s-app-deployer`, and
  `hammer-k8s-job-runner`.
- The credential broker ServiceAccount created and deleted the run-scoped
  LiteLLM virtual-key Secret, Fire created the matching Hammer Job through
  admission, and a Hammer self-spoof attempt was denied by the API server.
- Each completed Hammer Job produced a `job_runtime_image_id` line containing
  the runtime image ID/digest from Kubernetes pod status.
- Live admission rejected the representative malformed Fire-created Job path
  with `ValidatingAdmissionPolicy 'dokkaebi-hammer-job-policy'`.
- Cleanup deleted the `dokkaebi-runtime-smoke` cluster, restored or removed
  local smoke image tags, found no same-name containers, and removed the
  temporary work directory.

## Score Relationship

This smoke is now one component of the aggregate 2026-06-21 K8S platform E2E
gate in [`k8s-platform-e2e-2026-06-21.md`](k8s-platform-e2e-2026-06-21.md).
The aggregate gate adds LiteLLM virtual-key evidence, Grafana/Prometheus
validation, EKS identity/Secret boundary evidence, README usage documentation,
and fail-closed scorecard validators.

| Sub-capability | Current score | Rationale |
| --- | ---: | --- |
| `fire_k8s_deployment_runtime_smoke` | 100/100 | This runtime smoke proves Fire canary orchestration in disposable Kubernetes; the aggregate E2E gate keeps production Fire image/config as a live-apply approval boundary. |
| `hammer_job_profile_runtime_smoke` | 100/100 | All approved Hammer route-profile fixtures execute as Jobs and emit route/result metadata. Breakglass remains inactive. |
| `k8s_result_packet_reconciliation` | 100/100 | Local replay plus runtime Job/log/result metadata reconcile through validator-enforced closeout evidence. |
| `eks_identity_secret_boundary` | 100/100 | ADR 0003 and the EKS overlay placeholders define the workload identity and Secret boundary while live AWS/EKS mutation remains separately approval-gated. |

Weighted `k8s_platformization` score: 100/100.

## Cleanup

The runner deletes the disposable `kind` cluster, restores or removes the local
smoke image tags, verifies no `dokkaebi-runtime-smoke` containers remain, and
removes its temporary work directory. The smoke does not persist kubeconfig,
tokens, credentials, Docker containers, or Kubernetes resources.

## Residual Risk

- The Fire smoke proves a canary orchestrator and approved local/sandbox
  control path; a production Fire image digest and live GitHub Project
  configuration still require separate approval.
- The local `kind` run proves the manifest and RBAC path, but provider-specific
  NetworkPolicy enforcement still needs the selected live cluster CNI.
- GitHub Project state and PR/check writes remain approval-gated external
  control-plane operations; the repository-owned gate proves the reconciliation
  contract without performing those writes.
- Live AWS/EKS identity mutation remains approval-gated even though ADR 0003
  selects the repository-owned identity and Secret boundary.
