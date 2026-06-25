# Project Dokkaebi K8S Usage Guide

This guide explains how to run and validate the repository-owned Kubernetes
platform package for Project Dokkaebi. It is written for a first-time operator
who needs to understand what is safe to run locally, what must be configured
before a live cluster apply, and how Fire, Hammer, LiteLLM, Grafana, and
Prometheus fit together.

## What The Platform Contains

| Plane | Namespace | Main resources | Purpose |
| --- | --- | --- | --- |
| Fire control plane | `dokkaebi-system` | Fire blue/green Deployments, active-writer Lease, RBAC, NetworkPolicy | Watches approved work, owns dispatch, and creates Hammer Jobs only through scoped Kubernetes rights. |
| Hammer workers | `dokkaebi-workers` | Route ServiceAccounts, admission policy, accepted/rejected fixtures | Runs one bounded Job per ticket and returns evidence through the result-packet surface. |
| LiteLLM gateway | `dokkaebi-llm` | LiteLLM, Postgres, virtual-key broker Role, PVC placeholders | Keeps provider credentials and OAuth material in the gateway while giving Hammer only task-scoped virtual keys. |
| Observability | `dokkaebi-observability` | Prometheus, Grafana, dashboards, PVC placeholders | Shows Kubernetes work allocation, Hammer route health, LiteLLM usage, and credential-boundary signals. |

The base package is in [`../../k8s/base`](../../k8s/base). Local and EKS overlay
skeletons are in [`../../k8s/overlays`](../../k8s/overlays).
The local overlay routes the in-cluster `litellm` Service to the external
operator gateway at `10.10.40.150:4000` and scales the in-cluster LiteLLM and
Postgres Deployments to zero.

## Safety Model

You can render and validate the manifests locally without live credentials:

```bash
kubectl kustomize k8s/base
DOKKAEBI_K8S_E2E_RUNTIME=require bash scripts/run-k8s-platform-e2e.sh
```

These commands must not create production resources or issue real credentials.
They use repository fixtures, placeholder Secrets, and disposable local
Kubernetes when runtime smoke is enabled.

Do not apply to EKS, a shared cluster, production, or any cluster with live
provider credentials until a Human approval record names the cluster, provider
egress, credential owner, identity role, expiry, cleanup, and rollback plan.

## Prerequisites

For static validation:

- Bash
- Python 3 with PyYAML
- `kubectl` with Kustomize support

For full disposable runtime E2E:

- Docker
- `kind`
- `kubectl`
- Network access to pull public test images

The runtime scripts create disposable `kind` clusters and delete them on exit.
They do not require AWS, EKS, GitHub Project writes, real OpenAI provider keys,
or ChatGPT OAuth login.

## First Validation

Run the aggregate platform E2E gate:

```bash
DOKKAEBI_K8S_E2E_RUNTIME=require bash scripts/run-k8s-platform-e2e.sh
```

`require` mode is the 100-point scorecard gate. It must run both disposable
runtime smokes: Fire/Hammer orchestration and LiteLLM virtual-key lifecycle.
Use static mode only when the current machine cannot run Docker, `kind`, or
`kubectl`:

```bash
DOKKAEBI_K8S_E2E_RUNTIME=skip bash scripts/run-k8s-platform-e2e.sh
```

Static mode proves render, policy, scorecard, documentation, and
credential-boundary fixtures, but it is not enough to claim the 100-point
runtime gate.

The command writes a timestamped evidence directory and runs:

- `kubectl kustomize k8s/base`
- `bash scripts/validate-k8s-platformization.sh`
- `bash scripts/validate-k8s-litellm-grafana-platform.sh`
- `bash scripts/validate-k8s-result-reconciliation.sh`
- `bash scripts/validate-k8s-platform-e2e.sh`
- `bash scripts/validate-readiness-criteria.sh`
- `bash scripts/validate-enterprise-scorecard.sh`
- `bash scripts/validate-all.sh`
- `bash scripts/run-k8s-runtime-smoke.sh` when local Docker, `kind`, and
  `kubectl` are available
- `bash scripts/run-litellm-chatgpt-k8s-smoke.sh` when local runtime tools are
  available, unless `DOKKAEBI_SKIP_LITELLM_RUNTIME_SMOKE=1`

Useful controls:

```bash
DOKKAEBI_K8S_E2E_EVIDENCE_DIR=.omo/ulw-loop/evidence/my-run DOKKAEBI_K8S_E2E_RUNTIME=require bash scripts/run-k8s-platform-e2e.sh
DOKKAEBI_K8S_E2E_RUNTIME=skip bash scripts/run-k8s-platform-e2e.sh
```

Explicit runtime skip flags fail closed in `require` mode.

## Applying To A Local Sandbox

For a manually managed disposable cluster, prefer the E2E runner first. It
builds the smoke images, creates and deletes disposable clusters, and records
cleanup. Manual apply is mainly for manifest inspection after you prepare local
patches.

