# Kubernetes LiteLLM And Grafana Platform

This runbook defines the repository-owned Kubernetes package for operating
Dokkaebi Fire, Hammer route profiles, LiteLLM, Prometheus, Grafana, and
host-persistent data placeholders inside Kubernetes.

It is still a manifest and deterministic-validation package. Applying it to a
shared cluster, EKS, production, live credentials, live GitHub Project
control-plane state, or any external service remains approval-gated under
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Kubernetes Package

The base package is rendered from `k8s/base` and includes these planes:

| Plane | Kubernetes artifacts | Purpose |
| --- | --- | --- |
| Control | `dokkaebi-system`, `dokkaebi-fire`, `dokkaebi-fire-active-writer` Lease | Fire runs inside Kubernetes and must hold one active-writer Lease before dispatch. |
| Worker | `dokkaebi-workers`, Hammer ServiceAccounts, admission policy, route NetworkPolicy | Hammer Jobs stay route-scoped and are admitted only with ticket, approval, tenant, route, credential, and result-packet metadata. |
| LLM Gateway | `dokkaebi-llm`, LiteLLM, Postgres, broker Secret writer Role | LiteLLM owns provider credentials and token/spend logs; Hammer receives only a scoped virtual key. |
| Observability | `dokkaebi-observability`, Prometheus, Grafana provisioning, PVCs | Kubernetes work allocation, Hammer route health, LiteLLM usage, and credential-denial signals are visualized through bounded labels. |

Persistent state uses PVCs with the `dokkaebi-hostpath-placeholder` storage
class and `dokkaebi.io/host-persistence-placeholder: "true"` annotation. A
local operator may bind these PVCs to hostPath/PV storage such as
`/var/lib/dokkaebi/litellm/postgres`,
`/var/lib/dokkaebi/observability/prometheus`, and
`/var/lib/dokkaebi/observability/grafana`. Production storage classes, PVs,
backup policy, and retention owners require a separate approval record.
PVC-backed workloads set explicit `fsGroup` values so host-persistent paths can
be owned predictably by the non-root container users.

The base includes `allow-fire-kubernetes-api-egress` and
`allow-hammer-kubernetes-api-egress` NetworkPolicies with a placeholder
`10.96.0.1/32` Kubernetes service IP. A local or production overlay must patch
those CIDRs to the approved `kubernetes.default` service IP before applying
manifests to a NetworkPolicy-enforcing cluster. Hammer API egress selects only
pods labelled `dokkaebi.io/k8s-api-access=approved`, so `hammer-no-k8s` remains
outside that path. This keeps the base renderable while preventing catch-all API
egress.

LiteLLM provider egress is intentionally not opened in the base. An overlay must
add an approved provider-egress NetworkPolicy after the provider, destination,
budget, and credential owner are approved. Without that overlay, LiteLLM can
start with placeholder credentials but provider-backed model calls should fail
closed.

Public dependency images are pinned as `tag@sha256` references. The Fire image
is a private `ghcr.io/project-dokkaebi/fire:dev-sandbox` placeholder; live apply
requires an approved Fire build digest and a manifest patch that replaces that
placeholder before any shared-cluster, EKS, or production use.

## LiteLLM Credential Boundary

Hammer does not receive provider OAuth files, provider API keys, the LiteLLM
master key, GitHub tokens, kubeconfigs, SSH keys, or credential broker payloads.
The only Secret env exception in the Hammer admission policy is:

```text
request user: system:serviceaccount:dokkaebi-system:dokkaebi-fire
env name: DOKKAEBI_LITELLM_VIRTUAL_KEY
secret name: dokkaebi-litellm-virtual-key-${dokkaebi.io/credential-grant-id}
secret key: api-key
required labels: dokkaebi.io/litellm-key-scope=run-scoped,
  dokkaebi.io/litellm-key-ttl, dokkaebi.io/litellm-key-owner=fire-credential-broker,
  and dokkaebi.io/run-id
```

Fire or a Fire-owned credential broker creates the run-scoped Secret after
approval. The broker Role can `create`, `get`, and `delete` Secrets in
`dokkaebi-workers`; it cannot list or watch Secrets, and Hammer ServiceAccounts
receive no Secret RBAC. The virtual key must be generated in LiteLLM with model
allowlists, budget, TTL, team/user attribution, and revocation evidence.
A Hammer-created Job cannot self-spoof this exception because the admission
policy also checks the Kubernetes admission `request.userInfo.username`.

Codex-based Hammer images are built from `images/hammer/Dockerfile` and
published as `ghcr.io/twotwo-me/hammer:dev-sandbox` for the sandbox
image profile. The image contains Git, GitHub CLI, Python, `kubectl`, Codex,
and `scripts/setup-codex-litellm-from-dokkaebi-key.sh`. The
`.github/workflows/hammer-image.yml` workflow owns GitHub Container Registry
publishing with `packages: write`, immutable commit tags, and the `main` branch
`dev-sandbox` profile tag. Its entrypoint runs the helper before the ticket
command when a brokered
`DOKKAEBI_LITELLM_VIRTUAL_KEY` is injected. That helper reads only
`DOKKAEBI_LITELLM_VIRTUAL_KEY` or `LITELLM_API_KEY`, writes a private Codex key
file, configures `model_provider = "litellm"`, and moves any Codex `auth.json`
in that Hammer `CODEX_HOME` aside so the run does not depend on ChatGPT/Codex
OAuth. Hammer Jobs that use Codex mount `CODEX_HOME=/home/dokkaebi/.codex` and
`/tmp` as `emptyDir` volumes because admitted Hammer containers run with a
read-only root filesystem. Those Jobs set `fsGroup: 1000` and
`fsGroupChangePolicy: OnRootMismatch` so the non-root Hammer user can write the
Codex key and config files without changing the image filesystem.

