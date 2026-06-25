#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError as exc:
    print(f"FAIL PyYAML is required to validate the Hammer image contract: {exc}", file=sys.stderr)
    sys.exit(1)

errors: list[str] = []

dockerfile = Path("images/hammer/Dockerfile")
entrypoint = Path("images/hammer/dokkaebi-hammer-entrypoint.sh")
dockerignore = Path(".dockerignore")
codex_setup = Path("scripts/setup-codex-litellm-from-dokkaebi-key.sh")
fixture_path = Path("k8s/fixtures/accepted/hammer-job-litellm-virtual-key-approved.yaml")
docs_path = Path("docs/operations/k8s-platform-usage.md")
workflow = Path(".github/workflows/hammer-image.yml")


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


for path in [dockerfile, entrypoint, dockerignore, codex_setup, fixture_path, docs_path, workflow]:
    require(path.is_file(), f"missing file: {path}")

docker_text = dockerfile.read_text(encoding="utf-8") if dockerfile.is_file() else ""
entrypoint_text = entrypoint.read_text(encoding="utf-8") if entrypoint.is_file() else ""
dockerignore_text = dockerignore.read_text(encoding="utf-8") if dockerignore.is_file() else ""
docs_text = docs_path.read_text(encoding="utf-8") if docs_path.is_file() else ""
workflow_text = workflow.read_text(encoding="utf-8") if workflow.is_file() else ""

for term in [
    "FROM node:24-bookworm-slim",
    "git",
    "gh",
    "python3",
    "kubectl",
    "@openai/codex@",
    "dokkaebi-hammer-entrypoint.sh",
    "setup-codex-litellm-from-dokkaebi-key.sh",
    "USER 1000:1000",
]:
    require(term in docker_text, f"images/hammer/Dockerfile missing contract term: {term}")

for forbidden in ["litellm-key", "DOKKAEBI_LITELLM_VIRTUAL_KEY=", "LITELLM_API_KEY="]:
    require(forbidden not in docker_text, f"images/hammer/Dockerfile must not bake or mention secret material: {forbidden}")

for term in [
    "set -euo pipefail",
    "DOKKAEBI_LITELLM_VIRTUAL_KEY",
    "DOKKAEBI_LITELLM_BASE_URL",
    "setup-codex-litellm-from-dokkaebi-key.sh",
    "exec \"$@\"",
]:
    require(term in entrypoint_text, f"images/hammer/dokkaebi-hammer-entrypoint.sh missing contract term: {term}")

for forbidden in ["set -x", "env |", "printenv", "cat \"$API_KEY_FILE\"", "litellm-key"]:
    require(forbidden not in entrypoint_text, f"entrypoint must not expose secret-bearing output: {forbidden}")

for term in ["litellm-key", ".git", ".omo", "**/.env"]:
    require(term in dockerignore_text, f".dockerignore must exclude {term}")

for term in [
    "packages: write",
    "HAMMER_IMAGE: ghcr.io/twotwo-me/hammer",
    "docker login ghcr.io",
    "docker build",
    "docker push \"${HAMMER_IMAGE}:dev-sandbox-${GITHUB_SHA}\"",
    "docker push \"${HAMMER_IMAGE}:dev-sandbox\"",
]:
    require(term in workflow_text, f".github/workflows/hammer-image.yml missing publish contract term: {term}")


def load_yaml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    loaded = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(loaded, dict):
        errors.append(f"{path} must contain a YAML mapping")
        return {}
    return loaded


fixture = load_yaml(fixture_path)
template = fixture.get("spec", {}).get("template", {}) if isinstance(fixture.get("spec"), dict) else {}
pod_spec = template.get("spec", {}) if isinstance(template, dict) else {}
pod_security_context = pod_spec.get("securityContext", {}) if isinstance(pod_spec, dict) else {}
containers = pod_spec.get("containers", []) if isinstance(pod_spec, dict) else []
container = containers[0] if containers and isinstance(containers[0], dict) else {}
env = container.get("env", []) if isinstance(container, dict) else []
env_by_name = {item.get("name"): item for item in env if isinstance(item, dict)}
volume_mounts = {
    item.get("name"): item.get("mountPath")
    for item in container.get("volumeMounts", []) or []
    if isinstance(item, dict)
}
volumes = {
    item.get("name"): item
    for item in pod_spec.get("volumes", []) or []
    if isinstance(item, dict)
}

require(container.get("image") == "ghcr.io/twotwo-me/hammer:dev-sandbox", "Hammer fixture must use the approved GHCR image tag")
require(pod_security_context.get("fsGroup") == 1000, "Hammer fixture must set fsGroup 1000 for writable emptyDir ownership")
require(pod_security_context.get("fsGroupChangePolicy") == "OnRootMismatch", "Hammer fixture must set fsGroupChangePolicy OnRootMismatch")
require(env_by_name.get("CODEX_HOME", {}).get("value") == "/home/dokkaebi/.codex", "Hammer fixture must set CODEX_HOME to writable mount path")
require("DOKKAEBI_LITELLM_BASE_URL" in env_by_name, "Hammer fixture must inject LiteLLM base URL at deployment time")
virtual_key = env_by_name.get("DOKKAEBI_LITELLM_VIRTUAL_KEY", {})
secret_ref = virtual_key.get("valueFrom", {}).get("secretKeyRef", {}) if isinstance(virtual_key, dict) else {}
require(secret_ref.get("key") == "api-key", "Hammer fixture must source only api-key from the brokered virtual-key Secret")
require(volume_mounts.get("codex-home") == "/home/dokkaebi/.codex", "Hammer fixture must mount writable codex-home")
require(volume_mounts.get("tmp") == "/tmp", "Hammer fixture must mount writable /tmp")
for volume_name in ["codex-home", "tmp"]:
    require(isinstance(volumes.get(volume_name, {}).get("emptyDir"), dict), f"Hammer fixture volume {volume_name} must be emptyDir")

for term in [
    "ghcr.io/twotwo-me/hammer:dev-sandbox",
    "images/hammer/Dockerfile",
    "DOKKAEBI_LITELLM_BASE_URL",
    "DOKKAEBI_LITELLM_VIRTUAL_KEY",
    "CODEX_HOME=/home/dokkaebi/.codex",
    "emptyDir",
]:
    require(term in docs_text, f"{docs_path} missing Hammer image usage text: {term}")

if errors:
    for error in errors:
        print("FAIL " + error, file=sys.stderr)
    sys.exit(1)

print("PASS Dokkaebi Hammer image contract validation passed")
PY
