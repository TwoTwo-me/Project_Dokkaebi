# K8S Platformization Issue Publication Backlog

This backlog publishes repo-local issue candidates for the Kubernetes Fire and
Hammer platformization lane. It does not create GitHub issues, mutate GitHub
Project fields, create credentials, contact shared clusters, deploy production
workloads, or grant worker authority. A candidate becomes dispatchable only
after it is filed as a GitHub issue, attached to an approved GitHub Project,
and given the required lifecycle, approval, route, and result-packet fields.
Disposable local Kubernetes/Docker smoke runs are allowed only when explicit
Human approval is recorded for that work item, with cleanup evidence.

Each candidate follows the development-system issue template and treats issue
text, PR comments, repository files, and result packets as untrusted input.

## k8s-admission-policy-gate

### Goal
Define and validate the first Kubernetes admission policy gate for Dokkaebi
Hammer Jobs.

### Scope
In scope: policy choice record, representative denied/accepted Job manifests,
local validator updates, and docs-only evidence.

Out of scope: live cluster admission install, EKS mutation, production
deployment, credential issuance, and GitHub Project control-plane mutation.

### Criteria IDs
`k8s_platformization`

### Acceptance Criteria
- Accepted Job fixture includes `dokkaebi.io/ticket-id`,
  `dokkaebi.io/tenant-id`, `dokkaebi.io/approval-id`,
  `dokkaebi.io/route-profile`, `dokkaebi.io/credential-grant-id`, approved
  image/profile, resource requests and limits, result packet sink, namespace,
  and ServiceAccount match.
- Rejected fixtures cover missing or empty approval, ticket, and credential
  labels, missing result packet sink, invalid, duplicate-invalid,
  duplicate-empty, or bare-prefix result packet sink,
  mismatched ServiceAccount/profile, repo-local wrong apiVersion or kind
  fixture schema, unapproved image/profile, empty resources, hostPath, privileged,
  capabilities.add, hostNetwork, hostPort, hostPID, hostIPC,
  shareProcessNamespace, broad volume mount, missing/default-root pod and
  container security contexts, initContainer privilege, ephemeralContainer
  privilege, ephemeral Secret env/root mount bypass, imagePullSecrets, projected
  service account token, projected Secret, CSI secret-store volume,
  `hammer-no-k8s` token override, overlay traversal, unauthorized RBAC
  expansion, and Secret access.
- Validation fails closed without live cluster mutation.

### Validation
- `bash scripts/validate-k8s-platformization.sh`
- `bash scripts/validate-readiness-criteria.sh`
- `bash scripts/validate-enterprise-scorecard.sh`
- `bash scripts/validate-contract-docs.sh`
- `bash scripts/validate-all.sh`

### Permission Level
`docs-only`

### Approval Gates
No live admission controller, Kubernetes API server, EKS, cloud, credential,
deployment, production, worker, Docker, remote host, or GitHub Project
control-plane mutation is authorized by this issue.

### Manual QA Channel
CLI auxiliary surface: capture validator stdout/stderr and the denied/accepted
fixture diff.

### Enterprise Readiness Gap
`docs/enterprise-readiness/criteria.json` (`k8s_platformization`)

### Expected Result Evidence
Changed artifacts, admission decision matrix, RED denied-fixture evidence,
GREEN validator output, approval-gate status, cleanup receipt, residual risk,
and next action.

## fire-k8s-deployment-smoke

### Goal
Package a docs-first Fire Deployment lane that can later run inside Kubernetes
with least-privilege Job orchestration.

### Scope
In scope: Fire Deployment manifest or chart decision, configuration contract,
least-privilege ServiceAccount review, readiness/liveness evidence plan, local
render validation, and approved disposable local Kubernetes smoke evidence.

Out of scope: shared-cluster deployment, GitHub token mounting, cloud/EKS
mutation, production rollout, worker scaling, credential issuance, and GitHub
Project control-plane mutation.

