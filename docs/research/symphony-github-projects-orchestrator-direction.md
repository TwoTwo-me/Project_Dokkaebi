# Symphony, GitHub Projects, and always-on Worker direction

Date researched: 2026-05-28  
Scope: external research and documentation direction for Project Dokkaebi only. This document does **not** change runtime policy, mutate `.omx/ultragoal`, grant credentials, enable provider authority, merge PRs, or deploy anything.

## Executive direction

Keep the accepted Dokkaebi architecture: Dokkaebi is the Manager/evaluation layer, while Symphony remains the canonical project-scope scheduler/runner/tracker-reader layer. The external evidence strengthens ADR 0002 rather than replacing it:

1. **Do not fork Symphony concepts into a generic backend abstraction.** OpenAI's Symphony spec frames the service as a long-running issue-tracker reader, orchestrator, workspace manager, and agent runner; ticket writes and workflow-specific business logic are intentionally outside the scheduler core.[^openai-symphony-spec]
2. **Treat GitHub Projects v2 as the v0 tracker substrate, not as a full workflow engine.** GitHub Projects gives Dokkaebi durable fields, views, built-in workflows, GraphQL mutations, and webhooks, but Dokkaebi still needs its own status/provenance policy because GitHub's native automation is intentionally generic.[^github-projects-best-practices][^github-projects-api]
3. **Document an always-on service contract before expanding runtime authority.** Symphony's draft spec calls for bounded concurrency, retry/backoff, deterministic per-issue workspaces, observability, runtime policy from `WORKFLOW.md`, and explicit safety posture.[^openai-symphony-spec] Dokkaebi should turn those into local contracts before enabling multiple Workers, host Docker, or credential grants.
4. **Use related orchestrators as design pressure, not conceptual authority.** OpenHands, SWE-agent, Devin, OpenClaw Code Agent, and Overstory validate the market pattern around issue-driven agents, sandbox/worktree isolation, PR/result handoff, and review loops, but each optimizes a different boundary than Dokkaebi.[^openhands-action][^openhands-sandbox][^swe-agent][^devin][^openclaw-code-agent][^overstory]

## Source-backed implications

### OpenAI Symphony/spec

OpenAI's Symphony spec is the strongest source for Dokkaebi's execution-layer language. It says the service continuously reads an issue tracker, creates an isolated workspace per issue, and runs a coding-agent session in that workspace. It also draws a boundary: Symphony is a scheduler/runner and tracker reader; ticket comments, PR links, and state transitions are usually performed by the coding agent's tools and repo workflow contract.[^openai-symphony-spec]

Documentation direction:

- Preserve `ProjectScope / SymphonyScope` terminology in core docs.
- Keep `WORKFLOW.md` as the repo-owned policy/prompt/runtime contract for each scope.
- Add a GitHub Projects adapter contract that maps the Symphony tracker model from Linear-style issues to ProjectV2 items, issue/PR content, custom fields, labels, blockers, and status options.
- Keep business rules above Symphony: approval provenance, Worker capability policy, credential broker policy, result-packet review, and Human Review terminal gates remain Dokkaebi-owned.
- Record any intentional deviation from upstream Symphony as adapter policy, not a reinterpretation of Symphony.

### Codex app-server integration

The OpenAI Codex app-server docs describe app-server as a protocol for deep product integrations with authentication, conversation history, approvals, and streamed agent events; it uses JSON-RPC style messages over stdio, WebSocket, or Unix socket transports.[^codex-app-server] The docs also warn that non-loopback WebSocket listeners are risky without auth configuration and recommend token-file based auth over raw command-line tokens for supported WebSocket auth modes.[^codex-app-server]

Documentation direction:

- Keep `scripts/dokkaebi-codex-worker-app-server.sh` framed as a Worker runtime bootstrap and credential-scrubbing boundary, not as a Manager credential grant.
- Require generated app-server schema compatibility checks in a future implementation run before hard-coding protocol messages.
- Treat WebSocket app-server exposure as a gated provider/security decision. Prefer stdio/local Unix socket for bootstrap unless a later ADR approves remote Worker transport.

### GitHub Projects v2

