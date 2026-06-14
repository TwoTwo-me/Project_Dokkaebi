#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf 'FAIL missing file: %s\n' "$path" >&2
    return 1
  fi
}

require_text() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq -- "$needle" "$path"; then
    printf 'FAIL missing text in %s: %s\n' "$path" "$needle" >&2
    return 1
  fi
}

require_no_text() {
  local path="$1"
  local needle="$2"
  if grep -Fq -- "$needle" "$path"; then
    printf 'FAIL forbidden text in %s: %s\n' "$path" "$needle" >&2
    return 1
  fi
}

require_file ARCHITECTURE.md
require_file WORKFLOW.md
require_file docs/contracts/manager-contract.md
require_file docs/contracts/hammer-worker-contract.md
require_file docs/policies/authority-and-safety.md
require_file docs/policies/git-governance.md
require_file docs/adapters/hermes.md
require_file docs/templates/worker-ticket.md
require_file docs/templates/worker-result-packet.md
require_file README.md
require_file .github/pull_request_template.md
require_file .github/workflows/dokkaebi-governance.yml
require_file scripts/validate-git-governance.sh
require_file scripts/validate-dokkaebi-plugin.sh
require_file scripts/validate-readiness-criteria.sh
require_file scripts/validate-carbon-ui-baseline.sh
require_file scripts/validate-credential-lifecycle.sh
require_file scripts/validate-credential-revocation-drill.sh
require_file scripts/validate-security-threat-model.sh
require_file scripts/validate-multi-tenant-rbac.sh
require_file scripts/validate-multi-tenant-rbac-drill.sh
require_file scripts/validate-dispatch-lease-recovery.sh
require_file scripts/validate-orchestration-recovery-gate.sh
require_file scripts/validate-sre-operating-baseline.sh
require_file scripts/validate-incident-response-runbook.sh
require_file scripts/validate-central-metrics-backend.sh
require_file scripts/validate-central-metrics-replay.sh
require_file scripts/validate-on-call-paging-alerting.sh
require_file scripts/validate-on-call-alert-routing-drill.sh
require_file scripts/validate-onboarding-troubleshooting.sh
require_file scripts/validate-release-rollback-capacity-drills.sh
require_file scripts/validate-release-rollback-drill.sh
require_file scripts/validate-topology-backup-restore-dr.sh
require_file scripts/validate-backup-restore-drill.sh
require_file scripts/validate-sandbox-restore-drill.sh
require_file scripts/validate-compliance-package.sh
require_file scripts/validate-compliance-audit-review.sh
require_file scripts/validate-immutable-audit-export.sh
require_file scripts/validate-immutable-audit-export-verification.sh
require_file scripts/validate-signed-immutable-audit-export.sh
require_file scripts/validate-runtime-quality-gates.sh
require_file docs/enterprise-readiness/criteria.json
require_file docs/enterprise-readiness/development-loop.md
require_file docs/enterprise-readiness/runtime-quality-gate-matrix.md
require_file docs/reports/company-readiness-assessment.md
require_file docs/design/carbon-ui-baseline.md
require_file docs/product/onboarding-troubleshooting.md
require_file docs/operations/worker-cli-auth.md
require_file docs/policies/credential-lifecycle-and-revocation.md
require_file docs/policies/credential-revocation-access-review-drill-2026-06-13.md
require_file docs/policies/multi-tenant-rbac.md
require_file docs/policies/security-threat-model-and-prompt-injection-controls.md
require_file docs/policies/multi-tenant-rbac-drill-2026-06-13.md
require_file docs/operations/dispatch-lease-recovery.md
require_file docs/operations/orchestration-recovery-gate.md
require_file docs/operations/sre-operating-baseline.md
require_file docs/operations/incident-response-runbook-2026-06-13.md
require_file docs/operations/central-metrics-backend.md
require_file docs/operations/central-metrics-replay-2026-06-13.md
require_file docs/operations/on-call-paging-alerting.md
require_file docs/operations/on-call-alert-routing-drill-2026-06-13.md
require_file docs/operations/release-rollback-capacity-drills.md
require_file docs/operations/release-rollback-drill-2026-06-13.md
require_file docs/operations/topology-backup-restore-dr.md
require_file docs/operations/backup-restore-drill-2026-06-13.md
require_file docs/operations/sandbox-restore-drill-2026-06-13.md
require_file docs/compliance/control-map-and-evidence-package.md
require_file docs/compliance/audit-review-2026-06-13.md
require_file docs/compliance/immutable-audit-export.md
require_file docs/compliance/immutable-audit-export-verification-2026-06-13.md
require_file docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md
require_file docs/examples/result-packets/accepted.md
require_file docs/examples/result-packets/rejected-missing-acceptance-evidence.md
require_file docs/examples/result-packets/rejected-missing-validation-evidence.md
require_file docs/examples/result-packets/rejected-missing-scope-control.md
require_file docs/examples/result-packets/rejected-missing-approval-status.md
require_file docs/examples/replays/accepted-manager-fire-hammer.md
require_file docs/examples/replays/rejected-missing-dispatch-readiness.md
require_file docs/examples/replays/rejected-missing-approval-evidence.md
require_file docs/examples/replays/rejected-missing-worker-route-result-metadata.md
require_file docs/examples/replays/rejected-missing-closeout-review-evidence.md

require_text ARCHITECTURE.md '# Project Dokkaebi Architecture'
require_text ARCHITECTURE.md 'Dokkaebi Manager'
require_text ARCHITECTURE.md 'Credential broker'
require_text ARCHITECTURE.md 'Trust boundaries'
require_text ARCHITECTURE.md 'Critical risks'

require_text WORKFLOW.md '# Project Dokkaebi Workflow'
require_text WORKFLOW.md '## Phase 1: Manager intake'
require_text WORKFLOW.md '## Phase 3: Approval and readiness gate'
require_text WORKFLOW.md '## Status model'
require_text WORKFLOW.md '| Reopened |'

