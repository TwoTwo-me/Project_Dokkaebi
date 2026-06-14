# Role-Based Onboarding And Troubleshooting Guide

This guide packages Project Dokkaebi onboarding for admins, approvers,
operators, auditors, and worker authors. It is a docs-only productization
contract for local validation and review. It does not create GitHub Projects,
mutate project fields, grant credentials, start workers, touch remote hosts,
run Docker or Kubernetes, deploy services, or write production data.

The guide is intentionally self-contained. A new team should be able to follow
the role journeys, setup checks, approval steps, result-packet closeout actions,
and troubleshooting paths without relying on undocumented operator knowledge.

Required exact terms: admin journey; approver journey; operator journey; auditor
journey; worker-author journey; install walkthrough; GitHub Project setup checks;
repository setup checks; approval and review actions; result-packet closeout
actions; Fire failure troubleshooting; worker failure troubleshooting; GitHub
failure troubleshooting; credential failure troubleshooting; validation failure
troubleshooting; project-field failure troubleshooting; PR failure
troubleshooting; result-packet failure troubleshooting; clear next actions;
approval boundary; permission level; docs-only.

Validation coverage keywords: validation failure troubleshooting; project-field
failure troubleshooting; result-packet failure troubleshooting.

## Permission Level

Permission level: docs-only and local validation.