GitHub's own guidance recommends using Projects as a single source of truth, using custom fields for metadata, and using automation to reduce manual status drift.[^github-projects-best-practices] GitHub's Projects API docs show that automation needs ProjectV2 node IDs, field IDs, and single-select option IDs to update fields, and that webhooks can notify a server when project items are edited.[^github-projects-api]

Documentation direction:

- Keep `Dokkaebi Status` as the Symphony/Manager state field and `Status` as a strict human-visible mirror.
- Document ProjectV2 IDs and option IDs as runtime configuration, not inline code assumptions.
- Add an explicit `project-item-adapter` contract for:
  - candidate item discovery;
  - status field read/write;
  - label/readiness filtering;
  - blocker/dependency detection;
  - result packet/workpad/PR link surfaces;
  - terminal transition provenance lookup;
  - race-safe reread-before-mutation behavior.
- Use GitHub webhooks as an optimization, not the sole truth source. A poll/reconcile loop is still needed for missed events, restarts, rate limits, and bootstrap simplicity.

## Always-on Worker service tradeoffs

| Decision area | Recommended v0 posture | Why |
| --- | --- | --- |
| Dispatch trigger | Poll GitHub Project; later add webhook wakeups. | Polling matches Symphony's baseline loop and is simpler to recover. Webhooks reduce latency but require public endpoint/auth/replay handling.[^openai-symphony-spec][^github-projects-api] |
| State source | GitHub Project fields + repo/workpad/result-packet evidence. | GitHub recommends a single source of truth; Dokkaebi also needs durable evidence beyond private Manager memory.[^github-projects-best-practices] |
| Runtime state | Keep minimal local scheduler state; persist audit/evidence, leases, and retry intent. | Symphony allows tracker/filesystem restart recovery without requiring a persistent DB, but retry/session metadata persistence is still a known follow-up in the spec.[^openai-symphony-spec] |
| Worker isolation | Per-ticket workspace/worktree first; container/VM only after provider contracts. | Symphony requires per-issue workspace safety invariants; OpenHands' docs make sandbox provider choice explicit, with Docker recommended over unsafe process execution for stronger isolation.[^openai-symphony-spec][^openhands-sandbox] |
| Credentials | Brokered, least-privilege, time-bound credentials only; no raw Manager token copy. | Needed to preserve Dokkaebi's Manager/Worker boundary and to avoid turning tracker/runtime auth into broad Worker authority. |
| Concurrency | Keep bootstrap at one Worker; later raise only with lease/merge/conflict policy. | Symphony supports bounded concurrency; Overstory and OpenClaw show worktree isolation plus merge/review follow-through, but also introduce conflict and health-management complexity.[^openai-symphony-spec][^openclaw-code-agent][^overstory] |
| Human Review closeout | Manager may request Human Review; terminal approval remains human-origin. | Related tools advertise automated PR/CI loops, but Dokkaebi's current safety policy intentionally fails closed for merge/Done transitions without trusted provenance.[^devin][^linear-devin] |
| Observability | Structured logs, status surface, cost/token/runtime metadata, and concise result packets. | Symphony requires operator-visible observability; OpenClaw and Overstory expose session status/cost/output or fleet health as first-class operations.[^openai-symphony-spec][^openclaw-code-agent][^overstory] |

## Related orchestrator positioning

| System | Useful lesson for Dokkaebi | Do not import blindly |
| --- | --- | --- |
| OpenAI Symphony | Canonical scheduler/runner/tracker-reader and per-issue workspace model. | Linear-specific assumptions or high-trust default policies. |
| OpenHands Resolver | GitHub issue/PR trigger patterns, review feedback loop, and explicit sandbox provider terminology.[^openhands-action][^openhands-sandbox] | Treating a GitHub Action resolver as the whole Manager layer. |
| SWE-agent | Research-backed single-issue resolution framing and configurable agent-computer interface.[^swe-agent] | Benchmark/single-run orientation as a durable ProjectScope control plane. |
| Devin | Managed product pattern: Linear/GitHub/Slack integrations, tickets to PRs, CI/review feedback, multi-repo tasks.[^devin][^linear-devin] | Closed product assumptions, opaque governance, or self-approval semantics. |
| OpenClaw Code Agent | Chat-originated managed background sessions, plan review, worktree follow-through, PR/merge decisions, and session recovery.[^openclaw-code-agent] | Chat thread as the source of truth for Dokkaebi's project state. |
| Overstory | Worktree-per-agent, mailbox coordination, merge queue, watchdog tiers, and runtime adapters.[^overstory] | Multi-agent fleet complexity before Dokkaebi's single ProjectScope loop is stable. |

