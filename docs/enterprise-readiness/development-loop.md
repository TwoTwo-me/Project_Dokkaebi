# Enterprise Readiness Development Loop

This document explains how Project Dokkaebi uses
[`criteria.json`](criteria.json) as the single source of truth for company-use
readiness.

## Source Of Truth

`criteria.json` owns the durable criteria:

- readiness areas and current percentages;
- target percentage for every area and required capability;
- evidence required to raise a score;
- next GitHub issue candidates;
- Carbon Design System color baseline for future UI work;
- phase rules for issue, worktree, pull request, merge, and re-evaluation.

Issue URLs stored in `criteria.json` are backlog candidates until they are added
to an approved GitHub Project and given the required lifecycle/admission fields.
They are not dispatchable work by URL alone. If the repository or owner account
does not yet have the intended GitHub Project, creating or mutating that Project
requires separate explicit Human approval.

The company-readiness report remains source evidence, not the active criteria
registry. Future evaluation criteria must be added to `criteria.json` first and
then validated with:

```bash
bash scripts/validate-readiness-criteria.sh
```

## Closed Loop

Each readiness phase follows this loop:

1. Evaluate every area in `criteria.json` against current repository evidence.
2. Create one GitHub issue per deficient area or missing capability.
3. Assign each issue to an isolated worktree or worker workspace.
4. Implement only the issue scope.
5. Open a pull request with context, decision, rationale, validation, residual
   risk, and issue linkage.
6. Merge only after required checks and approval policy are satisfied.
7. Re-run validation and re-score the changed criteria.
8. Create follow-up issues for any area still below 100%.

The loop stops only when a required enterprise standard is genuinely undefined
or needs a Human product decision.

## Self-Improvement Contract

The loop may improve itself when evidence shows the current process is failing
to drive readiness work safely or clearly. Valid triggers include:

- a readiness issue is missing scope, authority, validation, result evidence,
  or metadata hygiene needed for dispatch;
- a criterion cannot be scored from repository, GitHub, CI, runtime, or
  operations evidence;
- a validator passes while a documented loop requirement is absent or
  unenforced;
- a review, incident, or failed pull request identifies a repeatable gap in the
  loop itself;
- an enterprise standard is undefined and needs a Human decision before scoring
  can continue.

Self-improvement work follows the same loop as product work:

1. Open or update a GitHub issue that names the loop gap and acceptance
   criteria.
2. Capture RED evidence showing the missing or weak loop behavior.
3. Make the smallest criteria, documentation, issue-template, or validator
   change that closes the gap.
4. Run readiness, contract, package, git-governance, and targeted validation.
5. Open and merge a pull request before using the improved loop to rescore
   readiness.

The loop must not use self-improvement to bypass Human approval, weaken result
evidence, skip validation, mutate production or infrastructure, or mark a
criterion 100% without evidence.

## Issue Contract

Every readiness issue should include:

- criteria area id or missing capability id;
- scope and non-goals;
- current percentage and target percentage;
- acceptance criteria copied or refined from `criteria.json`;
- required validation commands or review evidence;
- required approval boundary when the work touches credentials, infrastructure,
  workers, merge, deploy, or production operations;
- expected result-packet or pull request evidence.

GitHub Project `Status` remains the lifecycle source of truth for work items.
Issues, workpads, pull requests, logs, and validation outputs are evidence
surfaces. Repository issues that are not attached to the approved Project are
planning backlog, not active lifecycle records.

## Worktree And Branch Contract

Work for each issue runs in an isolated worktree or worker workspace. Branches
follow [`../policies/git-governance.md`](../policies/git-governance.md):

- use `<type>/<scope-slug>`;
- do not use actor prefixes;
- keep branches short lived;
- keep commits atomic and rationale-rich.

Public issue, branch, commit, and pull request metadata should describe the
product decision and evidence. Do not expose private tool execution details,
secrets, token contents, or local machine state that is not needed for review.

## Development Auth Boundary

The current Human-approved development exception for copying file-based Codex
CLI authentication to trusted dev/sandbox Hammer workers is documented in
[`../operations/worker-cli-auth.md`](../operations/worker-cli-auth.md).
That exception is narrow:

- trusted private development and sandbox worker targets only;
- Codex CLI worker authentication only;
- no GitHub Manager tokens, SSH private keys, kubeconfig files, Proxmox
  credentials, GitHub App private keys, or production credentials;
- no Docker daemon, Kubernetes secret, Proxmox, deployment, or production
  authority without a separate explicit approval.

## Carbon Design Baseline

Future Dokkaebi UI work uses the Carbon Design System color guidance as the
baseline: <https://carbondesignsystem.com/elements/color/overview/>.

Practical interpretation for Dokkaebi:

- use Carbon role-based tokens rather than hard-coded UI colors;
- support Carbon light and dark theme layering rules;
- use the primary action color intentionally and reserve support colors for
  status, notification, and alert semantics;
- provide visible focus states and accessible contrast for text, icons,
  graphical elements, and data visualizations;
- keep operational UI dense, scannable, and restrained.

Any future UI pull request should include visual QA evidence that checks token
usage, interaction states, contrast, desktop and mobile layout, and
information-density fit for an enterprise operations product.
