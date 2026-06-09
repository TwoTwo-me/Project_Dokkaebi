# Project Dokkaebi — Deep Interview Spec

## Metadata
- Slug: `project-dokkaebi`
- Profile: standard
- Final ambiguity: **15%**
- Threshold: **20%**
- Context type: greenfield Dokkaebi repo + local Symphony clone inspected
- Source traces: local planning artifacts, path intentionally omitted from the
  committed spec.

## Clarity Breakdown

| Dimension | Score | Gap / note |
|---|---:|---|
| Intent | 0.90 | Core hypothesis is clear: validate the delegation loop as a manageable project system. |
| Outcome | 0.88 | First milestone is a set of repo-local operating documents/contracts. |
| Scope | 0.82 | Dokkaebi is above Symphony, not a Symphony rewrite in milestone 1. |
| Constraints | 0.78 | Key human-approval boundaries are explicit; PR/deploy automation remains a risk to re-evaluate in planning. |
| Success criteria | 0.80 | Required documents/templates are listed. |
| Context grounding | 0.90 | Local Symphony clone was inspected and can be used as concrete backend context. |

## Intent

Project Dokkaebi should define a practical AI project-management structure where:

```text
Human -> AI Manager Agent -> Symphony/GitHub Project -> AI Worker -> verifiable result return
```

The first critical question is whether this delegation loop can become a reliable, auditable, human-manageable operating model instead of an ad-hoc chain of agent prompts.

## Desired Outcome

Milestone 1 should register Dokkaebi in this repository as the **upper Manager layer** above Symphony:

- Dokkaebi interprets Human goals.
- Dokkaebi decides or requests approval according to policy.
- Dokkaebi creates/maintains work contracts suitable for Symphony/GitHub Project execution.
- Symphony remains the lower worker orchestration backend that watches GitHub Projects, dispatches isolated Worker runs, and records progress/results.
- AI Workers execute bounded tickets and return evidence through tracker/workpad/PR/test artifacts rather than default direct Human conversation.

## In Scope for Milestone 1

Create a repo-local contract/documentation foundation for Dokkaebi:

1. **README concept declaration**
   - Explain Project Dokkaebi, the 3-layer structure, and primary use cases.
2. **ARCHITECTURE document**
   - Define Human, AI Manager, Symphony/GitHub Project, Worker, credential broker, approval gates, and result paths.
3. **WORKFLOW contract**
   - Define how Manager turns Human intent into GitHub Project tickets and how Workers consume/report them.
4. **Authority/Safety policy**
   - Define human-required approvals, automation candidates, forbidden actions, audit expectations, and escalation rules.
5. **GitHub Project ticket templates**
   - Define fields/sections Workers can reliably consume: goal, context, acceptance criteria, constraints, permissions, validation, result packet.
6. **Embedded critical review**
   - Include feasibility, failure modes, and staged experiment criteria inside the above documents or the planning artifact, even if not a separate standalone file.

## Out of Scope / Non-goals for Milestone 1

- No default direct Human-Worker conversation path.
  - Worker communication should flow through Manager/tracker/workpad unless explicitly approved as an exception.
- No separate user-facing dashboard.
  - Use GitHub Project, workpad comments, PRs, logs, and documents first.

## Decision Boundaries

Human approval is required before Dokkaebi/Manager/Worker may perform:

- Cloud or Proxmox changes: VM/network/storage/IAM/firewall/cost-bearing resource create/update/delete.
- Secret or credential access: API keys, SSH keys, tokens, admin accounts, repository/cloud authority delegation.
- Worker scaling or privilege elevation: new Worker creation, parallelism increase, broader tool/network access, stronger permissions.
- Manager runtime replacement: switching the core Manager implementation among Hermes/OpenClaw/Codex/oh-my-codex or future alternatives.

Automation candidates, subject to later planning safety review:

- GitHub Project ticket creation and state updates.
- Worker result comments/workpad updates.
- PR preparation and validation artifact posting.

