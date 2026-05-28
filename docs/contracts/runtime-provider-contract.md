# Dokkaebi Runtime Provider Contract

This contract defines how Dokkaebi describes Worker environment providers without
implementing any provider in this milestone.

## Purpose
Dokkaebi owns environment-provider policy above Symphony. Symphony schedules and
routes work to registered capable Workers inside a ProjectScope; it does not own
cloud, VM, Docker, Kubernetes, IaC, or Proxmox lifecycle authority by itself.

## Environment Controller responsibility
A future Dokkaebi Environment Controller is responsible for:

1. selecting a Worker profile from ticket, policy, and capability metadata;
2. provisioning or leasing the environment through an approved provider;
3. bootstrapping the Worker runtime and required tools;
4. registering the Worker endpoint and capabilities with the Symphony scope;
5. enforcing lease, credential, network, and environment-tier limits;
6. draining, destroying, or revoking the environment after completion, expiry, or
   kill-switch activation;
7. writing audit evidence for every provider decision.

## Provider-neutral lifecycle

```text
Request / ticket capability need
  -> policy and approval preflight
  -> provider selection
  -> provision or lease
  -> bootstrap Worker
  -> register capabilities
  -> Symphony dispatch/routing
  -> result/evidence review
  -> drain, destroy, revoke, or retain under policy
```

## Required provider metadata
A provider contract must expose, at minimum:

- provider id and kind;
- environment tier (`dev`, `staging`, `prod`, or project-defined equivalent);
- supported Worker capabilities;
- allowed repositories/projects;
- network mode and external service allowlist;
- credential broker compatibility;
- lease duration and revocation method;
- cleanup and residue-check expectations;
- audit/event sink;
- kill-switch behavior.

## Host Docker provider direction
The first planned provider direction is `host-docker`.

Requirements:

- Docker/Podman/Compose access is exposed through a narrow host helper daemon.
- The helper API must be allowlisted, auditable, and policy-gated.
- Dokkaebi must not mount or pass a broad host Docker socket by default.
- Worker containers must be leased, labeled, and revocable by project/scope.
- Cleanup and credential-residue checks are required before closeout.

This contract records the boundary only. It does not define a daemon API, compose
file, image, socket mount, or implementation.

## Future providers
Future providers may include:

- VM providers;
- Kubernetes providers;
- IaC-backed template providers;
- cloud providers;
- Proxmox or homelab providers;
- externally managed Worker pools.

Each provider must implement the same policy, capability, audit, cleanup, and
kill-switch expectations before being used for trusted automation.

## Authority and safety
Provider actions are approval-sensitive when they create, mutate, scale, destroy,
or privilege-elevate environments. They require the gates defined in
`docs/policies/authority-and-safety.md`, including per-project policy, Human
approval records where required, brokered credentials, validation expectations,
audit/rollback, and kill switches.

## Non-goals
- No provider runtime implementation.
- No Docker, VM, Kubernetes, IaC, cloud, or Proxmox mutation.
- No daemon API schema.
- No production credential handling.
- No testbed execution.
