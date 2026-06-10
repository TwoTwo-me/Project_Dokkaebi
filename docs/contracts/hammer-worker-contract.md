# Dokkaebi Hammer Worker Contract

This contract defines the typed Worker target/runtime that Dokkaebi Fire may
route to for one bounded ticket. A Hammer is not a Manager and does not own
approval, lifecycle state, or broad credentials.

GitHub Project `Status` remains the lifecycle source of truth. Hammer progress,
logs, workspaces, pull requests, validation output, and result packets are
evidence surfaces for Manager review.

## Worker profile fields

Every routable Hammer profile has these fields:

| Field | Meaning |
| --- | --- |
| `id` | Stable worker profile id. |
| `type` | One of `local_worktree`, `ssh`, `docker`, or `kubernetes_job`. |
| `endpoint` or `context` | Host, local worktree context, Docker runtime, or Kubernetes context. |
| `capabilities` | Tool or workload labels such as `browser`, `elixir`, `node`, or `gpu`. |
| `labels` | Operator-defined routing tags. |
| `os` | Optional normalized OS metadata: `linux`, `macos`, or `windows`. |
| `isolation` | Isolation mode such as `git_worktree`, `remote_workspace`, `container`, or `kubernetes_job`. |
| `image` or `profile` | Container image or named runtime profile for container providers. |
| `resources` | CPU, memory, or provider-specific resource hints. |
| `health` | Probe result and any unavailable reason. |
| `capacity` | Current running count and scheduling limit. |
| `lease` | Optional expiry for self-registered workers. |
| `credential_mode` | How the worker receives scoped auth, normally `broker_bundle`. |
| `log/result collection` | Where Fire can collect logs, status, and result packets. |
| `cleanup` | Provider-specific cleanup action for worktree, remote workspace, container, or Job. |

## Route types

### `local_worktree`

Fire creates an isolated local Git worktree under a configured workspace root.
The provider must reject worktrees inside the source repository and must support
cleanup with `git worktree remove` and stale metadata cleanup with
`git worktree prune`.

### `ssh`

Fire uses SSH to prepare a remote workspace and start the coding-agent runtime.
The host must pass health and capability checks before selection. In
`ssh_only` mode, manager-local endpoints are rejected.

### `docker`

Fire may route to Docker only when the ticket or project configuration marks the
work as containerizable and provides a compatible image or profile. Docker
routes must not mount broad host secrets or receive Manager PAT/OAuth tokens.
Wave 3 verifies this provider with fake command runners; live Docker smoke
belongs to the later live-routing validation wave.

### `kubernetes_job`

Fire may route to a Kubernetes Job only when the ticket or project configuration
marks the work as containerizable and provides a compatible image/profile plus a
configured Kubernetes context and namespace. The context may be local or remote;
Fire must not assume the cluster runs on the Fire server. Wave 3 verifies Job
manifest generation and fake runner behavior; live Kubernetes smoke belongs to
the later live-routing validation wave.

## Routing rules

Routing is fail-closed:

- Explicit `type`, `os`, `capabilities`, `containerizable`, `image/profile`,
  `isolation`, resource, or Kubernetes context requirements must match a worker
  profile before dispatch.
- Inferred OS hints may fall back to normal least-loaded routing when no exact
  OS match exists.
- Docker and Kubernetes routes are never selected from the legacy host-only
  selector; they require typed route selection.
- Unhealthy, disabled, stale, shadowed, removed, or full workers are not
  schedulable.
- Excluded attempted workers are skipped on retry.
- Among eligible workers, Fire prefers the requested worker when available and
  otherwise chooses the least-loaded worker.

## Credential boundary

Hammer workspaces receive only scoped credential broker bundles or explicit
operator-provided worker auth. Manager PATs, OAuth tokens, SSH private keys,
kubeconfig secrets, and long-lived secret material must not be copied into
ticket prose, logs, route metadata, provider env, or result packets.

## Result and cleanup contract

Every Hammer route must provide enough metadata for Manager review:

- provider type and worker id;
- workspace, container, or Job identity;
- health/capacity decision;
- validation command output or logs;
- cleanup status;
- residual risks and missing permissions.

Missing route metadata, missing cleanup evidence, or missing result-packet
surface blocks closeout.
