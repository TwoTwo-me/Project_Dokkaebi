#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    print(f"FAIL PyYAML is required to validate K8S E2E evidence: {exc}", file=sys.stderr)
    sys.exit(1)

errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def require_file(path: str) -> Path:
    p = Path(path)
    require(p.is_file(), f"missing file: {path}")
    return p


readme = require_file(os.environ.get("README_PATH", "README.md"))
usage = require_file(os.environ.get("K8S_BEGINNER_USAGE_PATH", "docs/operations/k8s-platform-usage.md"))
e2e_doc = require_file("docs/operations/k8s-platform-e2e-2026-06-21.md")
identity_adr = require_file("docs/adr/0003-k8s-identity-secret-boundary.md")
runner = require_file("scripts/run-k8s-platform-e2e.sh")

for script in [runner, require_file("scripts/validate-k8s-platform-e2e.sh")]:
    require(script.stat().st_mode & 0o111 != 0, f"{script} must be executable")

readme_text = readme.read_text(encoding="utf-8")
for term in [
    "Project Dokkaebi K8S",
    "Kubernetes platformization",
    "LiteLLM",
    "Grafana",
    "scripts/run-k8s-platform-e2e.sh",
    "docs/operations/k8s-platform-usage.md",
]:
    require(term in readme_text, f"README.md missing text: {term}")

usage_text = usage.read_text(encoding="utf-8")
for term in [
    "First Validation",
    "DOKKAEBI_K8S_E2E_EVIDENCE_DIR",
    "LiteLLM And GPT/OAuth Boundary",
    "Grafana And Prometheus",
    "Blue-Green Migration",
    "EKS Overlay",
    "Troubleshooting",
    "Required Closeout Evidence",
    "DOKKAEBI_LITELLM_VIRTUAL_KEY",
    "DOKKAEBI_K8S_E2E_RUNTIME=require",
    "not enough to claim the 100-point",
    "litellm-chatgpt-homelab-gateway.md",
    "port-forward -n dokkaebi-observability svc/grafana",
]:
    require(term in usage_text, f"{usage} missing text: {term}")

e2e_text = e2e_doc.read_text(encoding="utf-8")
for term in [
    "PASS Dokkaebi K8S platform E2E completed",
    "fire_k8s_deployment_runtime_smoke` | 100/100",
    "k8s_result_packet_reconciliation` | 100/100",
    "eks_identity_secret_boundary` | 100/100",
    "k8s_platformization` | 100/100",
    "does not authorize live AWS",
    "approved local/sandbox E2E gate",
    "runtime_mode=require",
    "PASS validate-k8s-result-reconciliation",
    "PASS k8s-runtime-smoke",
    "PASS litellm-chatgpt-k8s-smoke",
    "PASS Dokkaebi K8S platform static E2E completed",
    "litellm_virtual_key_secret_created_by_broker",
    "hammer_litellm_virtual_key_self_spoof_denied",
    "cleanup_kind_cluster=dokkaebi-runtime-smoke deleted",
    "cleanup_kind_cluster=dokkaebi-litellm-smoke deleted",
]:
    require(term in e2e_text, f"{e2e_doc} missing text: {term}")

adr_text = identity_adr.read_text(encoding="utf-8")
for term in [
    "EKS Pod Identity or IRSA",
    "Hammer ServiceAccounts do not receive AWS workload identity annotations by default",
    "request user is Fire",
    "live apply must fail closed",
    "provider API keys",
    "ChatGPT OAuth",
]:
    require(term in adr_text, f"{identity_adr} missing text: {term}")

runner_text = runner.read_text(encoding="utf-8")
for term in [
    "validate-k8s-platformization.sh",
    "validate-k8s-litellm-grafana-platform.sh",
    "validate-k8s-result-reconciliation.sh",
    "validate-k8s-platform-e2e.sh",
    "validate-all.sh",
    "run-k8s-runtime-smoke.sh",
    "run-litellm-chatgpt-k8s-smoke.sh",
    "DOKKAEBI_SKIP_RUNTIME_SMOKE",
    "DOKKAEBI_SKIP_LITELLM_RUNTIME_SMOKE",
    "PASS Dokkaebi K8S platform E2E completed",
    "PASS Dokkaebi K8S platform static E2E completed",
    "scorecard_100_point_claim=not_allowed_without_required_runtime_smokes",
]:
    require(term in runner_text, f"{runner} missing text: {term}")

