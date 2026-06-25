# Dokkaebi K8S Enterprise Architecture Assessment

Date: 2026-06-18
Updated: 2026-06-21

## Overall Verdict

The requested structure is feasible as an evidence-gated Kubernetes operating
system. Dokkaebi Fire can run inside Kubernetes, Dokkaebi Hammer can run as
scoped Jobs, selected Hammer profiles can create additional Kubernetes Jobs
inside their authority, LiteLLM can own the GPT/OAuth and provider credential
boundary, and Grafana/Prometheus can visualize work allocation and gateway
health.

The current repository-owned K8S platformization score is now 100/100. That
score is bounded to the manifest, policy, documentation, scorecard, and
approved local/sandbox E2E surfaces in this repository. It does not authorize
live AWS, EKS, shared-cluster, production, provider credentials, ChatGPT OAuth,
or GitHub Project control-plane mutation.

| Layer | Current state | Assessment |
| --- | --- | --- |
| Manager / governance contract | 100/100 in the program scorecard | Strong enough to govern K8S work and approval boundaries. |
| K8S platformization | 100/100 in `criteria.json` and `project-scorecard.md` | Complete for repository-owned local/sandbox operation with fail-closed live-apply gates. |
| Requested autonomous K8S operating model | Met within approved authority | Fire/Hammer/LiteLLM/Grafana are packaged and validated; live authority still requires explicit approval. |

## Target Architecture

```text
Human / GitHub Project Status
  -> Dokkaebi Manager contract and approval review
  -> Dokkaebi Fire blue/green control plane in Kubernetes
  -> namespace-scoped RBAC plus admission policy
  -> one Dokkaebi Hammer Job per approved ticket
  -> optional approved child Job creation through a route profile
  -> LiteLLM virtual key only, never raw provider OAuth/API credentials
  -> Prometheus and Grafana operational visibility
  -> logs, result packet, PR/check, and workpad evidence
  -> Manager closeout reconciliation
```

Kubernetes is the enforcement surface:

| Dokkaebi concept | Kubernetes control |
| --- | --- |
| Worker route | ServiceAccount, namespace, route-profile label, approved image profile. |
| Permission level | Role/RoleBinding plus admission checks. |
| Ticket approval | `dokkaebi.io/approval-id` and durable approval evidence. |
| Credential grant | `dokkaebi.io/credential-grant-id` plus broker-issued, scoped, expiring LiteLLM virtual keys. |
| Result packet | Required `DOKKAEBI_RESULT_PACKET_SINK` tied to the ticket id. |
| Version migration | Blue/green Fire Deployments, active-writer Lease, dispatch-off green default, and GitOps rollback. |
| Observability | Prometheus bounded labels and Grafana GitOps dashboards. |
| Scope boundary | Admission denial for host access, Secret references, root/default security context, broad mounts, unsafe token projection, and invalid route metadata. |

## Current Fit Matrix

