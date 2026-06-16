# K8S Platformization Fixture Replay

Date: 2026-06-14

This repository-local replay closes the first concrete evidence gap for the
K8S platformization lane. It does not contact a Kubernetes API server, create
GitHub issues, mutate GitHub Project fields, create credentials, deploy
workloads, or touch cloud, EKS, Docker, remote hosts, production, or shared
cluster resources.

## Iteration Boundary

This replay closes only the docs, fixture, and validator-enforcement iteration
for `k8s_platformization`. It intentionally leaves the readiness area below
100% because live or approved-sandbox runtime proof is still required.

Remaining runtime gaps are not hidden by this replay. They stay published as
`nextIssues` in `docs/enterprise-readiness/criteria.json` until separate issues
produce accepted evidence for admission installation, Fire startup, Hammer Job
profile smoke, GitHub/Kubernetes/result-packet reconciliation, and EKS workload
identity.

## Scope

The replay covers:

- accepted and rejected Hammer Job admission fixtures;
- repo-local ValidatingAdmissionPolicy and binding artifacts for Hammer Jobs;
- Fire ServiceAccount can/cannot expectations from the static RBAC baseline;
- Hammer ServiceAccount profile boundaries;
- Fire and Hammer namespace default-deny plus DNS-only NetworkPolicy baselines;
- GitHub Project, Job status, logs, PR/check, and result-packet reconciliation
  cases;
- EKS workload identity and Secret boundary decision for the next issue.
- an exact K8S `currentEvidence` lock that prevents scorecard, readiness, and
  platformization validators from drifting onto different evidence lists.

## Admission Fixture Matrix

