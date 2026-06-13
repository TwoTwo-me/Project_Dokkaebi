# Immutable Audit Export Design

This document defines the docs-only immutable audit export design for Project
Dokkaebi compliance evidence. It does not produce a live export, sign a
manifest, mutate infrastructure, or claim tamper-evident compliance readiness
by itself.

The design goal is to make a future export package independently verifiable:
an auditor should be able to inspect source links, redaction decisions,
retention metadata, ownership, and manifest hash evidence without receiving
raw secrets or private machine state.

## Export Package Contract

An immutable audit export package must include:

- package ID, schema version, and generated-at timestamp;
- permission level and approval boundary;
- source links for issues, pull requests, commits, checks, result packets, and
  review packages;
- redaction manifest that names excluded secret classes and review status;
- retention metadata with duration, owner, deletion or extension decision, and
  legal-hold state;
- ownership metadata for package owner, control owner, and reviewer;
- manifest hash algorithm, canonicalization rule, and manifest hash;
- verification steps that can recompute and compare the manifest hash;
- failure handling for missing sources, failed hash verification, retention
  conflict, redaction conflict, and incomplete approval evidence;
- remaining operational gaps until signed export verification exists.

## Manifest Hash

The manifest hash is a SHA-256 digest over canonical JSON. Canonicalization
sorts object keys, emits UTF-8, excludes volatile timestamps from the signed
payload, and includes source link IDs, commit SHAs, check run IDs, redaction
entries, retention metadata, ownership, approval-gate status, and residual
risk.

The current repository stores only the design contract. A later verification
drill must produce or replay a concrete export manifest and record the computed
hash.

The repository also carries a docs-only signed sandbox verification in
[`signed-immutable-audit-export-key-management-2026-06-13.md`](signed-immutable-audit-export-key-management-2026-06-13.md).
That artifact proves signature verification and signing-key management shape
without enabling immutable object storage, a production signing service, or
automated retention enforcement.

## Source Links

Required source link classes are:

| Source class | Requirement |
| --- | --- |
| Issue | Link issue request, approval evidence, and closeout evidence. |
| Pull request | Link PR body, review or approval evidence, checks, and merge commit. |
| Commit | Include implementation commit and merge commit SHAs. |
| Validation | Link or summarize command output and CI checks. |
| Review package | Link compliance package and audit review package. |
| Result packet | Link worker result packet if a worker executed the change. |

## Redaction Manifest

The redaction manifest must list every excluded data class. At minimum it must
exclude secrets, auth files, cookies, tokens, SSH keys, private machine state,
private home-directory paths, raw credential broker output, and secret-bearing
evidence. Each redaction entry records reviewer, reason, scope, and whether the
redaction was verified.

## Retention Metadata

Retention metadata must include retention duration, retention owner, storage
surface, deletion or extension decision, legal-hold state, and next review date.
Until retention enforcement exists, the export must mark enforcement as a
remaining operational gap.

## Ownership

Every export package names:

- package owner;
- control owner;
- compliance reviewer;
- retention owner;
- redaction reviewer;
- integrity verifier.

## Verification Steps

1. Load the export manifest.
2. Validate schema version and permission level.
3. Resolve source links or record unavailable sources as verification failures.
4. Recompute canonical JSON and SHA-256 manifest hash.
5. Compare the recomputed hash with the recorded manifest hash.
6. Confirm redaction manifest coverage.
7. Confirm retention metadata and owner decisions.
8. Confirm approval boundary did not authorize sensitive operations.
9. Record pass, fail, cleanup, residual risk, and next action.

## Failure Handling

Verification fails closed when any required source link is missing, hash
verification fails, redaction coverage is incomplete, retention metadata is
missing, ownership is missing, approval evidence is missing, or the manifest
claims credential, production, infrastructure, worker, remote host, Proxmox,
Docker, Kubernetes, deployment, or GitHub Project control-plane authority that
was not explicitly approved.

## Approval Boundary