require_text docs/contracts/manager-contract.md '# Dokkaebi Manager Contract'
require_text docs/contracts/manager-contract.md '## Fail-closed preflight'
require_text docs/contracts/manager-contract.md '## Credential broker boundary'
require_text docs/contracts/manager-contract.md '## Symphony compatibility'
require_text docs/contracts/manager-contract.md '## Adapter conformance'
require_text docs/contracts/manager-contract.md '### Adapter conformance proof'
require_text docs/contracts/manager-contract.md '../examples/result-packets/accepted.md'
require_text docs/contracts/manager-contract.md '../examples/result-packets/rejected-missing-acceptance-evidence.md'
require_text docs/contracts/manager-contract.md '../examples/result-packets/rejected-missing-validation-evidence.md'
require_text docs/contracts/manager-contract.md '../examples/result-packets/rejected-missing-scope-control.md'
require_text docs/contracts/manager-contract.md '../examples/result-packets/rejected-missing-approval-status.md'
require_text docs/contracts/manager-contract.md '../examples/replays/accepted-manager-fire-hammer.md'
require_text docs/contracts/manager-contract.md '../examples/replays/rejected-missing-dispatch-readiness.md'
require_text docs/contracts/manager-contract.md '../examples/replays/rejected-missing-approval-evidence.md'
require_text docs/contracts/manager-contract.md '../examples/replays/rejected-missing-worker-route-result-metadata.md'
require_text docs/contracts/manager-contract.md '../examples/replays/rejected-missing-closeout-review-evidence.md'
require_text docs/contracts/manager-contract.md '../design/carbon-ui-baseline.md'
require_text docs/contracts/manager-contract.md '../product/onboarding-troubleshooting.md'
require_text docs/contracts/manager-contract.md '../policies/authority-and-safety.md'
require_text docs/contracts/manager-contract.md '../policies/credential-lifecycle-and-revocation.md'
require_text docs/contracts/manager-contract.md '../policies/credential-revocation-access-review-drill-2026-06-13.md'
require_text docs/contracts/manager-contract.md '../policies/multi-tenant-rbac.md'
require_text docs/contracts/manager-contract.md '../policies/security-threat-model-and-prompt-injection-controls.md'
require_text docs/contracts/manager-contract.md '../policies/git-governance.md'
require_text docs/contracts/manager-contract.md '../operations/dispatch-lease-recovery.md'
require_text docs/contracts/manager-contract.md '../operations/orchestration-recovery-gate.md'
require_text docs/contracts/manager-contract.md '../operations/sre-operating-baseline.md'
require_text docs/contracts/manager-contract.md '../operations/central-metrics-backend.md'
require_text docs/contracts/manager-contract.md '../operations/on-call-paging-alerting.md'
require_text docs/contracts/manager-contract.md '../operations/release-rollback-capacity-drills.md'
require_text docs/contracts/manager-contract.md '../operations/topology-backup-restore-dr.md'
require_text docs/contracts/manager-contract.md '../operations/sandbox-restore-drill-2026-06-13.md'
require_text docs/contracts/manager-contract.md '../compliance/control-map-and-evidence-package.md'
require_text docs/contracts/manager-contract.md '../compliance/audit-review-2026-06-13.md'
require_text docs/contracts/manager-contract.md '../compliance/immutable-audit-export.md'
require_text docs/contracts/manager-contract.md '../compliance/signed-immutable-audit-export-key-management-2026-06-13.md'
require_text docs/contracts/manager-contract.md '../enterprise-readiness/runtime-quality-gate-matrix.md'
require_text docs/contracts/manager-contract.md '../adapters/hermes.md'
require_text docs/contracts/manager-contract.md 'hammer-worker-contract.md'
require_text docs/contracts/manager-contract.md 'A Worker result packet must include:'
require_text docs/contracts/manager-contract.md 'planned result-packet or Manager-review surface'
require_text docs/contracts/manager-contract.md 'closeout evidence'
require_text docs/contracts/manager-contract.md 'acceptance-criteria evidence'
require_text docs/contracts/manager-contract.md 'scope-control statement'
require_text docs/contracts/manager-contract.md 'approval-gate status'
require_text docs/contracts/manager-contract.md 'Manager-Fire-Hammer replay suite'
require_text docs/contracts/manager-contract.md 'dispatch readiness'
require_text docs/contracts/manager-contract.md 'Worker route metadata'
require_text docs/contracts/manager-contract.md 'durable lease and restart recovery contract'
require_text docs/contracts/manager-contract.md 'no duplicate dispatch after restart'
require_text docs/contracts/manager-contract.md 'Fault-injected orchestration recovery evidence'
require_text docs/contracts/manager-contract.md 'retry loss after restart'
require_text docs/contracts/manager-contract.md 'SRE operating evidence'
require_text docs/contracts/manager-contract.md 'review-age SLO'
require_text docs/contracts/manager-contract.md 'Service-level objective evidence'
require_text docs/contracts/manager-contract.md 'external SLA approval boundary'
require_text docs/contracts/manager-contract.md 'Central metrics backend designs'
require_text docs/contracts/manager-contract.md 'metric taxonomy'
require_text docs/contracts/manager-contract.md 'label and cardinality controls'
require_text docs/contracts/manager-contract.md 'On-call paging and alerting baselines'
require_text docs/contracts/manager-contract.md 'alert taxonomy'
require_text docs/contracts/manager-contract.md 'severity mapping'
require_text docs/contracts/manager-contract.md 'quiet-hours behavior'
require_text docs/contracts/manager-contract.md 'notification routing'
require_text docs/contracts/manager-contract.md 'test evidence shape'
require_text docs/contracts/manager-contract.md 'metrics linkage'
require_text docs/contracts/manager-contract.md 'Release rollback capacity evidence'
require_text docs/contracts/manager-contract.md 'staged rollout'
require_text docs/contracts/manager-contract.md 'Topology backup restore and disaster recovery evidence'
require_text docs/contracts/manager-contract.md 'environment tier'
require_text docs/contracts/manager-contract.md 'backup target'
require_text docs/contracts/manager-contract.md 'Credential-free sandbox restore drill evidence'
require_text docs/contracts/manager-contract.md 'measured RPO/RTO'
require_text docs/contracts/manager-contract.md 'cleanup receipt'
require_text docs/contracts/manager-contract.md 'Compliance evidence packages'
require_text docs/contracts/manager-contract.md 'approval control'
require_text docs/contracts/manager-contract.md 'sample evidence chain'
require_text docs/contracts/manager-contract.md 'Compliance audit review packages'
require_text docs/contracts/manager-contract.md 'completed-change reference'
require_text docs/contracts/manager-contract.md 'integrity check'
require_text docs/contracts/manager-contract.md 'Immutable audit export designs'
require_text docs/contracts/manager-contract.md 'manifest hash'
require_text docs/contracts/manager-contract.md 'redaction manifest'
require_text docs/contracts/manager-contract.md 'Signed immutable audit export key-management evidence'
require_text docs/contracts/manager-contract.md 'signed manifest storage'
require_text docs/contracts/manager-contract.md 'signing-key ownership'
require_text docs/contracts/manager-contract.md 'verification cadence'
require_text docs/contracts/manager-contract.md 'Runtime quality gates'
require_text docs/contracts/manager-contract.md 'required tests'
require_text docs/contracts/manager-contract.md 'accepted risk'
require_text docs/contracts/manager-contract.md 'Credential lifecycle and revocation dry runs'
require_text docs/contracts/manager-contract.md 'token classes'
require_text docs/contracts/manager-contract.md 'dry-run revocation checklist'
require_text docs/contracts/manager-contract.md 'Approved credential revocation and access-review drills'
require_text docs/contracts/manager-contract.md 'denial output'
require_text docs/contracts/manager-contract.md 'access-review output'
require_text docs/contracts/manager-contract.md 'Multi-tenant RBAC designs'
require_text docs/contracts/manager-contract.md 'tenant boundaries'
require_text docs/contracts/manager-contract.md 'permission matrix'
require_text docs/contracts/manager-contract.md 'Security threat models and prompt-injection controls'
require_text docs/contracts/manager-contract.md 'threat actors'
require_text docs/contracts/manager-contract.md 'prompt-injection paths'
require_text docs/contracts/manager-contract.md 'credential-broker misuse'
require_text docs/contracts/manager-contract.md 'GitHub Project control-plane risks'
require_text docs/contracts/manager-contract.md 'Human-facing UI surfaces'
require_text docs/contracts/manager-contract.md 'role-based token mapping'
require_text docs/contracts/manager-contract.md 'visual QA checklist'
require_text docs/contracts/manager-contract.md 'Role-based onboarding and troubleshooting guides'
require_text docs/contracts/manager-contract.md 'admin journey'
require_text docs/contracts/manager-contract.md 'approver journey'
require_text docs/contracts/manager-contract.md 'operator journey'
require_text docs/contracts/manager-contract.md 'auditor journey'
require_text docs/contracts/manager-contract.md 'worker-author journey'
require_text docs/contracts/manager-contract.md 'clear next actions'
require_no_text docs/contracts/manager-contract.md 'A Worker result packet should include:'
require_no_text docs/contracts/manager-contract.md 'result-review link. Missing approval evidence blocks dispatch.'

