#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys

criteria_path = Path(
    os.environ.get("READINESS_CRITERIA_PATH", "docs/enterprise-readiness/criteria.json")
)
k8s_evidence_lock_path = Path("docs/enterprise-readiness/k8s-platformization-current-evidence.json")
k8s_fixture_coverage_path = Path("docs/enterprise-readiness/k8s-platformization-fixture-coverage.json")
report_path = Path("docs/reports/company-readiness-assessment.md")
loop_path = Path("docs/enterprise-readiness/development-loop.md")
issue_form_path = Path(".github/ISSUE_TEMPLATE/development-system-task.yml")
issue_config_path = Path(".github/ISSUE_TEMPLATE/config.yml")

errors: list[str] = []

for path in [
    criteria_path,
    k8s_evidence_lock_path,
    k8s_fixture_coverage_path,
    report_path,
    loop_path,
    issue_form_path,
    issue_config_path,
]:
    if not path.is_file():
        errors.append(f"missing file: {path}")

if not criteria_path.is_file():
    for error in errors:
        print(f"FAIL {error}", file=sys.stderr)
    sys.exit(1)

try:
    data = json.loads(criteria_path.read_text())
except json.JSONDecodeError as exc:
    print(f"FAIL invalid JSON in {criteria_path}: {exc}", file=sys.stderr)
    sys.exit(1)


def load_k8s_current_evidence_lock() -> list[str]:
    if not k8s_evidence_lock_path.is_file():
        return []
    try:
        lock = json.loads(k8s_evidence_lock_path.read_text())
    except json.JSONDecodeError as exc:
        errors.append(f"invalid JSON in {k8s_evidence_lock_path}: {exc}")
        return []
    if lock.get("areaId") != "k8s_platformization":
        errors.append(f"{k8s_evidence_lock_path} areaId must be k8s_platformization")
    evidence = lock.get("currentEvidence")
    if not isinstance(evidence, list):
        errors.append(f"{k8s_evidence_lock_path} currentEvidence must be a list")
        return []
    invalid = [repr(item) for item in evidence if not isinstance(item, str) or not item]
    if invalid:
        errors.append(f"{k8s_evidence_lock_path} has invalid currentEvidence entries: {', '.join(invalid)}")
    return [item for item in evidence if isinstance(item, str)]


def require_exact_k8s_current_evidence(area: dict) -> None:
    expected = load_k8s_current_evidence_lock()
    actual = area.get("currentEvidence")
    if not isinstance(actual, list):
        errors.append("k8s_platformization currentEvidence must be a list")
        return
    actual_strings = [item for item in actual if isinstance(item, str)]
    if actual != actual_strings:
        errors.append("k8s_platformization currentEvidence entries must all be strings")
    if actual_strings == expected:
        return
    missing = [item for item in expected if item not in actual_strings]
    extra = [item for item in actual_strings if item not in expected]
    if missing:
        errors.append("k8s_platformization currentEvidence missing locked entries: " + ", ".join(missing))
    if extra:
        errors.append("k8s_platformization currentEvidence has unlocked entries: " + ", ".join(extra))
    if not missing and not extra:
        errors.append("k8s_platformization currentEvidence order must match k8s evidence lock")


