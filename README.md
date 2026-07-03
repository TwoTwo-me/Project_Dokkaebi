# Project Dokkaebi

Project Dokkaebi is an installable Manager plugin/skillset for a three-tier
project-management system. It configures and manages GitHub Projects and
issues as the durable coordination layer for Human-governed AI work:

```text
Human
  -> Dokkaebi Manager plugin/skillset
  -> GitHub Project issues and Status
  -> Dokkaebi Fire
  -> Dokkaebi Hammer
  -> verifiable result return
```

Dokkaebi manages Human intent, approval boundaries, work contracts, and
result review. Dokkaebi Fire is the long-running backend/orchestrator derived
from Symphony for GitHub Project based dispatch, isolated Hammer execution, and
progress/result tracking. Dokkaebi Hammer is the typed Worker target/runtime
launched by Fire to execute one bounded ticket and return evidence.

GitHub Project `Status` is the lifecycle source of truth. Fire, Hammer, workpad
comments, PRs, logs, and validation artifacts explain or prove state changes;
they do not replace the project lifecycle field.

## Project Dokkaebi K8S

Project Dokkaebi K8S is the Kubernetes platformization lane for Dokkaebi Fire,
Dokkaebi Hammer, LiteLLM, Prometheus, and Grafana. It packages Fire as a
blue/green Kubernetes control plane, runs Hammer as one route-scoped Job per
ticket, keeps provider OAuth/API credentials behind the LiteLLM gateway, and
visualizes work allocation, worker health, LiteLLM usage, and credential
boundary signals through Grafana.

Kubernetes platformization is repository-owned and evidence-bound: manifests,
admission policies, RBAC, NetworkPolicy, scorecards, and E2E scripts live in
this repo; live EKS, shared-cluster, production, provider credentials, ChatGPT
OAuth, and GitHub Project control-plane writes remain approval-gated.

Start here:

- [`docs/operations/k8s-platform-usage.md`](docs/operations/k8s-platform-usage.md)
  for the first-time operator guide.
- [`scripts/setup-codex-litellm-from-dokkaebi-key.sh`](scripts/setup-codex-litellm-from-dokkaebi-key.sh)
  for the Hammer-side Codex bootstrap that turns `DOKKAEBI_LITELLM_VIRTUAL_KEY`
  into file-based LiteLLM auth without mounting Codex OAuth material.
- [`docs/operations/k8s-platform-e2e-2026-06-21.md`](docs/operations/k8s-platform-e2e-2026-06-21.md)
  for the 100-point K8S E2E gate.
- [`docs/adr/0003-k8s-identity-secret-boundary.md`](docs/adr/0003-k8s-identity-secret-boundary.md)
  for the Fire, Hammer, LiteLLM, and EKS identity/Secret boundary.
- `bash scripts/run-k8s-platform-e2e.sh` for the aggregate K8S platform E2E
  validation command.


## Manager strategy

Dokkaebi is **installable, Hermes-first, contract-first**:

- Hermes is the first baseline AI Manager implementation.
- Dokkaebi itself is not Hermes-specific; the stable interface is the Manager Contract.
- Codex/oh-my-codex remains useful as a development, planning, and alternate Manager adapter.
- OpenClaw remains a future candidate for channel/UI-heavy operation after safety boundaries are mature.
- Dokkaebi Fire and Dokkaebi Hammer remain backend/runtime contracts, not broad
  authority grants to bypass Manager approval gates.

See:

- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`WORKFLOW.md`](WORKFLOW.md)
- [`docs/adr/0001-hermes-first-manager-contract.md`](docs/adr/0001-hermes-first-manager-contract.md)
- [`docs/contracts/manager-contract.md`](docs/contracts/manager-contract.md)
- [`docs/contracts/hammer-worker-contract.md`](docs/contracts/hammer-worker-contract.md)
- [`docs/policies/authority-and-safety.md`](docs/policies/authority-and-safety.md)
- [`docs/policies/git-governance.md`](docs/policies/git-governance.md)
- [`docs/enterprise-readiness/criteria.json`](docs/enterprise-readiness/criteria.json)
- [`docs/enterprise-readiness/development-loop.md`](docs/enterprise-readiness/development-loop.md)
- [`docs/enterprise-readiness/k8s-platformization-issues.md`](docs/enterprise-readiness/k8s-platformization-issues.md)
- [`docs/operations/fire-sandbox-service.md`](docs/operations/fire-sandbox-service.md)
- [`docs/operations/toolchain-bootstrap.md`](docs/operations/toolchain-bootstrap.md)
- [`docs/adapters/hermes.md`](docs/adapters/hermes.md)
- [`docs/adr/0002-k8s-fire-hammer-platformization.md`](docs/adr/0002-k8s-fire-hammer-platformization.md)
- [`docs/adr/0003-k8s-identity-secret-boundary.md`](docs/adr/0003-k8s-identity-secret-boundary.md)
- [`docs/operations/k8s-platform-usage.md`](docs/operations/k8s-platform-usage.md)
- [`docs/operations/k8s-platform-e2e-2026-06-21.md`](docs/operations/k8s-platform-e2e-2026-06-21.md)
- [`docs/templates/worker-ticket.md`](docs/templates/worker-ticket.md)
- [`docs/templates/worker-result-packet.md`](docs/templates/worker-result-packet.md)