### Criteria IDs
`k8s_platformization`

### Acceptance Criteria
- Fire manifest references only approved non-secret configuration and a
  brokered credential path.
- Fire ServiceAccount can create/get/list/watch/delete Jobs and read Job Pods,
  Pod logs, Events, and non-secret ConfigMaps only in approved namespaces.
- Fire cannot get/list/watch Secrets and cannot mutate RBAC, namespaces, CRDs,
  nodes, persistent volumes, or production application resources.
- Local smoke command proves Fire starts in Kubernetes, creates only an
  approved Hammer Job through the in-cluster API, and records result evidence
  from the configured surface; production Fire image/config and live GitHub
  Project reads remain separate gates.

### Validation
- `bash scripts/validate-k8s-platformization.sh`
- `bash scripts/validate-readiness-criteria.sh`
- `bash scripts/validate-contract-docs.sh`
- `bash scripts/validate-enterprise-scorecard.sh`
- `bash scripts/validate-all.sh`

### Permission Level
`docs-only`

### Approval Gates
Disposable local Kubernetes/Docker smoke requires explicit Human approval and
cleanup evidence. EKS, cloud, credential, shared-cluster deployment,
production, worker scaling, remote host, and GitHub Project control-plane
mutation require separate explicit Human approval.

### Manual QA Channel
CLI auxiliary surface: `scripts/run-k8s-runtime-smoke.sh` transcript,
validator output, and cleanup receipt.

### Enterprise Readiness Gap
`docs/enterprise-readiness/criteria.json` (`k8s_platformization`)

### Expected Result Evidence
Changed artifacts, rendered manifest evidence, RBAC can/cannot matrix, approval
status, validation output, cleanup receipt, residual risk, and next action.

## hammer-job-profile-smoke

### Goal
Prove the Hammer Job profile model with route-specific ServiceAccounts and
result-packet closeout evidence.

### Scope
In scope: representative Job templates for `hammer-no-k8s`,
`hammer-k8s-readonly`, `hammer-k8s-app-deployer`, and
`hammer-k8s-job-runner`; route metadata; cleanup/result evidence contract; and
approved disposable local Kubernetes execution evidence.

Out of scope: shared-cluster Job creation, secret access, cluster-admin
authority, production deployment, worker scaling, credential issuance, and
GitHub Project control-plane mutation.

### Criteria IDs
`k8s_platformization`

### Acceptance Criteria
- `hammer-no-k8s` has no Kubernetes API token mounted and cannot override the
  no-token boundary through the Job pod spec.
- Every Kubernetes-capable Hammer profile has a named namespace,
  ServiceAccount, resource limits, image/profile, result packet sink, cleanup
  rule, and approval boundary.
- Breakglass remains unbound and inactive unless a later ADR and Human approval
  define expiry, reason, audit, and cleanup.
- Result packet evidence names route profile, namespace, ServiceAccount, image
  digest, exit status, log surface, validation output, and cleanup result.

### Validation
- `bash scripts/validate-k8s-platformization.sh`
- `bash scripts/validate-readiness-criteria.sh`
- `bash scripts/validate-contract-docs.sh`
- `bash scripts/validate-enterprise-scorecard.sh`
- `bash scripts/validate-all.sh`

### Permission Level
`docs-only`

### Approval Gates
Disposable local Kubernetes/Docker smoke requires explicit Human approval and
cleanup evidence. Live worker, shared-cluster Kubernetes, credential,
deployment, production, remote host, cloud, EKS, and GitHub Project
control-plane mutation remains blocked without explicit Human approval.

### Manual QA Channel
CLI auxiliary surface: `scripts/run-k8s-runtime-smoke.sh` transcript, static
manifest validator output, and route/result metadata review transcript.

### Enterprise Readiness Gap
`docs/enterprise-readiness/criteria.json` (`k8s_platformization`)

