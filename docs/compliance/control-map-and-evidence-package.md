# Compliance Control Map And Evidence Package

This document defines the docs-only compliance control map and enterprise
evidence package skeleton for Project Dokkaebi. It does not claim SOC 2, ISO
27001, or other certification readiness. It does not authorize credential,
worker, infrastructure, Proxmox, Docker, Kubernetes, SSH, deployment,
production, or GitHub Project control-plane mutation.

The goal is narrower: a reviewer should be able to reconstruct how a work item
was approved, changed, validated, reviewed, merged, closed, retained, and
redacted without relying on private memory.

## Control Map

| Control | Objective | Evidence sources | Owner |
| --- | --- | --- | --- |
| Approval control | Prove that gated actions have explicit Human approval before execution. | Issue approval record, PR approval, result packet approval-gate status, authority policy link. | Manager reviewer. |
| Access control | Prove that credentials and worker authority are least-privilege, task-scoped, and time-bound. | Credential broker metadata, access review notes, worker route permission level, redacted grant summary. | Human owner. |
| Change management control | Prove that every change has branch, commit rationale, PR review, validation, and merge evidence. | Git branch, commit body, PR template, checks, merge commit, linked issue. | Release operator. |
| Logging control | Prove that dispatch, validation, worker result, and closeout events are retained in audit-visible surfaces. | GitHub issue timeline, PR timeline, workflow logs, result packet, Fire logs when available. | Fire operator. |
| Incident control | Prove that incidents have severity, commander, mitigation, communication, postmortem, and follow-up evidence. | Incident issue, SRE baseline, postmortem, validation output, follow-up issue. | Incident commander. |
| Credential control | Prove that secret lifecycle, redaction, revocation, and access review expectations are visible without exposing secret material. | Authority policy, broker metadata, redacted revocation record, access review result. | Human owner. |

These controls are mapped to internal audit needs first. SOC 2 and ISO 27001
mapping can be added later, but the package must not imply external audit
attestation until a Human owner approves that scope.

## Export Design

The export design is evidence-oriented and intentionally conservative.

| Field | Requirement |
| --- | --- |
| Retention | Each evidence package names retention duration, retention owner, and deletion or extension decision. |
| Redaction | Evidence must exclude secrets, auth files, cookies, tokens, private machine state, and secret-bearing evidence. |
| Integrity | Each package records source links, commit SHAs, check run URLs, and a manifest hash once immutable export exists. |
| Ownership | Each package names the Manager reviewer, control owner, and evidence package owner. |
| Storage | GitHub issue/PR timelines and repository fixtures are current storage; immutable audit export remains future work. |

Until immutable audit export exists, the package records an explicit
`immutableExportGap` rather than pretending to be tamper-proof.

## Package Contents

An enterprise evidence package must include:

- package ID and date;
- scope and linked readiness criteria;
- approval-gate status;
- control coverage table;
- access and credential boundary summary;
- change management evidence;
- validation command output;
- logging and closeout evidence;
- incident or no-incident statement;
- retention, redaction, integrity, and ownership decisions;
- residual risk and next action.

The package contents may be stored in a GitHub issue, pull request, result
packet, or checked-in fixture. It must never store raw secrets, auth files,
cookies, tokens, or private machine state.

## Sample Evidence Chain

The sample evidence chain below is the minimum end-to-end shape:

1. Request: linked GitHub issue names scope, non-goals, permission level, and
   expected result evidence.
2. Approval: issue or PR records approval-gate status and any Human approval.
3. Change: branch and commit body explain context, decision, why, validation,
   and residual risk.
4. Validation: check runs and targeted commands are linked or pasted in
   summarized form.
5. Review: PR review or Manager review records acceptance criteria, exceptions,
   and residual risk.
6. Merge: merge commit and closed issues are linked.
7. Closeout: result packet or issue closeout records control coverage,
   retention, redaction, integrity, ownership, and next action.

## Approval Boundary

The approval boundary is intentionally fail-closed.

This document authorizes docs-only planning and local validation. It does not
authorize credential, worker, infrastructure, Proxmox, Docker, Kubernetes, SSH,
deployment, production, or GitHub Project control-plane mutation. Any such
operation requires explicit Human approval under
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Validation

Run:

```bash
bash scripts/validate-compliance-package.sh
```

The validator checks the human-readable control map and the structured control
block below. It rejects empty baseline content, malformed control data, missing
approval control, access control, change management control, logging control,
incident control, credential control, retention, redaction, integrity,
ownership, export design, package contents, sample evidence chain, approval
boundary, or secret-bearing evidence wording.