**Risk flag:** PR merge/deploy/production writes were not selected as approval-required in Round 4, but they are high-impact operations. The next planning step should either explicitly require Human approval for them or define a narrower safe automation condition such as “only after Human moves ticket to Merging.” The local Symphony workflow already treats `Human Review` and `Merging` as Human-mediated states.

## Constraints

- Manager implementation must remain replaceable; do not hard-lock Dokkaebi to Hermes, OpenClaw, or Codex.
- Symphony is a concrete first backend, not the conceptual owner of Human intent/policy.
- Worker execution must be bounded by ticket scope, workspace isolation, permission constraints, and result evidence.
- No Manager PAT/OAuth token should be copied directly into Worker spaces. Prefer brokered, least-privilege, short-lived credentials where write access is needed.
- Real infrastructure actions require explicit approval and should not be part of milestone 1 unless separately authorized.

## Local Symphony Evidence

Local clone inspected:

- Path: `symphony-github-project-tracker/`
- Remote: `https://github.com/TwoTwo-me/symphony-github-project-tracker`
- Key files:
  - `symphony-github-project-tracker/README.md`
  - `symphony-github-project-tracker/SPEC.md`
  - `symphony-github-project-tracker/elixir/WORKFLOW.md`
  - `symphony-github-project-tracker/docs/github-project-v2-symphony-playbook.md`

Relevant confirmed capabilities:

- GitHub Projects v2 issue monitoring.
- Issue-status-based dispatch.
- Isolated Codex execution per issue/workspace.
- Workpad comment / PR / project status tracking.
- Docker Compose and external SSH worker fleet support.
- Worker OS metadata matching (`linux`, `windows`, `macos`).
- Credential Broker boundary with GitHub App installation tokens and capability allowlists.
- Whitelist-label admission control and Status mapping.
- Human Review / Merging states in the example workflow.

## Critical Feasibility Review

### Strong points

- GitHub Project provides human-visible project-level management, audit trail, and manual override points.
- Symphony already covers much of the lower orchestration layer, reducing the need for Dokkaebi to implement worker dispatch from scratch.
- Keeping Dokkaebi above Symphony preserves Manager portability.
- Ticket templates can turn vague Human intent into Worker-consumable contracts.
- Workpad/PR/test evidence can become the result packet Manager uses to summarize outcomes to Human.

### Main failure modes

1. **Authority leakage**
   - Manager or Worker receives broad credentials and performs infrastructure or repo writes beyond intended scope.
2. **Tracker drift**
   - GitHub Project status, issue comments, PR state, and actual workspace state disagree.
3. **Scope inflation**
   - Worker discovers adjacent improvements and expands beyond ticket acceptance criteria.
4. **Manager ambiguity**
   - Human asks for outcomes, but Manager emits underspecified tickets that Workers cannot safely execute.
5. **Backend coupling**
   - Dokkaebi accidentally becomes a Symphony-specific wrapper rather than a portable Manager contract.
6. **Human review bypass**
   - PR merge/deploy or infra changes happen without a clear Human gate.

### Recommended mitigations

- Use explicit ticket fields for goal, non-goals, acceptance criteria, permission level, validation, and expected result packet.
- Preserve Human approval gates for infrastructure, secrets, worker scaling, and Manager replacement.
- Add a planning decision for PR merge/deploy gates before execution automation.
- Treat Symphony as a backend adapter behind a Dokkaebi work-contract interface.
- Require Worker result packets to include changed files/PR links/tests/logs/blockers/residual risk.
- Use labels/status mapping as a minimum admission control; do not rely on issue body text alone.

## Testable Acceptance Criteria for Milestone 1

A downstream planner/executor can consider milestone 1 complete when:

- [x] `README.md` explains Project Dokkaebi, the 3-layer model, and where Symphony fits.
  - Evidence: `README.md` defines `Human -> AI Manager Agent -> Symphony/GitHub Project -> AI Worker -> verifiable result return` and states Symphony is the first worker orchestration backend.
- [x] `ARCHITECTURE.md` defines components, trust boundaries, authority flow, and result flow.
  - Evidence: `ARCHITECTURE.md` defines Human, Dokkaebi Manager, Symphony/GitHub Project, AI Worker, credential broker, approval gates, trust boundaries, authority flow, result flow, and critical risks.