## Recommended documentation backlog

1. **`docs/contracts/github-project-tracker-adapter.md`**  
   Define the GitHub ProjectV2 adapter contract: project/field discovery, status transitions, candidate queries, blocker checks, provenance lookup, workpad/comment/PR result surfaces, rate-limit behavior, and race-safe mutations.

2. **`docs/contracts/always-on-manager-service.md`**  
   Define the service contract for the long-running Manager/Symphony loop: polling, leases, retries, backoff, concurrency, restart recovery, logs, metrics, kill switch, status-sync preflight, and stop conditions.

3. **`docs/runbooks/github-project-adapter-preflight.md`**  
   Turn the current bootstrap scripts into an operator runbook: token-scope checks, project ID/field ID discovery, dry-run status sync, webhook-vs-poll mode, and failure recovery.

4. **`docs/adr/0003-github-projects-v2-tracker-substrate.md`**  
   Accept GitHub Projects v2 as the v0 tracker substrate while explicitly preserving Symphony's scheduler/runner/tracker-reader boundary and documenting where GitHub differs from Linear.

5. **`docs/strategy/provider-roadmap.md`**  
   Sequence `local-basic` → `container-capable via host helper` → `testbed` → future VM/Kubernetes/cloud/Proxmox providers with approval gates, credential broker dependencies, cleanup, and kill switches.

## Near-term acceptance criteria for the docs milestone

- Every dispatchable Project item can be explained from durable ProjectV2 fields plus issue/PR/comment/result evidence.
- Every status mutation has a documented actor, source, expected field IDs/options, race guard, and failure behavior.
- Every Worker launch path declares workspace isolation, credential scope, network posture, approval policy, and result-packet destination.
- The always-on loop has a stop condition for missing workflow config, missing credentials, status drift, kill switch, capability mismatch, approval gap, and repeated Worker failure.
- Related orchestrators are cited as comparative evidence only; Dokkaebi's source of truth remains local ADRs, contracts, policies, and runbooks.

## References

[^openai-symphony-spec]: OpenAI, `openai/symphony` `SPEC.md`, <https://github.com/openai/symphony/blob/main/SPEC.md> (accessed 2026-05-28).
[^codex-app-server]: OpenAI Developers, “Codex App Server,” <https://developers.openai.com/codex/app-server> (accessed 2026-05-28).
[^github-projects-best-practices]: GitHub Docs, “Best practices for Projects,” <https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/best-practices-for-projects> (accessed 2026-05-28).
[^github-projects-api]: GitHub Docs, “Using the API to manage Projects,” <https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects> (accessed 2026-05-28).
[^openhands-sandbox]: OpenHands Docs, “Sandbox overview,” <https://docs.openhands.dev/openhands/usage/sandboxes/overview> (accessed 2026-05-28).
[^openhands-action]: OpenHands Docs, “OpenHands GitHub Action,” <https://docs.openhands.dev/openhands/usage/run-openhands/github-action> (accessed 2026-05-28).
[^swe-agent]: SWE-agent repository, <https://github.com/SWE-agent/SWE-agent> (accessed 2026-05-28).
[^devin]: Devin, “The AI software engineer,” <https://devin.ai/> (accessed 2026-05-28).
[^linear-devin]: Linear Integrations, “Devin,” <https://linear.app/integrations/devin> (accessed 2026-05-28).
[^openclaw-code-agent]: OpenClaw Code Agent repository, <https://github.com/goldmar/openclaw-code-agent> (accessed 2026-05-28).
[^overstory]: Overstory repository, <https://github.com/jayminwest/overstory> (accessed 2026-05-28).
