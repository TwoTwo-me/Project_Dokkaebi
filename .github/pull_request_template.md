# Dokkaebi Pull Request

## Goal

<!-- One concrete outcome this PR delivers. -->

## Non-goals

<!-- Adjacent work that is explicitly out of scope. -->

## Changed artifacts

<!-- List root docs, policies, templates, submodule pointer updates, or runtime files. -->

## Decision rationale

Context:
<!-- What problem, goal, or prior state led to this PR? -->

Decision:
<!-- What changed, and which approach was chosen? -->

Why:
<!-- Why this approach instead of plausible alternatives? -->

## Validation

<!-- Commands/checks run and concise outcomes. -->

```text
bash scripts/validate-contract-docs.sh
```

## Risks

<!-- Residual risks, skipped checks, or N/A with rationale. -->

## Approval gates

<!-- State whether any Human approval gate was reached. -->

- PR merge: Human approval required unless a later ADR grants a narrow exception.
- Deployment / production write: Human approval required unless a later ADR grants a narrow exception.
- Credential / infrastructure / worker-scaling authority: Human approval required if reached.

## Public metadata hygiene

<!-- Confirm branch, commit messages, PR title/body, and project-facing summaries avoid private local paths and local tool-internal namespaces. -->

## Git status

<!-- Paste current status evidence relevant to this PR. Include submodule status when present or changed. -->

```text
git status --short --branch
git submodule status
git -C symphony-github-project-tracker status --short --branch
```