Local readers may inspect files, run validation commands, and prepare issues or
pull requests that follow the repository governance policy. Credential,
production, infrastructure, worker, remote host, Docker, Kubernetes, deployment,
or GitHub Project control-plane mutation requires explicit Human approval under
[`docs/policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Role Journeys

### Admin Journey

1. Read [`README.md`](../../README.md), [`ARCHITECTURE.md`](../../ARCHITECTURE.md),
   and [`WORKFLOW.md`](../../WORKFLOW.md) to understand the Manager, Fire, and
   Hammer boundaries.
2. Confirm the target repository, GitHub Project, issue template, branch
   protection, required checks, and service ownership before admitting work.
3. Map GitHub Project `Status`, admission, authorized-by, permission level, and
   result-packet fields to the workflow states.
4. Run local validation commands from the install walkthrough before asking
   another role to operate the project.
5. Record the approval boundary, residual risks, and next action in the issue or
   pull request when setup is incomplete.

### Approver Journey

1. Start from the linked issue, pull request, or result packet; do not approve
   from a private chat summary alone.
2. Verify scope, acceptance criteria, non-goals, permission level, validation
   plan, and result evidence before approving dispatch or merge.
3. Check whether any credential, infrastructure, worker, remote host, Docker,
   Kubernetes, deployment, production, or GitHub Project control-plane gate is
   present.
4. Approve only the named operation, target, actor, evidence surface, and
   rollback or cleanup expectation.
5. Request changes when evidence is missing, ambiguous, stale, or outside the
   authority boundary.

### Operator Journey

1. Watch GitHub Project state, issue labels, pull request checks, Fire service
   logs, worker route summaries, and result-packet closeout evidence.
2. Dispatch only tickets that are Ready or Dispatchable under `WORKFLOW.md` and
   pass the fail-closed preflight in the Manager contract.
3. Use the troubleshooting table to classify Fire, worker, GitHub, credential,
   validation, project-field, PR, and result-packet failures.
4. Prefer blocked tickets with concrete missing conditions over best-effort
   dispatch.
5. Close the loop by linking validation output, approval-gate status, cleanup,
   residual risk, and next action.

### Auditor Journey

1. Start from the compliance package, immutable audit export design, issue, PR,
   and worker result packet.
2. Confirm the source ticket, acceptance criteria, validation evidence,
   approval-gate status, scope-control statement, and whether acceptance
   criteria were met.
3. Check that evidence links are durable and do not contain secrets, auth file
   contents, cookies, tokens, or private machine state.
4. Verify that retention, redaction, integrity, ownership, residual risk, and
   next action are recorded.
5. Reject closeout when the issue, PR, result packet, and project state do not
   reconcile.

### Worker-Author Journey

1. Read [`docs/templates/worker-ticket.md`](../templates/worker-ticket.md) and
   [`docs/templates/worker-result-packet.md`](../templates/worker-result-packet.md).
2. Write tickets with goal, scope, acceptance criteria, validation, permission
   level, Human approval gates, git plan, and expected result packet.
3. Keep worker route assumptions explicit: local worktree, SSH, Docker, and
   Kubernetes routes have different approval and cleanup requirements.
4. Return result packets with changed artifacts, commit rationale, acceptance
   evidence, validation evidence, blockers, residual risks, scope control, and
   recommended Manager or Human next action.
5. Do not include secret material in ticket prose or result summaries.

## Install Walkthrough

1. Clone or open the repository and confirm the current branch and submodule
   pointer:

   ```bash
   git status --short --branch
   git submodule status
   ```

2. Read the root contract entry points:

   ```bash
   sed -n '1,180p' README.md
   sed -n '1,220p' ARCHITECTURE.md
   sed -n '1,220p' WORKFLOW.md
   ```

3. Run the local contract gates:

   ```bash
   bash scripts/validate-readiness-criteria.sh
   bash scripts/validate-contract-docs.sh
   bash scripts/validate-git-governance.sh
   ```

4. Confirm the Fire configuration and `tracker.projects` mapping in the backend
   repository before admitting real project work. If the mapping is missing,
   keep the issue blocked and record the missing project state.
5. Confirm credential broker ownership, but do not copy, print, or broaden
   credentials as part of onboarding.
6. Confirm the service-management path only from documented service guidance;
   a docs-only onboarding pass is not permission to start or change services.

## Setup Checks

### GitHub Project Setup Checks

- `Status` values map to Intake, Clarifying, Ready, Dispatchable, In Progress,
  Needs Review, Human Review, Fix Requested, Merging, Done, Blocked, Failed,
  Cancelled, and Reopened.
- Admission fields capture permission level, authorized-by, approval-gate
  status, worker route, repository, and result-packet surface.
- Project mutations are separated from GitHub Project control-plane changes.
- Every dispatch candidate links a source issue, acceptance criteria, validation
  plan, and result-packet expectation.
- Field drift produces a blocked issue with a named missing field and next
  action.

### Repository Setup Checks

- Branches follow [`docs/policies/git-governance.md`](../policies/git-governance.md).
- Pull requests use the repository template and include decision rationale,
  validation, residual risk, and public metadata hygiene.
- Required checks include contract docs, git governance, readiness criteria, and
  package validation.
- Submodule changes are committed inside the submodule before any root gitlink
  update.
- Result packets cite changed artifacts, validation commands, approval-gate
  status, scope-control statement, and whether acceptance criteria were met.

## Approval And Review Actions

- For dispatch: confirm the issue is linked, scoped, validated, and in an
  admitted lifecycle state.
- For gated authority: capture the Human approver, exact target, exact operation,
  credentials or route requested, expiration if relevant, cleanup, and rollback
  or recovery path.
- For pull requests: review the diff, validation output, public metadata, linked
  issue, result-packet evidence, residual risk, and merge authority.
- For stale Human Review: comment with the missing decision, owner, deadline,
  and next escalation path instead of silently continuing.
- For rejection: move the ticket to Fix Requested or Blocked and name the
  failing condition.

## Result-Packet Closeout Actions

1. Confirm the result packet has task identity, changed artifacts, commit
   rationale, acceptance-criteria evidence, validation evidence, blockers or
   missing permissions, residual risks, scope control, approval-gate status, and
   recommended next action.
2. Reconcile issue state, pull request state, GitHub Project status, branch,
   commit, and evidence links.
3. Record cleanup receipts for workers, sessions, ports, containers, temporary
   files, browser contexts, and other resources used by the work.
4. Close the issue only when acceptance criteria are met or when the closeout
   explicitly records a blocked or superseded decision.
5. Keep follow-up issues open when readiness remains below the target.

## Troubleshooting

| Failure class | Common symptoms | Clear next actions |
| --- | --- | --- |
| Fire failure troubleshooting | Service loop stops, dispatch lease is stale, or project polling does not advance. | Capture logs, current issue status, lease owner, retry count, and recovery-gate output; block dispatch until restart behavior is known. |
| Worker failure troubleshooting | Worker route exits early, produces no result packet, or leaves cleanup residue. | Capture route metadata, command transcript, exit code, cleanup state, and missing result fields; request a new result packet or mark blocked. |
| GitHub failure troubleshooting | Issue, PR, or project read fails; checks are missing; merge state is ambiguous. | Capture `gh` output, repository, issue or PR URL, expected permission, and retry result; avoid assuming GitHub state from memory. |
| Credential failure troubleshooting | Credential grant is absent, expired, overbroad, or requested through prose. | Stop the operation, record the missing grant or overbroad scope, and ask the credential owner for a task-scoped approved grant. |
| Validation failure troubleshooting | A required script fails, JSON is malformed, or a fixture unexpectedly passes. | Capture the failing command output, fix the smallest contract or fixture issue, rerun the targeted validator, then rerun contract docs. |
| Project-field failure troubleshooting | Status, admission, authorized-by, permission level, or route field is missing or unmapped. | Block the ticket, name the missing field, map it to workflow semantics, and record the mapping before dispatch. |
| PR failure troubleshooting | Template sections are missing, checks fail, branch is stale, or merge authority is unclear. | Refresh branch state, fill the template, rerun checks, cite the linked issue, and wait for the required Human review when applicable. |
| Result-packet failure troubleshooting | Acceptance evidence, validation evidence, scope control, approval-gate status, cleanup, or residual risk is missing. | Request a corrected packet; do not close the issue until the packet reconciles with the PR and project state. |

## Remaining Productization Gaps

- The guided onboarding UI includes a multi-project setup workflow for
  Greenfield and Brownfield dry-run setup with field discovery, required fields,
  admission mapping, repository setup checks, rollback notes, and retained
  browser proof, but live GitHub Project setup mutation remains approval-gated.
- The browser action log records desktop Greenfield, desktop Brownfield, mobile
  Greenfield, and mobile Brownfield setup states with retained screenshots for
  review.
- Role-specific screenshots and browser action logs are retained and validated
  as repository evidence, but CI does not yet regenerate a cross-browser product
  UI visual matrix on every relevant change.
- Multi-project setup still needs deeper product UI workflow integration across
  live issue, PR, and result-packet states.
- Troubleshooting remains partially document-led rather than fully embedded in
  the product UI.

<!-- onboarding-troubleshooting:begin -->
```json
{
  "permissionLevel": "docs-only and local validation",
  "approvalBoundary": "Credential, production, infrastructure, worker, remote host, Docker, Kubernetes, deployment, and GitHub Project control-plane mutation require explicit Human approval under docs/policies/authority-and-safety.md.",
  "roleJourneys": {
    "admin": [
      "admin journey reads README, ARCHITECTURE, WORKFLOW, Manager contract, and authority policy",
      "admin confirms GitHub Project, repository, issue template, branch protection, required checks, and service ownership",
      "admin maps Status, admission, authorized-by, permission level, and result-packet fields",
      "admin runs local validation before admitting real work",
      "admin records approval boundary, residual risk, and next action"
    ],
    "approver": [
      "approver journey starts from linked issue, pull request, or result packet",
      "approver checks scope, acceptance criteria, non-goals, permission level, validation plan, and result evidence",
      "approver checks credential, infrastructure, worker, remote host, Docker, Kubernetes, deployment, production, and GitHub Project control-plane gates",
      "approver approves only the named operation, target, actor, evidence surface, and cleanup or rollback expectation",
      "approver requests changes when approval evidence is missing, stale, or outside authority"
    ],
    "operator": [
      "operator journey watches GitHub Project state, issue labels, pull request checks, Fire logs, worker route summaries, and result packets",
      "operator dispatches only Ready or Dispatchable work that passes fail-closed preflight",
      "operator classifies Fire, worker, GitHub, credential, validation, project-field, PR, and result-packet failures",
      "operator blocks vague work instead of best-effort dispatch",
      "operator links validation output, approval-gate status, cleanup, residual risk, and next action"
    ],
    "auditor": [
      "auditor journey starts from compliance package, immutable audit export design, issue, PR, and worker result packet",
      "auditor confirms source ticket, acceptance criteria, validation evidence, approval-gate status, scope-control statement, and whether acceptance criteria were met",
      "auditor checks evidence links for secrets, tokens, cookies, auth file contents, and private machine state",
      "auditor verifies retention, redaction, integrity, ownership, residual risk, and next action",
      "auditor rejects closeout when issue, PR, result packet, and project state do not reconcile"
    ],
    "worker_author": [
      "worker-author journey reads worker ticket and worker result packet templates",
      "worker author writes goal, scope, acceptance criteria, validation, permission level, Human approval gates, git plan, and expected result packet",
      "worker author names route assumptions for local worktree, SSH, Docker, and Kubernetes",
      "worker author returns changed artifacts, commit rationale, acceptance evidence, validation evidence, blockers, residual risks, scope control, and recommended next action",
      "worker author keeps secret material out of ticket prose and result summaries"
    ]
  },
  "installWalkthrough": [
    "clone or open the repository and run git status --short --branch",
    "run git submodule status to confirm submodule pointer",
    "read README.md, ARCHITECTURE.md, WORKFLOW.md, and docs/contracts/manager-contract.md",
    "run bash scripts/validate-readiness-criteria.sh",
    "run bash scripts/validate-contract-docs.sh",
    "run bash scripts/validate-git-governance.sh",
    "confirm tracker.projects mapping before admitting real GitHub Project work",
    "confirm credential broker ownership without copying or printing credentials"
  ],
  "githubProjectSetupChecks": [
    "Status values map to the documented workflow state vocabulary",
    "admission fields capture permission level and authorized-by evidence",
    "approval-gate status is present before gated dispatch",
    "worker route and result-packet surface are mapped",
    "GitHub Project control-plane changes are separated from routine item updates",
    "field drift creates a blocked issue with a clear next action"
  ],
  "repositorySetupChecks": [
    "branches follow docs/policies/git-governance.md",
    "pull requests include decision rationale, validation, residual risk, and public metadata hygiene",
    "required checks include contract docs, git governance, readiness criteria, and package validation",
    "submodule changes are committed inside the submodule before root gitlink updates",
    "result packets cite changed artifacts, validation commands, approval-gate status, scope-control statement, and whether acceptance criteria were met"
  ],
  "approvalReviewActions": [
    "confirm linked issue, scope, validation, and admitted lifecycle state before dispatch",
    "capture Human approver, exact target, exact operation, credential or route request, expiration, cleanup, and rollback or recovery path for gated authority",
    "review diff, validation output, public metadata, linked issue, result-packet evidence, residual risk, and merge authority before PR approval",
    "comment with missing decision, owner, deadline, and next escalation path for stale Human Review",
    "move rejected work to Fix Requested or Blocked with the failing condition"
  ],
  "resultPacketCloseoutActions": [
    "confirm task identity, changed artifacts, commit rationale, acceptance-criteria evidence, validation evidence, blockers, residual risks, scope control, approval-gate status, and recommended next action",
    "reconcile issue state, pull request state, GitHub Project status, branch, commit, and evidence links",
    "record cleanup receipts for workers, sessions, ports, containers, temporary files, browser contexts, and other resources",
    "close the issue only when acceptance criteria are met or closeout records a blocked or superseded decision",
    "keep follow-up issues open when readiness remains below target"
  ],
  "troubleshooting": {
    "fire": {
      "symptoms": [
        "Fire service loop stops",
        "dispatch lease is stale",
        "project polling does not advance"
      ],
      "clearNextActions": [
        "capture logs, current issue status, lease owner, retry count, and recovery-gate output",
        "block dispatch until restart behavior is known"
      ]
    },
    "worker": {
      "symptoms": [
        "worker route exits early",
        "worker produces no result packet",
        "worker leaves cleanup residue"
      ],
      "clearNextActions": [
        "capture route metadata, command transcript, exit code, cleanup state, and missing result fields",
        "request a new result packet or mark blocked"
      ]
    },
    "github": {
      "symptoms": [
        "issue read fails",
        "pull request checks are missing",
        "merge state is ambiguous"
      ],
      "clearNextActions": [
        "capture gh output, repository, issue or PR URL, expected permission, and retry result",
        "avoid assuming GitHub state from memory"
      ]
    },
    "credential": {
      "symptoms": [
        "credential grant is absent",
        "credential grant is expired",
        "credential request is overbroad"
      ],
      "clearNextActions": [
        "stop the operation",
        "record the missing grant or overbroad scope",
        "ask the credential owner for a task-scoped approved grant"
      ]
    },
    "validation": {
      "symptoms": [
        "required script fails",
        "JSON is malformed",
        "fixture unexpectedly passes"
      ],
      "clearNextActions": [
        "capture failing command output",
        "fix the smallest contract or fixture issue",
        "rerun the targeted validator and contract docs"
      ]
    },
    "project_field": {
      "symptoms": [
        "Status is missing",
        "admission field is missing",
        "project field mapping is missing",
        "permission level or route field is unmapped"
      ],
      "clearNextActions": [
        "block the ticket",
        "name the missing field",
        "map it to workflow semantics before dispatch"
      ]
    },
    "pr": {
      "symptoms": [
        "template sections are missing",
        "checks fail",
        "branch is stale or merge authority is unclear"
      ],
      "clearNextActions": [
        "capture failing check output",
        "refresh branch state",
        "fill the template",
        "rerun checks and wait for required Human review when applicable"
      ]
    },
    "result_packet": {
      "symptoms": [
        "result packet is incomplete",
        "acceptance evidence is missing",
        "validation evidence is missing",
        "scope control, approval-gate status, cleanup, or residual risk is missing"
      ],
      "clearNextActions": [
        "request a corrected packet",
        "do not close the issue until the packet reconciles with PR and project state"
      ]
    }
  },
  "completedProductizationEvidence": [
    "guided onboarding UI includes issue #84 multi-project setup workflow proof",
    "Greenfield and Brownfield setup modes cover field discovery, required fields, admission mapping, repository setup checks, and rollback notes",
    "browser action log records desktop Greenfield, desktop Brownfield, mobile Greenfield, and mobile Brownfield setup states",
    "desktop and mobile screenshots are retained under the submodule design evidence path",
    "product UI proof remains local validation only and keeps live GitHub Project control-plane mutation approval-gated"
  ],
  "remainingProductizationGaps": [
    "guided onboarding UI has multi-project setup workflow proof, but live setup remains approval-gated and not a product UI mutation path",
    "screenshots and browser action logs are retained by repository validation, but CI does not regenerate cross-browser product UI evidence",
    "multi-project operator troubleshooting still needs deeper product UI workflow integration across issue, PR, and result-packet state",
    "troubleshooting is not fully embedded in product UI"
  ]
}
```
<!-- onboarding-troubleshooting:end -->
