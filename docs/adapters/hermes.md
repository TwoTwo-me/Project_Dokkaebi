# Hermes Manager Adapter

Hermes is the first baseline Manager adapter for Project Dokkaebi. This document
defines how Hermes should satisfy the Dokkaebi Manager Contract without making
Dokkaebi Hermes-specific.

## Adapter role

Hermes acts above Symphony:

```text
Human -> Hermes as Dokkaebi Manager -> Manager Contract -> Symphony/GitHub Project -> AI Worker
```

Hermes owns intake, clarification, work-contract drafting, approval checks,
Worker-result review, and Human-facing summaries. Symphony owns GitHub Project
monitoring, Worker dispatch, progress state, and backend-specific execution
mechanics.

## Required Hermes behavior

Hermes must:

1. Preserve the original Human request and separate goals from non-goals.
2. Clarify ambiguous scope, authority, safety, validation, or stop conditions.
3. Produce Worker tickets using `docs/templates/worker-ticket.md`.
4. Apply `docs/policies/authority-and-safety.md` before dispatch.
5. Route approved work through Symphony/GitHub Project instead of direct
   Human-to-Worker control.
6. Require Worker results to follow `docs/templates/worker-result-packet.md`.
7. Summarize results with evidence, blockers, residual risks, and next decisions.
8. Keep an audit trail sufficient for Codex/OMX, OpenClaw, or another Manager
   adapter to resume.

## Approval and preflight handling

Before Hermes marks a ticket dispatchable, it must run the fail-closed preflight
from the authority policy:

- ticket/source request linked;
- acceptance criteria and validation plan present;
- permission level declared;
- Human approval evidence present for every gated action;
- credential grants brokered and scoped when required;
- Symphony project status/label mapping confirmed;
- Worker capability and OS constraints available.

Unknown approval state means blocked, not best-effort dispatch.

## Symphony integration expectations

Hermes should communicate with Symphony through inspectable artifacts and, later,
through deterministic CLI/MCP integration:

- GitHub Project issue or item for each Worker-ready ticket;
- status fields mapped to the semantic states in `WORKFLOW.md`;
- labels/metadata for permission level, backend, OS/capability needs, and
  approval gates;
- workpad or issue comments for progress and result packets;
- PR links, commits, validation logs, or generated artifacts.

Hermes must support both greenfield and brownfield Symphony projects. In a
brownfield project, it first maps existing statuses and labels to Dokkaebi's
semantic states. In a greenfield project, it may propose initial fields and
labels, but it must not create or change GitHub Project schema, labels, templates,
admission rules, or auto-add workflows without approved setup authority.

## Adapter conformance matrix

| Contract capability | Hermes baseline | Required evidence |
| --- | --- | --- |
| Human intake | Capture source request and clarify ambiguity. | Intake notes or ticket context. |
| Ticket drafting | Generate Worker ticket template sections. | GitHub issue/project item body. |
| Approval gates | Enforce authority policy before dispatch. | Approval evidence record or blocked reason. |
| Symphony handoff | Create/update dispatchable project item. | Project status, labels, and workpad link. |
| Worker result review | Parse result packet and verify evidence. | Manager review summary. |
| Resume portability | Store enough audit for another adapter. | Links to request, ticket, result, PR/logs. |

## Adapter boundaries

Hermes must not:

- become the only source of truth for approvals or Worker results;
- store raw long-lived secrets in memory or prompts;
- bypass Symphony for Worker dispatch unless a later backend adapter is approved;
- merge PRs, deploy, write production data, create cloud/Proxmox resources, or
  scale Workers without explicit Human approval;
- rely on Hermes-only hidden state that prevents another Manager from resuming.

## Future CLI/MCP surface

The first version can be documentation- and template-driven. Later CLI/MCP tools
may validate preflight, read/write tracker state, and run adapter conformance
tests. Those tools must implement this contract and fail closed on missing
approval or unknown project status.
