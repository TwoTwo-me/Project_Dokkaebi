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
- [`docs/operations/fire-sandbox-service.md`](docs/operations/fire-sandbox-service.md)
- [`docs/operations/toolchain-bootstrap.md`](docs/operations/toolchain-bootstrap.md)
- [`docs/adapters/hermes.md`](docs/adapters/hermes.md)
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
   ```

3. Configure Dokkaebi Fire from
   [`symphony-github-project-tracker/elixir/WORKFLOW.md`](symphony-github-project-tracker/elixir/WORKFLOW.md).
   A single `tracker.project_id` remains valid; new multi-project deployments
   should use `tracker.default_project_key` plus `tracker.projects` entries.
4. Register the sandbox Fire process as a user-level service when it should
   keep watching the GitHub Project between Manager sessions. See
   [`docs/operations/fire-sandbox-service.md`](docs/operations/fire-sandbox-service.md).
5. Register Hammer targets with typed profiles: `local_worktree`, `ssh`,
   `docker`, or `kubernetes_job`. Container routes require containerizable work
   plus an approved image/profile; Kubernetes routes also require an explicit
   context and namespace.
6. Keep GitHub Project `Status` as the lifecycle source of truth. Fire logs,
   Hammer logs, workpads, PRs, and validation artifacts are evidence surfaces,
   not replacement state.

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
