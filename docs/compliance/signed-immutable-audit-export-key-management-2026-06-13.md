# Signed Immutable Audit Export Key Management Drill 2026-06-13

This artifact records the issue #72 docs-only local sandbox verification for
signed immutable audit export storage and signing-key management. It signs a
sanitized export manifest payload with an ephemeral sandbox key, retains only
the public key, public-key fingerprint, manifest hash, signature, and review
metadata, and verifies the signature without keeping private key material.

No credential, production, infrastructure, worker, remote host, Proxmox,
Docker, Kubernetes, SSH, deployment, object store, signing service, or GitHub
Project control-plane mutation occurred. This artifact does not authorize any
sensitive operation.

## Drill Summary

| Field | Value |
| --- | --- |
| Drill ID | issue-72-2026-06-13-signed-immutable-export-key-management |
| Package ID | IAE-20260613-issue-72-signed |
| Permission level | Docs-only local sandbox signed verification |
| Source design | [`immutable-audit-export.md`](immutable-audit-export.md) |
| Prior replay | [`immutable-audit-export-verification-2026-06-13.md`](immutable-audit-export-verification-2026-06-13.md) |
| Manifest hash | `e45fb1f9372dfb308c03b681cfd8c0091a1daf287a2289788c9bd1424066f784` |
| Public key fingerprint | `ce00a0d4e61109d2c7e20a96f58a116d7244fc6478491ae21cf8e830199c27ea` |
| Signature verification | `Verified OK` |
| Approval-gate status | Closed; no live, credentialed, production, infrastructure, deployment, worker, remote, object-store, signing-service, or control-plane mutation reached |

## Signed Manifest Storage

The signed manifest storage surface for this drill is the checked-in sanitized
artifact plus the related issue and pull request timelines. Immutable object
storage with retention lock is not enabled by this drill and remains future
work requiring explicit infrastructure approval.

The stored package contains:

- canonical JSON payload with sorted object keys and compact separators;
- SHA-256 hash of the canonical payload;
- RSA-2048/SHA-256 signature over the canonical payload;
- retained public key and SHA-256 public-key fingerprint;
- redaction review, owner review, retention enforcement decision, cleanup,
  residual risk, and next action.

## Signing-Key Ownership

The signing-key ownership record ties the sandbox key ID, public-key
fingerprint, owner, custodian, rotation cadence, revocation triggers, and
verification cadence into one auditable package.

The sandbox signing key is owned by the compliance owner and custodied by the
Manager reviewer for the duration of this drill. The private key was generated
for this single local sandbox verification, used once, and removed before
evidence was recorded. No private key material is retained.

Production signing keys must be owned by the compliance owner, rotated at
least every 90 days or immediately after custodian change, suspected exposure,
failed verification, expired rotation window, or owner-review rejection, and
revoked by marking the key in the export registry before future export
approval.

## Verification Cadence

Every export must be verified before closeout. Until automation exists,
operators must also sample signed export verification weekly and review key
ownership quarterly. A failed verification blocks closeout and opens a
replacement-key or evidence-repair issue before any new export approval.

Expected targeted validation output:

```text
PASS Dokkaebi signed immutable audit export validation passed
```

## Retention Enforcement

Retention enforcement for this artifact is manual repository retention plus
deterministic validation. The artifact is retained for one year minimum, has a
review due on 2026-09-13, and records no legal hold for this sandbox
verification. Automated retention service integration remains a follow-up
because this drill did not change infrastructure or object storage.

## Redaction Review And Cleanup

The retained artifact excludes secrets, auth files, cookies, tokens, SSH keys,
private machine state, private home-directory paths, raw credential broker
output, secret-bearing evidence, and private signing key material. Cleanup is
complete: the ephemeral sandbox private key and canonical payload temp files
were removed; retained evidence contains only public key material, fingerprint,
manifest hash, signature, and sanitized review metadata.

## Residual Risk And Next Action

Residual risk remains for immutable object storage with retention lock,
production signing-key registry and automated revocation, automated export
generation, and production-service scheduling of the verification cadence.

Next action: connect signed export verification to approved immutable object
storage and automated retention service under issue #88.