| Requested capability | Current support | Evidence | Fit | Boundary |
| --- | --- | --- | ---: | --- |
| Runs Fire inside K8S | Fire blue/green manifests render, Fire canary starts in disposable Kubernetes, and Fire creates approved Hammer Jobs through the in-cluster API. | `k8s/base/platform-runtime.yaml`, `docs/operations/k8s-runtime-smoke-2026-06-18.md`, `docs/operations/k8s-platform-e2e-2026-06-21.md` | 100/100 | Production Fire image digest and live GitHub Project config remain live-apply approval gates. |
| Runs Hammer inside K8S | Approved Hammer route fixtures run as Kubernetes Jobs and emit route/result metadata. | `k8s/fixtures/accepted/*.yaml`, `k8s/runtime-smoke/hammer-result-packet.sh` | 100/100 | Breakglass remains disabled until later ADR and Human approval. |
| Hammer creates additional Pods within authority | The `hammer-k8s-job-runner` profile can create Jobs in `dokkaebi-workers`; those Jobs create Pods under admission and RBAC boundaries. | `k8s/base/rbac-hammer-profiles.yaml`, `k8s/base/admission-policy.yaml`, `scripts/run-k8s-runtime-smoke.sh` | 100/100 | It does not create raw Pods directly and has no Secret/RBAC/namespace/node authority. |
| Uses service operation and testbed safely | Disposable API server and runtime smoke scripts create isolated local clusters and record cleanup. | `docs/operations/k8s-disposable-api-server-smoke-2026-06-16.md`, `scripts/run-k8s-platform-e2e.sh` | 100/100 | Shared clusters and production remain separate approval targets. |
| Replaces Hammer-side OAuth with LiteLLM API keys | LiteLLM owns provider credentials and ChatGPT OAuth material; Hammer receives only task-scoped virtual keys. | `k8s/base/litellm.yaml`, `docs/operations/litellm-chatgpt-k8s-smoke-2026-06-18.md`, `docs/adr/0003-k8s-identity-secret-boundary.md` | 100/100 | Real provider credentials and ChatGPT OAuth login are operator-approved inputs. |
| Grafana visualization | Prometheus and Grafana are packaged with bounded labels and GitOps dashboard provisioning. | `k8s/base/observability.yaml`, `docs/operations/k8s-litellm-grafana-platform.md` | 100/100 | Live dashboards need approved persistence, scrape targets, and retention settings. |
| K8S version migration | Fire blue/green tracks, active-writer Lease, canary defaults, promotion and rollback rules are documented and validated. | `k8s/base/platform-runtime.yaml`, `docs/operations/k8s-platform-usage.md` | 100/100 | Promotion to live production still requires approval and rollback evidence. |
| Dokkaebi-K8S self-improvement | The readiness loop, scorecard, validators, E2E command, and usage docs support repeatable improvement from evidence. | `docs/enterprise-readiness/development-loop.md`, `scripts/run-k8s-platform-e2e.sh`, `scripts/validate-all.sh` | 100/100 | Self-improvement is not self-approval for credentials, EKS, production, merge, or deploy. |
| Enterprise audit and approval | Manager contract, authority policy, result packet templates, Git governance, K8S result sinks, and E2E evidence are durable. | `ARCHITECTURE.md`, `WORKFLOW.md`, `docs/templates/worker-result-packet.md`, `docs/operations/k8s-platform-e2e-2026-06-21.md` | 100/100 | Live external writes still require explicit Human approval. |
| EKS identity and Secret boundary | ADR 0003 selects the boundary; EKS overlay contains placeholder identity annotations for approved Fire/LiteLLM roles only. | `docs/adr/0003-k8s-identity-secret-boundary.md`, `k8s/overlays/eks/kustomization.yaml` | 100/100 | Placeholder role ARNs must not be applied live until AWS/EKS approval exists. |

## Capability Scorecard

| Area | Repository score | Meaning for the requested structure |
| --- | ---: | --- |
| K8S loop contract and issue publication | 100/100 | Work can be represented as dispatchable, evidence-backed K8S platformization issues. |
| Static K8S base controls | 100/100 | Namespace, ServiceAccount, RBAC, NetworkPolicy, Kustomize, LiteLLM, and Grafana baseline exist. |
| Admission fixture matrix | 100/100 | Unsafe Hammer Job and credential-delivery shapes fail closed in repository validation. |
| Accepted route profile fixtures | 100/100 | Approved Hammer profiles and the LiteLLM virtual-key route are represented by fixtures. |
| Disposable API server admission/RBAC proof | 100/100 | API-server-level admission and can/cannot RBAC have been proven locally. |
| Fire K8S deployment runtime smoke | 100/100 | Fire canary works locally and production rollout is represented as an approval-gated live-apply step. |
| Hammer Job profile runtime smoke | 100/100 | Hammer route profiles execute as Jobs and return metadata. |
| K8S result packet reconciliation | 100/100 | Local replay plus runtime Job/log/result metadata reconcile through validator-enforced closeout evidence. |
| EKS identity and Secret boundary | 100/100 | ADR 0003 and overlay placeholders define the boundary while live AWS/EKS mutation remains approval-gated. |

## Migration Model

Blue-green and canary migration are modeled as Manager-approved route migration:

```text
Version N active blue Fire
  -> publish version N+1 as green Fire / updated Hammer image profile
  -> validate render, admission, LiteLLM key lifecycle, Grafana/Prometheus, and runtime smoke
  -> run green with DOKKAEBI_DISPATCH_ENABLED=false
  -> observe or route selected low-risk tickets by approval label
  -> compare result packets, validation, Job state, PR/check state, and cleanup
  -> promote only after active-writer Lease handoff and Human approval when gated
  -> rollback through GitOps, old route drain, and virtual-key revocation
```

