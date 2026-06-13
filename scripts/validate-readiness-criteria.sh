#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import json
import os
from pathlib import Path
import sys

criteria_path = Path(
    os.environ.get("READINESS_CRITERIA_PATH", "docs/enterprise-readiness/criteria.json")
)
report_path = Path("docs/reports/company-readiness-assessment.md")
loop_path = Path("docs/enterprise-readiness/development-loop.md")
issue_form_path = Path(".github/ISSUE_TEMPLATE/development-system-task.yml")
issue_config_path = Path(".github/ISSUE_TEMPLATE/config.yml")

errors: list[str] = []

for path in [criteria_path, report_path, loop_path, issue_form_path, issue_config_path]:
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