## Observability

Prometheus uses static scrape targets for the repository-owned services:

- `dokkaebi-fire` metrics for dispatch latency, work allocation, route health,
  retries, and credential denials;
- `dokkaebi-litellm` metrics for gateway health, spend, token usage, model, and
  team attribution;
- `dokkaebi-work-allocation` for Hammer route allocation and backlog views.

Allowed labels are bounded to `project`, `environment`, `component`,
`route_class`, `provider`, `model`, `team`, and `approval_gate_status`. Raw
prompts, issue bodies, OAuth contents, provider API keys, LiteLLM master keys,
GitHub tokens, command text, private paths, and arbitrary exception messages
must not become metric labels.

Grafana is provisioned from ConfigMaps. Dashboard JSON is mounted from a
separate ConfigMap under `/etc/grafana/dashboards`, outside the Grafana data
PVC, so a fresh host-persistent volume does not have to pre-create dashboard
directories. Dashboards must remain GitOps-managed and read-only by default so
dashboard state can be reviewed through repository diffs.

## Versioning And Migration

The platform version is published through the `dokkaebi-platform-version`
ConfigMap:

- semantic platform version: `0.1.0-k8s`;
- release channel: `blue`;
- migration mode: `active-writer-lease-canary`.

Blue-green and canary migration use these rules:

1. Green Fire is deployed as a candidate and may observe state before it owns
   the active-writer Lease.
2. Only the Lease holder may dispatch Hammer Jobs or issue LiteLLM virtual-key
   grants.
3. Canary traffic is selected by explicit ticket, tenant, route profile, risk
   class, or approval label.
4. Promotion requires render validation, admission fixture replay,
   observability scrape proof, result-packet comparison, key revocation proof,
   and rollback plan.
5. Rollback means GitOps revert to the previous manifests, old route drain,
   virtual-key block/delete, and release-channel restoration.

Production, EKS, live credential, live GitHub Project, and shared-cluster
promotion remain approval-gated. The base manifests intentionally contain only
placeholder Secret values.

The base manifests include a zero-replica `dokkaebi-fire-green` candidate
Deployment with `DOKKAEBI_DISPATCH_ENABLED=false`, `dokkaebi.io/canary=true`,
and green release-track labels. Promotion requires explicitly scaling the green
candidate, proving Lease acquisition, comparing result packets, and then
changing the active release channel through GitOps.

## Runtime Proof And E2E Gate

This package is proven by the aggregate platform gate in
[`k8s-platform-e2e-2026-06-21.md`](k8s-platform-e2e-2026-06-21.md) and
`bash scripts/run-k8s-platform-e2e.sh`. The gate combines static render,
policy validation, scorecard validation, local runtime smoke, LiteLLM
virtual-key smoke, and documentation/link checks. Runtime smoke must run only
in an approved local or sandbox cluster:

- Fire creates and watches Hammer Jobs through the patched Kubernetes API egress
  rule, and K8S-capable Hammer profiles use a separate patched Hammer API
  egress rule;
- Fire or the broker calls LiteLLM key-generation with model allowlist, budget,
  team/user attribution, TTL, and safe fingerprint metadata;
- Hammer uses the virtual key and never sees provider OAuth/API keys or the
  LiteLLM master key; Codex inside Hammer uses the LiteLLM provider and a
  file-based auth command for that virtual key;
- Fire or the broker blocks/deletes the key and records revocation evidence in
  the result packet;
- Prometheus scrapes Fire/LiteLLM targets and Grafana loads the provisioned
  datasource/dashboard from ConfigMaps;
- green Fire candidate can observe, acquire the active-writer Lease only after
  approval, and roll back through GitOps.

The E2E gate completes the repository-owned local/sandbox proof. Live
production, EKS, shared-cluster, provider-credential, ChatGPT OAuth, or GitHub
Project control-plane operation remains a separate approval and live-apply
record, not an implied authority from the repository package.

## Validation

Run:

```bash
kubectl kustomize k8s/base > .omo/ulw-loop/evidence/k8s-render.yaml
bash scripts/validate-k8s-platformization.sh
bash scripts/validate-k8s-litellm-grafana-platform.sh
bash scripts/validate-k8s-result-reconciliation.sh
bash scripts/validate-k8s-platform-e2e.sh
bash scripts/run-k8s-platform-e2e.sh
```

The validators reject missing Kubernetes resources, live-looking Secret values,
broad Hammer Secret access, provider key delivery to Hammer, missing bounded
Prometheus labels, missing Grafana provisioning, and missing migration
guardrails.
