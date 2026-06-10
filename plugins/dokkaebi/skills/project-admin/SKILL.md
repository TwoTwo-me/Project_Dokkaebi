---
name: project-admin
description: Use when administering Dokkaebi GitHub Projects, including Greenfield or Brownfield setup, required fields, issue and item changes, dry-runs, rollback notes, and authority gates.
---

# Dokkaebi Project Administration

Use this skill for GitHub Project setup and safe project or issue administration for Dokkaebi. Keep GitHub Project Status as the lifecycle SOT for intake, admission, dispatch, review, and closeout state.

## Modes

- **Greenfield**: create or select the target GitHub Project, then create/discover fields before adding work. Use `createProjectV2` only after owner, repository, title, and authority are confirmed.
- **Brownfield**: discover the existing project, linked repository, fields, items, and current status values first. Reuse existing fields and status options unless a new field is explicitly needed.

## Required Fields

Every managed project must have these required fields before admission or dispatch:

- `Status`
- `Agent`
- `Authorization`
- `Authorized By`
- `Symphony Admission`

If any required field is missing, treat the project as not dispatch-ready until field creation or an approved exception is recorded.

## Safe Mutation Rules

Default to dry-run behavior for project-altering or issue-altering work. The dry run must list the target owner/repository/project, proposed mutations, affected issue or item IDs, required fields, permission level, approval status, rollback notes, and expected GitHub Project Status transitions.

Allowed v1 mutations after the dry run and applicable authority gates:

- Create/select a project, including `createProjectV2` when a new project is approved.
- Create/discover fields, including the required fields above.
- Link the project to the repository with `linkProjectV2ToRepository`.
- Add existing issues or pull requests as project items.
- Create issues with scoped title, body, labels, and acceptance criteria.
- Update item fields/status with `updateProjectV2ItemFieldValue`, including GitHub Project Status changes.
- Create status updates that summarize admission, dispatch, blockers, review, or closeout.

For each executed mutation, record IDs or URLs, prior values for updates, and rollback notes. Rollback notes should state the practical undo path, such as restoring the previous field value, removing a newly added item, closing a newly created issue with rationale, or unlinking a repository after approval.

## Authority Gates

- Do not infer approval from token access, repository access, or project admin permissions.
- Human approval is required before credential changes, infrastructure changes, production writes, worker scaling, merge/deploy actions, destructive project/item/field deletion, or broad collaborator changes.
- Destructive project/item/field deletion and broad collaborator changes are explicit approval-required actions.
- Store the approver in `Authorized By`, the allowed scope in `Authorization`, and the admission decision in `Symphony Admission`.
- If scope, acceptance criteria, validation, permission level, or result-packet expectations are unclear, stop before mutation and report the blocker.
