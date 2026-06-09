# PROJECT KNOWLEDGE BASE

**Generated:** 2026-06-03
**Commit:** 19ef7bc
**Branch:** main

## OVERVIEW

Project Dokkaebi is the upper AI Manager layer for a human-governed, auditable work loop. The root repository is contract and policy documentation; the executable worker orchestration backend lives in the `symphony-github-project-tracker` submodule.

## STRUCTURE

```text
Project_Dokkaebi/
|-- README.md                         # entrypoint for the Dokkaebi contract milestone
|-- ARCHITECTURE.md                   # Manager, Symphony, Worker, credential boundaries
|-- WORKFLOW.md                       # Human -> Manager -> Symphony -> Worker state model
|-- .github/                          # PR template and GitHub Actions governance checks
|-- docs/                             # normative contracts, policy, ADR, templates
|-- scripts/validate-contract-docs.sh # root contract-doc validation gate
`-- symphony-github-project-tracker/    # Git submodule with the Symphony backend
```

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Understand Dokkaebi's role | `README.md`, `ARCHITECTURE.md` | Manager-first, contract-first project framing. |
| Trace workflow states | `WORKFLOW.md` | Status names must stay aligned with worker ticket templates. |
| Edit Manager obligations | `docs/contracts/manager-contract.md` | Normative adapter contract. |
| Edit authority rules | `docs/policies/authority-and-safety.md` | Human approval and credential boundaries. |
| Edit Git workflow rules | `docs/policies/git-governance.md` | GitHub Flow, branch naming, commit rationale, PR, and submodule policy. |
| Edit GitHub enforcement | `.github/`, `scripts/validate-git-governance.sh` | PR template and required-status-check implementation. |
| Add or revise ticket shape | `docs/templates/worker-ticket.md` | Must remain dispatch-ready for Symphony. |
| Add or revise closeout shape | `docs/templates/worker-result-packet.md` | Evidence schema for Manager review. |
| Validate root docs | `scripts/validate-contract-docs.sh` | Checks required files, phrases, links, and status vocabulary. |
| Work on runtime backend | `symphony-github-project-tracker/` | Submodule; see child `AGENTS.md` files. |

## CODE MAP

LSP codemap was unavailable because `elixir-ls` is not installed in this environment. This fallback map is from repository structure, configs, and symbol/file scans.

| Surface | Location | Role |
| --- | --- | --- |
| Manager contract | `docs/contracts/manager-contract.md` | Stable duties for Hermes, Codex, OpenClaw, and future adapters. |
| Safety policy | `docs/policies/authority-and-safety.md` | Approval gates, fail-closed preflight, credential broker boundary. |
| Git governance policy | `docs/policies/git-governance.md` | Branch, commit, PR, and submodule audit rules. |
| GitHub enforcement | `.github/workflows/dokkaebi-governance.yml`, `scripts/validate-git-governance.sh` | Status checks that can be required by branch protection/rulesets. |
| Workflow contract | `WORKFLOW.md` | Intake, dispatch, review, closeout, and status semantics. |
| Symphony backend | `symphony-github-project-tracker/elixir/` | Elixir/OTP GitHub Project tracker and Codex runner. |
| Docker worker fleet | `symphony-github-project-tracker/docker/` | Manager plus SSH worker Compose lane. |

## CONVENTIONS

- Root docs are the durable source of truth for Manager authority, workflow, and evidence requirements.
- `ARCHITECTURE.md`, `WORKFLOW.md`, `manager-contract.md`, `authority-and-safety.md`, and the two worker templates must stay semantically aligned.
- Approval exceptions use "later ADR" language; do not soften this into informal policy wording.
- Git work follows GitHub Flow from `docs/policies/git-governance.md`; commits must preserve development process, decision rationale, validation, and residual risk.
- `.github/` defines PR templates and status checks; GitHub branch protection or rulesets must require those checks before they become hard merge gates.
- The submodule is a separate Git worktree. Check both root and submodule status before reporting changes.
- Keep root-level changes focused on contract docs, validation scripts, or repository guidance. Runtime implementation belongs under `symphony-github-project-tracker/`.

## ANTI-PATTERNS (THIS PROJECT)

- Do not infer Human approval for credentials, infrastructure, worker scaling, merge, deploy, or production writes from tool availability.
- Do not let Manager memory be the only record of approval, blocker, validation, or closeout evidence.
- Do not replace the Manager contract with Hermes-specific, Codex-specific, or OpenClaw-specific behavior.
- Do not weaken result-packet requirements from "must include" concepts to optional wording in normative docs.
- Do not dispatch vague work: missing scope, acceptance criteria, validation, permission level, or result-packet surface means blocked.

## COMMANDS

```bash
bash scripts/validate-contract-docs.sh
git status --short --branch
git submodule status
git -C symphony-github-project-tracker status --short --branch
```

## NOTES

- `symphony-github-project-tracker` is configured as a submodule from `https://github.com/TwoTwo-me/symphony-github-project-tracker`.
- At generation time the submodule was checked out at `f50ce0c` on detached `HEAD`.
- Root validation does not build the Elixir app; use the child guidance under `symphony-github-project-tracker/elixir/` for runtime gates.
