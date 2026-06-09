# Worker Ticket Template

Use this template when the Dokkaebi Manager turns Human intent into a
GitHub Project/Symphony-ready Worker ticket.

## Ticket metadata

- **Title:** `<short imperative task name>`
- **Source request:** `<link or summary of original Human request>`
- **Manager owner:** `<manager adapter or human owner>`
- **Target backend:** `Symphony / GitHub Project`
- **Priority:** `<low | medium | high | urgent>`
- **Status:** use one semantic state from `WORKFLOW.md`, or map the backend label
  to one of these states: `Intake`, `Clarifying`, `Ready`, `Dispatchable`,
  `In Progress`, `Needs Review`, `Human Review`, `Fix Requested`, `Merging`,
  `Done`, `Reopened`, `Blocked`, `Failed`, `Cancelled`.

## Goal

Describe the concrete outcome the Worker must produce.

## Context

Provide only the context needed to execute safely:

- relevant repository, branch, issue, workpad, PR, or document links;
- important prior decisions;
- related tickets or dependencies;
- known constraints from Human/Manager review.

## Non-goals

List adjacent work that is explicitly out of scope.

## Acceptance criteria

The Worker ticket is complete only when all checked criteria are satisfied.

- [ ] `<observable outcome>`
- [ ] `<evidence or artifact expected>`
- [ ] `<review or handoff condition>`

## Constraints

- Stay within the assigned files, systems, and permission level.
- Do not broaden scope without Manager approval.
- Preserve Manager replaceability; do not hard-code Hermes, Codex-based tooling,
  OpenClaw, or Symphony-specific assumptions unless this ticket explicitly
  targets that adapter/backend.
- Keep diffs small, reviewable, and reversible.
- Follow [`../policies/git-governance.md`](../policies/git-governance.md) when
  creating branches, commits, PRs, or submodule pointer updates.

## Permission level

Choose the narrowest level that lets the Worker complete the task.

- **Read-only:** inspect and report only.
- **Repo-local write:** edit files in the assigned repository/workspace only.
- **PR preparation:** create GitHub Flow branches, commits, and PRs, but do not
  merge.
- **External write:** requires explicit Human approval before execution.

## Human approval gates

This section summarizes the canonical policy in
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).
Human approval is required before any of these actions:

- cloud or Proxmox create/update/delete operations;
- secret, credential, token, SSH key, or admin-account access;
- Worker creation, scaling, privilege elevation, or broader tool/network access;
- Manager runtime replacement;
- PR merge, deployment, production data writes, or production infrastructure
  writes unless a later ADR explicitly narrows this gate.

## Git plan

Fill this section when repository writes are in scope. Use `N/A` only for
read-only or planning-only tickets.

- **Base branch:** `<main or approved base>`
- **Branch name:** `<type>/<scope-slug> or <actor>/<type>/<scope-slug>`
- **Commit authority:** `<prepare only | create commits | open PR>`
- **Commit grouping:** `<atomic commit plan or N/A>`
- **Submodule handling:** `<N/A or expected submodule path/commit boundary>`
- **Merge authority:** `Human approval required unless a later ADR grants a narrow exception`

## Worker instructions

1. Restate the goal and constraints before implementation.
2. Inspect the relevant files/systems before editing.
3. Implement the smallest correct change.
4. Verify with the commands below.
5. Return a Worker result packet using [`worker-result-packet.md`](worker-result-packet.md).

## Validation requirements

List exact commands or checks the Worker must run.

```bash
# Example
<command that proves the acceptance criteria>
```

If a required check cannot run, the Worker must explain why and provide the next-best evidence.

## Expected result packet

The Worker must report:

- task identifier and source ticket;
- summary of completed work;
- changed files, branch, commit, PR, or artifact links;
- validation commands and outcomes;
- acceptance-criteria evidence and whether acceptance criteria were met;
- blockers or missing permissions;
- residual risks;
- scope-control statement and approval-gate status;
- recommended next Manager/Human action.

## Escalation rules

Escalate to the Manager instead of continuing when:

- acceptance criteria conflict with constraints;
- required permission is missing;
- a Human approval gate is reached;
- repository/project state differs materially from the ticket;
- safe completion requires files, systems, or credentials outside the ticket scope.