- [x] `WORKFLOW.md` defines Manager-to-Symphony-to-Worker operating flow and state transitions.
  - Evidence: `WORKFLOW.md` defines intake, work-contract drafting, approval/readiness gate, Symphony dispatch, Worker execution, result packet, Manager review, and the semantic status model.
- [x] A safety/authority policy document defines approval-required actions, automation candidates, forbidden actions, and audit requirements.
  - Evidence: `docs/policies/authority-and-safety.md` defines Human approval required, automation allowed by default, forbidden default actions, approval evidence records, fail-closed preflight, credential broker boundary, Symphony compatibility policy, and audit/review.
- [x] GitHub Project issue/ticket templates exist for Worker-ready tasks.
  - Evidence: `docs/templates/worker-ticket.md` defines Worker-ready ticket fields, approval gates, validation requirements, result-packet expectations, and escalation rules; `docs/templates/worker-result-packet.md` defines closeout evidence.
- [x] The documents explicitly state Dokkaebi is the upper Manager layer and Symphony is the worker orchestration backend for the first implementation path.
  - Evidence: `README.md`, `ARCHITECTURE.md`, `WORKFLOW.md`, `docs/contracts/manager-contract.md`, `docs/policies/authority-and-safety.md`, and `docs/adapters/hermes.md` all preserve the Dokkaebi Manager above Symphony/GitHub Project boundary.
- [x] The documents preserve Manager replaceability across Hermes, OpenClaw, Codex and oh-my-codex, and future managers.
  - Evidence: `README.md`, `ARCHITECTURE.md`, `docs/adr/0001-hermes-first-manager-contract.md`, and `docs/contracts/manager-contract.md` define Hermes-first but contract-first Manager replaceability.
- [x] The documents include a critical review section or equivalent risk/failure-mode coverage.
  - Evidence: `ARCHITECTURE.md` includes critical risks and mitigations; this interview spec includes Critical Feasibility Review, failure modes, and mitigations.
- [x] The PR/deploy/production-write decision boundary is resolved or explicitly marked as a planning blocker before enabling automation.
  - Evidence: `ARCHITECTURE.md`, `WORKFLOW.md`, `docs/contracts/manager-contract.md`, `docs/policies/authority-and-safety.md`, and `docs/templates/worker-ticket.md` require Human approval for PR merge, deployment, production data writes, and production infrastructure writes unless a later ADR grants a narrow exception.

## Assumptions Exposed + Resolutions

| Assumption | Resolution |
|---|---|
| Symphony/GitHub should be used instead of direct Worker launch. | Accepted because it provides auditability, async queueing, isolation, result packets, Manager portability, and human project-level management. |
| Dokkaebi might mean the whole system or just the Manager. | Resolved for milestone 1: Dokkaebi is the upper Manager layer above Symphony. |
| Symphony repository might be inaccessible. | Resolved by inspecting local clone under this repo. |
| First milestone might require implementation. | Resolved as a contract/documentation milestone. |
| Worker direct conversation might be desirable. | Non-goal by default; communication should flow through Manager/tracker unless explicitly approved. |

## Pressure-pass Findings

The main pressure pass challenged why Manager should not simply spawn Workers directly. The answer established that the tracker layer is not incidental; it is the core control plane for audit, async work, isolation, proof packets, portability, and human project-level management. This narrowed Dokkaebi from “agent launcher” to “project governance and delegation manager.”

## Recommended Handoff

Use this spec as the requirements source of truth. Recommended next step:

```text
$ralplan docs/deep-interview-project-dokkaebi.md
```

Planning should produce PRD/test-spec artifacts for the milestone documents. Implementation should not start until planning resolves the PR/deploy approval boundary.

Alternative follow-ups:

- `$ultragoal`: durable goal tracking after planning is approved.
- `$team`: if writing docs/templates and reviewing Symphony integration should happen in parallel.
- `$autopilot`: if you want direct plan+execute+QA from this spec.
- `$ralph`: explicit fallback only for a persistent single-owner completion loop.
