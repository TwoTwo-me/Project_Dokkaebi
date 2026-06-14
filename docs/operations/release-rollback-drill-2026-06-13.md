# Local Release And Rollback Drill

This document records a docs-only local release and rollback drill for
[`release-rollback-capacity-drills.md`](release-rollback-capacity-drills.md).
It does not authorize credentials, production writes, infrastructure mutation,
worker dispatch, remote host operations, Docker, Kubernetes, deployment, or
GitHub Project control-plane mutation.

The drill captures release candidate, staged rollout step, rollback trigger,
rollback decision, recovery path, operator, communication surface, command
output, validation output, staged rollout decision, approval-gate status,
cleanup, residual risk, and next action.

Approved local sandbox gate evidence that supersedes the sandbox and measured
soak residual risk from this historical drill is captured in
[`release-rollback-sandbox-gate-2026-06-14.md`](release-rollback-sandbox-gate-2026-06-14.md).

Required exact terms: local release and rollback drill; release candidate;
staged rollout step; rollback trigger; rollback decision; recovery path;
operator; communication surface; command output; validation output; staged
rollout decision; approval-gate status; cleanup; residual risk; next action;
does not authorize.

## Drill Summary

The release candidate is a local fixture representing the current repository
contract package. The staged rollout starts with local validation, intentionally
trips a rollback trigger with a malformed fixture, records the rollback decision,
then proves recovery by returning to the complete fixture and passing validation.
No live system is changed.

## Validation

Run:

```bash
bash scripts/validate-release-rollback-drill.sh
```

The validator accepts this complete local drill package and rejects empty
content, malformed drill data, missing release candidate, missing staged rollout
step, missing rollback trigger, missing rollback decision, missing recovery path,
missing operator, missing communication surface, missing command output, missing
approval-gate status, missing cleanup, missing residual risk, missing next
action, unsafe mutation wording, private local paths, secret-bearing wording, and
unauthorized credential, production, infrastructure, worker, remote host, Docker,
Kubernetes, deployment, or GitHub Project control-plane mutation wording.

<!-- release-rollback-drill:begin -->
```json
{
  "version": 1,
  "drillId": "release-rollback-local-2026-06-13",
  "date": "2026-06-13",
  "permissionLevel": "docs-only-local-drill",
  "sourceRunbook": "docs/operations/release-rollback-capacity-drills.md",
  "releaseCandidate": {
    "id": "contract-docs-release-candidate-2026-06-13",
    "commit": "c6cef3accd6806b7b1348f55b282b9b917257ffc",
    "artifact": "repository contract, operations, and readiness documentation",
    "scope": "local validation fixture only"
  },
  "stagedRollout": [
    {
      "step": "prepare",
      "operator": "release_operator",
      "decision": "allow local candidate preparation",
      "evidence": "issue #48 scope, validation plan, permission level, and approval-gate status are present"
    },
    {
      "step": "package",
      "operator": "release_operator",
      "decision": "allow local documentation package",
      "evidence": "release candidate commit and changed artifacts are named"
    },
    {
      "step": "validate",
      "operator": "release_operator",
      "decision": "allow validation after complete fixture passes",
      "evidence": "targeted, capacity, readiness, contract, plugin, and governance validation output all record PASS"
    },
    {
      "step": "stage rollout",
      "operator": "release_operator",
      "decision": "deny release advance when rollback trigger fixture is malformed",
      "evidence": "malformed local fixture rejected before any live mutation"
    },
    {
      "step": "closeout",
      "operator": "manager_reviewer",
      "decision": "complete local drill only",
      "evidence": "rollback decision, recovery path, cleanup, residual risk, and next action captured"
    }
  ],
  "stagedRolloutDecision": {
    "decision": "complete docs-only local staged rollout and rollback fixture recovery",
    "operator": "release_operator",
    "evidence": "validate and stage rollout steps record PASS output, rollback decision, and recovery path",
    "communicationSurface": "GitHub issue #48 and pull request timeline"
  },
  "rollbackTrigger": {
    "trigger": "malformed drill fixture removes rollbackDecision and commandOutput",
    "detectedBy": "scripts/validate-release-rollback-drill.sh",
    "decision": "rollback",
    "reason": "release candidate cannot proceed without rollback decision and command output evidence"
  },
  "rollbackDecision": {
    "decision": "rollback local fixture to last complete evidence package",
    "operator": "release_operator",
    "communicationSurface": "GitHub issue #48 and pull request timeline",
    "closeoutEvidence": "complete fixture passes targeted validation after rollback"
  },
  "recoveryPath": [
    "Restore complete local fixture payload.",
    "Re-run targeted drill validation.",
    "Re-run release rollback capacity baseline validation.",
    "Re-run readiness, contract, plugin, and git-governance validation.",
    "Record residual risk and next action."
  ],
  "commandOutput": [
    "bash scripts/validate-release-rollback-drill.sh: PASS",
    "malformed rollback fixture: rejected before live mutation",
    "recovered complete fixture: PASS"
  ],
  "validationOutput": [
    "bash scripts/validate-release-rollback-drill.sh: PASS",
    "bash scripts/validate-release-rollback-capacity-drills.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS",
    "bash scripts/validate-dokkaebi-plugin.sh: PASS",
    "bash scripts/validate-git-governance.sh: PASS"
  ],
  "communicationSurface": "GitHub issue #48 and pull request timeline record release decision, rollback decision, validation output, and closeout.",
  "operator": "release_operator",
  "reviewer": "manager_reviewer",
  "approvalGateStatus": "No live approval-gated mutation reached; credential, production, infrastructure, worker, remote host, Docker, Kubernetes, deployment, and GitHub Project control-plane mutation remain not authorized.",
  "cleanup": {
    "status": "complete",
    "receipt": "No release artifact was deployed, no rollback command touched a live system, and worker, remote host, container, cluster, production, credential, and GitHub Project configuration surfaces remained untouched."
  },
  "residualRisk": [
    "Runtime release gates are automated for approved local sandbox evidence in release-rollback-sandbox-gate-2026-06-14.md.",
    "Approved sandbox rollback evidence is captured in release-rollback-sandbox-gate-2026-06-14.md.",
    "Measured soak evidence is captured from the approved local sandbox gate package.",
    "Live production rollback remains separately approval-gated."
  ],
  "nextAction": "Use release-rollback-sandbox-gate-2026-06-14.md as routine local sandbox evidence; live production rollback remains separately approval-gated.",
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/76"
}
```
<!-- release-rollback-drill:end -->
