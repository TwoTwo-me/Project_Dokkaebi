# Governance Settings Sandbox Gate 2026-06-14

This evidence package captures an approved local governance settings sandbox
export for issue #100. It exports branch protection or ruleset settings,
required checks, pull request review requirements, GitHub Project field/settings
configuration, and a closeout reconciliation against pull request #116 and issue
#82 without using live repository settings or live GitHub Project settings as
readiness evidence.

## Source Summary

The approved sandbox export contains:

- branch protection settings for `main`, including pull request review and
  required status-check expectations;
- a repository ruleset fixture requiring `contract-docs` and `git-governance`;
- pull request review requirements derived from the repository PR template and
  Git governance policy;
- GitHub Project field/settings configuration derived from `WORKFLOW.md` and
  governance policy;
- closeout reconciliation for merged pull request #116 and closed issue #82.

This package is deliberately a sandbox gate. It does not claim that live branch
protection, live repository rulesets, or live GitHub Project fields were changed
or exported. Those targets remain separate setup work requiring explicit Human
approval.

## Closeout Reconciliation Summary

Pull request #116 merged with successful `contract-docs` and `git-governance`
checks and closed issue #82. The sandbox governance settings export reconciles
that closeout by matching required checks, PR body requirements, linked issue
state, result-packet evidence, workpad substitute evidence, and the expected
GitHub Project `Status` closeout value.

Expected targeted validation output:

```text
PASS Dokkaebi governance settings sandbox gate validation passed
```

## Approval Boundary

This package uses docs-only local deterministic validation and a repository
controlled sandbox export. It does not authorize credential access, branch
protection mutation, repository settings mutation, live GitHub Project
control-plane mutation, worker operation, infrastructure change, deployment,
production operation, Docker operation, Kubernetes operation, or remote-host
operation without explicit Human approval under
[`authority-and-safety.md`](authority-and-safety.md).

## Validation

Run:

```bash
bash scripts/run-governance-settings-sandbox-gate.sh
bash scripts/validate-governance-settings-sandbox-gate.sh
```

The validator rejects missing approval records, missing sandbox settings export,
missing required checks, incomplete pull request review rules, incomplete GitHub
Project field/settings configuration, unsafe live-settings claims, mismatched
runner output, missing closeout reconciliation, missing cleanup, missing
residual risk, private local paths, secrets, and missing issue #100 linkage.

