# Dokkaebi Worker Capability Model

This model defines routeable Worker capability metadata for Dokkaebi and
Symphony-native ProjectScopes.

## Purpose
Worker dispatch must be based on explicit, auditable capability metadata rather
than private Manager memory or incidental host access. A Manager writes Worker
requirements into a ticket/project item; Symphony routes eligible work inside the
ProjectScope to Workers whose registered capabilities satisfy those requirements.

## Minimum capability tiers

### `basic`
A Worker that can perform bounded code, documentation, analysis, and light local
validation without container orchestration.

Typical use:
- documentation edits;
- small code changes;
- static inspection;
- lightweight local commands allowed by project policy.

### `container-capable`
A Worker that can use Docker, Podman, or Compose-like tooling for development and
integration checks when the provider policy allows it.

Typical use:
- service-level local integration checks;
- Compose-based development environments;
- containerized toolchains;
- dependency isolation that is not a clean independent testbed.

`container-capable` is a schedulable capability. It must not imply broad host
Docker authority; provider policy decides how container access is exposed.

### `testbed`
A clean, independent verification environment used to confirm results separately
from the Worker that produced them.

Typical use:
- independent smoke checks;
- clean checkout validation;
- staging-like verification;
- regression confirmation before trusted direct action.

A testbed does not replace Worker-local Docker or Compose feedback. It is an
independent verification tier.

### Future provider-specific capabilities
Future capabilities may describe VM, Kubernetes, GPU, browser, OS, architecture,
network, repository, or environment-tier constraints. They must be documented in
project policy before dispatch depends on them.

## Capability metadata
A dispatchable ticket or project item should expose:

- required capability tier;
- optional capabilities;
- forbidden capabilities or environments;
- OS and architecture requirements;
- repository and branch scope;
- network mode;
- credential broker grant needs;
- validation requirements;
- result-packet requirements;
- escalation triggers when no compatible Worker exists.

A Worker registry entry should expose:

- Worker id;
- ProjectScope membership or allowlist;
- capability tiers;
- provider kind;
- environment tier;
- endpoint or registration handle;
- lease/expiry state;
- enabled, draining, unhealthy, or disabled status;
- current capacity and concurrency limits.

## Routing rules
- Symphony routes only within a ProjectScope.
- Dokkaebi manages which ProjectScopes exist and what policies they use.
- A ticket is not dispatchable when required capability metadata is missing.
- A Worker is not eligible when its capability, policy, credential, environment,
  or lease state is ambiguous.
- Missing capability should produce a blocked state, not best-effort dispatch.

## Relationship to trusted automation
Capability metadata does not grant authority by itself. Gated actions still
require per-project policy, credential broker approval, validation, audit,
rollback posture, environment tier checks, and kill-switch coverage.

## Non-goals
- No Worker scheduler implementation.
- No Worker registry file format migration.
- No Docker, VM, Kubernetes, or testbed provisioning.
- No production credential grant.
