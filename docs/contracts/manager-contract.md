# Dokkaebi Manager Contract

This contract defines what any AI Manager implementation must do to serve as Project Dokkaebi's Manager layer.

## Manager implementations

Initial target:

- Hermes Manager Adapter

Supported/future adapters:

- Codex/oh-my-codex Manager Adapter
- OpenClaw Manager Adapter
- Custom Manager Adapter

## Required capabilities

A Manager adapter must be able to:

1. Accept a Human request and preserve the original intent.
2. Clarify ambiguity before issuing Worker work when goals, non-goals, or approval boundaries are unclear.
3. Convert approved work into a GitHub Project/Symphony-ready ticket.
4. Attach acceptance criteria, constraints, validation requirements, permission level, and expected result packet.
5. Respect Human approval gates before high-impact actions.
6. Read Worker progress/result packets from GitHub Project, workpad comments, PRs, logs, or other configured surfaces.
7. Summarize Worker output back to the Human with evidence, blockers, residual risks, and next decisions.
8. Keep enough audit trail for another Manager adapter to resume.

## Stable contract artifacts

The preferred implementation surfaces are open and inspectable:

- Markdown guides and runbooks.
- Skill-style instruction folders, preferably with `SKILL.md` entrypoints where useful.
- CLI commands for deterministic local operations.
- MCP tools for structured stateful or external integrations.
- GitHub Project issue forms/templates.
- Result packet schemas.

## Authority levels

### Always requires Human approval

- Cloud or Proxmox changes.
- Secret or credential access.
- Worker creation, scaling, or privilege elevation.
- Manager runtime replacement.

### Automation candidates

- Drafting GitHub Project tickets.
- Updating workpad/progress comments.
- Posting validation evidence.
- Preparing PRs for review.

### Unresolved until explicit policy decision

- PR merge.
- Deployment.
- Production data or infrastructure writes.

## Result packet minimum

A Worker result packet should include:

- task identifier and source ticket;
- summary of completed work;
- changed files or PR links;
- validation commands and outcomes;
- blockers or missing permissions;
- residual risks;
- recommended next action for the Manager/Human.
