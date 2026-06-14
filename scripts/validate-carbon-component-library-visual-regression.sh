#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

DOC_PATH="${CARBON_COMPONENT_VISUAL_PATH:-docs/design/carbon-component-library-visual-regression.md}"

[[ -f "$DOC_PATH" ]] || fail "missing file: $DOC_PATH"

for term in \
  "component inventory" \
  "Carbon token inventory" \
  "CI visual regression" \
  "artifact capture" \
  "desktop viewport" \
  "mobile viewport" \
  "contrast coverage" \
  "focus" \
  "hover" \
  "selected" \
  "active" \
  "disabled" \
  "error" \
  "warning" \
  "success" \
  "status" \
  "data elements" \
  "cross-browser" \
  "approval-gate status" \
  "cleanup receipt" \
  "residual risk" \
  "next action"; do
  grep -Fqi -- "$term" "$DOC_PATH" || fail "missing text in $DOC_PATH: $term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import hashlib
import json
import re
import struct
import subprocess
import sys
from pathlib import Path
from typing import Any

START = "<!-- carbon-component-library-visual-regression:begin -->"
END = "<!-- carbon-component-library-visual-regression:end -->"
REQUIRED_TOP = [
    "version",
    "issueUrl",
    "permissionLevel",
    "sourceBaseline",
    "dashboardProof",
    "componentInventory",
    "stateCoverage",
    "visualRegressionGate",
    "contrastCoverage",
    "crossBrowserCoverage",
    "validationOutput",
    "approvalGateStatus",
    "cleanupReceipt",
    "residualRisk",
    "nextAction",
    "followUpIssueUrl",
]
REQUIRED_COMPONENTS = {
    "app-shell-navigation",
    "work-queue-table",
    "issue-intake-form",
    "approval-gate-panel",
    "worker-route-picker",
    "result-packet-review",
    "evidence-package-viewer",
    "metrics-dashboard",
    "alert-incident-banner",
    "settings-credential-summary",
    "overlay-surfaces",
}
REQUIRED_STATES = {
    "default",
    "hover",
    "selected",
    "active",
    "focus",
    "disabled",
    "error",
    "warning",
    "success",
    "status",
    "data elements",
}
REQUIRED_TOKEN_TERMS = {
    "$background",
    "$layer",
    "$field",
    "$border-subtle",
    "$border-strong",
    "$text-primary",
    "$text-secondary",
    "$link-primary",
    "$icon-primary",
    "$focus",
    "$support-error",
    "$support-warning",
    "$support-success",
    "$support-info",
    "$overlay",
}
REQUIRED_CONTRAST_CHECKS = {
    "text-primary-on-background",
    "focus-on-layer",
    "button-primary-text",
    "disabled-control-text",
    "success-status-border",
    "warning-status-text",
    "error-status-text",
    "token-meter-fill",
    "table-border",
    "mobile-card-border",
}
COMMANDS = [
    "bash scripts/validate-carbon-component-library-visual-regression.sh: PASS",
    "bash scripts/validate-carbon-ui-baseline.sh: PASS",
    "root-retained dashboard artifact hashes: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS",
    "bash scripts/validate-git-governance.sh: PASS",
]
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "Users" + "/"
PRIVATE_PATH_RE = re.compile(
    r"(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+",
    re.IGNORECASE,
)
SECRET_TERMS = ["cookie=", "private_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer"]
SECRET_PATTERNS = [
    ("github classic access key", r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"),
    ("github fine-grained access key", r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    ("cloud access key", r"\bA[KS]IA[A-Z0-9]{16}\b"),
]
UNSAFE_PATTERNS = [
    r"\bproduction\s+(deploy|deployment|release|rollback|write)\s+(succeeded|completed|executed|started)\b",
    r"\bdocker\s+(compose\s+)?(up|run|start|started|created|executed|completed)\b",
    r"\bkubectl\s+(apply|create|delete|rollout|scale|set|patch)\b",
    r"\bremote\s+host\s+(was\s+)?(changed|updated|mutated|configured|restarted)\b",
    r"\bworker\s+dispatch\s+(was\s+)?(completed|started|executed|launched)\b",
    r"\bgithub\s+project\s+(setting|settings|field|fields|schema|control-plane)\s+(was\s+)?(changed|updated|mutated|created|deleted|completed)\b",
    r"\bcredential\s+(used|issued|granted|exported|rotated)\b",
    r"\binfrastructure\s+(mutated|changed|updated|created|deleted)\b",
    r"\bdeploy(ment)?\s+(can|may|will)\s+proceed\b",
    r"\bcredentials?\s+(are|is)?\s*authorized\b",
]


class CarbonComponentError(Exception):
    pass


def reject(message: str) -> None:
    raise CarbonComponentError(message)


def flatten(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [item for child in value for item in flatten(child)]
    if isinstance(value, dict):
        return [item for child in value.values() for item in flatten(child)]
    return []


def require_safe(value: Any) -> None:
    text = "\n".join(flatten(value))
    lowered = text.lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing wording: {term}")
    for name, pattern in SECRET_PATTERNS:
        if re.search(pattern, text):
            reject(f"secret-like pattern: {name}")
    for pattern in UNSAFE_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            reject(f"unsafe mutation wording: {pattern}")
    if PRIVATE_PATH_RE.search(text):
        reject("private local path retained")
    if re.search(r"#[0-9a-fA-F]{6}\b", text):
        reject("arbitrary hex palette retained")


def extract(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty Carbon component visual content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate Carbon component visual block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed Carbon component visual data: {exc}")
    if not isinstance(payload, dict):
        reject("Carbon component visual block must be an object")
    return payload


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    return value


def require_list(value: Any, label: str, minimum: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value


def text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        reject(f"missing {label}")
    return value


def file_sha(path: str) -> str:
    candidate = Path(path)
    if not candidate.is_file():
        reject(f"missing artifact file: {path}")
    return hashlib.sha256(candidate.read_bytes()).hexdigest()


def png_dimensions(path: str) -> tuple[int, int]:
    candidate = Path(path)
    if not candidate.is_file():
        reject(f"missing PNG artifact: {path}")
    data = candidate.read_bytes()[:24]
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        reject(f"invalid PNG artifact: {path}")
    return struct.unpack(">II", data[16:24])


def validate_capture(capture: dict[str, Any], label: str) -> None:
    path = text(capture.get("path"), f"{label} path")
    expected_width = capture.get("width")
    expected_height = capture.get("height")
    if not isinstance(expected_width, int) or not isinstance(expected_height, int):
        reject(f"missing {label} dimensions")
    actual_width, actual_height = png_dimensions(path)
    if (actual_width, actual_height) != (expected_width, expected_height):
        reject(f"{label} dimensions mismatch")
    if file_sha(path) != text(capture.get("sha256"), f"{label} sha256"):
        reject(f"{label} sha256 mismatch")
    viewport = text(capture.get("viewport"), f"{label} viewport").lower()
    if label not in viewport:
        reject(f"{label} viewport mismatch")


def validate_contrast_report(report: dict[str, Any]) -> None:
    path = text(report.get("path"), "contrast report path")
    if file_sha(path) != text(report.get("sha256"), "contrast report sha256"):
        reject("contrast report sha256 mismatch")
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if data.get("browser") != "Playwright Chromium":
        reject("contrast report browser mismatch")
    checks = data.get("checks")
    minimum = report.get("minimumChecks")
    if not isinstance(minimum, int) or not isinstance(checks, list) or len(checks) < minimum:
        reject("missing contrast report checks")
    names = {str(item.get("name")) for item in checks if isinstance(item, dict)}
    missing = sorted(REQUIRED_CONTRAST_CHECKS - names)
    if missing:
        reject("contrast report missing checks: " + ", ".join(missing))
    for item in checks:
        if not isinstance(item, dict):
            reject("contrast report check must be object")
        ratio = item.get("ratio")
        threshold = item.get("threshold")
        if not isinstance(ratio, (int, float)) or not isinstance(threshold, (int, float)):
            reject("contrast report check missing ratio or threshold")
        if ratio < threshold:
            reject("contrast report ratio below threshold")


def validate(payload: dict[str, Any], run_submodule_validator: bool = True) -> None:
    for field in REQUIRED_TOP:
        if field not in payload or payload[field] in ("", [], {}):
            reject(f"missing {field}")
    if payload["version"] != 1:
        reject("version must be 1")
    if payload["issueUrl"] != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/67":
        reject("issueUrl must point to issue #67")
    if payload["permissionLevel"] != "docs-only-local-ui-and-ci-validation":
        reject("permissionLevel mismatch")
    if text(payload["sourceBaseline"], "source baseline") != "docs/design/carbon-ui-baseline.md":
        reject("source baseline mismatch")
    if not Path(payload["sourceBaseline"]).is_file():
        reject("missing source baseline file")

    proof = require_dict(payload["dashboardProof"], "dashboard proof")
    for field in ["proofDocument", "stylesheet", "submoduleCommit"]:
        text(proof.get(field), f"dashboard proof {field}")
    if len(proof["submoduleCommit"]) != 40:
        reject("dashboard proof submodule commit must be 40 chars")
    for field in ["proofDocument", "stylesheet"]:
        if not proof[field].startswith("symphony-github-project-tracker/"):
            reject(f"dashboard proof provenance must remain in submodule path: {proof[field]}")
    captures = require_dict(proof.get("captures"), "dashboard captures")
    validate_capture(require_dict(captures.get("desktop"), "desktop capture"), "desktop")
    validate_capture(require_dict(captures.get("mobile"), "mobile capture"), "mobile")
    validate_contrast_report(require_dict(proof.get("contrastReport"), "contrast report"))

    components = require_list(payload["componentInventory"], "component inventory", len(REQUIRED_COMPONENTS))
    by_id = {}
    token_terms: set[str] = set()
    state_terms: set[str] = set()
    for item in components:
        component = require_dict(item, "component")
        cid = text(component.get("id"), "component id")
        by_id[cid] = component
        text(component.get("surface"), "component surface")
        token_roles = [str(role) for role in require_list(component.get("tokenRoles"), f"{cid} token roles", 3)]
        states = [str(state) for state in require_list(component.get("stateSupport"), f"{cid} state support", 2)]
        token_terms.update(token_roles)
        state_terms.update(states)
        if "default" not in states or "focus" not in states:
            reject(f"{cid} must include default and focus state support")
    missing_components = sorted(REQUIRED_COMPONENTS - set(by_id))
    if missing_components:
        reject("component inventory missing: " + ", ".join(missing_components))
    missing_tokens = sorted(REQUIRED_TOKEN_TERMS - token_terms)
    if missing_tokens:
        reject("Carbon token inventory missing: " + ", ".join(missing_tokens))

    state_coverage = {str(item) for item in require_list(payload["stateCoverage"], "state coverage", len(REQUIRED_STATES))}
    missing_states = sorted(REQUIRED_STATES - state_coverage)
    if missing_states:
        reject("state coverage missing: " + ", ".join(missing_states))
    if "data elements" not in state_coverage:
        reject("state coverage missing data elements")

    gate = require_dict(payload["visualRegressionGate"], "visual regression gate")
    if text(gate.get("ciWorkflow"), "CI workflow") != ".github/workflows/dokkaebi-governance.yml":
        reject("CI workflow mismatch")
    if text(gate.get("ciJob"), "CI job") != "contract-docs":
        reject("CI job mismatch")
    if text(gate.get("ciCommand"), "CI command") != "bash scripts/validate-carbon-component-library-visual-regression.sh":
        reject("CI command mismatch")
    if gate.get("requiresSubmoduleCheckout") is not False:
        reject("CI gate must not require private submodule checkout")
    artifact_capture = " ".join(str(item).lower() for item in require_list(gate.get("artifactCapture"), "artifact capture", 3))
    for term in ["desktop", "mobile", "contrast report"]:
        if term not in artifact_capture:
            reject(f"artifact capture missing {term}")
    if "retained" not in text(gate.get("artifactRetention"), "artifact retention").lower():
        reject("artifact retention must describe retained evidence")

    workflow = Path(".github/workflows/dokkaebi-governance.yml").read_text(encoding="utf-8")
    if "submodules: false" not in workflow:
        reject("GitHub Actions workflow must not require submodule checkout for root-retained artifacts")
    if "bash scripts/validate-carbon-component-library-visual-regression.sh" not in workflow:
        reject("GitHub Actions workflow missing component visual gate")

    contrast = require_dict(payload["contrastCoverage"], "contrast coverage")
    contrast_text = " ".join(flatten(contrast)).lower()
    for term in ["4.5:1", "3:1", "text-primary-on-background", "focus-on-layer", "token-meter-fill", "mobile-card-border"]:
        if term not in contrast_text:
            reject(f"contrast coverage missing {term}")

    browser = require_dict(payload["crossBrowserCoverage"], "cross-browser coverage")
    if text(browser.get("firstLane"), "cross-browser first lane") != "Playwright Chromium":
        reject("cross-browser first lane mismatch")
    if "firefox" not in text(browser.get("residualMatrix"), "cross-browser residual matrix").lower():
        reject("cross-browser residual matrix must name Firefox")
    if "webkit" not in browser["residualMatrix"].lower():
        reject("cross-browser residual matrix must name WebKit")

    validation = require_list(payload["validationOutput"], "validation output", len(COMMANDS))
    for expected in COMMANDS:
        if expected not in validation:
            reject(f"validation output missing {expected}")
    if any("FAIL" in str(item) or "not run" in str(item).lower() for item in validation):
        reject("validation output contains non-passing marker")

    approval = text(payload["approvalGateStatus"], "approval-gate status").lower()
    for term in ["no deployment", "production write", "credential", "infrastructure", "worker", "remote host", "docker", "kubernetes", "github project control-plane mutation"]:
        if term not in approval:
            reject(f"approval-gate status missing {term}")
    cleanup = require_dict(payload["cleanupReceipt"], "cleanup receipt")
    if cleanup.get("status") != "complete":
        reject("cleanup receipt must be complete")
    text(cleanup.get("receipt"), "cleanup receipt")
    require_list(payload["residualRisk"], "residual risk", 3)
    text(payload["nextAction"], "next action")
    if payload["followUpIssueUrl"] != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/84":
        reject("followUpIssueUrl must point to issue #84")
    require_safe(payload)

    optional_submodule_validator = Path("symphony-github-project-tracker/scripts/validate-dashboard-carbon-proof.sh")
    if run_submodule_validator and optional_submodule_validator.is_file():
        subprocess.run(
            ["bash", str(optional_submodule_validator)],
            check=True,
        )


def expect_reject(label: str, candidate: dict[str, Any] | str) -> None:
    try:
        if isinstance(candidate, str):
            validate(extract(candidate), run_submodule_validator=False)
        else:
            validate(candidate, run_submodule_validator=False)
    except CarbonComponentError:
        return
    reject(f"negative fixture unexpectedly passed: {label}")


try:
    doc = Path(sys.argv[1])
    payload = extract(doc.read_text(encoding="utf-8"))
    validate(payload)

    expect_reject("empty content", "")
    expect_reject("malformed JSON", START + "\n```json\n{\"version\": \n```\n" + END)
    for field in REQUIRED_TOP:
        mutated = copy.deepcopy(payload)
        mutated[field] = []
        expect_reject(f"missing {field}", mutated)

    mutated = copy.deepcopy(payload)
    mutated["componentInventory"] = payload["componentInventory"][:2]
    expect_reject("missing component inventory", mutated)

    mutated = copy.deepcopy(payload)
    mutated["componentInventory"][0]["tokenRoles"] = ["$background"]
    expect_reject("missing token roles", mutated)

    mutated = copy.deepcopy(payload)
    mutated["stateCoverage"] = ["default", "focus"]
    expect_reject("missing interaction states", mutated)

    mutated = copy.deepcopy(payload)
    mutated["dashboardProof"]["captures"]["desktop"]["path"] = "missing-desktop.png"
    expect_reject("missing desktop capture", mutated)

    mutated = copy.deepcopy(payload)
    mutated["dashboardProof"]["captures"]["mobile"]["sha256"] = "0" * 64
    expect_reject("missing mobile capture hash", mutated)

    mutated = copy.deepcopy(payload)
    mutated["dashboardProof"]["contrastReport"]["path"] = "missing-contrast.json"
    expect_reject("missing contrast report", mutated)

    mutated = copy.deepcopy(payload)
    mutated["visualRegressionGate"]["ciCommand"] = ""
    expect_reject("missing CI gate", mutated)

    mutated = copy.deepcopy(payload)
    mutated["visualRegressionGate"]["artifactRetention"] = ""
    expect_reject("missing artifact retention", mutated)

    mutated = copy.deepcopy(payload)
    mutated["approvalGateStatus"] = "production deployment completed"
    expect_reject("unsafe approval-gate status", mutated)

    mutated = copy.deepcopy(payload)
    mutated["cleanupReceipt"]["status"] = "pending"
    expect_reject("missing cleanup receipt", mutated)

    mutated = copy.deepcopy(payload)
    mutated["nextAction"] = HOME_SEGMENT + "operator/private"
    expect_reject("private local path", mutated)

    mutated = copy.deepcopy(payload)
    mutated["residualRisk"] = ["to" + "ken=example"]
    expect_reject("secret-like evidence", mutated)

    mutated = copy.deepcopy(payload)
    mutated["componentInventory"][0]["tokenRoles"] = ["#123456", "$background", "$focus"]
    expect_reject("arbitrary hex palette", mutated)
except CarbonComponentError as exc:
    print(f"FAIL {exc}", file=sys.stderr)
    sys.exit(1)
except subprocess.CalledProcessError as exc:
    print(f"FAIL submodule dashboard Carbon proof validator failed with exit {exc.returncode}", file=sys.stderr)
    sys.exit(exc.returncode)

print("PASS Dokkaebi Carbon component library visual regression validation passed")
PY
