# Project Dokkaebi

Project Dokkaebi is the upper AI Manager layer for a Symphony-native,
human-governed project-management system:

```text
Human -> replaceable AI Manager -> ProjectScope / Symphony -> AI Worker -> verifiable result return -> Manager review
```

Dokkaebi manages Human intent, approval boundaries, work contracts, project
scopes, Worker capability requirements, environment-provider policy, and result
review. Symphony is the canonical project-scope execution layer for scheduler /
runner / tracker-reader orchestration. GitHub Project is the first v0
scheduler/tracker substrate.

See [`docs/adr/0002-symphony-native-execution-layer.md`](docs/adr/0002-symphony-native-execution-layer.md)
for the accepted Symphony-native architecture decision.

## Manager strategy

Dokkaebi is **Hermes-first, contract-first, and Manager-replaceable**:

- Hermes is the first baseline AI Manager implementation.
- Dokkaebi itself is not Hermes-specific; the stable interface is the Manager Contract.
- Codex/oh-my-codex remains useful as a development, planning, and alternate Manager adapter.
- OpenClaw remains a future candidate for channel/UI-heavy operation after safety boundaries are mature.
- Manager runtimes are replaceable; Symphony remains the canonical execution layer inside a ProjectScope.

See:

- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`WORKFLOW.md`](WORKFLOW.md)
- [`docs/adr/0001-hermes-first-manager-contract.md`](docs/adr/0001-hermes-first-manager-contract.md)
- [`docs/adr/0002-symphony-native-execution-layer.md`](docs/adr/0002-symphony-native-execution-layer.md)
- [`docs/contracts/manager-contract.md`](docs/contracts/manager-contract.md)
- [`docs/contracts/runtime-provider-contract.md`](docs/contracts/runtime-provider-contract.md)
- [`docs/contracts/worker-capability-model.md`](docs/contracts/worker-capability-model.md)
- [`docs/policies/authority-and-safety.md`](docs/policies/authority-and-safety.md)
- [`docs/adapters/hermes.md`](docs/adapters/hermes.md)
- [`docs/adapters/codex-omx-bootstrap.md`](docs/adapters/codex-omx-bootstrap.md)
- [`docs/templates/worker-ticket.md`](docs/templates/worker-ticket.md)
- [`docs/templates/worker-result-packet.md`](docs/templates/worker-result-packet.md)

## Current scope

The current architecture milestone is a repository-contract milestone:

- Define Dokkaebi as the management/evaluation layer above Symphony.
- Document ProjectScope, runtime-provider, and Worker capability boundaries.
- Define Manager-to-Symphony-to-Worker workflow contracts.
- Define safety/authority policy and trusted automation gates.
- Create durable templates for Worker-ready tickets and result packets.

It does not grant production authority, create infrastructure, design a UI,
implement runtime code, or enable unattended merge/deploy automation.

## Bootstrap ProjectScope

This repository is now bound as the first local Dokkaebi ProjectScope through
[`dokkaebi/project-scopes/project-dokkaebi.yml`](dokkaebi/project-scopes/project-dokkaebi.yml).
The accompanying per-project policy lives in
[`dokkaebi/policies/project-dokkaebi.yml`](dokkaebi/policies/project-dokkaebi.yml),
and the Symphony workflow contract for the existing GitHub Project tracker
implementation lives in
[`dokkaebi/symphony/WORKFLOW.project-dokkaebi.md`](dokkaebi/symphony/WORKFLOW.project-dokkaebi.md).

These bootstrap files are intentionally configuration-first: they do not grant
credential access, enable host Docker authority, create infrastructure, merge
PRs, or deploy. Remote GitHub Project ids are filled only after the GitHub
Project setup/auth gate succeeds; the current bootstrap Project lives at
<https://github.com/users/Project-Dokkaebi/projects/1>.

The runnable path is documented in
[`docs/runbooks/dokkaebi-runtime-bootstrap.md`](docs/runbooks/dokkaebi-runtime-bootstrap.md).
The configured Worker launcher uses
[`scripts/dokkaebi-codex-worker-app-server.sh`](scripts/dokkaebi-codex-worker-app-server.sh)
to scrub Manager/control-plane credentials before `codex app-server` starts.
Use `DOKKAEBI_WORKER_REF` when a Worker must validate a committed branch, pull
request ref, or SHA instead of remote `main`.

The v0 Human approval surface is the GitHub Project state pair:
`Dokkaebi Status` is the Symphony/Manager state field and the human-visible
`Status` field is a strict mirror with the same options. Verify the mirror with
`scripts/dokkaebi-project-status-sync.py --json`; use
`scripts/dokkaebi-project-status-sync.py --apply --json` only for non-terminal
repair because approval-gated moves fail closed without provenance. For the
always-on Manager loop, run
`scripts/dokkaebi-project-status-sync.py --direction bidirectional --watch --apply --record-state`
or the wrapper `scripts/dokkaebi-project-status-sync-loop.sh`
so a later change to either field is mirrored to the other side when the source
can be inferred from the local sync snapshot. Approval-gated terminal moves are
not auto-promoted from `Status` to `Dokkaebi Status` without trusted provenance.
The Manager may route complete results to `Human Review`, but
`Human Review` → `Merging` and `Human Review` → `Done` require human-origin
provenance from a trusted verifier with source-specific evidence. Manager
self-approval, GitHub issue closeout without human-origin approval, and
ambiguous provenance fail closed.

See [`docs/deep-interview-project-dokkaebi.md`](docs/deep-interview-project-dokkaebi.md)
for the original clarified initial specification, and
[`docs/adr/0002-symphony-native-execution-layer.md`](docs/adr/0002-symphony-native-execution-layer.md)
for the Symphony-native planning decision.
