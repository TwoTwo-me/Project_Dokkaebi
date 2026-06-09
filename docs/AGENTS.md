# Dokkaebi Docs

## OVERVIEW

This directory holds Dokkaebi's normative Manager contract, authority policy, adapter notes, ADRs, and worker-facing templates.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Manager duties | `contracts/manager-contract.md` | Required capabilities and preflight rules. |
| Human approval rules | `policies/authority-and-safety.md` | Binding safety policy. |
| Git branch and commit rules | `policies/git-governance.md` | GitHub Flow, commit rationale, PR, and submodule policy. |
| Hermes baseline | `adapters/hermes.md` | Adapter conformance for the first Manager. |
| Architecture decision | `adr/0001-hermes-first-manager-contract.md` | Why Hermes-first and contract-first. |
| Worker ticket shape | `templates/worker-ticket.md` | Dispatchable work contract. |
| Worker closeout shape | `templates/worker-result-packet.md` | Evidence required for Manager review. |

## CONVENTIONS

- Treat `contracts/manager-contract.md` and `policies/authority-and-safety.md` as normative.
- Keep status vocabulary aligned with root `WORKFLOW.md`: Intake, Clarifying, Ready, Dispatchable, In Progress, Needs Review, Human Review, Fix Requested, Merging, Done, Blocked, Failed, Cancelled, Reopened.
- Worker ticket and result-packet templates must preserve acceptance-criteria evidence, validation commands, scope-control statement, approval-gate status, and whether acceptance criteria were met.
- Branch, commit, PR, and submodule-pointer rules live in `policies/git-governance.md`; keep ticket/result-packet wording aligned with it.
- Local markdown links in the core docs must resolve from the file that contains them.
- If a doc grants an exception for merge, deploy, infrastructure, production write, or credentialed work, tie it to a later ADR or explicit Human approval path.

## ANTI-PATTERNS

- Do not soften mandatory result-packet or approval sections into optional language.
- Do not add adapter-specific behavior as Dokkaebi core unless the Manager Contract and policy support it.
- Do not remove the fail-closed preflight language when simplifying docs.
- Do not add broad setup, merge, deploy, credential, or worker-scaling authority without recording the approval boundary.

## COMMANDS

```bash
bash scripts/validate-contract-docs.sh
```