require_text docs/contracts/hammer-worker-contract.md '# Dokkaebi Hammer Worker Contract'
require_text docs/contracts/hammer-worker-contract.md 'local_worktree'
require_text docs/contracts/hammer-worker-contract.md 'ssh'
require_text docs/contracts/hammer-worker-contract.md 'docker'
require_text docs/contracts/hammer-worker-contract.md 'kubernetes_job'
require_text docs/contracts/hammer-worker-contract.md 'capabilities'
require_text docs/contracts/hammer-worker-contract.md 'isolation'
require_text docs/contracts/hammer-worker-contract.md 'credential_mode'
require_text docs/contracts/hammer-worker-contract.md 'cleanup'
require_text docs/contracts/hammer-worker-contract.md 'Manager PATs, OAuth tokens'
require_text docs/contracts/hammer-worker-contract.md 'isolated live smoke'

require_text docs/policies/authority-and-safety.md '# Dokkaebi Authority and Safety Policy'
require_text docs/policies/authority-and-safety.md '## Human approval required'
require_text docs/policies/authority-and-safety.md '## Approval evidence record'
require_text docs/policies/authority-and-safety.md '## Fail-closed preflight'
require_text docs/policies/authority-and-safety.md '## Credential broker boundary'
require_text docs/policies/authority-and-safety.md '## Multi-tenant RBAC boundary'
require_text docs/policies/authority-and-safety.md '[`multi-tenant-rbac.md`](multi-tenant-rbac.md)'
require_text docs/policies/authority-and-safety.md '## Symphony compatibility policy'
require_text docs/policies/authority-and-safety.md 'planned result-packet or Manager-review surface'
require_text docs/policies/authority-and-safety.md 'required at closeout'
require_text docs/policies/authority-and-safety.md 'control-plane writes'
require_text docs/policies/authority-and-safety.md 'approved setup authority'
require_text docs/policies/authority-and-safety.md '## Git governance boundary'
require_text docs/policies/authority-and-safety.md '[`git-governance.md`](git-governance.md)'
require_no_text docs/policies/authority-and-safety.md 'link to the resulting Worker result packet or Manager review'

require_text docs/policies/multi-tenant-rbac.md '# Multi-Tenant RBAC Model'
require_text docs/policies/multi-tenant-rbac.md 'tenant boundaries'
require_text docs/policies/multi-tenant-rbac.md 'role taxonomy'
require_text docs/policies/multi-tenant-rbac.md 'permission matrix'
require_text docs/policies/multi-tenant-rbac.md 'admission checks'
require_text docs/policies/multi-tenant-rbac.md 'authorization checks'
require_text docs/policies/multi-tenant-rbac.md 'GitHub Project scope mapping'
require_text docs/policies/multi-tenant-rbac.md 'repository scope mapping'
require_text docs/policies/multi-tenant-rbac.md 'credential boundary'
require_text docs/policies/multi-tenant-rbac.md 'worker route boundary'
require_text docs/policies/multi-tenant-rbac.md 'break-glass path'
require_text docs/policies/multi-tenant-rbac.md 'access review'
require_text docs/policies/multi-tenant-rbac.md 'audit evidence'
require_text docs/policies/multi-tenant-rbac.md 'onboarding and offboarding'
require_text docs/policies/multi-tenant-rbac.md 'failure handling'
require_text docs/policies/multi-tenant-rbac.md 'remaining operational gaps'
require_text docs/policies/multi-tenant-rbac.md 'permission level'
require_text docs/policies/multi-tenant-rbac.md 'docs-only'
require_text docs/policies/multi-tenant-rbac.md 'control-plane'
require_text docs/policies/multi-tenant-rbac-drill-2026-06-13.md '# Multi-Tenant RBAC Replay Drill'
require_text docs/policies/multi-tenant-rbac-drill-2026-06-13.md 'admission decision output'
require_text docs/policies/multi-tenant-rbac-drill-2026-06-13.md 'authorization decision output'
require_text docs/policies/multi-tenant-rbac-drill-2026-06-13.md 'denied cross-tenant operation evidence'
require_text docs/policies/multi-tenant-rbac-drill-2026-06-13.md 'credential grant boundary evidence'
require_text docs/policies/multi-tenant-rbac-drill-2026-06-13.md 'worker route boundary evidence'
require_text docs/policies/multi-tenant-rbac-drill-2026-06-13.md 'access-review evidence'
require_text docs/policies/multi-tenant-rbac-drill-2026-06-13.md 'approval-gate status'
require_text scripts/validate-multi-tenant-rbac-drill.sh 'PASS Dokkaebi multi-tenant RBAC drill validation passed'

require_text docs/policies/credential-lifecycle-and-revocation.md '# Credential Lifecycle And Revocation Dry Run'
require_text docs/policies/credential-lifecycle-and-revocation.md 'token classes'
require_text docs/policies/credential-lifecycle-and-revocation.md 'owners'
require_text docs/policies/credential-lifecycle-and-revocation.md 'storage'
require_text docs/policies/credential-lifecycle-and-revocation.md 'rotation cadence'
require_text docs/policies/credential-lifecycle-and-revocation.md 'revocation triggers'
require_text docs/policies/credential-lifecycle-and-revocation.md 'audit evidence'
require_text docs/policies/credential-lifecycle-and-revocation.md 'development and sandbox auth exception'
require_text docs/policies/credential-lifecycle-and-revocation.md 'dry-run revocation checklist'
require_text docs/policies/credential-lifecycle-and-revocation.md 'approval-gate status'
require_text docs/policies/credential-lifecycle-and-revocation.md 'cleanup receipt'
require_text docs/policies/credential-lifecycle-and-revocation.md 'residual risk'
require_text docs/policies/credential-lifecycle-and-revocation.md 'next action'
require_text docs/policies/credential-lifecycle-and-revocation.md 'does not authorize'
require_text scripts/validate-credential-lifecycle.sh 'PASS Dokkaebi credential lifecycle validation passed'

require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md '# Credential Revocation And Access-Review Drill 2026-06-13'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'owner approval'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'grant scope'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'expiration'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'revocation trigger'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'denial output'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'sandbox revocation output'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'access-review output'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'approval-gate status'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'cleanup receipt'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'residual risk'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'next action'
require_text docs/policies/credential-revocation-access-review-drill-2026-06-13.md 'does not authorize'
require_text scripts/validate-credential-revocation-drill.sh 'PASS Dokkaebi credential revocation drill validation passed'

require_text docs/policies/security-threat-model-and-prompt-injection-controls.md '# Security Threat Model And Prompt-Injection Controls'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'threat actors'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'trust boundaries'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'assets'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'abuse cases'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'prompt-injection paths'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'data exfiltration paths'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'credential-broker misuse paths'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'worker-route escalation paths'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'GitHub Project control-plane risks'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'mitigations'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'detection evidence'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'fail-closed behavior'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'owner review cadence'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'residual risk'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'next action'
require_text docs/policies/security-threat-model-and-prompt-injection-controls.md 'does not authorize'
require_text scripts/validate-security-threat-model.sh 'PASS Dokkaebi security threat model validation passed'

