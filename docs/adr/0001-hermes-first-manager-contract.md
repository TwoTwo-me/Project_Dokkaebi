# ADR 0001: Hermes-first, contract-first AI Manager strategy

## Status
Accepted

## Context
Project Dokkaebi should not be locked to one AI Manager runtime. The Manager may be Hermes, Codex/oh-my-codex, OpenClaw, or a future custom implementation. The stable part of Dokkaebi should be the operating contract that transforms Human intent into worker-ready GitHub Project/Symphony work, not the specific agent process that happens to run first.

The first concrete Manager baseline will be **Hermes-first** because Hermes is well aligned with a long-running, self-hosted, memory-capable manager role. However, Hermes must be treated as an implementation adapter, not as the conceptual definition of Dokkaebi.

## Decision
Dokkaebi will use a **contract-first Manager architecture**:

```text
Human
  -> Dokkaebi Manager Contract
  -> Hermes Manager Adapter (v0 baseline)
  -> Symphony / GitHub Project
  -> AI Workers
  -> Result Packet
```

The Dokkaebi Manager Contract is expressed through open, inspectable artifacts:

- guides and runbooks;
- open skill-style instructions, preferably `SKILL.md`-like where practical;
- CLI commands for deterministic actions;
- MCP servers/tools for structured integration where CLI is insufficient;
- GitHub Project issue templates and state contracts;
- result-packet schemas for Worker output review.

Hermes is the first target Manager implementation. Codex/OMX remains the development/planning/maintenance agent and can also act as an alternate Manager adapter. OpenClaw remains a later candidate for channel/UI-heavy operation, not the initial root authority layer.

## Consequences

### Positive
- Dokkaebi can start with Hermes without hard vendor/runtime lock-in.
- The Human-facing and Worker-facing contracts remain reusable across managers.
- CLI/MCP boundaries allow deterministic integration tests and safer automation gates.
- Skills/guides can be versioned in this repository and reviewed like code.

### Risks
- Hermes-first may tempt the project to depend on Hermes-specific memory or gateway behavior too early.
- Open skill formats can drift unless schemas and acceptance tests are added.
- MCP/CLI integrations can accidentally become authority bypasses if safety policy is not enforced at the contract layer.

### Guardrails
- Every Manager adapter must implement the same Dokkaebi Manager Contract before receiving real credentials or infrastructure authority.
- Human approval remains required for cloud/Proxmox changes, secret access, Worker scaling/privilege elevation, and Manager runtime replacement.
- PR merge/deploy/production-write authority remains unresolved until a later explicit policy decision.
- Hermes-specific behavior must be documented as adapter behavior, not as Dokkaebi core behavior.

## Rejected alternatives
- **Codex/OMX-only Manager:** too tied to the current development/runtime environment.
- **OpenClaw-first Manager:** powerful channel and local automation model, but broader host/tool authority is too risky for the first root Manager layer.
- **Custom Manager from scratch:** too much runtime/scheduler work before the core contract is validated.