Review-only apply:

```bash
kind create cluster --name dokkaebi-sandbox
kubectl apply -k k8s/base
kubectl get namespaces
kubectl get deploy -A
```

The base uses placeholders and should not be expected to become fully Ready as
an operating stack without patches. Before expecting all Pods to become Ready,
prepare a local overlay or patch set for these items:

- Patch the Fire image to an approved immutable digest.
- Bind PVCs to a real local storage class or hostPath-backed PVs.
- Patch the Kubernetes API Service IP in
  `allow-fire-kubernetes-api-egress` and
  `allow-hammer-kubernetes-api-egress` for your cluster.
- If using the local overlay, confirm the external LiteLLM gateway at
  `10.10.40.150:4000` is approved and reachable from the cluster.
- Add any other approved provider-egress NetworkPolicy for LiteLLM only after
  provider, destination, budget, and credential owner are approved.
- Replace placeholder LiteLLM/Postgres/Grafana Secret values through an
  approved Secret management path.

Useful local inspection commands:

```bash
kubectl get svc kubernetes -o jsonpath='{.spec.clusterIP}{"\n"}'
kubectl get pvc -A
kubectl describe pvc -n dokkaebi-llm litellm-postgres-data
kubectl describe pvc -n dokkaebi-observability prometheus-data
kubectl describe pvc -n dokkaebi-observability grafana-data
kubectl get secret -n dokkaebi-llm litellm-runtime-placeholder -o yaml
kubectl get secret -n dokkaebi-observability grafana-admin-placeholder -o yaml
```

Use `kubectl create secret ... --dry-run=client -o yaml` and a reviewed
overlay when replacing placeholders. Do not edit live Secret values into the
repository.

## LiteLLM And GPT/OAuth Boundary

Provider credentials and ChatGPT OAuth material belong inside the LiteLLM
gateway, not inside Hammer. The normal flow is:

1. Operator approves a provider credential or ChatGPT OAuth token directory for
   the LiteLLM gateway.
2. Fire requests a LiteLLM virtual key for one ticket/run with a model allowlist,
   budget, TTL, team/user attribution, and result-packet metadata.
3. Fire creates a run-scoped Secret named from the credential-grant id.
4. Hammer receives only `DOKKAEBI_LITELLM_VIRTUAL_KEY`.
5. Fire or the broker blocks/deletes the virtual key at closeout and records
   revocation evidence.

Hammer must never receive raw `OPENAI_API_KEY`, `LITELLM_MASTER_KEY`,
`GITHUB_TOKEN`, ChatGPT OAuth files, kubeconfigs, SSH keys, cloud credentials,
or GitHub App private keys.

For Codex-based Hammer runtimes, build and deploy the repository Hammer image
from [`../../images/hammer/Dockerfile`](../../images/hammer/Dockerfile). The
approved sandbox image reference is
`ghcr.io/twotwo-me/hammer:dev-sandbox`. The image includes Git, GitHub
CLI, Python, `kubectl`, Codex, and the repository helper
[`../../scripts/setup-codex-litellm-from-dokkaebi-key.sh`](../../scripts/setup-codex-litellm-from-dokkaebi-key.sh).
GitHub publishes the image through
[`../../.github/workflows/hammer-image.yml`](../../.github/workflows/hammer-image.yml)
with `packages: write`; branch pushes publish immutable
`dev-sandbox-${GITHUB_SHA}` tags, and `main` publishes the mutable
`dev-sandbox` sandbox profile tag.
The image entrypoint runs the helper before the ticket command when
`DOKKAEBI_LITELLM_VIRTUAL_KEY` is present:

```bash
export CODEX_HOME=/home/dokkaebi/.codex
export DOKKAEBI_LITELLM_BASE_URL=http://litellm.dokkaebi-llm.svc.cluster.local:4000
export DOKKAEBI_LITELLM_MODEL=chatgpt/gpt-5.5
scripts/setup-codex-litellm-from-dokkaebi-key.sh
codex app-server
```

The helper accepts `DOKKAEBI_LITELLM_VIRTUAL_KEY` from the approved Secret env,
writes it to `CODEX_HOME/litellm_api_key` with mode `600`, configures
`model_provider = "litellm"` with the Responses wire API, and disables any
`auth.json` in that Codex home by moving it to a timestamped backup. A Hammer
Pod uses `CODEX_HOME=/home/dokkaebi/.codex` on an `emptyDir` volume plus a
separate `/tmp` `emptyDir` because the admitted Hammer security context keeps
`readOnlyRootFilesystem: true`. Set `fsGroup: 1000` with
`fsGroupChangePolicy: OnRootMismatch` on Codex-enabled Hammer Jobs so those
volumes are writable by the non-root Hammer process. Do not mount a user or Manager
`~/.codex/auth.json` into Hammer, and do not bake `DOKKAEBI_LITELLM_VIRTUAL_KEY`
or any provider key into the image.