<!-- compliance-package:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only",
  "approvalGateStatus": "no credential, worker, infrastructure, Proxmox, Docker, Kubernetes, SSH, deployment, production, or GitHub Project control-plane mutation reached",
  "controls": {
    "approval": {
      "controlObjective": "Gated actions have explicit Human approval before execution",
      "evidenceSources": ["issue approval record", "PR approval", "result packet approval-gate status", "authority policy link"],
      "owner": "Manager reviewer",
      "reviewCadence": "Every gated work item and quarterly policy review"
    },
    "access": {
      "controlObjective": "Credentials and worker authority are least-privilege, task-scoped, and time-bound",
      "evidenceSources": ["credential broker metadata", "access review notes", "worker route permission level", "redacted grant summary"],
      "owner": "Human owner",
      "reviewCadence": "Every credentialed task and quarterly access review"
    },
    "changeManagement": {
      "controlObjective": "Every change has branch, commit rationale, PR review, validation, and merge evidence",
      "evidenceSources": ["git branch", "commit body", "PR template", "checks", "merge commit", "linked issue"],
      "owner": "Release operator",
      "reviewCadence": "Every pull request"
    },
    "logging": {
      "controlObjective": "Dispatch, validation, worker result, and closeout events are retained in audit-visible surfaces",
      "evidenceSources": ["GitHub issue timeline", "PR timeline", "workflow logs", "result packet", "Fire logs when available"],
      "owner": "Fire operator",
      "reviewCadence": "Every closeout and incident review"
    },
    "incident": {
      "controlObjective": "Incidents have severity, commander, mitigation, communication, postmortem, and follow-up evidence",
      "evidenceSources": ["incident issue", "SRE baseline", "postmortem", "validation output", "follow-up issue"],
      "owner": "Incident commander",
      "reviewCadence": "Every incident and quarterly tabletop"
    },
    "credential": {
      "controlObjective": "Secret lifecycle, redaction, revocation, and access review expectations are visible without exposing secret material",
      "evidenceSources": ["authority policy", "broker metadata", "redacted revocation record", "access review result"],
      "owner": "Human owner",
      "reviewCadence": "Every grant and quarterly access review"
    }
  },
  "exportDesign": {
    "retention": "Evidence package names retention duration, retention owner, and deletion or extension decision",
    "redaction": "Evidence excludes secrets, auth files, cookies, tokens, private machine state, and secret-bearing evidence",
    "integrity": "Package records source links, commit SHAs, check run URLs, and future manifest hash",
    "ownership": "Package names Manager reviewer, control owner, and evidence package owner",
    "storageSurface": "GitHub issue/PR timelines and repository fixtures are current storage",
    "immutableExportGap": "Immutable audit export remains future work and must stay visible in readiness criteria"
  },
  "packageContents": [
    "package ID and date",
    "scope and linked readiness criteria",
    "approval-gate status",
    "control coverage table",
    "access and credential boundary summary",
    "change management evidence",
    "validation command output",
    "logging and closeout evidence",
    "incident or no-incident statement",
    "retention, redaction, integrity, and ownership decisions",
    "residual risk and next action"
  ],
  "sampleEvidenceChain": [
    "request issue names scope, non-goals, permission level, and expected result evidence",
    "approval surface records approval-gate status and any Human approval",
    "change branch and commit body explain context, decision, why, validation, and residual risk",
    "validation surface links check runs and targeted command output",
    "review surface records acceptance criteria, exceptions, and residual risk",
    "merge surface links merge commit and closed issues",
    "closeout surface records control coverage, retention, redaction, integrity, ownership, and next action"
  ],
  "approvalBoundary": "This package authorizes docs-only planning and local validation; credential, worker, infrastructure, Proxmox, Docker, Kubernetes, SSH, deployment, production, and GitHub Project control-plane operations require explicit Human approval",
  "requiredEvidence": [
    "changed artifacts and rationale",
    "acceptance-criteria evidence",
    "validation command output",
    "approval-gate status",
    "residual risk and next action"
  ]
}
```
<!-- compliance-package:end -->

## Remaining Gaps

This package skeleton does not finish compliance readiness. Remaining work
includes a real audit review walkthrough, immutable audit export, measured
retention enforcement, signed export manifests, access-review drills, and
external-control mapping if a Human owner chooses a formal framework.
