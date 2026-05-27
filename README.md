# Project Dokkaebi

Project Dokkaebi is the upper AI Manager layer for a three-tier
project-management system:

```text
Human -> AI Manager Agent -> Symphony/GitHub Project -> AI Worker -> verifiable result return
```

Dokkaebi manages Human intent, approval boundaries, work contracts, and
result review. Symphony is treated as the first worker orchestration backend for
GitHub Project based dispatch, isolated Worker execution, and progress/result
tracking.


## Manager strategy

Dokkaebi is **Hermes-first, contract-first**:

- Hermes is the first baseline AI Manager implementation.
- Dokkaebi itself is not Hermes-specific; the stable interface is the Manager Contract.
- Codex/oh-my-codex remains useful as a development, planning, and alternate Manager adapter.
- OpenClaw remains a future candidate for channel/UI-heavy operation after safety boundaries are mature.

See:

- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`WORKFLOW.md`](WORKFLOW.md)
- [`docs/adr/0001-hermes-first-manager-contract.md`](docs/adr/0001-hermes-first-manager-contract.md)
- [`docs/contracts/manager-contract.md`](docs/contracts/manager-contract.md)
- [`docs/policies/authority-and-safety.md`](docs/policies/authority-and-safety.md)
- [`docs/adapters/hermes.md`](docs/adapters/hermes.md)
- [`docs/templates/worker-ticket.md`](docs/templates/worker-ticket.md)
- [`docs/templates/worker-result-packet.md`](docs/templates/worker-result-packet.md)

## Initial scope

Milestone 1 is a repository-contract milestone:

- Define the Dokkaebi concept and manager role.
- Document architecture and trust boundaries.
- Define Manager-to-Symphony-to-Worker workflow contracts.
- Define safety/authority policy.
- Create GitHub Project ticket templates for Worker-ready tasks.

See [`docs/deep-interview-project-dokkaebi.md`](docs/deep-interview-project-dokkaebi.md)
for the clarified initial specification.