## Toolchain bootstrap policy

Dokkaebi prefers user-local tool installation for Manager plugins, Dokkaebi
Fire helpers, and Dokkaebi Hammer runtimes. Bootstrap work must start with
read-only preflight, use scripted install steps when changes are approved,
record install evidence, and include rollback notes in the result packet.

Remote hosts, Docker, `kubectl`, and Kubernetes require preflight and explicit
authority before live mutation. The runtime now models typed Hammer routes for
`local_worktree`, `ssh`, `docker`, and `kubernetes_job`; Docker and Kubernetes
provider behavior is covered by fake command/manifest runners and isolated live
smoke evidence for the approved test targets. Production Docker daemons,
shared clusters, remote namespaces, and persistent infrastructure still require
ticket-specific setup authority. See
[`docs/operations/toolchain-bootstrap.md`](docs/operations/toolchain-bootstrap.md)
for local/remote install rules and `dokkaebi-hammer` reset boundaries.

## Quickstart

1. Install or register the Manager package from [`plugins/dokkaebi`](plugins/dokkaebi).
   The local marketplace entry is [`.agents/plugins/marketplace.json`](.agents/plugins/marketplace.json).
2. Validate the package before use:

   ```bash
   bash scripts/validate-dokkaebi-plugin.sh
   bash scripts/validate-contract-docs.sh
   bash scripts/validate-readiness-criteria.sh
   bash scripts/validate-enterprise-scorecard.sh
   bash scripts/validate-k8s-platformization.sh
   bash scripts/validate-k8s-result-reconciliation.sh
   bash scripts/validate-k8s-platform-e2e.sh
   bash scripts/validate-all.sh
   ```

3. Use
   [`docs/enterprise-readiness/criteria.json`](docs/enterprise-readiness/criteria.json)
   as the company-readiness criteria source of truth. The operating loop for
   issue, worktree, pull request, merge, and re-evaluation is documented in
   [`docs/enterprise-readiness/development-loop.md`](docs/enterprise-readiness/development-loop.md).
   The human-readable scorecard is
   [`docs/enterprise-readiness/project-scorecard.md`](docs/enterprise-readiness/project-scorecard.md)
   and is validated by `bash scripts/validate-enterprise-scorecard.sh`.
4. Configure Dokkaebi Fire from
   [`symphony-github-project-tracker/elixir/WORKFLOW.md`](symphony-github-project-tracker/elixir/WORKFLOW.md).
   A single `tracker.project_id` remains valid; new multi-project deployments
   should use `tracker.default_project_key` plus `tracker.projects` entries.
5. Register the sandbox Fire process as a user-level service when it should
   keep watching the GitHub Project between Manager sessions. See
   [`docs/operations/fire-sandbox-service.md`](docs/operations/fire-sandbox-service.md).
6. Register Hammer targets with typed profiles: `local_worktree`, `ssh`,
   `docker`, or `kubernetes_job`. Container routes require containerizable work
   plus an approved image/profile; Kubernetes routes also require an explicit
   context and namespace.
7. Keep GitHub Project `Status` as the lifecycle source of truth. Fire logs,
   Hammer logs, workpads, PRs, and validation artifacts are evidence surfaces,
   not replacement state.
8. For the Kubernetes platform lane, run:

   ```bash
   bash scripts/run-k8s-platform-e2e.sh
   ```

   See
   [`docs/operations/k8s-platform-usage.md`](docs/operations/k8s-platform-usage.md)
   before applying manifests to any live cluster.

## Kubernetes platformization

The K8S lane keeps GitHub Project as the short-term lifecycle source while
moving Fire and Hammer execution into Kubernetes behind RBAC, admission,
NetworkPolicy, LiteLLM, Prometheus, and Grafana. The base package starts in
[`k8s/base`](k8s/base), with local and EKS overlays under
[`k8s/overlays`](k8s/overlays). Repo-local issue candidates are published in
[`docs/enterprise-readiness/k8s-platformization-issues.md`](docs/enterprise-readiness/k8s-platformization-issues.md);
they are backlog candidates until filed and attached to an approved GitHub
Project.

The local overlay uses the documentation-only external LiteLLM gateway example
`192.0.2.150:4000`. Operators must patch it to an approved reachable gateway
before applying it. Hammer still receives only a run-scoped
`DOKKAEBI_LITELLM_VIRTUAL_KEY`; Codex reads that key through the LiteLLM
provider config generated by
[`scripts/setup-codex-litellm-from-dokkaebi-key.sh`](scripts/setup-codex-litellm-from-dokkaebi-key.sh).

## Initial scope

Milestone 1 is a repository-contract milestone:

- Define Dokkaebi as the installable Manager plugin/skillset and manager role.
- Document architecture and trust boundaries for Dokkaebi, Dokkaebi Fire, and
  Dokkaebi Hammer.
- Define Manager-to-Fire-to-Hammer workflow contracts.
- Define safety/authority policy.
- Create GitHub Project ticket templates for Worker-ready tasks.

See [`docs/deep-interview-project-dokkaebi.md`](docs/deep-interview-project-dokkaebi.md)
for the clarified initial specification.
