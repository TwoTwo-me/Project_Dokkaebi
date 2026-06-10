---
name: fire-ops
description: Use when operating Dokkaebi Fire as the multi-project backend, including project registry checks, observability, admission diagnostics, worker routing, stuck-run reconciliation, and safe status updates.
---

# Fire Operations

Use this skill when Dokkaebi Fire needs operational review or a Manager needs to inspect Fire behavior before dispatch, routing, or closeout. GitHub Project Status remains the lifecycle source of truth; Fire logs, workpads, PRs, checks, and result packets are evidence surfaces.

## Operating Loop

1. Load the project registry and identify the exact GitHub Project, repository set, admission fields, and active/terminal Status mapping for the item.
2. Verify admission checks before dispatch: Status, Agent, Authorization, Authorized By, Fire or Symphony Admission, fallback labels, permission level, and Hammer capability requirements.
3. Inspect observability surfaces before changing state: Fire state endpoint, worker registry, queue depth, active leases, recent run logs, workpad comments, PR checks, and result packet links.
4. Diagnose worker routing with explicit evidence: target Hammer id, provider type, capability match, OS/runtime match, capacity, health, lease status, and why alternatives were rejected.
5. Reconcile stuck runs by comparing GitHub Project Status, Fire lease state, Hammer workspace state, workpad comments, PR status, checks, and logs.
6. Update project Status or comments only when the evidence explains the transition and the ticket authority permits that write.

## Safe Actions

- Read the project registry, Fire runtime state, worker routing diagnostics, and observability logs.
- Mark a ticket blocked when admission checks, authority, credentials, capacity, or project mapping are missing.
- Record a review/status update that cites the exact evidence surface used.
- Recommend follow-up tickets for registry migration, provider bootstrap, or Hammer capacity work.

Do not dispatch best-effort work when admission, authorization, project registry mapping, or worker routing evidence is incomplete. Do not expose Manager credentials to Hammer workspaces. Do not mutate Docker, Kubernetes, remote hosts, or shared infrastructure from this skill; route those requests through the bootstrap policy and approval gates.

## Result Notes

A Fire operations note should include:

- source project item and current GitHub Project Status;
- project registry entry used;
- admission checks and pass/fail state;
- worker routing decision or blocker;
- observability evidence reviewed;
- stuck-run reconciliation outcome, if applicable;
- approval-gate status;
- recommended next Manager/Human action.