require_text docs/design/carbon-ui-baseline.md '# Carbon UI Token And Accessibility Baseline'
require_text docs/design/carbon-ui-baseline.md 'theme choice'
require_text docs/design/carbon-ui-baseline.md 'role-based token mapping'
require_text docs/design/carbon-ui-baseline.md 'layering model'
require_text docs/design/carbon-ui-baseline.md 'interaction states'
require_text docs/design/carbon-ui-baseline.md 'focus requirements'
require_text docs/design/carbon-ui-baseline.md 'contrast thresholds'
require_text docs/design/carbon-ui-baseline.md 'data visualization rules'
require_text docs/design/carbon-ui-baseline.md 'status color rules'
require_text docs/design/carbon-ui-baseline.md 'component state inventory'
require_text docs/design/carbon-ui-baseline.md 'visual QA checklist'
require_text docs/design/carbon-ui-baseline.md 'remaining operational gaps'
require_text docs/design/carbon-ui-baseline.md 'permission level'
require_text docs/design/carbon-ui-baseline.md 'docs-only'
require_text docs/design/carbon-ui-baseline.md 'Carbon Design System'
require_text docs/product/onboarding-troubleshooting.md '# Role-Based Onboarding And Troubleshooting Guide'
require_text docs/product/onboarding-troubleshooting.md 'admin journey'
require_text docs/product/onboarding-troubleshooting.md 'approver journey'
require_text docs/product/onboarding-troubleshooting.md 'operator journey'
require_text docs/product/onboarding-troubleshooting.md 'auditor journey'
require_text docs/product/onboarding-troubleshooting.md 'worker-author journey'
require_text docs/product/onboarding-troubleshooting.md 'install walkthrough'
require_text docs/product/onboarding-troubleshooting.md 'GitHub Project setup checks'
require_text docs/product/onboarding-troubleshooting.md 'repository setup checks'
require_text docs/product/onboarding-troubleshooting.md 'approval and review actions'
require_text docs/product/onboarding-troubleshooting.md 'result-packet closeout actions'
require_text docs/product/onboarding-troubleshooting.md 'Fire failure troubleshooting'
require_text docs/product/onboarding-troubleshooting.md 'worker failure troubleshooting'
require_text docs/product/onboarding-troubleshooting.md 'GitHub failure troubleshooting'
require_text docs/product/onboarding-troubleshooting.md 'credential failure troubleshooting'
require_text docs/product/onboarding-troubleshooting.md 'validation failure troubleshooting'
require_text docs/product/onboarding-troubleshooting.md 'project-field failure troubleshooting'
require_text docs/product/onboarding-troubleshooting.md 'PR failure troubleshooting'
require_text docs/product/onboarding-troubleshooting.md 'result-packet failure troubleshooting'
require_text docs/product/onboarding-troubleshooting.md 'clear next actions'
require_text docs/product/onboarding-troubleshooting.md 'approval boundary'
require_text docs/product/onboarding-troubleshooting.md 'permission level'
require_text docs/product/onboarding-troubleshooting.md 'docs-only'

require_text docs/policies/git-governance.md '# Dokkaebi Git Governance Policy'
require_text docs/policies/git-governance.md '## Enforcement surfaces'
require_text docs/policies/git-governance.md '## GitHub Flow'
require_text docs/policies/git-governance.md '`main` is the only long-lived integration branch'
require_text docs/policies/git-governance.md 'short-lived branches'
require_text docs/policies/git-governance.md 'PR merge requires explicit Human approval'
require_text docs/policies/git-governance.md '## Branch naming'
require_text docs/policies/git-governance.md '<type>/<scope-slug>'
require_no_text docs/policies/git-governance.md '<actor>/<type>/<scope-slug>'
require_text docs/policies/git-governance.md '## Commit policy'
require_text docs/policies/git-governance.md 'Commit messages must preserve the development process and decision rationale'
require_text docs/policies/git-governance.md 'Context:'
require_text docs/policies/git-governance.md 'Decision:'
require_text docs/policies/git-governance.md 'Why:'
require_text docs/policies/git-governance.md 'Validation:'
require_text docs/policies/git-governance.md 'Risks:'
require_text docs/policies/git-governance.md '## Pull request requirements'
require_text docs/policies/git-governance.md '## Submodule policy'
require_text docs/policies/git-governance.md 'Submodule commits must be created inside the submodule first'
require_text docs/policies/git-governance.md 'A root gitlink update must cite the submodule path and target commit sha'
require_text docs/policies/git-governance.md 'Public metadata hygiene'

require_text .github/pull_request_template.md '# Dokkaebi Pull Request'
require_text .github/pull_request_template.md '## Decision rationale'
require_text .github/pull_request_template.md 'Context:'
require_text .github/pull_request_template.md 'Decision:'
require_text .github/pull_request_template.md 'Why:'
require_text .github/pull_request_template.md '## Public metadata hygiene'
require_text .github/pull_request_template.md '## Git status'

require_text .github/workflows/dokkaebi-governance.yml 'name: Dokkaebi governance'
require_text .github/workflows/dokkaebi-governance.yml 'contract-docs'
require_text .github/workflows/dokkaebi-governance.yml 'git-governance'
require_text .github/workflows/dokkaebi-governance.yml 'bash scripts/validate-contract-docs.sh'
require_text .github/workflows/dokkaebi-governance.yml 'bash scripts/validate-git-governance.sh'
require_text .github/workflows/dokkaebi-governance.yml 'bash scripts/validate-dokkaebi-plugin.sh'
require_text .github/workflows/dokkaebi-governance.yml 'bash scripts/validate-readiness-criteria.sh'

require_text scripts/validate-git-governance.sh 'PASS Dokkaebi Git governance checks passed'
require_text scripts/validate-git-governance.sh 'Context:'
require_text scripts/validate-git-governance.sh 'Decision:'
require_text scripts/validate-git-governance.sh 'Why:'
require_text scripts/validate-git-governance.sh 'Validation:'
require_text scripts/validate-git-governance.sh 'Risks:'
require_text scripts/validate-dokkaebi-plugin.sh 'PASS Dokkaebi plugin packaging checks passed'
require_text scripts/validate-readiness-criteria.sh 'PASS Dokkaebi enterprise readiness criteria are present and structurally valid'
require_text scripts/validate-carbon-ui-baseline.sh 'PASS Dokkaebi Carbon UI baseline validation passed'
require_text scripts/validate-multi-tenant-rbac.sh 'PASS Dokkaebi multi-tenant RBAC validation passed'
require_text scripts/validate-dispatch-lease-recovery.sh 'PASS Dokkaebi dispatch lease recovery validation passed'
require_text scripts/validate-orchestration-recovery-gate.sh 'PASS Dokkaebi orchestration recovery gate validation passed'
require_text scripts/validate-sre-operating-baseline.sh 'PASS Dokkaebi SRE operating baseline validation passed'
require_text scripts/validate-incident-response-runbook.sh 'PASS Dokkaebi incident response runbook validation passed'
require_text scripts/validate-service-level-objectives.sh 'PASS Dokkaebi service-level objectives validation passed'
require_text scripts/validate-central-metrics-backend.sh 'PASS Dokkaebi central metrics backend validation passed'
require_text scripts/validate-central-metrics-replay.sh 'PASS Dokkaebi central metrics replay validation passed'
require_text scripts/validate-on-call-paging-alerting.sh 'PASS Dokkaebi on-call paging alerting validation passed'
require_text scripts/validate-on-call-alert-routing-drill.sh 'PASS Dokkaebi on-call alert routing drill validation passed'
require_text scripts/validate-onboarding-troubleshooting.sh 'PASS Dokkaebi onboarding troubleshooting validation passed'
require_text scripts/validate-release-rollback-capacity-drills.sh 'PASS Dokkaebi release rollback capacity drill validation passed'
require_text scripts/validate-release-rollback-drill.sh 'PASS Dokkaebi release rollback drill validation passed'
require_text scripts/validate-topology-backup-restore-dr.sh 'PASS Dokkaebi topology backup restore DR validation passed'
require_text scripts/validate-backup-restore-drill.sh 'PASS Dokkaebi backup restore drill validation passed'
require_text scripts/validate-sandbox-restore-drill.sh 'PASS Dokkaebi sandbox restore drill validation passed'
require_text scripts/validate-compliance-package.sh 'PASS Dokkaebi compliance package validation passed'
require_text scripts/validate-compliance-audit-review.sh 'PASS Dokkaebi compliance audit review validation passed'
require_text scripts/validate-immutable-audit-export.sh 'PASS Dokkaebi immutable audit export validation passed'

