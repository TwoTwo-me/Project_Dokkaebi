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
- `ghcr.io/project-dokkaebi/hammer:dev-sandbox`

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
- Each completed Hammer Job produced a `job_runtime_image_id` line containing
  the runtime image ID/digest from Kubernetes pod status.
- Live admission rejected the representative malformed Fire-created Job path
  with `ValidatingAdmissionPolicy 'dokkaebi-hammer-job-policy'`.
- Cleanup deleted the `dokkaebi-runtime-smoke` cluster, restored or removed
  local smoke image tags, found no same-name containers, and removed the
  temporary work directory.

## Score Impact

| Sub-capability | Score after this smoke | Rationale |
| --- | ---: | --- |
| `fire_k8s_deployment_runtime_smoke` | 80/100 | A Fire canary Job starts in Kubernetes and creates an approved Hammer Job through the in-cluster API with least-privilege RBAC. It is not yet the production Fire Deployment image wired to live GitHub Project configuration. |
| `hammer_job_profile_runtime_smoke` | 100/100 | All approved Hammer route-profile fixtures execute as Jobs and emit route/result metadata. Breakglass remains inactive. |
| `k8s_result_packet_reconciliation` | 80/100 | Kubernetes Job state, logs, and result metadata reconcile locally. Live GitHub Project, PR/check, and stale/failed watch-loop reconciliation remain open. |
| `eks_identity_secret_boundary` | 0/100 | No approved live AWS/EKS identity evidence exists yet. |

Weighted `k8s_platformization` score: 92/100.

## Cleanup

The runner deletes the disposable `kind` cluster, restores or removes the local
smoke image tags, verifies no `dokkaebi-runtime-smoke` containers remain, and
removes its temporary work directory. The smoke does not persist kubeconfig,
tokens, credentials, Docker containers, or Kubernetes resources.

## Residual Risk

- The Fire smoke proves a canary orchestrator, not the production Fire
  Deployment package.
- The local `kind` run does not prove provider-specific NetworkPolicy
  enforcement for Fire egress to the Kubernetes API server.
- GitHub Project state, PR/check state, and stale/failed Job closeout remain
  replayed rather than live control-plane evidence.
- EKS workload identity and Secret boundaries remain unscored until explicitly
  approved live AWS/EKS evidence exists.