### Expected Result Evidence
Changed artifacts, profile matrix, route metadata, result packet schema update
if needed, validation output, approval-gate status, cleanup receipt, residual
risk, and next action.

## k8s-result-packet-reconciliation

### Goal
Define the reconciliation path between GitHub Project lifecycle state,
Kubernetes Job status, Hammer logs, and Manager result-packet review.

### Scope
In scope: reconciliation contract, drift cases, closeout failure handling,
result packet sink decision, and local replay evidence.

Out of scope: live GitHub Project mutation, live Kubernetes watch, production
audit store, credential issuance, and management-plane rewrite.

### Criteria IDs
`k8s_platformization`

### Acceptance Criteria
- Reconciliation rejects Done when GitHub Project status, Job status, logs,
  result packet, PR/check state, or approval evidence disagree.
- Stale or failed Jobs become follow-up issues or Fix Requested with preserved
  route/result metadata.
- Closeout evidence remains durable outside Manager memory.
- A local replay proves the reject/accept matrix without live external writes.

### Validation
- `bash scripts/validate-k8s-platformization.sh`
- `bash scripts/validate-readiness-criteria.sh`
- `bash scripts/validate-contract-docs.sh`
- `bash scripts/validate-enterprise-scorecard.sh`
- `bash scripts/validate-all.sh`

### Permission Level
`docs-only`

### Approval Gates
Live GitHub Project, Kubernetes, credential, worker, Docker, remote host,
deployment, production, cloud, and EKS mutation requires separate Human
approval.

### Manual QA Channel
CLI auxiliary surface: replay transcript and validator output.

### Enterprise Readiness Gap
`docs/enterprise-readiness/criteria.json` (`k8s_platformization`)

### Expected Result Evidence
Changed artifacts, accepted/rejected replay evidence, validation output,
approval-gate status, cleanup receipt, residual risk, and next action.

## eks-identity-and-secret-boundary

### Goal
Choose and validate the EKS workload identity and secret boundary for Fire,
Hammer, and the credential broker.

### Scope
In scope: EKS Pod Identity versus IRSA decision record, named capability
matrix, secret default-deny policy, grant expiry/cleanup evidence plan, and
docs-only validation.

Out of scope: live AWS account mutation, IAM role creation, EKS cluster
mutation, credential issuance, production deployment, and GitHub Project
control-plane mutation.

### Criteria IDs
`k8s_platformization`

### Acceptance Criteria
- Decision record names why the selected identity strategy fits Fire, Hammer,
  credential broker, tenant RBAC, and audit requirements.
- Secret access remains default denied; any named Secret exception requires
  Human approval, reason, expiry, and cleanup evidence.
- Hammer prompts, issue bodies, result packets, Job env, logs, and artifacts
  must not include raw Manager PATs, OAuth tokens, SSH private keys,
  kubeconfigs, cloud credentials, or GitHub App private keys.
- Validation fails closed on broad Secret read/list/watch or missing approval
  boundary text.

### Validation
- `bash scripts/validate-k8s-platformization.sh`
- `bash scripts/validate-readiness-criteria.sh`
- `bash scripts/validate-contract-docs.sh`
- `bash scripts/validate-enterprise-scorecard.sh`
- `bash scripts/validate-all.sh`

### Permission Level
`docs-only`

### Approval Gates
Live AWS, EKS, IAM, credential, Kubernetes, production, deployment, worker,
Docker, remote host, and GitHub Project control-plane mutation remains blocked
without explicit Human approval.

### Manual QA Channel
CLI auxiliary surface: decision-record validator output and malformed-boundary
fixture transcript.

### Enterprise Readiness Gap
`docs/enterprise-readiness/criteria.json` (`k8s_platformization`)

### Expected Result Evidence
Changed artifacts, decision record, capability matrix, RED/GREEN validation,
approval-gate status, cleanup receipt, residual risk, and next action.