require_text docs/operations/dispatch-lease-recovery.md '# Dispatch Lease And Restart Recovery'
require_text docs/operations/dispatch-lease-recovery.md 'lease store'
require_text docs/operations/dispatch-lease-recovery.md 'owner identity'
require_text docs/operations/dispatch-lease-recovery.md 'retry persistence'
require_text docs/operations/dispatch-lease-recovery.md 'recovery behavior'
require_text docs/operations/dispatch-lease-recovery.md 'no duplicate dispatch after restart'
require_text docs/operations/dispatch-lease-recovery.md 'live GitHub Project residual risks'
require_text docs/operations/dispatch-lease-recovery.md 'lease_token'
require_text docs/operations/dispatch-lease-recovery.md 'idempotency_key'
require_text docs/operations/dispatch-lease-recovery.md 'stale lease'
require_text docs/operations/orchestration-recovery-gate.md '# Orchestration Recovery Gate'
require_text docs/operations/orchestration-recovery-gate.md 'worker failure'
require_text docs/operations/orchestration-recovery-gate.md 'stale lease recovery'
require_text docs/operations/orchestration-recovery-gate.md 'route result handling'
require_text docs/operations/orchestration-recovery-gate.md 'Retry loss after restart'
require_text docs/operations/orchestration-recovery-gate.md 'Live GitHub Project Boundary'
require_text docs/operations/sre-operating-baseline.md '# SRE Operating Baseline'
require_text docs/operations/sre-operating-baseline.md 'dispatch latency'
require_text docs/operations/sre-operating-baseline.md 'recovery time'
require_text docs/operations/sre-operating-baseline.md 'review age'
require_text docs/operations/sre-operating-baseline.md 'error budget'
require_text docs/operations/sre-operating-baseline.md 'incident commander'
require_text docs/operations/sre-operating-baseline.md 'postmortem'
require_text docs/operations/sre-operating-baseline.md 'intentionally deferred'
require_text docs/operations/sre-operating-baseline.md 'central-metrics-backend.md'
require_text docs/operations/sre-operating-baseline.md 'service-level-objectives.md'
require_text docs/operations/sre-operating-baseline.md 'incident-response-runbook-2026-06-13.md'
require_text docs/operations/incident-response-runbook-2026-06-13.md '# Incident Response Runbook And Tabletop'
require_text docs/operations/incident-response-runbook-2026-06-13.md 'severity model'
require_text docs/operations/incident-response-runbook-2026-06-13.md 'incident commander'
require_text docs/operations/incident-response-runbook-2026-06-13.md 'detection'
require_text docs/operations/incident-response-runbook-2026-06-13.md 'mitigation sequence'
require_text docs/operations/incident-response-runbook-2026-06-13.md 'rollback or recovery decision'
require_text docs/operations/incident-response-runbook-2026-06-13.md 'alert routing decision'
require_text docs/operations/incident-response-runbook-2026-06-13.md 'postmortem template'
require_text docs/operations/incident-response-runbook-2026-06-13.md 'evidence retention'
require_text docs/operations/service-level-objectives.md '# Service-Level Objectives And SLA Boundary'
require_text docs/operations/service-level-objectives.md 'dispatch latency'
require_text docs/operations/service-level-objectives.md 'recovery time'
require_text docs/operations/service-level-objectives.md 'review age'
require_text docs/operations/service-level-objectives.md 'availability posture'
require_text docs/operations/service-level-objectives.md 'error-budget'
require_text docs/operations/service-level-objectives.md 'fallback evidence'
require_text docs/operations/service-level-objectives.md 'External SLA Boundary'
require_text docs/operations/service-level-objectives.md 'issue #80'
require_text docs/operations/central-metrics-backend.md '# Central Metrics Backend Integration'
require_text docs/operations/central-metrics-backend.md 'metric taxonomy'
require_text docs/operations/central-metrics-backend.md 'ingestion path'
require_text docs/operations/central-metrics-backend.md 'storage backend assumptions'
require_text docs/operations/central-metrics-backend.md 'retention'
require_text docs/operations/central-metrics-backend.md 'label and cardinality controls'
require_text docs/operations/central-metrics-backend.md 'dashboard and alert integration'
require_text docs/operations/central-metrics-backend.md 'SLO linkage'
require_text docs/operations/central-metrics-backend.md 'ownership'
require_text docs/operations/central-metrics-backend.md 'security boundary'
require_text docs/operations/central-metrics-backend.md 'rollout phases'
require_text docs/operations/central-metrics-backend.md 'verification steps'
require_text docs/operations/central-metrics-backend.md 'failure handling'
require_text docs/operations/central-metrics-backend.md 'remaining operational gaps'
require_text docs/operations/central-metrics-backend.md 'permission level'
require_text docs/operations/central-metrics-backend.md 'docs-only'
require_text docs/operations/central-metrics-backend.md 'control-plane'
require_text docs/operations/central-metrics-backend.md 'central-metrics-replay-2026-06-13.md'
require_text docs/operations/central-metrics-replay-2026-06-13.md '# Central Metrics Local Replay'
require_text docs/operations/central-metrics-replay-2026-06-13.md 'representative metrics'
require_text docs/operations/central-metrics-replay-2026-06-13.md 'ingestion output'
require_text docs/operations/central-metrics-replay-2026-06-13.md 'storage/query output'
require_text docs/operations/central-metrics-replay-2026-06-13.md 'parsed dashboard view'
require_text docs/operations/central-metrics-replay-2026-06-13.md 'alert-rule evaluation'
require_text docs/operations/central-metrics-replay-2026-06-13.md 'retention/cardinality checks'
require_text docs/operations/central-metrics-replay-2026-06-13.md 'approval-gate status'
require_text docs/operations/on-call-paging-alerting.md '# On-Call Paging And Alerting Baseline'
require_text docs/operations/on-call-paging-alerting.md 'alert taxonomy'
require_text docs/operations/on-call-paging-alerting.md 'severity mapping'
require_text docs/operations/on-call-paging-alerting.md 'escalation roster shape'
require_text docs/operations/on-call-paging-alerting.md 'paging backend decision'
require_text docs/operations/on-call-paging-alerting.md 'quiet-hours behavior'
require_text docs/operations/on-call-paging-alerting.md 'notification routing'
require_text docs/operations/on-call-paging-alerting.md 'test evidence shape'
require_text docs/operations/on-call-paging-alerting.md 'SLO linkage'
require_text docs/operations/on-call-paging-alerting.md 'metrics linkage'
require_text docs/operations/on-call-paging-alerting.md 'ownership'
require_text docs/operations/on-call-paging-alerting.md 'failure handling'
require_text docs/operations/on-call-paging-alerting.md 'approval boundary'
require_text docs/operations/on-call-paging-alerting.md 'remaining operational gaps'
require_text docs/operations/on-call-paging-alerting.md 'permission level'
require_text docs/operations/on-call-paging-alerting.md 'docs-only'
require_text docs/operations/on-call-paging-alerting.md 'control-plane'
require_text docs/operations/on-call-paging-alerting.md 'on-call-alert-routing-drill-2026-06-13.md'
require_text docs/operations/on-call-alert-routing-drill-2026-06-13.md '# On-Call Alert Routing Dry-Run Drill'
require_text docs/operations/on-call-alert-routing-drill-2026-06-13.md 'selected GitHub evidence dry-run sink'
require_text docs/operations/on-call-alert-routing-drill-2026-06-13.md 'quiet-hours behavior'
require_text docs/operations/on-call-alert-routing-drill-2026-06-13.md 'dry-run delivery output'
require_text docs/operations/on-call-alert-routing-drill-2026-06-13.md 'approval-gate status'
require_text docs/operations/on-call-alert-routing-drill-2026-06-13.md 'followUpIssueUrl'
require_text docs/operations/release-rollback-capacity-drills.md '# Release Rollback Capacity And Drill Baseline'
require_text docs/operations/release-rollback-capacity-drills.md 'staged rollout'
require_text docs/operations/release-rollback-capacity-drills.md 'rollback trigger'
require_text docs/operations/release-rollback-capacity-drills.md 'queue'
require_text docs/operations/release-rollback-capacity-drills.md 'worker'
require_text docs/operations/release-rollback-capacity-drills.md 'retry'
require_text docs/operations/release-rollback-capacity-drills.md 'review age'
require_text docs/operations/release-rollback-capacity-drills.md 'local validation path'
require_text docs/operations/release-rollback-capacity-drills.md 'drill evidence'
require_text docs/operations/release-rollback-capacity-drills.md 'does not authorize live mutation'
require_text docs/operations/release-rollback-drill-2026-06-13.md '# Local Release And Rollback Drill'
require_text docs/operations/release-rollback-drill-2026-06-13.md 'release candidate'
require_text docs/operations/release-rollback-drill-2026-06-13.md 'staged rollout step'
require_text docs/operations/release-rollback-drill-2026-06-13.md 'rollback trigger'
require_text docs/operations/release-rollback-drill-2026-06-13.md 'rollback decision'
require_text docs/operations/release-rollback-drill-2026-06-13.md 'recovery path'
require_text docs/operations/release-rollback-drill-2026-06-13.md 'command output'
require_text docs/operations/release-rollback-drill-2026-06-13.md 'validation output'
require_text docs/operations/release-rollback-drill-2026-06-13.md 'staged rollout decision'
require_text docs/operations/topology-backup-restore-dr.md '# Topology Backup Restore And Disaster Recovery Baseline'
require_text docs/operations/topology-backup-restore-dr.md 'development'
require_text docs/operations/topology-backup-restore-dr.md 'sandbox'
require_text docs/operations/topology-backup-restore-dr.md 'staging'
require_text docs/operations/topology-backup-restore-dr.md 'production'
require_text docs/operations/topology-backup-restore-dr.md 'HA assumption'
require_text docs/operations/topology-backup-restore-dr.md 'backup target'
require_text docs/operations/topology-backup-restore-dr.md 'restore step'
require_text docs/operations/topology-backup-restore-dr.md 'RPO'
require_text docs/operations/topology-backup-restore-dr.md 'RTO'
require_text docs/operations/topology-backup-restore-dr.md 'DR role'
require_text docs/operations/topology-backup-restore-dr.md 'evidence retention'
require_text docs/operations/topology-backup-restore-dr.md 'drill evidence'
require_text docs/operations/topology-backup-restore-dr.md 'does not authorize live mutation'
require_text docs/operations/backup-restore-drill-2026-06-13.md '# Local Backup Restore And Disaster Recovery Replay Drill'
require_text docs/operations/backup-restore-drill-2026-06-13.md 'local fixture replay'
require_text docs/operations/backup-restore-drill-2026-06-13.md 'backup target'
require_text docs/operations/backup-restore-drill-2026-06-13.md 'restore point'
require_text docs/operations/backup-restore-drill-2026-06-13.md 'RPO result'
require_text docs/operations/backup-restore-drill-2026-06-13.md 'RTO result'
require_text docs/operations/backup-restore-drill-2026-06-13.md 'approval-gate status'
require_text docs/operations/backup-restore-drill-2026-06-13.md 'cleanup'
require_text docs/operations/backup-restore-drill-2026-06-13.md 'does not authorize'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md '# Credential-Free Sandbox Restore Drill'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md 'credential-free sandbox restore drill'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md 'sandbox target'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md 'restore point'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md 'Measured RPO'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md 'Measured RTO'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md 'DR Roles'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md 'validation output'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md 'approval-gate status'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md 'cleanup receipt'
require_text docs/operations/sandbox-restore-drill-2026-06-13.md 'does not authorize'
require_text docs/compliance/control-map-and-evidence-package.md '# Compliance Control Map And Evidence Package'
require_text docs/compliance/control-map-and-evidence-package.md 'approval control'
require_text docs/compliance/control-map-and-evidence-package.md 'access control'
require_text docs/compliance/control-map-and-evidence-package.md 'change management control'
require_text docs/compliance/control-map-and-evidence-package.md 'logging control'
require_text docs/compliance/control-map-and-evidence-package.md 'incident control'
require_text docs/compliance/control-map-and-evidence-package.md 'credential control'
require_text docs/compliance/control-map-and-evidence-package.md 'retention'
require_text docs/compliance/control-map-and-evidence-package.md 'redaction'
require_text docs/compliance/control-map-and-evidence-package.md 'integrity'
require_text docs/compliance/control-map-and-evidence-package.md 'ownership'
require_text docs/compliance/control-map-and-evidence-package.md 'export design'
require_text docs/compliance/control-map-and-evidence-package.md 'package contents'
require_text docs/compliance/control-map-and-evidence-package.md 'sample evidence chain'
require_text docs/compliance/control-map-and-evidence-package.md 'approval boundary'
require_text docs/compliance/control-map-and-evidence-package.md 'secret-bearing evidence'
require_text docs/compliance/audit-review-2026-06-13.md '# Compliance Audit Review 2026-06-13'
require_text docs/compliance/audit-review-2026-06-13.md 'completed change'
require_text docs/compliance/audit-review-2026-06-13.md 'reviewer'
require_text docs/compliance/audit-review-2026-06-13.md 'control coverage'
require_text docs/compliance/audit-review-2026-06-13.md 'evidence links'
require_text docs/compliance/audit-review-2026-06-13.md 'exceptions'
require_text docs/compliance/audit-review-2026-06-13.md 'retention decision'
require_text docs/compliance/audit-review-2026-06-13.md 'redaction decision'
require_text docs/compliance/audit-review-2026-06-13.md 'integrity check'
require_text docs/compliance/audit-review-2026-06-13.md 'approval-gate status'
require_text docs/compliance/audit-review-2026-06-13.md 'residual risk'
require_text docs/compliance/audit-review-2026-06-13.md 'next action'
require_text docs/compliance/audit-review-2026-06-13.md 'no credential'
require_text docs/compliance/audit-review-2026-06-13.md 'no production'
require_text docs/compliance/immutable-audit-export.md '# Immutable Audit Export Design'
require_text docs/compliance/immutable-audit-export.md 'manifest hash'
require_text docs/compliance/immutable-audit-export.md 'source links'
require_text docs/compliance/immutable-audit-export.md 'redaction manifest'
require_text docs/compliance/immutable-audit-export.md 'retention metadata'
require_text docs/compliance/immutable-audit-export.md 'ownership'
require_text docs/compliance/immutable-audit-export.md 'verification steps'
require_text docs/compliance/immutable-audit-export.md 'failure handling'
require_text docs/compliance/immutable-audit-export.md 'approval boundary'
require_text docs/compliance/immutable-audit-export.md 'remaining operational gaps'
require_text docs/compliance/immutable-audit-export.md 'permission level'
require_text docs/compliance/immutable-audit-export.md 'docs-only'
require_text docs/compliance/immutable-audit-export.md 'no production'
require_text docs/compliance/immutable-audit-export.md 'control-plane'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md '# Immutable Audit Export Verification Drill 2026-06-13'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md 'manifest hash'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md 'source links'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md 'redaction manifest'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md 'retention metadata'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md 'verification output'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md 'approval-gate status'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md 'cleanup'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md 'residual risk'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md 'next action'
require_text docs/compliance/immutable-audit-export-verification-2026-06-13.md 'does not authorize'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md '# Signed Immutable Audit Export Key Management Drill 2026-06-13'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'signed manifest storage'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'signing-key ownership'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'rotation'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'revocation'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'verification cadence'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'retention enforcement'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'redaction review'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'owner review'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'cleanup'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'residual risk'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'next action'
require_text docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md 'does not authorize'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md '# Runtime Quality Gate Matrix'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'orchestration'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'credential'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'GitHub adapter'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'worker provider'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'UI'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'required tests'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'accepted risk'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'approval-gate status'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'cleanup receipt'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'residual risk'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'next action'
require_text docs/enterprise-readiness/runtime-quality-gate-matrix.md 'does not authorize'