def submodule_gitlink_exists(path: str) -> bool:
    try:
        result = subprocess.run(
            ["git", "ls-files", "--stage", path],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return False
    return result.stdout.startswith("160000 ")


def evidence_path_exists(evidence_path: str) -> bool:
    if Path(evidence_path).exists():
        return True
    submodule_root = "symphony-github-project-tracker"
    return (
        evidence_path.startswith(submodule_root + "/")
        and submodule_gitlink_exists(submodule_root)
    )


required_k8s_subcriteria = {
    "k8s_loop_contract": {"weight": 10, "currentPercent": 100},
    "k8s_base_controls_static": {"weight": 15, "currentPercent": 100},
    "k8s_admission_fixture_matrix": {"weight": 20, "currentPercent": 100},
    "k8s_accepted_route_profile_fixtures": {"weight": 15, "currentPercent": 100},
    "k8s_disposable_api_server_admission_rbac": {"weight": 10, "currentPercent": 100},
    "fire_k8s_deployment_runtime_smoke": {"weight": 10, "currentPercent": 0},
    "hammer_job_profile_runtime_smoke": {"weight": 10, "currentPercent": 0},
    "k8s_result_packet_reconciliation": {"weight": 5, "currentPercent": 40},
    "eks_identity_secret_boundary": {"weight": 5, "currentPercent": 0},
}


def validate_k8s_subcriteria(area: dict) -> None:
    subcriteria = area.get("subCriteria")
    if not isinstance(subcriteria, list) or not subcriteria:
        errors.append("k8s_platformization must define granular subCriteria")
        return
    by_id = {
        item.get("id"): item
        for item in subcriteria
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    missing = sorted(set(required_k8s_subcriteria) - set(by_id))
    extra = sorted(set(by_id) - set(required_k8s_subcriteria))
    if missing:
        errors.append("k8s_platformization subCriteria missing ids: " + ", ".join(missing))
    if extra:
        errors.append("k8s_platformization subCriteria has extra ids: " + ", ".join(extra))
    total_weight = 0
    weighted_score = 0.0
    for item_id, expected in required_k8s_subcriteria.items():
        item = by_id.get(item_id)
        if not item:
            continue
        weight = item.get("weight")
        current = item.get("currentPercent")
        target = item.get("targetPercent")
        total_weight += int(weight) if isinstance(weight, int) else 0
        if weight != expected["weight"]:
            errors.append(f"{item_id} weight must be {expected['weight']}")
        if current != expected["currentPercent"]:
            errors.append(f"{item_id} currentPercent must be {expected['currentPercent']}")
        if target != 100:
            errors.append(f"{item_id} targetPercent must be 100")
        if isinstance(weight, int) and isinstance(current, int):
            weighted_score += weight * current / 100
        evidence_paths = item.get("currentEvidence")
        if not isinstance(evidence_paths, list):
            errors.append(f"{item_id} currentEvidence must be a list")
        elif current != 0 and not evidence_paths:
            errors.append(f"{item_id} currentEvidence must be non-empty for non-zero progress")
        else:
            for evidence_path in evidence_paths:
                if not isinstance(evidence_path, str) or not evidence_path_exists(evidence_path):
                    errors.append(f"{item_id} currentEvidence path does not exist: {evidence_path}")
        gaps = item.get("gaps")
        if current == 100:
            if gaps:
                errors.append(f"{item_id} scored 100 must not retain open gaps")
        else:
            if not isinstance(gaps, list) or not gaps:
                errors.append(f"{item_id} below 100 must list gaps")
            if not item.get("nextIssueTitle"):
                errors.append(f"{item_id} below 100 must name nextIssueTitle")
    if total_weight != 100:
        errors.append(f"k8s_platformization subCriteria weights must sum to 100, got {total_weight}")
    expected_area_score = round(weighted_score)
    if area.get("currentPercent") != expected_area_score:
        errors.append(
            f"k8s_platformization currentPercent must equal weighted subCriteria score {expected_area_score}"
        )

required_top = {
    "version",
    "updated",
    "sourceReports",
    "designStandards",
    "scoringScale",
    "workflow",
    "areas",
    "criticalCapabilities",
}
missing_top = sorted(required_top - data.keys())
if missing_top:
    errors.append(f"criteria missing top-level keys: {', '.join(missing_top)}")

source_reports = data.get("sourceReports", [])
if "docs/reports/company-readiness-assessment.md" not in source_reports:
    errors.append("criteria must cite docs/reports/company-readiness-assessment.md")

carbon_url = "https://carbondesignsystem.com/elements/color/overview/"
design_standards = data.get("designStandards", [])
if not any(item.get("url") == carbon_url for item in design_standards if isinstance(item, dict)):
    errors.append("criteria must cite Carbon Design System color overview")

workflow = data.get("workflow", {})
for key in [
    "sourceOfTruth",
    "phaseModel",
    "issueContract",
    "worktreeContract",
    "pullRequestContract",
    "mergeContract",
    "evaluationLoop",
    "selfImprovementContract",
    "improvementTriggers",
    "improvementEvidence",
]:
    if not workflow.get(key):
        errors.append(f"workflow missing {key}")
for key in ["improvementTriggers", "improvementEvidence"]:
    value = workflow.get(key)
    if not isinstance(value, list) or len(value) < 3:
        errors.append(f"workflow {key} must list at least three items")

if loop_path.is_file():
    loop_text = loop_path.read_text()
    for required_text in [
        "## Self-Improvement Contract",
        "Capture RED evidence",
        "must not use self-improvement to bypass Human approval",
    ]:
        if required_text not in loop_text:
            errors.append(f"development loop missing self-improvement text: {required_text}")

areas = data.get("areas", [])
if not isinstance(areas, list) or not areas:
    errors.append("areas must be a non-empty list")
else:
    expected_area_ids = {
        "architecture_contracts",
        "core_orchestration",
        "infrastructure_platform",
        "development_quality",
        "security_authority",
        "management_governance",
        "logging_observability",
        "operations_sre",
        "compliance_audit",
        "productization_ux",
        "design_system",
        "k8s_platformization",
    }
    seen = set()
    for area in areas:
        area_id = area.get("id")
        if not area_id:
            errors.append("area missing id")
            continue
        if area_id in seen:
            errors.append(f"duplicate area id: {area_id}")
        seen.add(area_id)
        if area.get("targetPercent") != 100:
            errors.append(f"{area_id} targetPercent must be 100")
        current = area.get("currentPercent")
        if not isinstance(current, int) or current < 0 or current > 100:
            errors.append(f"{area_id} currentPercent must be an integer from 0 to 100")
        for field in [
            "enterpriseStandard",
            "currentEvidence",
            "evaluationQuestions",
            "evidenceRequired",
        ]:
            value = area.get(field)
            if value in (None, "", []):
                errors.append(f"{area_id} missing {field}")

        for evidence_path in area.get("currentEvidence", []):
            if not isinstance(evidence_path, str) or evidence_path.startswith("https://"):
                continue
            if not evidence_path_exists(evidence_path):
                errors.append(f"{area_id} currentEvidence path does not exist: {evidence_path}")

        gaps = area.get("gaps")
        if not isinstance(gaps, list):
            errors.append(f"{area_id} gaps must be a list")
        elif current < area.get("targetPercent", 100) and not gaps:
            errors.append(f"{area_id} missing gaps")

        next_issues = area.get("nextIssues")
        if not isinstance(next_issues, list):
            errors.append(f"{area_id} nextIssues must be a list")
        elif current < area.get("targetPercent", 100) and not next_issues:
            errors.append(f"{area_id} missing nextIssues")

        for issue in area.get("nextIssues", []):
            if not issue.get("title"):
                errors.append(f"{area_id} has issue without title")
            issue_url = issue.get("githubIssueUrl", "")
            if not issue_url.startswith("https://github.com/"):
                errors.append(f"{area_id} has issue without githubIssueUrl")
            if not issue.get("acceptanceCriteria"):
                errors.append(f"{area_id} has issue without acceptanceCriteria")
            if not issue.get("validationRequired"):
                errors.append(f"{area_id} has issue without validationRequired")
            if not issue.get("authorityRequirement"):
                errors.append(f"{area_id} has issue without authorityRequirement")
            if not issue.get("resultEvidence"):
                errors.append(f"{area_id} has issue without resultEvidence")

            if area_id == "k8s_platformization":
                if issue.get("publicationStatus") != "candidate-not-published":
                    errors.append(f"{area_id} issue must be candidate-not-published")
                issue_body_path = issue.get("issueBodyPath", "")
                if not issue_body_path.startswith("docs/enterprise-readiness/k8s-platformization-issues.md#"):
                    errors.append(f"{area_id} issue missing k8s issueBodyPath anchor")
                if "bash scripts/validate-k8s-platformization.sh" not in issue.get("validationRequired", []):
                    errors.append(f"{area_id} issue missing validate-k8s-platformization.sh")
                if "explicit Human approval" not in issue.get("authorityRequirement", ""):
                    errors.append(f"{area_id} issue weakens Human approval boundary")

        if area_id == "k8s_platformization":
            require_exact_k8s_current_evidence(area)
            validate_k8s_subcriteria(area)
            if len(area.get("nextIssues", [])) < 5:
                errors.append(f"{area_id} must publish at least five nextIssues")
            required_issue_anchors = {
                "Define K8S admission policy gate for Hammer Jobs": "docs/enterprise-readiness/k8s-platformization-issues.md#k8s-admission-policy-gate",
                "Package Fire Deployment smoke with least-privilege Job orchestration": "docs/enterprise-readiness/k8s-platformization-issues.md#fire-k8s-deployment-smoke",
                "Prove Hammer Job profile smoke and route-result metadata": "docs/enterprise-readiness/k8s-platformization-issues.md#hammer-job-profile-smoke",
                "Define K8S result packet and GitHub lifecycle reconciliation": "docs/enterprise-readiness/k8s-platformization-issues.md#k8s-result-packet-reconciliation",
                "Decide EKS workload identity and Secret boundary": "docs/enterprise-readiness/k8s-platformization-issues.md#eks-identity-and-secret-boundary",
            }
            actual_issue_anchors = {
                issue.get("title"): issue.get("issueBodyPath")
                for issue in area.get("nextIssues", [])
                if isinstance(issue, dict)
            }
            for title, anchor in required_issue_anchors.items():
                if actual_issue_anchors.get(title) != anchor:
                    errors.append(f"{area_id} issue drift: {title} must point to {anchor}")

    missing_area_ids = sorted(expected_area_ids - seen)
    if missing_area_ids:
        errors.append(f"missing area ids: {', '.join(missing_area_ids)}")

critical_capabilities = data.get("criticalCapabilities", [])
expected_capability_ids = {
    "incident_response",
    "on_call_paging_alerting",
    "slo_sla",
    "backup_restore_dr",
    "compliance_package",
    "production_release_rollback_runbook",
    "central_metrics_backend",
    "immutable_audit_export",
    "multi_tenant_rbac",
}
seen_capability_ids = {
    item.get("id")
    for item in critical_capabilities
    if isinstance(item, dict) and item.get("id")
}
missing_capability_ids = sorted(expected_capability_ids - seen_capability_ids)
if missing_capability_ids:
    errors.append(f"missing critical capability ids: {', '.join(missing_capability_ids)}")
for item in critical_capabilities:
    current = item.get("currentPercent")
    if not isinstance(current, int) or current < 0 or current > 100:
        errors.append(f"{item.get('id', '<missing>')} currentPercent must be an integer from 0 to 100")
    if item.get("targetPercent") != 100:
        errors.append(f"{item.get('id', '<missing>')} targetPercent must be 100")
    issue_url = item.get("githubIssueUrl", "")
    if not issue_url.startswith("https://github.com/"):
        errors.append(f"{item.get('id', '<missing>')} missing githubIssueUrl")
    for field in ["acceptanceCriteria", "validationRequired", "authorityRequirement", "resultEvidence"]:
        if item.get(field) in (None, "", []):
            errors.append(f"{item.get('id', '<missing>')} missing {field}")

try:
    import yaml
except ImportError as exc:
    errors.append(f"PyYAML is required to validate GitHub issue forms: {exc}")
else:
    if issue_form_path.is_file():
        form = yaml.safe_load(issue_form_path.read_text())
        body = form.get("body", []) if isinstance(form, dict) else []
        ids = {
            item.get("id")
            for item in body
            if isinstance(item, dict) and item.get("id")
        }
        required_form_ids = {
            "goal",
            "scope",
            "criteria_ids",
            "acceptance_criteria",
            "validation",
            "permission_level",
            "approval_gates",
            "manual_qa_channel",
            "enterprise_readiness",
            "carbon_baseline",
            "metadata_hygiene",
            "result_packet",
        }
        missing_form_ids = sorted(required_form_ids - ids)
        if missing_form_ids:
            errors.append(f"development-system issue form missing ids: {', '.join(missing_form_ids)}")
        if issue_config_path.is_file():
            config = yaml.safe_load(issue_config_path.read_text())
            if config.get("blank_issues_enabled") is not False:
                errors.append("GitHub issue template config must disable blank issues")
        lowered = issue_form_path.read_text().lower()
        for forbidden in ["o" + "mo", "o" + "mx", "cod" + "ex/"]:
            if forbidden in lowered:
                errors.append(f"development-system issue form contains forbidden public metadata term: {forbidden}")

if errors:
    for error in errors:
        print(f"FAIL {error}", file=sys.stderr)
    sys.exit(1)

print("PASS Dokkaebi enterprise readiness criteria are present and structurally valid")
PY
