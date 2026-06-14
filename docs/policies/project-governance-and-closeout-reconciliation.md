# Project Governance And Closeout Reconciliation

This docs-only baseline defines the GitHub Project governance matrix and
closeout reconciliation plan for issue #19. It names the required project owner,
approver, Fire operator, Hammer operator, security reviewer, and auditor roles;
defines stale Human Review handling; and defines mismatch handling across issue,
pull request, result packet, workpad comment, and GitHub Project state surfaces.

This baseline does not authorize credential, infrastructure, worker, deployment,
production, branch protection, repository settings, GitHub Project control-plane,
or live GitHub settings mutation.

## Governance Matrix

| Role | Owns | Must not self-approve |
| --- | --- | --- |
| Project owner | Project field schema, lifecycle semantics, and final governance exceptions | Own runtime or credential changes without another approver |
| Approver | Scope, non-goals, permission level, and gated action decisions | Dispatch or execute the work they approved |
| Fire operator | Admission, dispatch readiness, lease/retry evidence, and workpad updates | Broaden tenant, credential, route, or project authority |
| Hammer operator | Worker route execution, validation evidence, cleanup, and result packet | Approve their own scope, route, or credential expansion |
| Security reviewer | Credential, RBAC, prompt-injection, and authority-boundary review | Replace the approver for product scope decisions |
| Auditor | Evidence package review, retention, redaction, and reconciliation checks | Mutate project state or result evidence |

Expected targeted validation output:

```text
PASS Dokkaebi project governance reconciliation validation passed
```

## Stale Human Review And Mismatch Handling

- Stale Human Review: record missing decision, owner, deadline, and escalation
  target; leave the ticket blocked until the decision is explicit.
- Issue mismatch: block closeout when issue status, acceptance criteria, or
  approval state cannot be reconciled with the result packet.
- Pull request mismatch: block closeout when PR review, checks, merge state, or
  linked issue state contradict the result packet.
- Result-packet mismatch: reject closeout when acceptance evidence, validation
  evidence, scope-control statement, approval-gate status, cleanup, residual
  risk, or next action is absent.
- Workpad mismatch: require a repair comment when workpad progress or result
  metadata contradicts GitHub Project Status.
- GitHub Project mismatch: treat GitHub Project Status as lifecycle source of
  truth and require GraphQL confirmation before dispatch, retry, or closeout.

## Residual Risk And Next Action

This baseline documents the operating policy and deterministic validation.
Reproducible branch protection, repository ruleset, required-check, PR review,
GitHub Project settings export, and automated closeout reconciliation output
remain pending. Next action: complete issue #97.