require_text docs/adapters/hermes.md '# Hermes Manager Adapter'
require_text docs/adapters/hermes.md '## Approval and preflight handling'
require_text docs/adapters/hermes.md '## Symphony integration expectations'
require_text docs/adapters/hermes.md '## Adapter conformance matrix'
require_text docs/adapters/hermes.md 'approved setup authority'

require_text docs/templates/worker-ticket.md '# Worker Ticket Template'
require_text docs/templates/worker-ticket.md '## Goal'
require_text docs/templates/worker-ticket.md '## Acceptance criteria'
require_text docs/templates/worker-ticket.md '## Permission level'
require_text docs/templates/worker-ticket.md '## Human approval gates'
require_text docs/templates/worker-ticket.md '## Git plan'
require_text docs/templates/worker-ticket.md '## Validation requirements'
require_text docs/templates/worker-ticket.md '## Expected result packet'
require_text docs/templates/worker-ticket.md '[`worker-result-packet.md`](worker-result-packet.md)'
require_text docs/templates/worker-ticket.md '../policies/authority-and-safety.md'
require_text docs/templates/worker-ticket.md '../policies/git-governance.md'
require_text docs/templates/worker-ticket.md 'acceptance-criteria evidence'
require_text docs/templates/worker-ticket.md 'whether acceptance criteria were met'
require_text docs/templates/worker-ticket.md 'scope-control statement'
require_text docs/templates/worker-ticket.md 'approval-gate status'

