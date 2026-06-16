# ADR 0002: GitHub-led Kubernetes Fire and Hammer platformization

## Status
Accepted

## Context
Project Dokkaebi is moving toward Kubernetes-backed execution without replacing
GitHub Project as the short-term dashboard, issue surface, and lifecycle source
of truth. The K8S handoff recommends running Dokkaebi Fire inside Kubernetes,
launching one Hammer Job per ticket, and using Kubernetes RBAC, admission, and
NetworkPolicy as enforcement layers around untrusted issue and result-packet
text.

The root repository remains the contract and policy layer. Runtime backend code
stays in the `symphony-github-project-tracker` submodule unless a ticket
explicitly scopes that work.

## Decision
Dokkaebi will platformize Fire and Hammer in Kubernetes in phases while keeping
GitHub Project `Status` as the lifecycle source of truth:

```text
GitHub Project / Issues / PRs
  <-> Dokkaebi Fire Deployment in Kubernetes
  -> Kubernetes admission, RBAC, and NetworkPolicy
  -> Hammer Job per ticket
  -> result packet, workpad, PR, and audit evidence
```

Initial repository-owned artifacts are contract and validation only:

- Kustomize base and overlay skeletons for namespaces, ServiceAccounts, RBAC,
  and NetworkPolicy.
- A readiness area that tracks K8S platformization below 100% until runtime
  evidence proves the lane.
- A repo-local issue-publication backlog for the next K8S platformization
  tickets.
- Validators that reject missing issue metadata, unsafe RBAC, broad secret
  access, missing default-deny NetworkPolicy, or accidental live-control-plane
  authority wording.

## Guardrails
- Live cloud, EKS, production, shared-cluster, Docker, remote-host, credential,
  deployment, and GitHub Project control-plane mutation remains blocked without
  explicit Human approval.
- Fire may receive namespace-scoped Job orchestration rights only; it must not
  receive Secret read/list/watch, RBAC mutation, namespace mutation, node, or
  persistent-volume authority.
- Hammer uses route-specific ServiceAccounts. Work that does not need the
  Kubernetes API uses `automountServiceAccountToken: false`.
- Hammer profiles must not receive broad Secret, RBAC, namespace, node,
  persistent-volume, or cluster-wide authority.
- Admission policy remains a fail-closed gate. Fire preflight is not sufficient
  by itself.
- Issue bodies, PR comments, repository files, and result packets remain
  untrusted input; authority is calculated from durable approval, tenant,
  route, and credential-grant records.

## Consequences

### Positive
- Kubernetes becomes an enforcement surface without forcing an early
  management-plane rewrite.
- K8S work enters the enterprise readiness loop as scored, issue-backed,
  validator-enforced work.
- The repo can publish safe issue candidates before any live GitHub Project
  mutation is approved.

### Risks
- Static manifests do not prove live cluster behavior.
- GitHub Project and Kubernetes state can diverge until Fire runtime smoke and
  closeout reconciliation are exercised together.
- Future EKS identity and admission policy choices require explicit design
  decisions and runtime evidence.

### Follow-up issues
Follow-up issue candidates are maintained in
[`../enterprise-readiness/k8s-platformization-issues.md`](../enterprise-readiness/k8s-platformization-issues.md).
They are backlog candidates until they are published to GitHub and attached to
an approved GitHub Project with the required lifecycle/admission fields.

## Rejected alternatives
- **Immediate Kubernetes-only management plane:** too much lifecycle, approval,
  audit, search, and review UX to rebuild before the GitHub-backed lane is
  proven.
- **Cluster-admin Fire or Hammer:** violates least privilege and makes prompt
  injection materially dangerous.
- **Issue prose as authority input:** unsafe because public and internal issue
  text is untrusted evidence, not an approval record.