| Fixture | Expected decision | Evidence |
| --- | --- | --- |
| `k8s/fixtures/accepted/hammer-job-approved.yaml` | Accept | Includes ticket, tenant, approval, route profile, credential grant, image profile, namespace, ServiceAccount match, result packet sink, resource requests/limits, and non-privileged security context. |
| `k8s/fixtures/rejected/missing-approval-id.yaml` | Reject | Missing `dokkaebi.io/approval-id`. |
| `k8s/fixtures/rejected/mismatched-serviceaccount-profile.yaml` | Reject | Route profile is `hammer-k8s-readonly` but ServiceAccount is `hammer-k8s-job-runner`. |
| `k8s/fixtures/rejected/privileged-hostpath.yaml` | Reject | Legacy filename retained; the fixture now isolates a single `hostPath` denial while preserving the approved non-root container context. |
| `k8s/fixtures/rejected/secret-env-reference.yaml` | Reject | References a Kubernetes Secret through volume and env valueFrom. |
| `k8s/fixtures/rejected/missing-result-packet-sink.yaml` | Reject | Omits `DOKKAEBI_RESULT_PACKET_SINK`, so closeout evidence would exist only in process memory or logs. |
| `k8s/fixtures/rejected/missing-container-security-context.yaml` | Reject | Omits the main container `securityContext`, leaving default-root and default-capability behavior ambiguous. |
| `k8s/fixtures/rejected/missing-pod-security-context.yaml` | Reject | Omits the pod-level `securityContext`, leaving the pod non-root and seccomp baseline unenforced. |
| `k8s/fixtures/rejected/hostnetwork.yaml` | Reject | Enables `hostNetwork: true`, bypassing the worker namespace network boundary. |
| `k8s/fixtures/rejected/hostport.yaml` | Reject | Binds a container port directly to a node `hostPort`, bypassing the namespace network boundary. |
| `k8s/fixtures/rejected/broad-volume-mount.yaml` | Reject | Mounts a volume at `/`, creating a broad filesystem overlay instead of a narrow work directory. |
| `k8s/fixtures/rejected/hostpid.yaml` | Reject | Enables `hostPID: true`, exposing host process namespace state to a ticket worker. |
| `k8s/fixtures/rejected/hostipc.yaml` | Reject | Enables `hostIPC: true`, exposing host IPC namespace state to a ticket worker. |
| `k8s/fixtures/rejected/share-process-namespace.yaml` | Reject | Enables `shareProcessNamespace: true`, allowing sidecar/process snooping inside a worker Pod. |
| `k8s/fixtures/rejected/init-container-privileged.yaml` | Reject | Uses a privileged initContainer, which must be covered by the same admission boundary as the main worker container. |
| `k8s/fixtures/rejected/ephemeral-container-privileged.yaml` | Reject | Uses a privileged ephemeralContainer/debug surface, which must not bypass the Hammer Job admission profile. |
| `k8s/fixtures/rejected/root-pod-security-context.yaml` | Reject | Sets pod-level root execution, bypassing the non-root worker baseline. |
| `k8s/fixtures/rejected/no-k8s-token-override.yaml` | Reject | Selects `hammer-no-k8s` but forces `automountServiceAccountToken: true`, bypassing the no-Kubernetes-token route boundary. |
| `k8s/fixtures/rejected/unapproved-image-profile.yaml` | Reject | Uses an image/profile outside the approved Hammer image profile allowlist. |
| `k8s/fixtures/rejected/invalid-result-packet-sink.yaml` | Reject | Sends result evidence to an unapproved non-workpad sink. |
| `k8s/fixtures/rejected/wrong-kind.yaml` | Reject | Presents a non-Job object through the repo-local Hammer Job fixture schema path before policy dispatch. |
| `k8s/fixtures/rejected/projected-serviceaccount-token.yaml` | Reject | Projects an explicit Kubernetes API token volume outside the route profile boundary. |
| `k8s/fixtures/rejected/projected-secret.yaml` | Reject | Projects Secret material through a projected volume source. |
| `k8s/fixtures/rejected/csi-secret-store.yaml` | Reject | Mounts Secret material through a CSI secret-store volume. |
| `k8s/fixtures/rejected/image-pull-secrets.yaml` | Reject | References Kubernetes Secret material through `imagePullSecrets`, bypassing the default-denied Secret boundary. |
| `k8s/fixtures/rejected/overlay-traversal-kustomization.yaml` | Reject | Adds a non-base traversal resource to an overlay kustomization. |
| `k8s/fixtures/rejected/rbac-extra-workload-permission.yaml` | Reject | Adds an unauthorized workload mutation rule outside the exact RBAC allowlist. |
| `k8s/fixtures/rejected/empty-approval-id.yaml` | Reject | Keeps the approval label key but leaves the approval value empty. |
| `k8s/fixtures/rejected/empty-credential-grant-id.yaml` | Reject | Keeps the credential grant label key but leaves the grant value empty. |
| `k8s/fixtures/rejected/empty-ticket-id.yaml` | Reject | Keeps the ticket label key but leaves the ticket value empty. |
| `k8s/fixtures/rejected/container-privileged-only.yaml` | Reject | Sets only the main container `privileged: true` while preserving the rest of the accepted fixture shape. |
| `k8s/fixtures/rejected/capabilities-add.yaml` | Reject | Adds a Linux capability despite dropping `ALL`. |
| `k8s/fixtures/rejected/ephemeral-container-secret-env.yaml` | Reject | Adds Secret env access through an ephemeral debug container. |
| `k8s/fixtures/rejected/ephemeral-container-root-mount.yaml` | Reject | Adds a root filesystem mount through an ephemeral debug container. |
| `k8s/fixtures/rejected/bare-result-packet-sink.yaml` | Reject | Uses only the result sink prefix without the matching ticket id suffix. |
| `k8s/fixtures/rejected/duplicate-invalid-result-packet-sink.yaml` | Reject | Includes one valid result sink plus a duplicate invalid sink, proving every sink entry must match the ticket id. |
| `k8s/fixtures/rejected/duplicate-empty-result-packet-sink.yaml` | Reject | Includes one valid result sink plus a duplicate empty sink, proving empty duplicates cannot be ignored. |
| `k8s/fixtures/rejected/init-container-invalid-result-packet-sink.yaml` | Reject | Adds an alternate result sink through an initContainer while the main container keeps the valid sink. |
| `k8s/fixtures/rejected/init-container-empty-result-packet-sink.yaml` | Reject | Adds an empty duplicate result sink through an initContainer while the main container keeps the valid sink. |
| `k8s/fixtures/rejected/ephemeral-container-invalid-result-packet-sink.yaml` | Reject | Adds an alternate result sink through an ephemeralContainer while the main container keeps the valid sink. |
| `k8s/fixtures/rejected/ephemeral-container-empty-result-packet-sink.yaml` | Reject | Adds an empty duplicate result sink through an ephemeralContainer while the main container keeps the valid sink. |
| `k8s/fixtures/rejected/empty-resources.yaml` | Reject | Keeps the resources keys but leaves requests and limits empty, proving non-empty resource maps are required. |

## Fire Static Can/Cannot Matrix

