#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys

errors: list[str] = []

criteria_path = Path("docs/enterprise-readiness/criteria.json")
k8s_evidence_lock_path = Path("docs/enterprise-readiness/k8s-platformization-current-evidence.json")
k8s_fixture_coverage_path = Path("docs/enterprise-readiness/k8s-platformization-fixture-coverage.json")
scorecard_path = Path("docs/enterprise-readiness/project-scorecard.md")
loop_path = Path("docs/enterprise-readiness/development-loop.md")
readme_path = Path("README.md")
workflow_path = Path(".github/workflows/dokkaebi-governance.yml")

for path in [
    criteria_path,
    k8s_evidence_lock_path,
    k8s_fixture_coverage_path,
    scorecard_path,
    loop_path,
    readme_path,
    workflow_path,
    Path("scripts/validate-all.sh"),
    Path("scripts/validate-readiness-criteria.sh"),
    Path("scripts/validate-k8s-platformization.sh"),
]:
    if not path.is_file():
        errors.append(f"missing file: {path}")

if not criteria_path.is_file():
    for error in errors:
        print(f"FAIL {error}", file=sys.stderr)
    sys.exit(1)

data = json.loads(criteria_path.read_text())


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


def parse_score_table(markdown: str, heading: str) -> dict[str, tuple[int, int]]:
    rows: dict[str, tuple[int, int]] = {}
    in_section = False
    for raw_line in markdown.splitlines():
        line = raw_line.strip()
        if line.startswith("## "):
            in_section = line == f"## {heading}"
            continue
        if not in_section or not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 2:
            continue
        item_id, score = cells[0], cells[1]
        if item_id in {"Area", "Capability"}:
            continue
        if all(char in "-: " for char in item_id) or all(char in "-: " for char in score):
            continue
        match = re.fullmatch(r"(\d{1,3})/(\d{1,3})", score)
        if not match:
            errors.append(f"{heading} row {item_id} score must use N/100: {score}")
            continue
        rows[item_id] = (int(match.group(1)), int(match.group(2)))
    return rows


def require_score_table(
    *,
    heading: str,
    actual: dict[str, tuple[int, int]],
    expected: dict[str, tuple[int, int]],
) -> None:
    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    if missing:
        errors.append(f"{heading} missing rows: {', '.join(missing)}")
    if extra:
        errors.append(f"{heading} has extra rows: {', '.join(extra)}")
    for item_id, expected_score in expected.items():
        actual_score = actual.get(item_id)
        if actual_score is not None and actual_score != expected_score:
            errors.append(
                f"{heading} score drift for {item_id}: "
                f"{actual_score[0]}/{actual_score[1]} != {expected_score[0]}/{expected_score[1]}"
            )


required_k8s_subcriteria = {
    "k8s_loop_contract": {"weight": 10, "currentPercent": 100},
    "k8s_base_controls_static": {"weight": 15, "currentPercent": 100},
    "k8s_admission_fixture_matrix": {"weight": 20, "currentPercent": 100},
    "k8s_accepted_route_profile_fixtures": {"weight": 15, "currentPercent": 100},
    "k8s_disposable_api_server_admission_rbac": {"weight": 10, "currentPercent": 100},
    "fire_k8s_deployment_runtime_smoke": {"weight": 10, "currentPercent": 80},
    "hammer_job_profile_runtime_smoke": {"weight": 10, "currentPercent": 100},
    "k8s_result_packet_reconciliation": {"weight": 5, "currentPercent": 80},
    "eks_identity_secret_boundary": {"weight": 5, "currentPercent": 0},
}


def validate_k8s_subcriteria(area: dict) -> dict[str, tuple[int, int]]:
    subcriteria = area.get("subCriteria")
    expected_scores: dict[str, tuple[int, int]] = {}
    if not isinstance(subcriteria, list) or not subcriteria:
        errors.append("k8s_platformization must define granular subCriteria")
        return expected_scores
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
        if isinstance(current, int) and isinstance(target, int):
            expected_scores[item_id] = (current, target)
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
    return expected_scores


required_k8s_issues = {
    "Define K8S admission policy gate for Hammer Jobs": "docs/enterprise-readiness/k8s-platformization-issues.md#k8s-admission-policy-gate",
    "Package Fire Deployment smoke with least-privilege Job orchestration": "docs/enterprise-readiness/k8s-platformization-issues.md#fire-k8s-deployment-smoke",
    "Prove Hammer Job profile smoke and route-result metadata": "docs/enterprise-readiness/k8s-platformization-issues.md#hammer-job-profile-smoke",
    "Define K8S result packet and GitHub lifecycle reconciliation": "docs/enterprise-readiness/k8s-platformization-issues.md#k8s-result-packet-reconciliation",
    "Decide EKS workload identity and Secret boundary": "docs/enterprise-readiness/k8s-platformization-issues.md#eks-identity-and-secret-boundary",
}

areas = [area for area in data.get("areas", []) if isinstance(area, dict)]
if not areas:
    errors.append("scorecard requires at least one readiness area")