<!-- signed-immutable-audit-export:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only-local-sandbox-signed-verification",
  "signedExportManifest": {
    "canonicalization": "Canonical JSON with sorted object keys, UTF-8 encoding, and compact separators over signed payload evidence",
    "signatureAlgorithm": "RSA-2048 with SHA-256 digest",
    "publicKeyPem": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuwvsR/t2Hfv0Lc7yrsbH\ngwoopBovmkTrN64jHVn4a2jon1X7GdeqwswNYf+DnkRFzkIY5UKvEGak0oFc+Npv\nitmzEZngcC4Wvw2oiWCLlEsRH3gLjw5wXJe2z8s6mL+8qTU/CfA9KleuOPeewsgV\nppQGqr4lGmOL/EUDplS6u0+B9ClO/VrbKyTufRlO8nZU+idJMDI1JBGUf7Y5AgfX\nGSN7u8FQ1jIjg7F/ph8qpXbsceoDTOsKr8zTuNJ1qMBozl7+2sroGwhclfsqiFEf\nVNoCSldU9KgEGMSn9ZpasSHMXdYPBVvuEEMesJc6Kq9GptHqtv+Cve3YI+GTOD0c\nzwIDAQAB\n-----END PUBLIC KEY-----",
    "signedPayload": {
      "approvalGateStatus": "Closed: no live credential, production, infrastructure, worker, remote host, Proxmox, Docker, Kubernetes, SSH, deployment, object store, signing service, or GitHub Project control-plane mutation reached",
      "cleanup": {
        "receipt": "ephemeral sandbox private key and canonical payload temp files removed; retained artifact includes only public key, fingerprint, manifest hash, signature, and sanitized review metadata",
        "status": "complete"
      },
      "date": "2026-06-13",
      "drillId": "issue-72-2026-06-13-signed-immutable-export-key-management",
      "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/88",
      "nextAction": "Connect signed export verification to approved immutable object storage and automated retention service after explicit infrastructure approval",
      "ownerReview": {
        "complianceReviewer": "Compliance reviewer",
        "controlOwner": "Compliance owner",
        "integrityVerifier": "Evidence reviewer",
        "packageOwner": "Manager reviewer",
        "redactionReviewer": "Compliance reviewer",
        "retentionOwner": "Manager reviewer",
        "reviewStatus": "accepted for docs-only sandbox evidence"
      },
      "packageId": "IAE-20260613-issue-72-signed",
      "permissionLevel": "docs-only-local-sandbox-signed-verification",
      "redactionReview": {
        "excludedClasses": [
          "secrets",
          "auth files",
          "cookies",
          "tokens",
          "SSH keys",
          "private machine state",
          "private home-directory paths",
          "raw credential broker output",
          "secret-bearing evidence",
          "private signing key material"
        ],
        "privateSigningKeyRetained": false,
        "rawSecretsIncluded": false,
        "reviewer": "Compliance reviewer",
        "status": "passed"
      },
      "residualRisk": [
        "Immutable object storage with retention lock is not operational",
        "Production signing-key registry and automated revocation are not implemented",
        "Automated export generation is not implemented",
        "Verification cadence is documented but not scheduled by a production service"
      ],
      "retentionEnforcement": {
        "deletionOrExtensionDecision": "retain until the 2026-09-13 review, then extend or delete according to legal hold and compliance owner decision",
        "duration": "one year minimum for repository evidence",
        "enforcementStatus": "manual repository retention gate plus deterministic validator; automated retention service remains future work",
        "legalHoldState": "none asserted for this sandbox verification",
        "nextReviewDate": "2026-09-13",
        "owner": "Manager reviewer",
        "storageSurface": "checked-in sanitized artifact plus issue and pull request timelines"
      },
      "schemaVersion": "immutable-audit-export-signed/v1",
      "signedManifestStorage": {
        "objectLockStatus": "not enabled in this repository; immutable object storage remains a future approved infrastructure task",
        "signedManifestLocation": "docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md",
        "storageOwner": "Compliance owner",
        "storageSurface": "checked-in sanitized signed manifest artifact plus issue and pull request timelines",
        "writeBoundary": "repository documentation only; no object store, production system, credential store, or control plane changed"
      },
      "signingKeyManagement": {
        "algorithm": "RSA-2048 with SHA-256 digest",
        "keyId": "sandbox-rsa-20260613-ce00a0d4e611",
        "privateKeyHandling": "ephemeral sandbox key generated for this drill, used once, and removed before evidence was recorded; no private key material is retained",
        "publicKeyFingerprintSha256": "ce00a0d4e61109d2c7e20a96f58a116d7244fc6478491ae21cf8e830199c27ea",
        "revocationAction": "mark key revoked in the export registry, reject future packages signed by the key, and open a replacement-key issue before new export approval",
        "revocationTriggers": [
          "custodian change",
          "suspected key exposure",
          "failed signature verification",
          "expired rotation window",
          "owner review rejection"
        ],
        "rotationCadence": "rotate production signing keys at least every 90 days or immediately after custodian change, suspected exposure, or failed verification",
        "signingKeyCustodian": "Manager reviewer",
        "signingKeyOwner": "Compliance owner",
        "verificationCadence": "verify every export before closeout, sample weekly until automation exists, and review key ownership quarterly"
      },
      "sourceDesign": "docs/compliance/immutable-audit-export.md",
      "sourceLinks": {
        "commits": [
          "6ab67675b2322365eb8042a7f5e017b432ae6e67",
          "c5afcfa10daa68f97c4de0d3c36468fd336d8d1d",
          "1f664b4a4b0d2ec24e192d11a9c377e7e4d78a14",
          "95a0643a5a9f3785a648c12ac9abb9d9ad6adb92"
        ],
        "issues": [
          "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/72",
          "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/55",
          "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/32",
          "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/52"
        ],
        "pullRequests": [
          "https://github.com/TwoTwo-me/Project_Dokkaebi/pull/56",
          "https://github.com/TwoTwo-me/Project_Dokkaebi/pull/54"
        ],
        "resultPackets": [
          "not applicable; docs-only local sandbox signing verification did not dispatch worker execution"
        ],
        "reviewPackages": [
          "docs/compliance/control-map-and-evidence-package.md",
          "docs/compliance/audit-review-2026-06-13.md",
          "docs/compliance/immutable-audit-export-verification-2026-06-13.md"
        ],
        "validation": [
          "bash scripts/validate-signed-immutable-audit-export.sh",
          "bash scripts/validate-immutable-audit-export.sh",
          "bash scripts/validate-immutable-audit-export-verification.sh",
          "bash scripts/validate-readiness-criteria.sh",
          "bash scripts/validate-contract-docs.sh"
        ]
      },
      "verificationOutput": {
        "command": "bash scripts/validate-signed-immutable-audit-export.sh",
        "opensslVersion": "OpenSSL 3 compatible verifier",
        "result": "PASS signature verified with retained public key; recorded manifest hash equals recomputed SHA-256 of signed payload",
        "verifiedBy": "Evidence reviewer"
      },
      "verificationReplay": "docs/compliance/immutable-audit-export-verification-2026-06-13.md"
    },
    "recordedSha256": "e45fb1f9372dfb308c03b681cfd8c0091a1daf287a2289788c9bd1424066f784",
    "signatureHex": "473ba75c828f56bf14a4b471c1a4ac3ea75fe4455bf66d734d3acdd22db9061017e8f725cc732f9ab9c627dc3f092411fb9003784e1abe62e5d983d9f9da1a0a455cfd074966e9bb17df7533ebd3484f807c626e28350f7c7b1ed236df9b067322f61fd050b39c06f0b5775988ffcd2d752b57e9f0593bf83e9367292704e1ddecad31225ff47d1482bda28c2d76c59dcc4026ba18c28cd6e565d9fa62240417ad9feaa1153e9a8a39daede19e1e6ae41fdbf9dcbb38b1339507e5fcc642e76b2cac619dbebee283f5dc956dc5f948f9780f5f4501fdd9fbc4a152ba9a6a717706c05788b4df342a5001f959eb32f0c5d8bdc13ef47c67f0215b01510072cab8",
    "signatureVerificationOutput": "Verified OK"
  }
}
```
<!-- signed-immutable-audit-export:end -->