criteria = json.loads(require_file(os.environ.get("READINESS_CRITERIA_PATH", "docs/enterprise-readiness/criteria.json")).read_text(encoding="utf-8"))
k8s_area = next((area for area in criteria.get("areas", []) if area.get("id") == "k8s_platformization"), None)
require(isinstance(k8s_area, dict), "criteria.json missing k8s_platformization")
if isinstance(k8s_area, dict):
    require(k8s_area.get("currentPercent") == 100, "k8s_platformization currentPercent must be 100")
    require(not k8s_area.get("gaps"), "k8s_platformization scored 100 must not retain gaps")
    evidence = k8s_area.get("currentEvidence", [])
    for path in [
        "docs/adr/0003-k8s-identity-secret-boundary.md",
        "docs/operations/k8s-platform-usage.md",
        "docs/operations/k8s-platform-e2e-2026-06-21.md",
        "scripts/run-k8s-platform-e2e.sh",
        "scripts/validate-k8s-platform-e2e.sh",
        "docs/enterprise-readiness/k8s-result-reconciliation-matrix.json",
        "scripts/validate-k8s-result-reconciliation.sh",
        "scripts/run-litellm-chatgpt-k8s-smoke.sh",
    ]:
        require(path in evidence, f"k8s_platformization currentEvidence missing {path}")
    subcriteria = {
        item.get("id"): item
        for item in k8s_area.get("subCriteria", [])
        if isinstance(item, dict)
    }
    for sub_id in [
        "fire_k8s_deployment_runtime_smoke",
        "k8s_result_packet_reconciliation",
        "eks_identity_secret_boundary",
    ]:
        item = subcriteria.get(sub_id)
        require(isinstance(item, dict), f"k8s subcriterion missing {sub_id}")
        if isinstance(item, dict):
            require(item.get("currentPercent") == 100, f"{sub_id} currentPercent must be 100")
            require(not item.get("gaps"), f"{sub_id} scored 100 must not retain gaps")
            require(item.get("nextIssueTitle") is None, f"{sub_id} scored 100 must not name nextIssueTitle")
    reconciliation = subcriteria.get("k8s_result_packet_reconciliation", {})
    if isinstance(reconciliation, dict):
        for path in [
            "docs/enterprise-readiness/k8s-result-reconciliation-matrix.json",
            "scripts/validate-k8s-result-reconciliation.sh",
        ]:
            require(path in reconciliation.get("currentEvidence", []), f"k8s_result_packet_reconciliation currentEvidence missing {path}")

scorecard = require_file("docs/enterprise-readiness/project-scorecard.md").read_text(encoding="utf-8")
for term in [
    "| k8s_platformization | 100/100 |",
    "| fire_k8s_deployment_runtime_smoke | 100/100 |",
    "| k8s_result_packet_reconciliation | 100/100 |",
    "| eks_identity_secret_boundary | 100/100 |",
    "Repository-Owned K8S Continuous Improvement Gates",
    "approved local/sandbox runtime evidence",
]:
    require(term in scorecard, f"project-scorecard.md missing text: {term}")
require("must not mark a score 100 until" not in scorecard, "project-scorecard.md still contains stale 92-point gate wording")

evidence_lock = json.loads(require_file("docs/enterprise-readiness/k8s-platformization-current-evidence.json").read_text(encoding="utf-8"))
locked = evidence_lock.get("currentEvidence", [])
if isinstance(k8s_area, dict):
    require(locked == k8s_area.get("currentEvidence"), "K8S evidence lock must exactly match criteria currentEvidence")

eks_overlay = yaml.safe_load(require_file("k8s/overlays/eks/kustomization.yaml").read_text(encoding="utf-8"))
overlay_text = Path("k8s/overlays/eks/kustomization.yaml").read_text(encoding="utf-8")
require(isinstance(eks_overlay, dict), "EKS overlay kustomization must be YAML mapping")
for term in [
    "eks.amazonaws.com/role-arn",
    "REPLACE_WITH_APPROVED_EKS_FIRE_ROLE_ARN",
    "REPLACE_WITH_APPROVED_EKS_LITELLM_ROLE_ARN",
    "explicit-human-approved-aws-iam-and-eks",
]:
    require(term in overlay_text, f"EKS overlay missing identity boundary term: {term}")
require("hammer-" not in re.sub(r"hammer ServiceAccounts", "", overlay_text), "EKS overlay must not assign workload identity to Hammer ServiceAccounts")

if errors:
    for error in errors:
        print("FAIL " + error, file=sys.stderr)
    sys.exit(1)

print("PASS Dokkaebi K8S platform E2E documentation and score evidence are valid")
PY
