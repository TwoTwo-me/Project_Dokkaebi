#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

require_text() {
  local path="$1"
  local needle="$2"
  [[ -f "$path" ]] || fail "missing file: $path"
  grep -Fqi -- "$needle" "$path" || fail "missing text in $path: $needle"
}

DOC_PATH="${CARBON_UI_BASELINE_PATH:-docs/design/carbon-ui-baseline.md}"

for term in \
  "theme choice" \
  "role-based token mapping" \
  "layering model" \
  "interaction states" \
  "focus requirements" \
  "contrast thresholds" \
  "data visualization rules" \
  "status color rules" \
  "component state inventory" \
  "visual QA checklist" \
  "remaining operational gaps" \
  "permission level" \
  "docs-only" \
  "Carbon Design System"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import json
import re
import sys
from pathlib import Path
from typing import Any

START = "<!-- carbon-ui-baseline:begin -->"
END = "<!-- carbon-ui-baseline:end -->"
REQUIRED_TOP_LEVEL = [
    "permissionLevel",
    "sourceGuidance",
    "themeChoice",
    "roleBasedTokenMapping",
    "layeringModel",
    "interactionStates",
    "focusRequirements",
    "contrastThresholds",
    "dataVisualizationStatusRules",
    "componentStateInventory",
    "visualQaChecklist",
    "implementationRules",
    "remainingOperationalGaps",
]
REQUIRED_TOKEN_GROUPS = {
    "background",
    "layer",
    "field",
    "border",
    "text",
    "link",
    "icon",
    "interactive",
    "focus",
    "support",
    "overlay",
    "skeleton",
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
    "informational",
}
REQUIRED_COMPONENTS = {
    "app shell",
    "navigation",
    "project",
    "tenant",
    "work queue",
    "issue intake",
    "approval gate",
    "worker route",
    "result packet",
    "evidence package",
    "metrics dashboard",
    "alert",
    "settings",
    "modal",
    "drawer",
    "toast",
    "inline notification",
}
REQUIRED_QA = {
    "desktop",
    "mobile",
    "light theme",
    "focus",
    "disabled",
    "error",
    "warning",
    "success",
    "token usage",
    "contrast",
    "cleanup",
}


class CarbonBaselineError(Exception):
    pass