| Capability | Expected result | Evidence surface |
| --- | --- | --- |
| Create approved Hammer Jobs in `dokkaebi-workers` | Can | `k8s/base/rbac-fire.yaml` grants `batch/jobs` create/get/list/watch/delete. |
| Read Job Pods and logs | Can | `k8s/base/rbac-fire.yaml` grants `pods` get/list/watch and `pods/log` get. |
| Read Events and non-secret ConfigMaps | Can | `k8s/base/rbac-fire.yaml` grants Events and ConfigMaps get/list/watch. |
| Read/list/watch Secrets | Cannot | `scripts/validate-k8s-platformization.sh` rejects `secrets` in any Role. |
| Mutate RBAC, namespaces, CRDs, nodes, or persistent volumes | Cannot | `scripts/validate-k8s-platformization.sh` rejects those resources and any ClusterRole/ClusterRoleBinding. |

## Hammer Profile Matrix

| Profile | ServiceAccount | Expected boundary |
| --- | --- | --- |
| `hammer-no-k8s` | `hammer-no-k8s` | No Kubernetes token mounted and no RoleBinding. |
| `hammer-k8s-readonly` | `hammer-k8s-readonly` | Namespace-scoped read-only pods, logs, events, ConfigMaps, and Jobs. |
| `hammer-k8s-app-deployer` | `hammer-k8s-app-deployer` | Namespace-scoped app resource reader until controller admission coverage is approved; no Secret, RBAC, namespace, node, persistent-volume, or workload mutation authority. |
| `hammer-k8s-job-runner` | `hammer-k8s-job-runner` | Namespace-scoped batch Job runner covered by the repo-local admission artifact; no CronJob, Secret, RBAC, namespace, node, or persistent-volume authority. |
| `hammer-breakglass` | `hammer-breakglass` | Disabled, no token mounted, and no RoleBinding until later ADR plus explicit Human approval defines reason, expiry, audit, and cleanup. |

## Reconciliation Replay

| Case | GitHub Project state | Kubernetes Job state | Result evidence | Manager decision |
| --- | --- | --- | --- | --- |
| Accepted closeout | Needs Review | Job complete, logs collected | Result packet cites ticket id, route profile, namespace, ServiceAccount, image digest, exit status, validation output, PR/check link, and cleanup receipt | Move to Human Review or Merging only after approval and checks. |
| Missing result packet | Needs Review | Job complete | No durable result packet sink or workpad evidence | Reject closeout and request worker fixup. |
| Failed Job | In Progress | Job failed | Logs surface exists but no passing validation | Move to Fix Requested, Blocked, or Failed with route/result metadata preserved. |
| Status drift | Done | Job still running or missing | PR/check/result evidence incomplete | Reopen or block Done until GitHub Project, Job state, PR/check, and result-packet evidence reconcile. |
| Stale Job | In Progress | Job active past TTL or lease window | No fresh logs or heartbeat | Create follow-up or recovery ticket with stale lease and cleanup evidence. |

Closeout evidence must remain outside Manager memory. The accepted path uses
GitHub workpad/result packet references first; future CRD/status or audit DB
surfaces need their own issue, validator, backup/restore, and approval evidence.

## EKS Identity And Secret Boundary

Initial decision: defer live EKS identity mutation and use a future issue to
choose EKS Pod Identity versus IRSA from evidence. Until that decision is
accepted:

- Secret access remains default denied for Fire and Hammer.
- Any named Secret exception requires explicit Human approval, reason, expiry,
  and cleanup evidence.
- `imagePullSecrets` are treated as Secret references and remain denied until a
  later ADR names an approved registry-credential exception.
- Raw Manager PATs, OAuth tokens, SSH private keys, kubeconfigs, cloud
  credentials, and GitHub App private keys must not appear in issue bodies,
  result packets, Job env, logs, or artifacts.
- Workload identity must be attached to the smallest ServiceAccount profile
  that can satisfy the ticket.

## Validation

Required local validation:

```bash
bash scripts/validate-k8s-platformization.sh
bash scripts/validate-readiness-criteria.sh
bash scripts/validate-enterprise-scorecard.sh
bash scripts/validate-contract-docs.sh
bash scripts/validate-all.sh
```

## Approval-Gate Status

Closed for this replay. No live GitHub issue, GitHub Project, Kubernetes,
Docker, remote host, cloud, EKS, credential, worker, deployment, production, or
shared cluster mutation was performed or authorized.

## Cleanup

No runtime resources, ports, containers, clusters, credentials, browser
contexts, tmux sessions, or temp directories are created by this replay.
