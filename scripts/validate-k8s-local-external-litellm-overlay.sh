#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

from pathlib import Path
import subprocess
import sys

try:
    import yaml
except ImportError as exc:
    print(f"FAIL PyYAML is required to validate local external LiteLLM overlay: {exc}", file=sys.stderr)
    sys.exit(1)

errors: list[str] = []
manifest_path = Path("k8s/overlays/local/external-litellm.yaml")
kustomization_path = Path("k8s/overlays/local/kustomization.yaml")


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def load_docs(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as f:
        return [doc for doc in yaml.safe_load_all(f) if isinstance(doc, dict)]


require(manifest_path.is_file(), f"missing file: {manifest_path}")
require(kustomization_path.is_file(), f"missing file: {kustomization_path}")

if manifest_path.is_file():
    docs = load_docs(manifest_path)
else:
    docs = []

objects = {
    (doc.get("kind"), doc.get("metadata", {}).get("namespace"), doc.get("metadata", {}).get("name")): doc
    for doc in docs
}
expected_objects = {
    ("Endpoints", "dokkaebi-llm", "litellm"),
    ("NetworkPolicy", "dokkaebi-system", "allow-fire-external-litellm-egress"),
    ("NetworkPolicy", "dokkaebi-workers", "allow-hammer-external-litellm-egress"),
    ("NetworkPolicy", "dokkaebi-observability", "allow-prometheus-external-litellm-egress"),
}
missing_objects = sorted(expected_objects - set(objects))
require(not missing_objects, f"{manifest_path} missing objects: {missing_objects}")

endpoint = objects.get(("Endpoints", "dokkaebi-llm", "litellm"), {})
subsets = endpoint.get("subsets", []) if isinstance(endpoint, dict) else []
if subsets and isinstance(subsets[0], dict):
    addresses = subsets[0].get("addresses", [])
    ports = subsets[0].get("ports", [])
    endpoint_ip = addresses[0].get("ip") if addresses and isinstance(addresses[0], dict) else None
    endpoint_port = ports[0].get("port") if ports and isinstance(ports[0], dict) else None
    require(endpoint_ip == "192.0.2.150", "local external LiteLLM endpoint must use documentation TEST-NET address 192.0.2.150")
    require(endpoint_port == 4000, "local external LiteLLM endpoint must use port 4000")
else:
    require(False, "local external LiteLLM Endpoints must declare one subset")

for policy_name in [
    "allow-fire-external-litellm-egress",
    "allow-hammer-external-litellm-egress",
    "allow-prometheus-external-litellm-egress",
]:
    policy = next((doc for key, doc in objects.items() if key[2] == policy_name), {})
    spec = policy.get("spec", {}) if isinstance(policy, dict) else {}
    egress = spec.get("egress", []) if isinstance(spec, dict) else []
    require(len(egress) == 1, f"{policy_name} must declare exactly one egress rule")
    if len(egress) != 1 or not isinstance(egress[0], dict):
        continue
    destinations = egress[0].get("to", [])
    ports = egress[0].get("ports", [])
    require(len(destinations) == 1, f"{policy_name} must declare exactly one egress destination")
    require(len(ports) == 1, f"{policy_name} must declare exactly one egress port")
    if destinations and not isinstance(destinations[0], dict):
        require(False, f"{policy_name} egress destination must be a mapping")
    elif destinations:
        require(destinations[0].get("ipBlock", {}).get("cidr") == "192.0.2.150/32", f"{policy_name} must restrict egress to 192.0.2.150/32")
        require(set(destinations[0]) == {"ipBlock"}, f"{policy_name} must not combine external LiteLLM with namespace or pod selectors")
    if ports and not isinstance(ports[0], dict):
        require(False, f"{policy_name} egress port must be a mapping")
    elif ports:
        require(ports[0].get("protocol") == "TCP", f"{policy_name} must use TCP")
        require(ports[0].get("port") == 4000, f"{policy_name} must restrict egress to port 4000")
        require(set(ports[0]) == {"protocol", "port"}, f"{policy_name} must not declare extra port selectors")

if kustomization_path.is_file():
    kustomization = yaml.safe_load(kustomization_path.read_text(encoding="utf-8"))
    resources = kustomization.get("resources", []) if isinstance(kustomization, dict) else []
    require(resources == ["../../base", "external-litellm.yaml"], f"{kustomization_path} resources must include only ../../base and external-litellm.yaml")
    patches = kustomization.get("patches", []) if isinstance(kustomization, dict) else []
    require(isinstance(patches, list) and len(patches) == 3, f"{kustomization_path} must declare exactly three local LiteLLM patches")

try:
    rendered = subprocess.run(
        ["kubectl", "kustomize", "k8s/overlays/local"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
except (OSError, subprocess.CalledProcessError) as exc:
    print(f"FAIL kubectl kustomize k8s/overlays/local failed: {exc}", file=sys.stderr)
    sys.exit(1)

rendered_docs = [doc for doc in yaml.safe_load_all(rendered) if isinstance(doc, dict)]
rendered_objects = {
    (doc.get("kind"), doc.get("metadata", {}).get("namespace"), doc.get("metadata", {}).get("name")): doc
    for doc in rendered_docs
}
rendered_litellm_service = rendered_objects.get(("Service", "dokkaebi-llm", "litellm"), {})
rendered_litellm_endpoint = rendered_objects.get(("Endpoints", "dokkaebi-llm", "litellm"), {})
rendered_litellm_deployment = rendered_objects.get(("Deployment", "dokkaebi-llm", "litellm"), {})
rendered_postgres_deployment = rendered_objects.get(("Deployment", "dokkaebi-llm", "litellm-postgres"), {})

require("selector" not in rendered_litellm_service.get("spec", {}), "rendered local LiteLLM Service must not have a selector")
require(rendered_litellm_deployment.get("spec", {}).get("replicas") == 0, "rendered local LiteLLM Deployment must scale to zero")
require(rendered_postgres_deployment.get("spec", {}).get("replicas") == 0, "rendered local LiteLLM Postgres Deployment must scale to zero")
rendered_subsets = rendered_litellm_endpoint.get("subsets", []) if isinstance(rendered_litellm_endpoint, dict) else []
if rendered_subsets and isinstance(rendered_subsets[0], dict):
    rendered_addresses = rendered_subsets[0].get("addresses", [])
    rendered_ports = rendered_subsets[0].get("ports", [])
    rendered_ip = rendered_addresses[0].get("ip") if rendered_addresses and isinstance(rendered_addresses[0], dict) else None
    rendered_port = rendered_ports[0].get("port") if rendered_ports and isinstance(rendered_ports[0], dict) else None
    require(rendered_ip == "192.0.2.150", "rendered local LiteLLM endpoint must use documentation TEST-NET address 192.0.2.150")
    require(rendered_port == 4000, "rendered local LiteLLM endpoint must use port 4000")
else:
    require(False, "rendered local LiteLLM Endpoints must declare one subset")

for policy_name in [
    "allow-fire-external-litellm-egress",
    "allow-hammer-external-litellm-egress",
    "allow-prometheus-external-litellm-egress",
]:
    policy = next((doc for key, doc in rendered_objects.items() if key[2] == policy_name), {})
    spec = policy.get("spec", {}) if isinstance(policy, dict) else {}
    egress = spec.get("egress", []) if isinstance(spec, dict) else []
    require(len(egress) == 1, f"rendered {policy_name} must declare exactly one egress rule")
    if len(egress) != 1 or not isinstance(egress[0], dict):
        continue
    destinations = egress[0].get("to", [])
    ports = egress[0].get("ports", [])
    require(len(destinations) == 1, f"rendered {policy_name} must declare exactly one egress destination")
    require(len(ports) == 1, f"rendered {policy_name} must declare exactly one egress port")
    if destinations and not isinstance(destinations[0], dict):
        require(False, f"rendered {policy_name} egress destination must be a mapping")
    elif destinations:
        require(destinations[0].get("ipBlock", {}).get("cidr") == "192.0.2.150/32", f"rendered {policy_name} must restrict egress to 192.0.2.150/32")
        require(set(destinations[0]) == {"ipBlock"}, f"rendered {policy_name} must not combine external LiteLLM with namespace or pod selectors")
    if ports and not isinstance(ports[0], dict):
        require(False, f"rendered {policy_name} egress port must be a mapping")
    elif ports:
        require(ports[0].get("protocol") == "TCP", f"rendered {policy_name} must use TCP")
        require(ports[0].get("port") == 4000, f"rendered {policy_name} must restrict egress to port 4000")
        require(set(ports[0]) == {"protocol", "port"}, f"rendered {policy_name} must not declare extra port selectors")

if errors:
    for error in errors:
        print("FAIL " + error, file=sys.stderr)
    sys.exit(1)

print("PASS Dokkaebi local external LiteLLM overlay validation passed")
PY