<!-- project-governance-reconciliation:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only project governance and closeout reconciliation",
  "approvalBoundary": "This baseline does not authorize credential, infrastructure, worker, deployment, production, branch protection, repository settings, GitHub Project control-plane, or live GitHub settings mutation without explicit Human approval",
  "roles": [
    {
      "id": "project_owner",
      "name": "project owner",
      "owns": [
        "GitHub Project field schema",
        "lifecycle semantics",
        "governance exception review"
      ],
      "mustNotSelfApprove": "runtime, credential, infrastructure, or project control-plane changes without another approver"
    },
    {
      "id": "approver",
      "name": "approver",
      "owns": [
        "scope decision",
        "non-goals",
        "permission level",
        "gated action approval"
      ],
      "mustNotSelfApprove": "dispatch, execute, or close out the work they approved"
    },
    {
      "id": "fire_operator",
      "name": "Fire operator",
      "owns": [
        "admission checks",
        "dispatch readiness",
        "lease and retry evidence",
        "workpad update"
      ],
      "mustNotSelfApprove": "tenant, credential, route, or project authority expansion"
    },
    {
      "id": "hammer_operator",
      "name": "Hammer operator",
      "owns": [
        "worker route execution",
        "validation evidence",
        "cleanup receipt",
        "result packet"
      ],
      "mustNotSelfApprove": "scope, route, or credential expansion"
    },
    {
      "id": "security_reviewer",
      "name": "security reviewer",
      "owns": [
        "credential review",
        "RBAC review",
        "prompt-injection review",
        "authority-boundary review"
      ],
      "mustNotSelfApprove": "product scope approval or merge approval"
    },
    {
      "id": "auditor",
      "name": "auditor",
      "owns": [
        "evidence package review",
        "retention decision",
        "redaction decision",
        "reconciliation check"
      ],
      "mustNotSelfApprove": "project state or result evidence mutation"
    }
  ],
  "reconciliationSurfaces": [
    {
      "id": "issue_status",
      "source": "GitHub issue state, labels, linked PR, acceptance criteria, and approval evidence",
      "mismatchHandling": "block closeout until issue status, acceptance criteria, and approval state match the result packet",
      "detectionEvidence": [
        "issue timeline",
        "linked pull request",
        "approval-gate status"
      ],
      "failClosedBehavior": "blocked ticket with mismatch reason"
    },
    {
      "id": "pr_review_check_merge_state",
      "source": "pull request review decision, required checks, merge state, and linked issue reference",
      "mismatchHandling": "block closeout when PR review, checks, merge state, or linked issue state contradict the result packet",
      "detectionEvidence": [
        "PR review state",
        "required checks",
        "merge commit"
      ],
      "failClosedBehavior": "Human Review until PR state reconciles"
    },
    {
      "id": "result_packet",
      "source": "worker result packet acceptance evidence, validation evidence, scope-control statement, approval-gate status, cleanup, residual risk, and next action",
      "mismatchHandling": "reject result packet when required closeout fields are absent or contradict issue or PR state",
      "detectionEvidence": [
        "result packet",
        "validation output",
        "cleanup receipt"
      ],
      "failClosedBehavior": "request fixed result packet"
    },
    {
      "id": "workpad_comment",
      "source": "workpad progress comment, route metadata, result metadata, and Manager review note",
      "mismatchHandling": "require repair comment when workpad progress or result metadata contradicts GitHub Project Status",
      "detectionEvidence": [
        "workpad comment",
        "route metadata",
        "Manager review note"
      ],
      "failClosedBehavior": "blocked review until workpad evidence is repaired"
    },
    {
      "id": "github_project_status",
      "source": "GitHub Project Status, admission fields, agent fields, and GraphQL confirmation",
      "mismatchHandling": "treat GitHub Project Status as lifecycle source of truth and confirm state before dispatch, retry, or closeout",
      "detectionEvidence": [
        "GraphQL state confirmation",
        "project item status",
        "admission field snapshot"
      ],
      "failClosedBehavior": "deny dispatch or closeout until project state reconciles"
    }
  ],
  "staleHumanReview": {
    "definition": "Human Review is stale when a required decision has no owner, deadline, or next escalation path",
    "requiredRecord": [
      "missing decision",
      "owner",
      "deadline",
      "escalation target",
      "blocked action"
    ],
    "escalationPath": [
      "assigned approver",
      "project owner",
      "security reviewer for authority or credential risk",
      "auditor for evidence integrity risk"
    ],
    "failClosedBehavior": "leave ticket blocked until a durable decision is recorded"
  },
  "validationOutput": [
    "PASS Dokkaebi project governance reconciliation validation passed",
    "PASS Dokkaebi enterprise readiness criteria are present and structurally valid",
    "PASS Dokkaebi contract docs are present, linked, and structurally aligned"
  ],
  "residualRisk": [
    "branch protection and repository ruleset export is not captured",
    "GitHub Project field/settings export is not captured",
    "automated closeout reconciliation report output is not captured"
  ],
  "nextAction": "Complete issue #97 for reproducible governance settings export and automated closeout reconciliation evidence.",
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/97"
}
```
<!-- project-governance-reconciliation:end -->