For the current sandbox where LiteLLM runs outside the cluster, render or apply
the local overlay:

```bash
kubectl kustomize k8s/overlays/local
kubectl apply -k k8s/overlays/local
```

The overlay keeps the service name stable as
`http://litellm.dokkaebi-llm.svc.cluster.local:4000` while routing it to
`10.10.40.150:4000`.

Detailed LiteLLM/ChatGPT references:

- [`litellm-chatgpt-homelab-gateway.md`](litellm-chatgpt-homelab-gateway.md)
  explains the optional ChatGPT homelab gateway setup.
- [`litellm-chatgpt-k8s-smoke-2026-06-18.md`](litellm-chatgpt-k8s-smoke-2026-06-18.md)
  records the Kubernetes smoke. The repo smoke reaches the ChatGPT OAuth
  device-flow gate and proves the LiteLLM virtual-key boundary, but it does not
  complete ChatGPT OAuth or prove successful ChatGPT model output.

## Grafana And Prometheus

Prometheus scrapes bounded operational signals for Fire, LiteLLM, and work
allocation. Grafana is provisioned from ConfigMaps and reads dashboards from
`/etc/grafana/dashboards`, outside the Grafana data PVC.

Use Grafana to answer operational questions such as:

- How many jobs are allocated by Hammer route profile?
- Which Fire channel owns dispatch?
- Is LiteLLM healthy and within token/spend budgets?
- Are credential requests being denied by policy?

Do not put prompts, API keys, OAuth payloads, command text, private paths, or
raw exception messages into metric labels.

For local access after a patched local apply:

```bash
kubectl port-forward -n dokkaebi-observability svc/grafana 3000:3000
kubectl get secret -n dokkaebi-observability grafana-admin-placeholder -o jsonpath='{.data.admin-user}' | base64 -d; echo
kubectl get secret -n dokkaebi-observability grafana-admin-placeholder -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl port-forward -n dokkaebi-observability svc/prometheus 9090:9090
```

Open Grafana at `http://127.0.0.1:3000`, confirm the provisioned Prometheus
datasource, and open the `Dokkaebi Platform` dashboard. Open Prometheus at
`http://127.0.0.1:9090/targets` to confirm scrape target health.

## Blue-Green Migration

Fire is deployed with a blue active track and a green candidate track:

1. Keep green at zero replicas while preparing a new version.
2. Scale green as an observer with `DOKKAEBI_DISPATCH_ENABLED=false`.
3. Validate render, admission fixtures, runtime smoke, LiteLLM key lifecycle,
   Grafana/Prometheus visibility, and result-packet comparison.
4. Promote only after the active-writer Lease, approval record, rollback plan,
   and GitOps diff are reviewed.
5. Roll back by restoring the previous GitOps manifests, draining old routes,
   revoking virtual keys, and restoring the previous release channel.

Only the active-writer Lease holder may dispatch Hammer Jobs or issue
LiteLLM virtual-key grants.

## EKS Overlay

The EKS overlay contains placeholder workload identity annotations for Fire and
LiteLLM. Replace those placeholders only after approval selects EKS Pod
Identity or IRSA role ARNs. Hammer ServiceAccounts do not receive AWS workload
identity by default.

```bash
kubectl kustomize k8s/overlays/eks
```

Live `kubectl apply -k k8s/overlays/eks` remains blocked until the approval
record names the AWS account, EKS cluster, IAM roles, provider egress, secrets,
budget, cleanup, and rollback.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `kubectl kustomize` fails | Run `bash scripts/validate-k8s-platformization.sh` and inspect the rendered object named in the failure. |
| Hammer fixture is denied unexpectedly | Confirm route profile, ServiceAccount, ticket, tenant, approval, credential-grant, image-profile, resource, securityContext, and result sink labels. |
| Hammer can see raw provider credentials | Treat as a security failure; run `bash scripts/validate-k8s-litellm-grafana-platform.sh` and inspect Secret env/volume references. |
| Fire cannot create Jobs | Check the `dokkaebi-fire-job-orchestrator` RoleBinding and `kubectl auth can-i` output from the runtime smoke transcript. |
| LiteLLM worker gets 401 | Confirm the virtual key was generated, scoped to the model, not blocked, and mounted only as `DOKKAEBI_LITELLM_VIRTUAL_KEY`. |
| Grafana dashboard missing | Confirm `grafana-dashboard-dokkaebi-platform` exists and the provisioning ConfigMap points to `/etc/grafana/dashboards`. |

## Required Closeout Evidence

Before claiming a platform change complete, collect:

- changed artifact list and rationale;
- E2E command transcript;
- rendered manifest evidence;
- accepted and rejected admission fixture evidence;
- RBAC can/cannot evidence;
- LiteLLM virtual-key generation/blocking evidence when runtime smoke runs;
- Grafana/Prometheus provisioning evidence;
- cleanup receipt for disposable clusters;
- approval-gate status and residual risk.