## Main Risks

| Risk | Current mitigation | Required boundary |
| --- | --- | --- |
| Duplicate dispatch during blue/green | Active-writer Lease and dispatch-off green default. | Only the Lease holder dispatches Hammer Jobs or issues LiteLLM grants. |
| Hammer privilege expansion | Route-specific ServiceAccounts, admission policy, denied fixtures, and runtime can/cannot smoke. | No Secret/RBAC/namespace/node/persistent-volume authority for Hammer. |
| Secret leakage | LiteLLM gateway owns provider credentials; admission denies raw keys, projected Secrets, imagePullSecrets, and self-spoofed virtual-key exceptions. | Hammer receives only approved virtual keys and result evidence never contains raw credentials. |
| State drift | Result-packet sink, runtime logs, replay matrix, scorecard validators, and E2E command. | Live GitHub Project and PR/check mutation still need approved control-plane evidence. |
| Overclaiming readiness | Scorecard and E2E docs state the 100 score is repository-owned local/sandbox proof. | Live AWS/EKS/production/provider operations remain approval-gated. |

## Recommended Continuous-Improvement Sequence

1. Keep the Fire production image digest and live GitHub Project configuration behind a signed approval record.
2. Align any Symphony `kubernetes_job` provider output with the root K8S admission contract before using it as a live dispatch path.
3. Expand canary selection rules when tenants, risk classes, or route profiles become more granular.
4. Re-run `bash scripts/run-k8s-platform-e2e.sh` whenever Fire, Hammer, LiteLLM, Grafana, admission policy, RBAC, or scorecard evidence changes.
5. Add a new ADR and fixture coverage before granting any new Secret, cloud, registry, or breakglass exception.

## Evidence Index

| Evidence surface | Role in this assessment |
| --- | --- |
| `README.md` | Names the Manager, Fire, Hammer, and Project Dokkaebi K8S operating lane. |
| `docs/operations/k8s-platform-usage.md` | First-time operator guide for validation, local sandbox use, LiteLLM, Grafana, migration, and EKS. |
| `docs/operations/k8s-platform-e2e-2026-06-21.md` | 100-point K8S platform E2E evidence record. |
| `docs/adr/0002-k8s-fire-hammer-platformization.md` | Accepts GitHub-led K8S Fire/Hammer platformization and guardrails. |
| `docs/adr/0003-k8s-identity-secret-boundary.md` | Selects the Fire, Hammer, LiteLLM, and EKS identity/Secret boundary. |
| `docs/enterprise-readiness/criteria.json` | Source of truth for 100/100 K8S platformization score and subcriteria. |
| `docs/enterprise-readiness/project-scorecard.md` | Program-readable scorecard and continuous-improvement gates. |
| `docs/operations/k8s-runtime-smoke-2026-06-18.md` | Local Fire/Hammer runtime smoke proof and cleanup record. |
| `docs/operations/litellm-chatgpt-k8s-smoke-2026-06-18.md` | LiteLLM gateway, virtual-key, and ChatGPT device-flow boundary proof. |
| `k8s/base/*` | Namespace, ServiceAccount, RBAC, admission, NetworkPolicy, Fire, LiteLLM, Prometheus, and Grafana baseline. |
| `k8s/overlays/eks/kustomization.yaml` | Approval-gated EKS workload identity placeholders. |
| `k8s/fixtures/*` | Accepted and rejected route/profile/admission/credential cases. |
| `scripts/run-k8s-platform-e2e.sh` | Aggregate K8S platform E2E command. |

## Validation Plan

```bash
bash scripts/validate-contract-docs.sh
bash scripts/validate-readiness-criteria.sh
bash scripts/validate-enterprise-scorecard.sh
bash scripts/validate-k8s-platformization.sh
bash scripts/validate-k8s-litellm-grafana-platform.sh
bash scripts/validate-k8s-platform-e2e.sh
bash scripts/run-k8s-platform-e2e.sh
bash scripts/validate-all.sh
```
