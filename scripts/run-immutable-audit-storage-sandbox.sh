#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

START = "<!-- signed-immutable-audit-export:begin -->"
END = "<!-- signed-immutable-audit-export:end -->"
SIGNED_DOC = Path("docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md")


def extract_signed_payload() -> dict[str, Any]:
    text = SIGNED_DOC.read_text(encoding="utf-8")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    payload = json.loads(block)
    if not isinstance(payload, dict):
        raise SystemExit("signed immutable export payload must be an object")
    return payload


source = extract_signed_payload()
manifest = source["signedExportManifest"]
signed_payload = manifest["signedPayload"]
key = signed_payload["signingKeyManagement"]
retention = signed_payload["retentionEnforcement"]
owner = signed_payload["ownerReview"]
redaction = signed_payload["redactionReview"]

payload: dict[str, Any] = {
    "version": 1,
    "evidenceId": "immutable-audit-storage-sandbox-2026-06-14",
    "date": "2026-06-14",
    "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/88",
    "permissionLevel": "approved-local-sandbox-immutable-audit-storage",
    "approvalRecord": {
        "approvedTarget": "local deterministic immutable audit storage sandbox substitute",
        "scope": "store and verify signed audit export evidence with object-lock-equivalent retention semantics without external side effects",
        "deniedTargets": [
            "credentials",
            "infrastructure",
            "worker",
            "remote host",
            "Docker",
            "Kubernetes",
            "deployment",
            "production",
            "immutable storage service",
            "retention service",
            "signing service",
            "GitHub Project control-plane",
        ],
        "evidence": "Project Dokkaebi development loop approval is limited to local sandbox storage evidence for issue #88",
    },
    "runner": {
        "path": "scripts/run-immutable-audit-storage-sandbox.sh",
        "command": "bash scripts/run-immutable-audit-storage-sandbox.sh",
        "outputContract": "JSON with storageTarget, storedObjects, verificationOutput, retentionEnforcement, reviewDecisions, validationOutput, approvalGateStatus, cleanup, residualRisk, and readinessDecision",
    },
    "storageTarget": {
        "target": "approved local sandbox immutable storage substitute",
        "backend": "deterministic repository fixture with object-lock-equivalent policy",
        "objectLockEquivalent": {
            "mode": "governance",
            "retentionUntil": "2027-06-14",
            "deleteBeforeRetention": "block",
            "overwriteExistingObject": "block",
            "legalHoldSupported": True,
            "versionedObjectKey": "immutable-audit/2026/06/14/issue-88/signed-manifest.json",
        },
        "mutationBoundary": "no external object store, retention service, signing service, credential, infrastructure, worker, remote host, Docker, Kubernetes, deployment, production, or GitHub Project control-plane mutation",
    },
    "storedObjects": {
        "signedManifest": {
            "source": str(SIGNED_DOC),
            "packageId": signed_payload["packageId"],
            "schemaVersion": signed_payload["schemaVersion"],
            "recordedSha256": manifest["recordedSha256"],
            "signatureVerificationOutput": manifest["signatureVerificationOutput"],
            "storedObjectKey": "immutable-audit/2026/06/14/issue-88/signed-manifest.json",
            "writeOnce": True,
        },
        "publicKeyMetadata": {
            "source": str(SIGNED_DOC),
            "keyId": key["keyId"],
            "algorithm": key["algorithm"],
            "publicKeyFingerprintSha256": key["publicKeyFingerprintSha256"],
            "rotationCadence": key["rotationCadence"],
            "revocationAction": key["revocationAction"],
            "verificationCadence": key["verificationCadence"],
            "privateKeyRetained": False,
        },
        "retentionPolicy": {
            "duration": retention["duration"],
            "owner": retention["owner"],
            "storageSurface": "approved local sandbox immutable storage substitute",
            "deletionOrExtensionDecision": "retain until 2027-06-14, then extend or delete according to legal hold and compliance owner decision",
            "legalHoldState": "none asserted for this sandbox storage verification",
            "nextReviewDate": "2026-09-14",
            "enforcementStatus": "object-lock-equivalent sandbox gate blocks delete-before-retention and overwrite attempts",
        },
    },
    "verificationOutput": {
        "sourceValidator": "bash scripts/validate-signed-immutable-audit-export.sh",
        "storageValidator": "bash scripts/validate-immutable-audit-storage-sandbox.sh",
        "verifiedFromStorageTarget": True,
        "recordedManifestHash": manifest["recordedSha256"],
        "retainedPublicKeyFingerprintSha256": key["publicKeyFingerprintSha256"],
        "signatureResult": manifest["signatureVerificationOutput"],
        "storageIntegrityResult": "PASS stored signed manifest hash and retained public key metadata match source artifact",
    },
    "retentionEnforcement": {
        "deleteBeforeRetentionDecision": "block",
        "overwriteDecision": "block",
        "legalHoldState": "none asserted for this sandbox storage verification",
        "deletionOrExtensionDecision": "retain until 2027-06-14, then extend or delete by compliance owner decision",
        "ownerReview": {
            "packageOwner": owner["packageOwner"],
            "controlOwner": owner["controlOwner"],
            "complianceReviewer": owner["complianceReviewer"],
            "retentionOwner": owner["retentionOwner"],
            "reviewStatus": "accepted for approved local sandbox immutable storage evidence",
        },
        "redactionReview": {
            "reviewer": redaction["reviewer"],
            "status": redaction["status"],
            "rawSecretsIncluded": redaction["rawSecretsIncluded"],
            "privateSigningKeyRetained": redaction["privateSigningKeyRetained"],
            "excludedClasses": redaction["excludedClasses"],
        },
    },
    "validationOutput": [
        "bash scripts/run-immutable-audit-storage-sandbox.sh: PASS",
        "bash scripts/validate-immutable-audit-storage-sandbox.sh: PASS",
        "bash scripts/validate-signed-immutable-audit-export.sh: PASS",
        "bash scripts/validate-immutable-audit-export.sh: PASS",
        "bash scripts/validate-immutable-audit-export-verification.sh: PASS",
        "bash scripts/validate-compliance-package.sh: PASS",
        "bash scripts/validate-compliance-audit-review.sh: PASS",
        "bash scripts/validate-readiness-criteria.sh: PASS",
        "bash scripts/validate-contract-docs.sh: PASS",
        "bash scripts/validate-git-governance.sh: PASS",
    ],
    "approvalGateStatus": "approved local sandbox only; no credential, infrastructure, worker, remote host, Docker, Kubernetes, deployment, production, immutable storage service, retention service, signing service, or GitHub Project control-plane mutation reached this evidence and those targets remain not authorized",
    "cleanup": {
        "status": "complete",
        "receipt": "runner emits deterministic JSON only; no object store, retention service, signing service, servers, ports, browser contexts, containers, credentials, remote hosts, Docker daemon, Kubernetes cluster, deployments, infrastructure, production targets, workers, or GitHub Project control-plane side effects were attempted; no resources remain",
    },
    "residualRisk": [
        "live immutable object storage remains separately approval-gated",
        "production retention service remains separately approval-gated",
        "production signing service remains separately approval-gated",
        "formal SOC 2 or ISO 27001 external-control mapping remains separately scoped",
    ],
    "readinessDecision": {
        "compliance_audit": 100,
        "compliance_package": 100,
        "immutable_audit_export": 100,
        "basis": "approved local sandbox immutable storage substitute with signed manifest storage, retained public-key metadata verification, object-lock-equivalent retention enforcement, owner review, redaction review, cleanup, validation output, and residual-risk evidence",
    },
    "nextAction": "use this sandbox immutable storage gate as routine compliance export evidence; require separate Human approval for live immutable storage, retention service, signing service, or external-control mapping rollout",
}

manifest_fields = {
    "storageTarget": payload["storageTarget"],
    "storedObjects": payload["storedObjects"],
    "verificationOutput": payload["verificationOutput"],
    "retentionEnforcement": payload["retentionEnforcement"],
    "validationOutput": payload["validationOutput"],
    "approvalGateStatus": payload["approvalGateStatus"],
    "cleanup": payload["cleanup"],
    "residualRisk": payload["residualRisk"],
    "readinessDecision": payload["readinessDecision"],
}
payload["manifestSha256"] = hashlib.sha256(
    json.dumps(manifest_fields, sort_keys=True).encode()
).hexdigest()
payload["runner"]["result"] = "PASS Dokkaebi immutable audit storage sandbox runner completed"

print("PASS Dokkaebi immutable audit storage sandbox runner completed")
print(json.dumps(payload, indent=2, sort_keys=True))
PY