require_text docs/templates/worker-result-packet.md '# Worker Result Packet Template'
require_text docs/templates/worker-result-packet.md '## Task identity'
require_text docs/templates/worker-result-packet.md '## Changed artifacts'
require_text docs/templates/worker-result-packet.md '**Commit rationale:**'
require_text docs/templates/worker-result-packet.md '## Acceptance criteria evidence'
require_text docs/templates/worker-result-packet.md '## Validation evidence'
require_text docs/templates/worker-result-packet.md '## Blockers or missing permissions'
require_text docs/templates/worker-result-packet.md '## Residual risks'
require_text docs/templates/worker-result-packet.md '## Scope control'
require_text docs/templates/worker-result-packet.md 'Human approval gates reached'
require_text docs/templates/worker-result-packet.md '## Recommended Manager/Human next action'

require_text README.md 'ARCHITECTURE.md'
require_text README.md 'WORKFLOW.md'
require_text README.md 'docs/adr/0001-hermes-first-manager-contract.md'
require_text README.md 'docs/contracts/manager-contract.md'
require_text README.md 'docs/contracts/hammer-worker-contract.md'
require_text README.md 'docs/deep-interview-project-dokkaebi.md'
require_text README.md 'docs/policies/authority-and-safety.md'
require_text README.md 'docs/policies/git-governance.md'
require_text README.md 'docs/enterprise-readiness/criteria.json'
require_text README.md 'docs/enterprise-readiness/development-loop.md'
require_text README.md 'docs/adapters/hermes.md'
require_text README.md 'docs/templates/worker-ticket.md'
require_text README.md 'docs/templates/worker-result-packet.md'
require_text README.md '## Quickstart'
require_text README.md 'tracker.projects'
require_text README.md 'kubernetes_job'

python3 - <<'PY'
from pathlib import Path
import re
import subprocess
import sys

scope = [
    Path('README.md'),
    Path('ARCHITECTURE.md'),
    Path('WORKFLOW.md'),
    Path('docs/contracts/manager-contract.md'),
    Path('docs/contracts/hammer-worker-contract.md'),
    Path('docs/policies/authority-and-safety.md'),
    Path('docs/policies/git-governance.md'),
    Path('docs/adapters/hermes.md'),
    Path('docs/templates/worker-ticket.md'),
    Path('docs/templates/worker-result-packet.md'),
]

