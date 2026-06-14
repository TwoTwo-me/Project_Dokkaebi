# Orchestration Recovery Gate

This runbook defines the deterministic local recovery gate for Fire/Hammer
orchestration changes. It builds on
[`dispatch-lease-recovery.md`](dispatch-lease-recovery.md) and proves the
fault-injected behavior that must pass before orchestration recovery evidence can
raise enterprise readiness.

## Gate Goal

The gate simulates a long-running orchestration path with controlled worker failure faults:

- admitted work receives a durable dispatch lease;
- a Hammer route accepts work and then fails before result closeout;
- Fire restarts with retry intent still persisted;
- stale lease recovery is rejected before expiry and accepted after expiry;
- recovered work dispatches through a new lease token and idempotency key;
- duplicate dispatch is rejected deterministically;
- route result handling records result-packet evidence;
- closeout is rejected without result evidence and accepted with Manager review
  evidence.

The gate is local and deterministic. It does not mutate GitHub Projects, live
workers, Docker, Kubernetes, SSH hosts, production systems, or credentials.

## Required Validation

Run:

```bash
bash scripts/validate-orchestration-recovery-gate.sh
```

The script is part of the root contract validation path through
`scripts/validate-contract-docs.sh`. Any orchestration change that claims
recovery behavior must keep both validators passing:

```bash
bash scripts/validate-orchestration-recovery-gate.sh
bash scripts/validate-dispatch-lease-recovery.sh
bash scripts/validate-contract-docs.sh
bash scripts/validate-readiness-criteria.sh
```

## Fault Classes

The validator must reject these unsafe paths:

| Fault class | Required rejection |
| --- | --- |
| Duplicate dispatch | A second Hammer dispatch with the same idempotency key fails. |
| Early stale lease recovery | Recovery before `lease_expires_at` fails. |
| Retry loss after restart | Restart with a failed attempt and no persisted retry intent fails. |
| Closeout without result evidence | Manager closeout before route result evidence fails. |

## Live GitHub Project Boundary

This gate explains but does not remove live-operation limits:

- GitHub Project webhook delivery can be delayed, duplicated, or absent.
- GraphQL reads and writes can be rate limited or temporarily inconsistent.
- Project field mapping can drift in brownfield projects.
- Real route cleanup and result collection still need sandbox transcript
  evidence.

Live worker, Docker, Kubernetes, SSH, remote host, credential, production,
deployment, and GitHub Project control-plane mutation remain approval-gated under
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

Repository-local sandbox issue processing evidence is captured in
[`sandbox-issue-processing-transcript-2026-06-14.md`](sandbox-issue-processing-transcript-2026-06-14.md).
That transcript proves discovery, admission, dispatch readiness, Worker result
evidence, Manager review, and closeout through public issue, pull request, and
validator evidence rather than private memory. Live Worker, Docker, Kubernetes,
remote host, credential, production, deployment, and GitHub Project
control-plane mutation still require a later explicitly approved target and
operation list.