def reject(message: str) -> None:
    raise CarbonBaselineError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty Carbon UI baseline")
    if START not in text or END not in text:
        reject("missing carbon UI baseline block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    if re.search(r"#[0-9a-fA-F]{6}\b", block):
        reject("hard-coded arbitrary hex palette")
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed baseline data: {exc}")
    if not isinstance(payload, dict):
        reject("carbon UI baseline block must be an object")
    return payload


def require_nonempty(value: Any, label: str) -> None:
    if value in (None, "", [], {}):
        reject(f"missing {label}")


def require_list(value: Any, label: str, min_items: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < min_items:
        reject(f"missing {label}")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    return value


def text_join(value: Any) -> str:
    if isinstance(value, dict):
        return " ".join(f"{key} {text_join(val)}" for key, val in value.items())
    if isinstance(value, list):
        return " ".join(text_join(v) for v in value)
    return str(value)


def contains_all(text: str, required: set[str], label: str) -> None:
    lowered = text.lower()
    missing = sorted(item for item in required if item not in lowered)
    if missing:
        reject(f"{label} missing {', '.join(missing)}")


def validate_payload(payload: dict[str, Any]) -> None:
    for field in REQUIRED_TOP_LEVEL:
        require_nonempty(payload.get(field), field)

    permission = str(payload.get("permissionLevel", "")).lower()
    if "docs-only" not in permission:
        reject("missing permission level")

    source = require_dict(payload.get("sourceGuidance"), "source guidance")
    source_text = text_join(source).lower()
    for term in [
        "carbon design system",
        "https://carbondesignsystem.com/elements/color/overview/",
        "role-based",
        "theme",
        "layering",
        "interaction",
        "focus",
        "contrast",
    ]:
        if term not in source_text:
            reject(f"source guidance missing {term}")

    theme = require_dict(payload.get("themeChoice"), "theme choice")
    theme_text = text_join(theme).lower()
    for term in ["gray 10", "white", "gray 100", "gray 90", "primary", "support"]:
        if term not in theme_text:
            reject(f"theme choice missing {term}")

    tokens = require_dict(payload.get("roleBasedTokenMapping"), "role-based token mapping")
    missing_token_groups = REQUIRED_TOKEN_GROUPS - set(tokens.keys())
    if missing_token_groups:
        reject("role-based token mapping missing " + ", ".join(sorted(missing_token_groups)))
    token_text = text_join(tokens)
    for token in [
        "$background",
        "$layer",
        "$field",
        "$text-primary",
        "$text-secondary",
        "$interactive",
        "$focus",
        "$support-error",
        "$support-warning",
        "$support-success",
        "$support-info",
    ]:
        if token not in token_text:
            reject(f"role-based token mapping missing {token}")

    layering = require_dict(payload.get("layeringModel"), "layering model")
    layering_text = text_join(layering).lower()
    for term in ["light", "dark", "global background", "layer", "shell", "modal", "metrics chart"]:
        if term not in layering_text:
            reject(f"layering model missing {term}")

    states_text = " ".join(str(item).lower() for item in require_list(payload.get("interactionStates"), "interaction states", 10))
    contains_all(states_text, REQUIRED_STATES, "interaction states")
    for term in ["-hover", "-selected", "-active", "focus token", "disabled tokens", "non-color cue"]:
        if term not in states_text:
            reject(f"interaction states missing {term}")

    focus = require_dict(payload.get("focusRequirements"), "focus requirements")
    focus_text = text_join(focus).lower()
    for term in ["two pixel", "focus token", "3:1", "focus-inset", "buttons", "links", "workflow controls"]:
        if term not in focus_text:
            reject(f"focus requirements missing {term}")

    contrast = require_dict(payload.get("contrastThresholds"), "contrast thresholds")
    contrast_text = text_join(contrast).lower()
    for term in ["4.5:1", "3:1", "smalltext", "largetext", "focusindicators", "icons", "datavisualization", "statusindicators", "notcolor-only"]:
        if term not in contrast_text.replace(" ", ""):
            reject(f"contrast thresholds missing {term}")

    status = require_dict(payload.get("dataVisualizationStatusRules"), "data visualization rules")
    status_text = text_join(status).lower()
    for term in ["error", "warning", "success", "info", "labels", "legends", "patterns", "icons", "text"]:
        if term not in status_text:
            reject(f"data visualization or status color rules missing {term}")

    components_text = " ".join(str(item).lower() for item in require_list(payload.get("componentStateInventory"), "component state inventory", 10))
    contains_all(components_text, REQUIRED_COMPONENTS, "component state inventory")

    qa_text = " ".join(str(item).lower() for item in require_list(payload.get("visualQaChecklist"), "visual QA checklist", 12))
    contains_all(qa_text, REQUIRED_QA, "visual QA checklist")

    rules_text = " ".join(str(item).lower() for item in require_list(payload.get("implementationRules"), "implementation rules", 4))
    for term in ["carbon role-based tokens", "arbitrary hard-coded", "one-off palette", "color as the only", "token roles"]:
        if term not in rules_text:
            reject(f"implementation rules missing {term}")

    gaps_text = " ".join(str(item).lower() for item in require_list(payload.get("remainingOperationalGaps"), "remaining operational gaps", 4))
    for term in ["first-party ui", "desktop visual qa", "mobile visual qa", "contrast report", "component library"]:
        if term not in gaps_text:
            reject(f"remaining operational gaps missing {term}")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except CarbonBaselineError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty design", "")
expect_reject(
    "malformed baseline data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

for field in REQUIRED_TOP_LEVEL:
    mutated = copy.deepcopy(baseline)
    mutated[field] = [] if isinstance(mutated.get(field), list) else ""
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["roleBasedTokenMapping"].pop("focus", None)
expect_reject("missing focus token mapping", mutated)

mutated = copy.deepcopy(baseline)
mutated["interactionStates"] = ["default", "hover"]
expect_reject("missing interaction states", mutated)

mutated = copy.deepcopy(baseline)
mutated["contrastThresholds"]["smallText"] = "visual check later"
expect_reject("missing contrast threshold", mutated)

mutated = copy.deepcopy(baseline)
mutated["visualQaChecklist"] = ["desktop viewport"]
expect_reject("missing visual QA checklist", mutated)

mutated = copy.deepcopy(baseline)
mutated["implementationRules"] = ["use any product colors", "status by color only"]
expect_reject("non-Carbon one-off color wording", mutated)

expect_reject(
    "hard-coded arbitrary hex palette",
    START + "\n```json\n" + json.dumps({**baseline, "hardCodedPalette": ["#123456"]}) + "\n```\n" + END,
)

print("PASS Dokkaebi Carbon UI baseline validation passed")
PY