def is_unchecked_submodule_link(target: str) -> bool:
    parts = Path(target).parts
    if not parts:
        return False
    root = parts[0]
    if Path(root, '.git').exists():
        return False
    try:
        output = subprocess.check_output(
            ['git', 'ls-files', '--stage', '--', root],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return False
    return output.startswith('160000 ')

errors = []
for path in scope:
    text = path.read_text()
    for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', text):
        if '://' in target or target.startswith('#') or target.startswith('mailto:'):
            continue
        local = target.split('#', 1)[0]
        if not local:
            continue
        resolved = path.parent / local
        if not resolved.exists() and not is_unchecked_submodule_link(str(resolved)):
            errors.append(f'missing markdown link target: {path} -> {target}')

workflow = Path('WORKFLOW.md').read_text()
ticket = Path('docs/templates/worker-ticket.md').read_text()

for term in ['Intake', 'Clarifying', 'Ready', 'Dispatchable', 'In Progress',
             'Needs Review', 'Human Review', 'Fix Requested', 'Merging', 'Done',
             'Blocked', 'Failed', 'Cancelled', 'Reopened']:
    if term not in workflow:
        errors.append(f'workflow missing status term: {term}')
    if term not in ticket:
        errors.append(f'worker ticket missing status term: {term}')

contract = Path('docs/contracts/manager-contract.md').read_text()
architecture = Path('ARCHITECTURE.md').read_text()
result = Path('docs/templates/worker-result-packet.md').read_text()
for doc_name, doc_text in [
    ('manager contract', contract),
    ('architecture result flow', architecture),
    ('workflow result packet', workflow),
    ('worker ticket expected result packet', ticket),
]:
    for term in ['acceptance-criteria evidence', 'validation commands',
                 'scope-control', 'approval-gate status',
                 'whether acceptance criteria were met']:
        if term not in doc_text:
            errors.append(f'{doc_name} result packet minimum missing: {term}')
for heading in ['## Acceptance criteria evidence', '## Validation evidence',
                '## Scope control', 'Human approval gates reached']:
    if heading not in result:
        errors.append(f'result packet template missing: {heading}')

def markdown_section(text: str, heading: str) -> str | None:
    marker = re.search(rf'^{re.escape(heading)}\s*$', text, re.MULTILINE)
    if marker is None:
        return None
    rest = text[marker.end():]
    next_heading = re.search(r'^##\s+', rest, re.MULTILINE)
    return rest[: next_heading.start()] if next_heading else rest


def validate_result_packet_fixture(path: Path) -> list[str]:
    text = path.read_text()
    found: list[str] = []
    for heading in [
        '## Task identity',
        '## Changed artifacts',
        '## Acceptance criteria evidence',
        '## Validation evidence',
        '## Blockers or missing permissions',
        '## Residual risks',
        '## Scope control',
        '## Recommended Manager/Human next action',
    ]:
        if heading not in text:
            found.append(f'missing required section: {heading}')

    acceptance = markdown_section(text, '## Acceptance criteria evidence')
    if acceptance is not None:
        if '| Criterion | Evidence | Status |' not in acceptance:
            found.append('missing acceptance evidence table')
        if re.search(r'\|\s*(pass|fail|blocked)\s*\|', acceptance, re.IGNORECASE) is None:
            found.append('missing acceptance status')

    validation = markdown_section(text, '## Validation evidence')
    if validation is not None:
        if '```text' not in validation:
            found.append('missing validation command block')
        if 'PASS ' not in validation and 'FAIL ' not in validation:
            found.append('missing validation command outcome')

    scope = markdown_section(text, '## Scope control')
    if scope is not None:
        if '**Stayed within ticket scope:**' not in scope:
            found.append('missing scope-control statement')
        if '**Scope deviations:**' not in scope:
            found.append('missing scope deviation statement')
        if '**Human approval gates reached:**' not in scope:
            found.append('missing approval-gate status')

    return found


def validate_replay_fixture(path: Path) -> list[str]:
    text = path.read_text()
    found: list[str] = []
    required_sections = [
        '## Replay identity',
        '## Manager intake',
        '## Approval gate state',
        '## Fire dispatch readiness',
        '## Hammer work result',
        '## Manager review and closeout',
        '## Replay decision',
    ]
    for heading in required_sections:
        if heading not in text:
            found.append(f'missing required section: {heading}')

    replay_identity = markdown_section(text, '## Replay identity')
    if replay_identity is not None:
        for field in ['**Replay ID:**', '**Contract version:**', '**Source ticket:**',
                      '**Expected replay result:**']:
            if field not in replay_identity:
                found.append(f'missing replay identity field: {field}')

    manager_intake = markdown_section(text, '## Manager intake')
    if manager_intake is not None:
        for field in ['**Source request preserved:** yes', '**Goal:**',
                      '**Acceptance criteria:**', '**Permission level:**',
                      '**Result packet surface:**']:
            if field not in manager_intake:
                found.append(f'missing manager intake field: {field}')

    approval = markdown_section(text, '## Approval gate state')
    if approval is not None:
        for field in ['**Approval evidence:**', '**PR merge approval:**',
                      '**Credential/infrastructure/deployment gates:**',
                      '**Worker authority:**']:
            if field not in approval:
                found.append(f'missing approval gate field: {field}')

    dispatch = markdown_section(text, '## Fire dispatch readiness')
    if dispatch is not None:
        for field in ['**Semantic status:** Dispatchable',
                      '**Project source of truth:** GitHub Project Status',
                      '**Ticket link:**', '**Route metadata:**',
                      '**Admission check:**']:
            if field not in dispatch:
                found.append(f'missing dispatch readiness field: {field}')

    hammer = markdown_section(text, '## Hammer work result')
    if hammer is not None:
        for field in ['**Worker route metadata:**', '**Result packet:**',
                      '**Acceptance criteria evidence:**',
                      '**Validation evidence:**', '**Scope control:**',
                      '**Approval-gate status:**']:
            if field not in hammer:
                found.append(f'missing hammer result field: {field}')

    closeout = markdown_section(text, '## Manager review and closeout')
    if closeout is not None:
        for field in ['**Review decision:**', '**Closeout evidence:**',
                      '**Residual risk:**', '**Next state:**']:
            if field not in closeout:
                found.append(f'missing manager closeout field: {field}')

    replay_decision = markdown_section(text, '## Replay decision')
    if replay_decision is not None:
        for field in ['**Expected replay result:**', '**Reason:**']:
            if field not in replay_decision:
                found.append(f'missing replay decision field: {field}')

    return found


accepted_packet = Path('docs/examples/result-packets/accepted.md')
accepted_errors = validate_result_packet_fixture(accepted_packet)
if accepted_errors:
    errors.append(
        f'{accepted_packet} should pass result-packet validation: '
        + '; '.join(accepted_errors)
    )

rejected_packets = {
    Path('docs/examples/result-packets/rejected-missing-acceptance-evidence.md'):
        'missing required section: ## Acceptance criteria evidence',
    Path('docs/examples/result-packets/rejected-missing-validation-evidence.md'):
        'missing required section: ## Validation evidence',
    Path('docs/examples/result-packets/rejected-missing-scope-control.md'):
        'missing required section: ## Scope control',
    Path('docs/examples/result-packets/rejected-missing-approval-status.md'):
        'missing approval-gate status',
}
for packet, expected_error in rejected_packets.items():
    fixture_errors = validate_result_packet_fixture(packet)
    if expected_error not in fixture_errors:
        errors.append(
            f'{packet} did not fail for expected reason: {expected_error}; '
            + 'actual: '
            + ('; '.join(fixture_errors) if fixture_errors else 'no validation errors')
        )

accepted_replay = Path('docs/examples/replays/accepted-manager-fire-hammer.md')
accepted_replay_errors = validate_replay_fixture(accepted_replay)
if accepted_replay_errors:
    errors.append(
        f'{accepted_replay} should pass replay validation: '
        + '; '.join(accepted_replay_errors)
    )

rejected_replays = {
    Path('docs/examples/replays/rejected-missing-dispatch-readiness.md'):
        'missing required section: ## Fire dispatch readiness',
    Path('docs/examples/replays/rejected-missing-approval-evidence.md'):
        'missing approval gate field: **Approval evidence:**',
    Path('docs/examples/replays/rejected-missing-worker-route-result-metadata.md'):
        'missing hammer result field: **Worker route metadata:**',
    Path('docs/examples/replays/rejected-missing-closeout-review-evidence.md'):
        'missing required section: ## Manager review and closeout',
}
for replay, expected_error in rejected_replays.items():
    fixture_errors = validate_replay_fixture(replay)
    if expected_error not in fixture_errors:
        errors.append(
            f'{replay} did not fail for expected reason: {expected_error}; '
            + 'actual: '
            + ('; '.join(fixture_errors) if fixture_errors else 'no validation errors')
        )

for path in [Path('ARCHITECTURE.md'), Path('WORKFLOW.md'), Path('docs/templates/worker-ticket.md')]:
    if 'later policy' in path.read_text() or 'later approved policy' in path.read_text():
        errors.append(f'approval exception wording should say later ADR: {path}')

for path in [Path('docs/contracts/manager-contract.md'), Path('docs/policies/authority-and-safety.md')]:
    text = path.read_text()
    if 'should issue' in text:
        errors.append(f'credential broker requirement is weak in {path}')
    if 'should include' in text:
        errors.append(f'result packet requirement is weak in {path}')

if errors:
    for error in errors:
        print('FAIL ' + error, file=sys.stderr)
    sys.exit(1)
PY

bash scripts/validate-readiness-criteria.sh >/dev/null
bash scripts/validate-carbon-ui-baseline.sh >/dev/null
bash scripts/validate-credential-lifecycle.sh >/dev/null
bash scripts/validate-credential-revocation-drill.sh >/dev/null
bash scripts/validate-security-threat-model.sh >/dev/null
bash scripts/validate-multi-tenant-rbac.sh >/dev/null
bash scripts/validate-multi-tenant-rbac-drill.sh >/dev/null
bash scripts/validate-dispatch-lease-recovery.sh >/dev/null
bash scripts/validate-orchestration-recovery-gate.sh >/dev/null
bash scripts/validate-sre-operating-baseline.sh >/dev/null
bash scripts/validate-incident-response-runbook.sh >/dev/null
bash scripts/validate-service-level-objectives.sh >/dev/null
bash scripts/validate-central-metrics-backend.sh >/dev/null
bash scripts/validate-central-metrics-replay.sh >/dev/null
bash scripts/validate-on-call-paging-alerting.sh >/dev/null
bash scripts/validate-on-call-alert-routing-drill.sh >/dev/null
bash scripts/validate-onboarding-troubleshooting.sh >/dev/null
bash scripts/validate-release-rollback-capacity-drills.sh >/dev/null
bash scripts/validate-release-rollback-drill.sh >/dev/null
bash scripts/validate-topology-backup-restore-dr.sh >/dev/null
bash scripts/validate-backup-restore-drill.sh >/dev/null
bash scripts/validate-sandbox-restore-drill.sh >/dev/null
bash scripts/validate-compliance-package.sh >/dev/null
bash scripts/validate-compliance-audit-review.sh >/dev/null
bash scripts/validate-immutable-audit-export.sh >/dev/null
bash scripts/validate-immutable-audit-export-verification.sh >/dev/null
bash scripts/validate-signed-immutable-audit-export.sh >/dev/null
bash scripts/validate-runtime-quality-gates.sh >/dev/null

printf 'PASS Dokkaebi contract docs are present, linked, and structurally aligned\n'