<!-- governance-settings-sandbox-gate:begin -->
```json
{
  "approvalGateStatus": "approved local sandbox settings export only; branch protection mutation, repository settings mutation, live GitHub Project control-plane mutation, credential access, infrastructure, worker operation, Docker, Kubernetes, deployment, and production remain not authorized",
  "approvalRecord": {
    "approvedSurfaces": [
      "branch protection sandbox fixture",
      "repository ruleset sandbox fixture",
      "required checks derived from repository workflow",
      "pull request review requirements derived from repository template and policy",
      "GitHub Project field/settings schema derived from workflow and policy",
      "closeout reconciliation for pull request #116 and issue #82"
    ],
    "approvedTarget": "repository-controlled governance settings sandbox export for Project Dokkaebi",
    "deniedTargets": [
      "live GitHub Project control-plane mutation",
      "branch protection mutation",
      "repository settings mutation",
      "credential access",
      "infrastructure change",
      "worker operation",
      "remote host operation",
      "Docker operation",
      "Kubernetes operation",
      "deployment",
      "production operation"
    ],
    "evidence": "Project Dokkaebi enterprise readiness loop is approved to use repository-local sandbox evidence for issue #100; live repository settings and GitHub Project settings are not used as readiness evidence here",
    "scope": "export branch protection or ruleset settings, required checks, PR review requirements, GitHub Project field settings, and closeout reconciliation without live settings mutation"
  },
  "cleanup": {
    "receipt": "runner emits deterministic JSON only; no live GitHub settings, credentials, infrastructure, workers, remote hosts, Docker daemon, Kubernetes cluster, deployments, production targets, servers, ports, browser contexts, or persistent temp files were created or changed; no resources remain",
    "status": "complete"
  },
  "closeoutReconciliation": {
    "checks": [
      {
        "completedAt": "2026-06-14T06:28:58Z",
        "conclusion": "SUCCESS",
        "name": "contract-docs"
      },
      {
        "completedAt": "2026-06-14T06:28:51Z",
        "conclusion": "SUCCESS",
        "name": "git-governance"
      }
    ],
    "decision": "approved sandbox governance settings export reconciles PR #116 and issue #82; live settings mutation was not attempted",
    "projectStatusEvidence": {
      "basis": "PR #116 merged, issue #82 closed, required checks succeeded, and local result evidence passed",
      "field": "Status",
      "reconciledValue": "Done",
      "status": "approved_sandbox_exported"
    },
    "resultPacketEvidence": {
      "fields": [
        "changed artifacts",
        "decision rationale",
        "validation",
        "risks",
        "approval gates",
        "public metadata hygiene",
        "git status",
        "cleanup receipt"
      ],
      "status": "present_in_pr_body_and_local_evidence"
    },
    "settingsAppliedForReconciliation": [
      "required status checks matched contract-docs and git-governance",
      "pull request body followed the governance template sections",
      "linked issue reached CLOSED after merge",
      "sandbox Project Status moved through Needs Review or Human Review to Merging and Done",
      "workpad substitute evidence is the PR body, merge record, validation output, and local evidence files"
    ],
    "subject": {
      "issue": {
        "closedAt": "2026-06-14T06:29:31Z",
        "number": 82,
        "state": "CLOSED",
        "title": "Connect approved on-call delivery sandbox gate"
      },
      "pullRequest": {
        "headRef": "docs/on-call-delivery-sandbox",
        "mergeCommit": "c67a42045eacde41e97dee1d58dea163e2492079",
        "mergedAt": "2026-06-14T06:29:30Z",
        "number": 116,
        "state": "MERGED",
        "title": "Add on-call delivery sandbox gate"
      }
    },
    "workpadEvidence": {
      "status": "approved_sandbox_substitute_exported",
      "surfaces": [
        "PR #116 body",
        "merge record",
        "issue #82 closeout",
        "local validation transcripts"
      ]
    }
  },
  "date": "2026-06-14",
  "evidenceId": "governance-settings-sandbox-gate-2026-06-14",
  "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/100",
  "manifestSha256": "d1a1cadc45ba4f9509d3d8c2decf18907ffbd0844ab2f4a5a2aad7af0d90c3de",
  "nextAction": "use this sandbox governance settings export gate as the repeatable readiness evidence until a separately approved live GitHub settings rollout replaces the sandbox export",
  "permissionLevel": "approved-local-sandbox-governance-settings-export",
  "readinessDecision": {
    "basis": "approved sandbox export includes branch protection or ruleset settings, required checks, PR review requirements, GitHub Project field/settings schema, closeout reconciliation for merged PR #116 and closed issue #82, approval-gate status, cleanup, residual risk, and validation output",
    "management_governance": 100
  },
  "residualRisk": [
    "live branch protection and repository ruleset setup remains separately approval-gated rollout work",
    "live GitHub Project field creation or mutation remains separately approval-gated rollout work",
    "formal GitHub review settings should be exported from the live repository after setup approval"
  ],
  "runner": {
    "command": "bash scripts/run-governance-settings-sandbox-gate.sh",
    "path": "scripts/run-governance-settings-sandbox-gate.sh",
    "result": "PASS Dokkaebi governance settings sandbox gate runner completed"
  },
  "sandboxTarget": {
    "authority": "docs-only and local deterministic validation; no live GitHub repository or Project settings mutation",
    "kind": "repository-local governance settings export",
    "sourceFiles": [
      "WORKFLOW.md",
      "docs/policies/git-governance.md",
      "docs/policies/project-governance-and-closeout-reconciliation.md",
      "docs/policies/governance-settings-sandbox-gate-2026-06-14.md",
      ".github/pull_request_template.md",
      ".github/workflows/dokkaebi-governance.yml",
      "scripts/validate-git-governance.sh"
    ],
    "target": "Project Dokkaebi management governance sandbox"
  },
  "settingsExport": {
    "branchProtection": {
      "branch": "main",
      "dismissStaleReviews": true,
      "liveMutationStatus": "not_attempted",
      "requireConversationResolution": true,
      "requireLastPushApproval": true,
      "requiredApprovingReviewCount": 1,
      "requiredStatusChecks": [
        "contract-docs",
        "git-governance"
      ],
      "requiresPullRequest": true,
      "restriction": "only maintainers or explicitly approved automation may merge after review and required checks",
      "status": "sandbox_exported"
    },
    "githubProjectSettings": {
      "controlPlaneMutationStatus": "not_attempted",
      "fieldSchema": [
        {
          "allowedMutators": [
            "Human",
            "Dokkaebi Manager",
            "Dokkaebi Fire after admission"
          ],
          "name": "Status",
          "options": [
            "Intake",
            "Clarifying",
            "Ready",
            "Dispatchable",
            "In Progress",
            "Needs Review",
            "Human Review",
            "Fix Requested",
            "Merging",
            "Done",
            "Reopened",
            "Blocked",
            "Failed",
            "Cancelled"
          ],
          "rollbackPath": "restore prior Status from exported field snapshot before retry or closeout",
          "type": "single_select"
        },
        {
          "allowedMutators": [
            "Human",
            "Dokkaebi Manager"
          ],
          "name": "Agent",
          "options": [
            "Human",
            "Dokkaebi Manager",
            "Dokkaebi Fire",
            "Dokkaebi Hammer"
          ],
          "rollbackPath": "clear Agent or restore prior value if admission fails",
          "type": "single_select"
        },
        {
          "allowedMutators": [
            "Human",
            "Dokkaebi Manager"
          ],
          "name": "Authorization",
          "options": [
            "Not Required",
            "Human Approved",
            "Blocked Until Approval"
          ],
          "rollbackPath": "return to Blocked Until Approval when approval evidence is missing",
          "type": "single_select"
        },
        {
          "allowedMutators": [
            "Human",
            "Dokkaebi Manager"
          ],
          "name": "Authorized By",
          "requiredWhen": "Authorization is Human Approved",
          "rollbackPath": "remove stale approver text when approval is revoked or superseded",
          "type": "text"
        },
        {
          "allowedMutators": [
            "Dokkaebi Manager",
            "Dokkaebi Fire"
          ],
          "name": "Admission",
          "options": [
            "Not Ready",
            "Dispatchable",
            "Blocked"
          ],
          "rollbackPath": "set to Blocked with mismatch reason when dispatch evidence fails",
          "type": "single_select"
        },
        {
          "allowedMutators": [
            "Dokkaebi Manager",
            "Dokkaebi Fire",
            "Dokkaebi Hammer"
          ],
          "name": "Workpad",
          "requiredWhen": "Status is In Progress, Needs Review, Human Review, Merging, or Done",
          "rollbackPath": "append repair comment rather than deleting durable evidence",
          "type": "text"
        }
      ],
      "lifecycleSourceOfTruth": "GitHub Project Status",
      "status": "sandbox_exported"
    },
    "pullRequestReviewRules": {
      "requiredSections": [
        "Goal",
        "Non-goals",
        "Changed artifacts",
        "Decision rationale",
        "Validation",
        "Risks",
        "Approval gates",
        "Public metadata hygiene",
        "Git status"
      ],
      "reviewRequirement": "one approving review or explicit Human merge approval is required before Merging or Done",
      "selfApprovalBoundary": "author may not use tool availability as approval evidence",
      "sourceFiles": [
        ".github/pull_request_template.md",
        "docs/policies/git-governance.md"
      ]
    },
    "repositoryRuleset": {
      "enforcement": "active in approved sandbox only",
      "liveMutationStatus": "not_attempted",
      "name": "Project Dokkaebi required PR governance",
      "rules": [
        "pull request required before merge",
        "one approving review required unless a later ADR grants a narrow exception",
        "contract-docs required status check",
        "git-governance required status check",
        "linear public metadata hygiene validation",
        "no branch protection or repository settings mutation without explicit Human approval"
      ],
      "status": "sandbox_exported",
      "target": "refs/heads/main"
    },
    "requiredChecks": {
      "enforcementBasis": "sandbox ruleset requires both checks before main merge",
      "expectedChecks": [
        "contract-docs",
        "git-governance"
      ],
      "observedOnPullRequest": [
        "PR #116 contract-docs: SUCCESS",
        "PR #116 git-governance: SUCCESS"
      ],
      "sourceFiles": [
        ".github/workflows/dokkaebi-governance.yml",
        "scripts/validate-contract-docs.sh",
        "scripts/validate-git-governance.sh"
      ]
    }
  },
  "validationOutput": [
    "bash scripts/run-governance-settings-sandbox-gate.sh: PASS",
    "bash scripts/validate-governance-settings-sandbox-gate.sh: PASS",
    "bash scripts/validate-governance-settings-export-reconciliation.sh: PASS",
    "bash scripts/validate-project-governance-reconciliation.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS",
    "bash scripts/validate-git-governance.sh: PASS"
  ],
  "version": 1
}
```
<!-- governance-settings-sandbox-gate:end -->
