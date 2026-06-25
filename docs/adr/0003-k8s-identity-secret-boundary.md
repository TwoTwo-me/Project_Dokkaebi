# ADR 0003: Kubernetes Identity And Secret Boundary

## Status
Accepted

## Context
Project Dokkaebi now packages Fire, Hammer, LiteLLM, Prometheus, and Grafana
for Kubernetes operation. The platform must let Fire create approved Hammer
Jobs and broker LiteLLM virtual keys without handing raw OAuth material,
provider API keys, GitHub tokens, kubeconfigs, SSH keys, cloud credentials, or
LiteLLM master keys to Hammer.

The repository-owned base must also be safe before any EKS, shared-cluster, or
production deployment. Live AWS IAM, EKS Pod Identity, IRSA, provider egress,
and real credentials remain external authority gates.

## Decision
The Kubernetes identity and secret boundary is:

| Principal | Kubernetes identity | Allowed secret path | Denied secret path |
| --- | --- | --- | --- |
| Fire | `system:serviceaccount:dokkaebi-system:dokkaebi-fire` | Create/get/delete run-scoped LiteLLM virtual-key Secrets through the named broker Role only. | Read/list/watch arbitrary Secrets, mount provider credentials, mutate RBAC, namespaces, nodes, CRDs, or persistent volumes. |
| LiteLLM gateway | `system:serviceaccount:dokkaebi-llm:litellm` | Own provider credential/OAuth material and master-key configuration inside the gateway namespace. | Expose provider credentials, OAuth token directories, or the master key to Hammer pods. |
| Hammer workers | Route-specific `dokkaebi-workers` ServiceAccounts | Read only a Fire-brokered `DOKKAEBI_LITELLM_VIRTUAL_KEY` Secret that matches the ticket credential grant, run id, owner, TTL, and admission request user. | Receive provider API keys, ChatGPT OAuth files, GitHub tokens, kubeconfigs, cloud credentials, SSH keys, imagePullSecrets, projected Secrets, or broad Secret RBAC. |
| Observability | `prometheus` and `grafana` ServiceAccounts | Scrape and display bounded operational signals only. | Store raw prompts, tokens, API keys, OAuth payloads, command text, arbitrary exception strings, or private paths in metric labels or dashboards. |

For EKS, the selected live strategy is EKS Pod Identity or IRSA attached only to
the smallest ServiceAccount that needs AWS authority. The EKS overlay carries
placeholder identity annotations for Fire and LiteLLM so a live operator can
patch approved role ARNs without changing the base. Hammer ServiceAccounts do not receive AWS workload identity annotations by default.

## Enforcement
- `k8s/base/rbac-fire.yaml` gives Fire only namespace-scoped Job, Pod, log,
  Event, and non-secret ConfigMap access in `dokkaebi-workers`.
- `k8s/base/litellm.yaml` defines the only broker Secret writer Role with
  `create`, `get`, and `delete`; it does not allow `list` or `watch`.
- `k8s/base/admission-policy.yaml` allows Hammer Secret env only when the
  admission request user is Fire and the Secret name, key, owner, TTL, run id,
  and credential grant match the ticket labels.
- Rejected fixtures cover raw provider key delivery, LiteLLM master-key
  delivery, GitHub-token delivery, projected Secrets, imagePullSecrets, CSI
  Secret Store, and Hammer self-spoof attempts.
- Prometheus/Grafana configuration uses bounded labels and GitOps-managed
  dashboards; credentials and raw prompt material are never valid labels.

## Live Apply Gate
The repository reaches a complete local/sandbox boundary when render,
admission, RBAC, runtime smoke, LiteLLM virtual-key, Grafana/Prometheus, and
documentation validators pass. Live EKS mutation still requires a separate
Human approval record naming:

- AWS account and EKS cluster;
- selected Pod Identity or IRSA role ARN per ServiceAccount;
- credential owner, expiry, cleanup, and revocation evidence;
- provider-egress destinations and budgets;
- rollback plan and result-packet surface.

Without that record, placeholders remain placeholders and live apply must fail closed.

## Consequences
- Fire can operate as the Kubernetes orchestrator without becoming a general
  cluster or Secret administrator.
- Hammer can call models through LiteLLM with a task-scoped virtual key while
  staying blind to provider OAuth/API credentials.
- EKS deployment becomes a patchable overlay step rather than a base-manifest
  assumption.
- Future exceptions must be added through ADR, approval evidence, fixture
  coverage, validator updates, and cleanup receipts.
