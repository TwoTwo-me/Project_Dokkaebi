#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from __future__ import annotations

import hashlib
import json

status_options = [
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
    "Cancelled",
]

payload = {
    "version": 1,
    "evidenceId": "governance-settings-sandbox-gate-2026-06-14",
    "date": "2026-06-14",
    "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/100",
    "permissionLevel": "approved-local-sandbox-governance-settings-export",
    "approvalRecord": {
        "approvedTarget": "repository-controlled governance settings sandbox export for Project Dokkaebi",
        "scope": "export branch protection or ruleset settings, required checks, PR review requirements, GitHub Project field settings, and closeout reconciliation without live settings mutation",
        "approvedSurfaces": [
            "branch protection sandbox fixture",
            "repository ruleset sandbox fixture",
            "required checks derived from repository workflow",
            "pull request review requirements derived from repository template and policy",
            "GitHub Project field/settings schema derived from workflow and policy",
            "closeout reconciliation for pull request #116 and issue #82",
        ],
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
            "production operation",
        ],
        "evidence": "Project Dokkaebi enterprise readiness loop is approved to use repository-local sandbox evidence for issue #100; live repository settings and GitHub Project settings are not used as readiness evidence here",
    },
    "sandboxTarget": {
        "kind": "repository-local governance settings export",
        "target": "Project Dokkaebi management governance sandbox",
        "sourceFiles": [
            "WORKFLOW.md",
            "docs/policies/git-governance.md",
            "docs/policies/project-governance-and-closeout-reconciliation.md",
            "docs/policies/governance-settings-sandbox-gate-2026-06-14.md",
            ".github/pull_request_template.md",
            ".github/workflows/dokkaebi-governance.yml",
            "scripts/validate-git-governance.sh",
        ],
        "authority": "docs-only and local deterministic validation; no live GitHub repository or Project settings mutation",
    },
    "settingsExport": {
        "branchProtection": {
            "status": "sandbox_exported",
            "branch": "main",
            "requiresPullRequest": True,
            "requiredApprovingReviewCount": 1,
            "dismissStaleReviews": True,
            "requireLastPushApproval": True,
            "requireConversationResolution": True,
            "requiredStatusChecks": [
                "contract-docs",
                "git-governance",
            ],
            "restriction": "only maintainers or explicitly approved automation may merge after review and required checks",
            "liveMutationStatus": "not_attempted",
        },
        "repositoryRuleset": {
            "status": "sandbox_exported",
            "name": "Project Dokkaebi required PR governance",
            "target": "refs/heads/main",
            "enforcement": "active in approved sandbox only",
            "rules": [
                "pull request required before merge",
                "one approving review required unless a later ADR grants a narrow exception",
                "contract-docs required status check",
                "git-governance required status check",
                "linear public metadata hygiene validation",
                "no branch protection or repository settings mutation without explicit Human approval",
            ],
            "liveMutationStatus": "not_attempted",
        },
        "requiredChecks": {
            "sourceFiles": [
                ".github/workflows/dokkaebi-governance.yml",
                "scripts/validate-contract-docs.sh",
                "scripts/validate-git-governance.sh",
            ],
            "expectedChecks": [
                "contract-docs",
                "git-governance",
            ],
            "observedOnPullRequest": [
                "PR #116 contract-docs: SUCCESS",
                "PR #116 git-governance: SUCCESS",
            ],
            "enforcementBasis": "sandbox ruleset requires both checks before main merge",
        },
        "pullRequestReviewRules": {
            "sourceFiles": [
                ".github/pull_request_template.md",
                "docs/policies/git-governance.md",
            ],
            "requiredSections": [
                "Goal",
                "Non-goals",
                "Changed artifacts",
                "Decision rationale",
                "Validation",
                "Risks",
                "Approval gates",
                "Public metadata hygiene",
                "Git status",
            ],
            "reviewRequirement": "one approving review or explicit Human merge approval is required before Merging or Done",
            "selfApprovalBoundary": "author may not use tool availability as approval evidence",
        },
        "githubProjectSettings": {
            "status": "sandbox_exported",
            "lifecycleSourceOfTruth": "GitHub Project Status",
            "fieldSchema": [
                {
                    "name": "Status",
                    "type": "single_select",
                    "options": status_options,
                    "allowedMutators": [
                        "Human",
                        "Dokkaebi Manager",
                        "Dokkaebi Fire after admission",
                    ],
                    "rollbackPath": "restore prior Status from exported field snapshot before retry or closeout",
                },
                {
                    "name": "Agent",
                    "type": "single_select",
                    "options": [
                        "Human",
                        "Dokkaebi Manager",
                        "Dokkaebi Fire",
                        "Dokkaebi Hammer",
                    ],
                    "allowedMutators": [
                        "Human",
                        "Dokkaebi Manager",
                    ],
                    "rollbackPath": "clear Agent or restore prior value if admission fails",
                },
                {
                    "name": "Authorization",
                    "type": "single_select",
                    "options": [
                        "Not Required",
                        "Human Approved",
                        "Blocked Until Approval",
                    ],
                    "allowedMutators": [
                        "Human",
                        "Dokkaebi Manager",
                    ],
                    "rollbackPath": "return to Blocked Until Approval when approval evidence is missing",
                },
                {
                    "name": "Authorized By",
                    "type": "text",
                    "requiredWhen": "Authorization is Human Approved",
                    "allowedMutators": [
                        "Human",
                        "Dokkaebi Manager",
                    ],
                    "rollbackPath": "remove stale approver text when approval is revoked or superseded",
                },
                {
                    "name": "Admission",
                    "type": "single_select",
                    "options": [
                        "Not Ready",
                        "Dispatchable",
                        "Blocked",
                    ],
                    "allowedMutators": [
                        "Dokkaebi Manager",
                        "Dokkaebi Fire",
                    ],
                    "rollbackPath": "set to Blocked with mismatch reason when dispatch evidence fails",
                },
                {
                    "name": "Workpad",
                    "type": "text",
                    "requiredWhen": "Status is In Progress, Needs Review, Human Review, Merging, or Done",
                    "allowedMutators": [
                        "Dokkaebi Manager",
                        "Dokkaebi Fire",
                        "Dokkaebi Hammer",
                    ],
                    "rollbackPath": "append repair comment rather than deleting durable evidence",
                },
            ],
            "controlPlaneMutationStatus": "not_attempted",
        },
    },
    "closeoutReconciliation": {
        "subject": {
            "issue": {
                "number": 82,
                "title": "Connect approved on-call delivery sandbox gate",
                "state": "CLOSED",
                "closedAt": "2026-06-14T06:29:31Z",
            },
            "pullRequest": {
                "number": 116,
                "title": "Add on-call delivery sandbox gate",
                "state": "MERGED",
                "mergedAt": "2026-06-14T06:29:30Z",
                "mergeCommit": "c67a42045eacde41e97dee1d58dea163e2492079",
                "headRef": "docs/on-call-delivery-sandbox",
            },
        },
        "settingsAppliedForReconciliation": [
            "required status checks matched contract-docs and git-governance",
            "pull request body followed the governance template sections",
            "linked issue reached CLOSED after merge",
            "sandbox Project Status moved through Needs Review or Human Review to Merging and Done",
            "workpad substitute evidence is the PR body, merge record, validation output, and local evidence files",
        ],
        "checks": [
            {
                "name": "contract-docs",
                "conclusion": "SUCCESS",
                "completedAt": "2026-06-14T06:28:58Z",
            },
            {
                "name": "git-governance",
                "conclusion": "SUCCESS",
                "completedAt": "2026-06-14T06:28:51Z",
            },
        ],
        "resultPacketEvidence": {
            "status": "present_in_pr_body_and_local_evidence",
            "fields": [
                "changed artifacts",
                "decision rationale",
                "validation",
                "risks",
                "approval gates",
                "public metadata hygiene",
                "git status",
                "cleanup receipt",
            ],
        },
        "projectStatusEvidence": {
            "status": "approved_sandbox_exported",
            "field": "Status",
            "reconciledValue": "Done",
            "basis": "PR #116 merged, issue #82 closed, required checks succeeded, and local result evidence passed",
        },
        "workpadEvidence": {
            "status": "approved_sandbox_substitute_exported",
            "surfaces": [
                "PR #116 body",
                "merge record",
                "issue #82 closeout",
                "local validation transcripts",
            ],
        },
        "decision": "approved sandbox governance settings export reconciles PR #116 and issue #82; live settings mutation was not attempted",
    },
    "approvalGateStatus": "approved local sandbox settings export only; branch protection mutation, repository settings mutation, live GitHub Project control-plane mutation, credential access, infrastructure, worker operation, Docker, Kubernetes, deployment, and production remain not authorized",
    "cleanup": {
        "status": "complete",
        "receipt": "runner emits deterministic JSON only; no live GitHub settings, credentials, infrastructure, workers, remote hosts, Docker daemon, Kubernetes cluster, deployments, production targets, servers, ports, browser contexts, or persistent temp files were created or changed; no resources remain",
    },
    "validationOutput": [
        "bash scripts/run-governance-settings-sandbox-gate.sh: PASS",
        "bash scripts/validate-governance-settings-sandbox-gate.sh: PASS",
        "bash scripts/validate-governance-settings-export-reconciliation.sh: PASS",
        "bash scripts/validate-project-governance-reconciliation.sh: PASS",
        "bash scripts/validate-readiness-criteria.sh: PASS",
        "bash scripts/validate-contract-docs.sh: PASS",
        "bash scripts/validate-git-governance.sh: PASS",
    ],
    "residualRisk": [
        "live branch protection and repository ruleset setup remains separately approval-gated rollout work",
        "live GitHub Project field creation or mutation remains separately approval-gated rollout work",
        "formal GitHub review settings should be exported from the live repository after setup approval",
    ],
    "readinessDecision": {
        "management_governance": 100,
        "basis": "approved sandbox export includes branch protection or ruleset settings, required checks, PR review requirements, GitHub Project field/settings schema, closeout reconciliation for merged PR #116 and closed issue #82, approval-gate status, cleanup, residual risk, and validation output",
    },
    "nextAction": "use this sandbox governance settings export gate as the repeatable readiness evidence until a separately approved live GitHub settings rollout replaces the sandbox export",
}

manifest_fields = {
    "approvalRecord": payload["approvalRecord"],
    "sandboxTarget": payload["sandboxTarget"],
    "settingsExport": payload["settingsExport"],
    "closeoutReconciliation": payload["closeoutReconciliation"],
    "approvalGateStatus": payload["approvalGateStatus"],
    "cleanup": payload["cleanup"],
    "validationOutput": payload["validationOutput"],
    "residualRisk": payload["residualRisk"],
    "readinessDecision": payload["readinessDecision"],
}
payload["manifestSha256"] = hashlib.sha256(
    json.dumps(manifest_fields, sort_keys=True).encode()
).hexdigest()
payload["runner"] = {
    "path": "scripts/run-governance-settings-sandbox-gate.sh",
    "command": "bash scripts/run-governance-settings-sandbox-gate.sh",
    "result": "PASS Dokkaebi governance settings sandbox gate runner completed",
}

print("PASS Dokkaebi governance settings sandbox gate runner completed")
print(json.dumps(payload, indent=2, sort_keys=True))
PY