This design authorizes docs-only planning and local validation. It does not
authorize credential, production, infrastructure, worker, remote host, Proxmox,
Docker, Kubernetes, SSH, deployment, or GitHub Project control-plane mutation.
No production mutation and no credential mutation are authorized by this
design; this is a no production and no credential mutation boundary.
Any such operation requires explicit Human approval under
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Validation

Run:

```bash
bash scripts/validate-immutable-audit-export.sh
```

The validator rejects empty export design content, malformed export data,
missing manifest hash, missing source links, missing redaction manifest,
missing retention metadata, missing ownership, missing verification steps,
missing failure handling, missing approval boundary, missing remaining
operational gaps, missing permission level, or unauthorized credential,
production, infrastructure, or control-plane mutation wording.

<!-- immutable-audit-export:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only design and local validation",
  "approvalBoundary": "This design does not authorize credential, production, infrastructure, worker, remote host, Proxmox, Docker, Kubernetes, SSH, deployment, or GitHub Project control-plane mutation without explicit Human approval",
  "exportPackage": {
    "packageIdFormat": "IAE-YYYYMMDD-<change-id>",
    "schemaVersion": "immutable-audit-export/v1",
    "generatedAt": "recorded outside the canonical signed payload",
    "storageAssumptions": "Repository fixtures, GitHub issue/PR timelines, and a signed sandbox verification artifact are current storage; signed immutable object storage remains future work"
  },
  "manifestHash": {
    "algorithm": "SHA-256",
    "canonicalization": "Canonical JSON with sorted object keys, UTF-8 encoding, and volatile timestamps excluded from the signed payload",
    "requiredInputs": [
      "source link IDs",
      "commit SHAs",
      "check run IDs",
      "redaction entries",
      "retention metadata",
      "ownership metadata",
      "approval-gate status",
      "residual risk"
    ],
    "verificationResult": "A later drill must produce or replay a manifest and compare the recomputed hash; issue #72 adds signed sandbox verification without object-storage retention lock"
  },
  "sourceLinks": {
    "issues": "request, approval, and closeout issue links",
    "pullRequests": "PR body, review evidence, checks, and merge commit",
    "commits": "implementation and merge commit SHAs",
    "validation": "command output and CI checks",
    "reviewPackages": "compliance package and audit review package",
    "resultPackets": "worker result packet when a worker executed the change"
  },
  "redactionManifest": {
    "excludedClasses": [
      "secrets",
      "auth files",
      "cookies",
      "tokens",
      "SSH keys",
      "private machine state",
      "private home-directory paths",
      "raw credential broker output",
      "secret-bearing evidence"
    ],
    "entryFields": ["reviewer", "reason", "scope", "verified"]
  },
  "retentionMetadata": {
    "duration": "required",
    "owner": "required",
    "storageSurface": "required",
    "deletionOrExtensionDecision": "required",
    "legalHoldState": "required",
    "nextReviewDate": "required"
  },
  "ownership": {
    "packageOwner": "required",
    "controlOwner": "required",
    "complianceReviewer": "required",
    "retentionOwner": "required",
    "redactionReviewer": "required",
    "integrityVerifier": "required"
  },
  "verificationSteps": [
    "load export manifest",
    "validate schema version and permission level",
    "resolve source links",
    "recompute canonical JSON and SHA-256 manifest hash",
    "compare recomputed hash with recorded manifest hash",
    "confirm redaction manifest coverage",
    "confirm retention metadata and owner decisions",
    "confirm approval boundary did not authorize sensitive operations",
    "record pass, fail, cleanup, residual risk, and next action"
  ],
  "failureHandling": [
    "missing source link fails closed",
    "hash mismatch fails closed",
    "incomplete redaction manifest fails closed",
    "missing retention metadata fails closed",
    "missing ownership fails closed",
    "missing approval evidence fails closed",
    "unauthorized sensitive authority wording fails closed"
  ],
  "remainingOperationalGaps": [
    "immutable object storage is not implemented",
    "retention enforcement is not operational",
    "production signing-key registry is not implemented",
    "automated export generation is not implemented"
  ],
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/88"
}
```
<!-- immutable-audit-export:end -->