for area in areas:
    area_id = area.get("id", "<missing>")
    target = area.get("targetPercent")
    current = area.get("currentPercent")
    if target != 100:
        errors.append(f"{area_id} targetPercent must be 100")
    if not isinstance(current, int) or not 0 <= current <= 100:
        errors.append(f"{area_id} currentPercent must be an integer from 0 to 100")
        continue
    if current < 100:
        if not area.get("gaps"):
            errors.append(f"{area_id} below 100 must name gaps")
        if not area.get("nextIssues"):
            errors.append(f"{area_id} below 100 must publish nextIssues")
    if current == 100 and area.get("gaps"):
        errors.append(f"{area_id} scored 100 must not retain open gaps")

k8s_area = next((area for area in areas if area.get("id") == "k8s_platformization"), None)
k8s_subcriteria_scores: dict[str, tuple[int, int]] = {}
if not k8s_area:
    errors.append("missing k8s_platformization area")
else:
    if k8s_area.get("currentPercent") == 100:
        errors.append("k8s_platformization must not be scored 100 before live or approved-sandbox runtime evidence")
    k8s_subcriteria_scores = validate_k8s_subcriteria(k8s_area)
    actual_issues = {
        issue.get("title"): issue.get("issueBodyPath")
        for issue in k8s_area.get("nextIssues", [])
        if isinstance(issue, dict)
    }
    for title, anchor in required_k8s_issues.items():
        if actual_issues.get(title) != anchor:
            errors.append(f"k8s_platformization issue drift: {title} must point to {anchor}")
    require_exact_k8s_current_evidence(k8s_area)
    for evidence_path in k8s_area.get("currentEvidence", []):
        if not isinstance(evidence_path, str) or evidence_path.startswith("https://"):
            continue
        if not evidence_path_exists(evidence_path):
            errors.append(f"k8s_platformization currentEvidence path does not exist: {evidence_path}")

for capability in data.get("criticalCapabilities", []):
    if not isinstance(capability, dict):
        continue
    capability_id = capability.get("id", "<missing>")
    target = capability.get("targetPercent")
    current = capability.get("currentPercent")
    if target != 100:
        errors.append(f"{capability_id} targetPercent must be 100")
    if not isinstance(current, int) or not 0 <= current <= 100:
        errors.append(f"{capability_id} currentPercent must be an integer from 0 to 100")
    if isinstance(current, int) and current < 100:
        for field in ["acceptanceCriteria", "validationRequired", "authorityRequirement", "resultEvidence"]:
            if not capability.get(field):
                errors.append(f"{capability_id} below 100 missing {field}")

if scorecard_path.is_file():
    scorecard_text = scorecard_path.read_text()
    for required_text in [
        "Program Scorecard",
        "100-point loop",
        "k8s_platformization",
        "scripts/validate-enterprise-scorecard.sh",
        "scripts/validate-all.sh",
        "k8s-platformization-current-evidence.json",
        "k8s-platformization-fixture-coverage.json",
        "K8S Sub-Capability Scores",
        "k8s-admission-policy-gate",
        "Critical Capability Scores",
        "scorecard table must match criteria.json",
        "`hammer-no-k8s` token override",
        "fire-k8s-deployment-smoke",
        "hammer-job-profile-smoke",
        "k8s-result-packet-reconciliation",
        "eks-identity-and-secret-boundary",
        "must not mark a score 100",
    ]:
        if required_text not in scorecard_text:
            errors.append(f"project scorecard missing text: {required_text}")
    area_scores = parse_score_table(scorecard_text, "Current Program Scores")
    expected_area_scores = {
        str(area["id"]): (int(area["currentPercent"]), int(area["targetPercent"]))
        for area in areas
        if isinstance(area.get("id"), str)
        and isinstance(area.get("currentPercent"), int)
        and isinstance(area.get("targetPercent"), int)
    }
    require_score_table(
        heading="Current Program Scores",
        actual=area_scores,
        expected=expected_area_scores,
    )
    capabilities = [
        capability
        for capability in data.get("criticalCapabilities", [])
        if isinstance(capability, dict)
    ]
    capability_scores = parse_score_table(scorecard_text, "Critical Capability Scores")
    expected_capability_scores = {
        str(capability["id"]): (
            int(capability["currentPercent"]),
            int(capability["targetPercent"]),
        )
        for capability in capabilities
        if isinstance(capability.get("id"), str)
        and isinstance(capability.get("currentPercent"), int)
        and isinstance(capability.get("targetPercent"), int)
    }
    require_score_table(
        heading="Critical Capability Scores",
        actual=capability_scores,
        expected=expected_capability_scores,
    )
    k8s_subcriteria_rows = parse_score_table(scorecard_text, "K8S Sub-Capability Scores")
    require_score_table(
        heading="K8S Sub-Capability Scores",
        actual=k8s_subcriteria_rows,
        expected=k8s_subcriteria_scores,
    )

for path, required_commands in {
    loop_path: [
        "bash scripts/validate-enterprise-scorecard.sh",
        "bash scripts/validate-all.sh",
    ],
    readme_path: [
        "bash scripts/validate-enterprise-scorecard.sh",
        "bash scripts/validate-all.sh",
    ],
    workflow_path: [
        "bash scripts/validate-enterprise-scorecard.sh",
        "bash scripts/validate-all.sh",
    ],
}.items():
    if not path.is_file():
        continue
    text = path.read_text()
    for command in required_commands:
        if command not in text:
            errors.append(f"{path} missing command: {command}")

if errors:
    for error in errors:
        print("FAIL " + error, file=sys.stderr)
    sys.exit(1)

print("PASS Dokkaebi enterprise scorecard loop is fail-closed and evidence-bound")
PY
