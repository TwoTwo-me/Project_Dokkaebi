# Dokkaebi Git Governance Policy

This policy defines how Project Dokkaebi uses branches, commits, pull requests,
and submodule pointers. It applies to Human contributors, Manager adapters, and
Workers whenever repository writes are in scope.

## Policy goals

- Keep `main` reviewable, reproducible, and ready for the next Manager to audit.
- Follow GitHub Flow with short-lived branches and pull requests.
- Make commit history explain not only what changed, but why the chosen path was
  taken.
- Keep root contract-document changes distinct from Symphony submodule runtime
  changes.
- Preserve Human approval gates for merge, deploy, production writes, and shared
  history rewriting.

## Enforcement surfaces

GitHub-readable enforcement lives in `.github/`:

- `.github/pull_request_template.md` defines the required PR evidence surface.
- `.github/workflows/dokkaebi-governance.yml` runs the contract-doc and Git
  governance checks on pull requests.
- `scripts/validate-git-governance.sh` validates branch naming, PR evidence
  sections, commit-message rationale markers, and submodule PR evidence.

Repository administrators must configure GitHub branch protection or a ruleset
for `main` that requires the `contract-docs` and `git-governance` status checks
before merge. Without that GitHub setting, the workflow reports violations but
does not block merging by itself.

## GitHub Flow

- `main` is the only long-lived integration branch.
- Start every change from current `main`, or from the current submodule `main`
  when working inside `symphony-github-project-tracker/`.
- Use short-lived branches for every non-trivial change.
- Open a pull request from the branch back to `main`.
- Keep the branch updated with `main` by merge or rebase before review when drift
  affects validation.
- Run the relevant validation before requesting review.
- PR merge requires explicit Human approval unless a later ADR grants a narrow
  exception.
- Delete merged branches after the merge unless a Human intentionally keeps them
  for audit or release work.

Direct commits to `main` are reserved for repository bootstrap, emergency repair,
or explicitly approved Human-maintainer actions. Any emergency direct write must
leave follow-up evidence that explains why the pull-request path was skipped.

## Branch naming

Use lowercase kebab-case names.

Preferred shape:

```text
<type>/<scope-slug>
```

Examples:

```text
feat/dokkaebi-routing
docs/git-governance
fix/credential-broker-timeout
chore/review-findings
infra/github-rulesets
```

Allowed types:

- `feat` - short alias for feature work.
- `feature` - user-visible capability or new workflow behavior.
- `fix` - bug fix or correctness repair.
- `docs` - documentation, policy, ADR, or template change.
- `test` - validation-only change.
- `refactor` - behavior-preserving restructuring.
- `chore` - repository maintenance or tooling upkeep.
- `infra` - infrastructure definition, deployment plumbing, or environment setup.
- `experiment` - explicitly disposable exploration that must not merge as-is.

Avoid vague names such as `update`, `misc`, `wip`, `final`, or `changes`.
Do not use local tool-internal namespace names, private workstation paths, or
default agent-generated branch prefixes in branch names.

## Commit policy

Commits are audit records. A reviewer should be able to read the commit subject
and body without private Manager memory and understand the development process,
the decision, the reason for that decision, and how it was verified.

Required rules:

- Keep commits atomic: one coherent reason to change, one coherent rollback
  boundary.
- Do not mix unrelated root documentation, submodule runtime implementation,
  generated files, and test-only changes in one commit unless they are
  inseparable.
- Do not commit unrelated dirty work.
- Inspect root and submodule status before committing when a submodule is
  present.
- Use an imperative subject that names the outcome, not the activity.
- Avoid final-history subjects such as `wip`, `fix stuff`, `updates`, or
  `changes`.
- Commit messages must preserve the development process and decision rationale.

For non-trivial commits, use this body shape:

```text
Context:
<problem, goal, or prior state>

Decision:
<what changed and which approach was chosen>

Why:
<reason this approach was chosen, including rejected alternatives when useful>

Validation:
<commands/checks run and concise outcomes>

Risks:
<residual risk, skipped check, or N/A>
```

An evidence-style body is also valid when it preserves the same audit value:

```text
Constraint: <scope, safety, compatibility, or operational constraint>
Decision: <chosen approach, when useful>
Rejected: <alternative> | <reason it was not chosen>
Tested: <commands/checks and concise outcomes>
Not-tested: <skipped checks and why>
```

Optional footers:

```text
Refs: <issue, ticket, workpad, PR, or ADR>
Plan: <plan path or N/A>
Evidence: <result packet, log, or artifact path>
Submodule: <path and commit sha when the root commit updates a gitlink>
```

Squashing is allowed only when the final squashed commit preserves the rationale
and validation evidence from the commits being removed. Do not squash away the
reason a choice was made.

## Pull request requirements

Every pull request must include:

- goal and non-goals;
- changed artifacts;
- decision log or short rationale for the selected approach;
- validation commands and outcomes;
- residual risks and skipped checks;
- approval-gate status;
- root `git status --short --branch` when the root repo changed;
- `git submodule status` and `git -C symphony-github-project-tracker status
  --short --branch` when the submodule is present or changed.

The PR body must be understandable without reading Manager chat memory.

## Public metadata hygiene

The PR title, branch, body, and commit messages must not expose private local
paths, local tool-internal namespaces, or default agent-generated branch
prefixes.

## Submodule policy

`symphony-github-project-tracker/` is a separate Git worktree. Treat it as a
separate repository even when it is checked out under Project Dokkaebi.

Rules:

- Submodule commits must be created inside the submodule first.
- Root commits must not silently include submodule implementation changes.
- A root gitlink update must cite the submodule path and target commit sha.
- If root docs and submodule code change for one work item, keep the submodule
  commit and the root commit separate.
- The root result packet or PR must include both root status and submodule
  worktree status.
- Do not vendor or copy submodule code into the root repo to avoid submodule
  workflow friction.

## Manager and Worker duties

When a ticket allows repository writes, the Manager must specify:

- base branch;
- intended branch name or naming pattern;
- allowed commit scope;
- whether commits may be created or only prepared;
- whether a PR may be opened;
- validation required before handoff;
- Human approval gates for merge, deploy, production writes, or history
  rewriting.

Workers must stop and ask for Manager/Human direction when the required branch,
commit, PR, submodule, or merge authority is missing or ambiguous.
