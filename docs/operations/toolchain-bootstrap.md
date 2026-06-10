# Dokkaebi Toolchain Bootstrap

This runbook defines the local and remote tool installation policy for
Dokkaebi Manager plugin/skillset installs, Dokkaebi Fire helpers, and
Dokkaebi Hammer runtimes.

It is an authority boundary, not a broad implementation claim. Typed Hammer
routes now include Docker and Kubernetes Job providers with fake runner coverage
and isolated live-smoke evidence for approved disposable targets. Any new
daemon, context, namespace, remote host, shared cluster, or persistent resource
still needs ticket-specific setup authority before mutation.

## Scope

This policy applies when a Manager, Fire backend, or Hammer Worker needs a tool,
runtime, plugin, skillset, CLI, or helper that is not already available.

Definitions:

- **Local bootstrap**: installing into the current Human/user account,
  user-owned cache, or ticket-scoped workspace.
- **Remote bootstrap**: installing on another host, container runtime, cluster,
  shared account, shared directory, CI runner, or managed service.
- **Dokkaebi Hammer reset**: removing or recreating a named `dokkaebi-hammer`
  runtime target, cache, or workspace so Fire can launch a clean Hammer.

## Default policy

Dokkaebi must prefer user-local installs. Local bootstrap should use locations
owned by the current user, avoid `sudo`, avoid system package changes, and avoid
shared directories unless a ticket explicitly grants broader setup authority.

Every bootstrap task must start with read-only preflight. Preflight may inspect
existing commands, versions, paths, environment variables, disk availability,
GitHub Project mapping, Fire admission fields, Hammer runtime metadata, and
credential broker readiness. Preflight must not create, update, delete, reset,
or authenticate against a higher-privilege target.

If installation is approved, use scripted install steps instead of ad-hoc manual
mutation. The script or runbook output must provide install evidence:

- source ticket and approved actor/runtime;
- command names and concise output;
- installed version, source, checksum or release identifier when available;
- install path and user/account ownership;
- environment changes required to use the tool;
- validation command and outcome;
- rollback notes naming files, directories, environment entries, or project
  fields to revert;
- skipped checks and residual risk.

## Remote and container routes

Remote bootstrap is approval-gated. A ticket must explicitly name the remote
host, container runtime, cluster, namespace, service account, credential scope,
and allowed mutation before Fire or a Manager may proceed.

Docker, `kubectl`, and Kubernetes may be checked in read-only preflight, such as
detecting whether commands exist or reading the active context. Creating or
deleting images, containers, volumes, contexts, namespaces, deployments,
secrets, jobs, or cluster resources requires explicit Human approval and
brokered credentials.

Typed route support means Dokkaebi Fire may consider the route only when the
ticket, project fields, worker profile, credential policy, and bootstrap
evidence all match. It does not grant a Hammer permission to install tools,
mount broad secrets, mutate a daemon, or create cluster resources outside the
approved test or production boundary.

## Dokkaebi Hammer reset boundaries

A `dokkaebi-hammer` reset request must identify:

- Hammer target id;
- owning ticket or project item;
- local or remote location;
- exact directories, caches, or runtime state eligible for deletion;
- data that must be preserved;
- approval record for any remote, shared, Docker, `kubectl`, or Kubernetes
  resource;
- rollback or recovery notes.

By default, a reset may affect only the named user-local Hammer target or
ticket-scoped workspace. It must not delete repositories, SSH keys, credential
stores, Manager memory, GitHub Project data, Dokkaebi Fire state, Docker
volumes, Kubernetes namespaces, remote home directories, or shared caches unless
the ticket grants that exact authority.

If the reset boundary is ambiguous, the Manager or Fire must mark the ticket
Blocked and ask for a clarified reset request.

## Closeout evidence

Bootstrap result packets must include:

- read-only preflight summary;
- scripted install or reset command;
- installed or reset target path;
- validation commands and outcomes;
- rollback notes;
- approval-gate status;
- whether acceptance criteria were met;
- residual risks or skipped checks.

Missing evidence does not authorize silent continuation. The Manager should ask
for a scoped fix, create a follow-up ticket, or request Human approval.
