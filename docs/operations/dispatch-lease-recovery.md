# Dispatch Lease And Restart Recovery

This runbook defines the durable dispatch lease contract for Fire/Hammer
orchestration. It is a local validation and design contract for Project
Dokkaebi; live GitHub Project mutation, remote worker mutation, Docker daemon
mutation, Kubernetes mutation, or production use still follows
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Contract Goal

Fire must be able to restart without duplicate dispatch, lost retry intent, or
silent closeout loss. A work item may be observed many times, but it may be
dispatched to a Hammer route only when a durable lease proves that the current
Fire owner has exclusive dispatch authority for the current attempt.

The contract explicitly covers lease store, owner identity, retry persistence, recovery behavior, no duplicate dispatch after restart, live GitHub Project residual risks, lease token, idempotency key, and stale lease handling.

The required invariant is:

```text
For one source work item and one attempt id, at most one Hammer dispatch may be
accepted unless the durable store records completion, cancellation, or an
expired lease that has been recovered by a later owner with a new attempt id.
```

## Durable Lease Store

The lease store is the durable control-plane record Fire reads before dispatch.
For GitHub Project backed operation, the source of truth remains the GitHub
Project item plus issue or workpad evidence. A production implementation may
mirror the lease into a database table, but the mirror must not replace the
GitHub Project lifecycle state.

Minimum lease fields:

| Field | Meaning |
| --- | --- |
| `work_item_id` | Stable GitHub issue, PR, or project item identifier. |
| `project_id` | Approved GitHub Project identifier. |
| `status` | Semantic lifecycle status mapped from GitHub Project `Status`. |
| `lease_token` | Random or monotonic lease token owned by one Fire instance. |
| `lease_owner_id` | Owner identity for the Fire process or backend instance. |
| `hammer_route_id` | Selected Hammer route, such as local worktree, SSH, Docker, or Kubernetes job. |
| `attempt_id` | Monotonic attempt number or idempotency key for this dispatch. |
| `idempotency_key` | Stable idempotency key derived from work item, route, and attempt. |
| `lease_expires_at` | Time after which another owner may recover the stale lease. |
| `heartbeat_at` | Last owner heartbeat. |
| `retry_count` | Persisted retry count. |
| `next_retry_at` | Persisted retry schedule after a failed or timed-out attempt. |
| `result_packet_ref` | Link or identifier for the Hammer result packet when complete. |
| `closeout_review_ref` | Link or identifier for Manager review and closeout evidence. |

## Owner Identity

Each Fire instance must publish a stable owner identity for its current runtime:

- backend instance id;
- host or runtime class;
- process start time;
- software version or commit;
- route allocator identity.

The owner identity is evidence, not authority by itself. Authority comes from a
valid `lease_token` recorded in the durable lease store and from the admission
and approval gates in the Manager contract.

## Acquire And Dispatch

Fire may dispatch only after these steps succeed:

1. Confirm the GitHub Project item is admitted and mapped to a dispatchable
   semantic status.
2. Confirm ticket scope, acceptance criteria, permission level, validation plan,
   result packet surface, and approval gates are complete.
3. Select a Hammer route and record `hammer_route_id`.
4. Atomically create or renew a lease with `lease_token`, `lease_owner_id`,
   `attempt_id`, `idempotency_key`, `lease_expires_at`, and `heartbeat_at`.
5. Re-read the durable lease store and confirm the same owner/token still owns
   the lease.
6. Dispatch the Hammer work using the `idempotency_key`.
7. Persist dispatch evidence before relying on in-memory state.

If any step is unknown, Fire blocks instead of dispatching.

## Restart Recovery Behavior

On restart, Fire must not trust memory from the prior process. It reloads the
durable lease store and classifies every admitted work item:

| Durable state | Required recovery behavior |
| --- | --- |
| No lease | Run normal admission and acquire flow. |
| Active unexpired lease owned by another owner | Do not dispatch. Record that the item is already leased. |
| Active unexpired lease owned by this owner/token | Resume monitoring and heartbeat before any new dispatch. |
| Expired stale lease with no result packet | Recover with a new owner, new `lease_token`, and new `attempt_id`; preserve retry count. |
| Failed attempt with `next_retry_at` in the future | Persist retry intent and do not dispatch until the schedule matures. |
| Completed attempt with result packet and closeout review | Do not dispatch again. Move toward Manager review or Done according to workflow. |

This is the no duplicate dispatch after restart rule: restart may resume,
recover, or wait, but it must not produce a second Hammer dispatch for an
active unexpired lease or a completed attempt.

## Retry Persistence

Retry intent is durable state. A retry decision must record:

- failed `attempt_id`;
- failure reason;
- `retry_count`;
- `next_retry_at`;
- whether the same Hammer route remains allowed;
- approval-gate status when the next attempt could affect credentials,
  infrastructure, deployment, remote workers, Docker, Kubernetes, or production.

After restart, Fire reads `next_retry_at` and `retry_count` before dispatch. If
the schedule is not mature, Fire records waiting evidence and does not dispatch.

## Stale Lease Recovery

A stale lease is recoverable only when `lease_expires_at` has passed and no
accepted result packet or closeout review proves completion. Recovery must use a
new `lease_token` and `attempt_id`, and must retain the prior owner, token,
failure, and retry evidence for audit.

Clock skew, webhook delay, GraphQL lag, and partial GitHub API failures must be
treated as reasons to extend observation or block, not as reasons to duplicate
dispatch.

## Local Validation

The deterministic local validator is:

```bash
bash scripts/validate-dispatch-lease-recovery.sh
```

It verifies this document contains the required contract terms and runs a local
simulation proving:

- a Fire owner can acquire a durable lease and dispatch exactly one Hammer
  attempt;
- a restarted Fire owner sees the active persisted lease and does not duplicate
  dispatch;
- completion prevents re-dispatch;
- duplicate or malformed dispatch attempts are rejected deterministically;
- retry count and retry schedule survive restart.

## Live GitHub Project Residual Risks

This document and local validator do not by themselves prove live GitHub Project
operation. Remaining risks:

- GitHub ProjectV2 webhook delivery is public-preview behavior and may be
  delayed, duplicated, or absent.
- GraphQL reads and writes may have rate limits, pagination gaps, or transient
  consistency delay.
- Project field mapping can drift in brownfield projects unless setup approval
  and mapping evidence are refreshed.
- A database lease mirror can diverge from GitHub Project state unless
  reconciliation is implemented and validated.
- Real Hammer routes can fail after accepting work; route-specific cleanup,
  result-packet collection, and closeout review still need fault-injected gates.
- Live Docker, Kubernetes, SSH, remote host, credential, production, deployment,
  and GitHub Project control-plane mutation remain approval-gated.

The next readiness step is to add a long-running or fault-injected orchestration
gate that exercises these recovery paths against the intended runtime boundary.
