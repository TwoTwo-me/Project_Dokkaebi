#!/usr/bin/env bash
# noqa: SIZE_OK - aggregate LiteLLM/Grafana manifest contract validator; kept single-file to preserve the repository validator pattern and exact rendered-object checks.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError as exc:
    print(f"FAIL PyYAML is required to validate K8S manifests: {exc}", file=sys.stderr)
    sys.exit(1)

errors: list[str] = []
BASE_DIR = Path("k8s/base")
DOC = Path("docs/operations/k8s-litellm-grafana-platform.md")
SAFE_PLACEHOLDER_PREFIX = "REPLACE_WITH_APPROVED_"
LIVE_SECRET_PATTERNS = [
    r"sk-[A-Za-z0-9_-]{12,}",
    r"ghp_[A-Za-z0-9_]{12,}",
    r"github_pat_[A-Za-z0-9_]{12,}",
    r"xox[baprs]-[A-Za-z0-9-]{12,}",
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    r"refresh_token",
    r"access_token",
]


def load_yaml_documents(path: Path) -> list[dict[str, Any]]:
    try:
        loaded = list(yaml.safe_load_all(path.read_text()))
    except yaml.YAMLError as exc:
        errors.append(f"invalid YAML in {path}: {exc}")
        return []
    docs: list[dict[str, Any]] = []
    for index, doc in enumerate(loaded, start=1):
        if doc is None:
            continue
        if not isinstance(doc, dict):
            errors.append(f"{path} document {index} must be a mapping")
            continue
        docs.append(doc)
    return docs


def metadata(doc: dict[str, Any]) -> dict[str, Any]:
    value = doc.get("metadata")
    return value if isinstance(value, dict) else {}


def spec(doc: dict[str, Any]) -> dict[str, Any]:
    value = doc.get("spec")
    return value if isinstance(value, dict) else {}


def object_key(doc: dict[str, Any]) -> tuple[str, str, str]:
    meta = metadata(doc)
    return (str(doc.get("kind", "")), str(meta.get("namespace", "")), str(meta.get("name", "")))


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


for required in [
    DOC,
    BASE_DIR / "platform-runtime.yaml",
    BASE_DIR / "litellm.yaml",
    BASE_DIR / "observability.yaml",
    Path("k8s/fixtures/accepted/hammer-job-litellm-virtual-key-approved.yaml"),
    Path("k8s/fixtures/rejected/provider-api-key-secret-env.yaml"),
    Path("k8s/fixtures/rejected/litellm-master-key-secret-env.yaml"),
    Path("k8s/fixtures/rejected/github-token-secret-env.yaml"),
    Path("k8s/fixtures/rejected/litellm-virtual-key-self-spoof.yaml"),
]:
    require(required.is_file(), f"missing file: {required}")

kustomization = yaml.safe_load((BASE_DIR / "kustomization.yaml").read_text())
resources = kustomization.get("resources", []) if isinstance(kustomization, dict) else []
for resource in ["platform-runtime.yaml", "litellm.yaml", "observability.yaml"]:
    require(resource in resources, f"k8s/base/kustomization.yaml missing {resource}")

documents: list[dict[str, Any]] = []
for resource in resources:
    if isinstance(resource, str) and resource.endswith((".yaml", ".yml")):
        documents.extend(load_yaml_documents(BASE_DIR / resource))

by_key = {object_key(doc): doc for doc in documents}
required_objects = [
    ("Deployment", "dokkaebi-system", "dokkaebi-fire"),
    ("Deployment", "dokkaebi-system", "dokkaebi-fire-green"),
    ("Lease", "dokkaebi-system", "dokkaebi-fire-active-writer"),
    ("NetworkPolicy", "dokkaebi-system", "allow-fire-kubernetes-api-egress"),
    ("NetworkPolicy", "dokkaebi-workers", "allow-hammer-kubernetes-api-egress"),
    ("Deployment", "dokkaebi-llm", "litellm"),
    ("Deployment", "dokkaebi-llm", "litellm-postgres"),
    ("Service", "dokkaebi-llm", "litellm"),
    ("Secret", "dokkaebi-llm", "litellm-runtime-placeholder"),
    ("Role", "dokkaebi-workers", "dokkaebi-litellm-virtual-key-secret-writer"),
    ("Deployment", "dokkaebi-observability", "prometheus"),
    ("Deployment", "dokkaebi-observability", "grafana"),
    ("ConfigMap", "dokkaebi-observability", "prometheus-config"),
    ("ConfigMap", "dokkaebi-observability", "grafana-provisioning"),
    ("ConfigMap", "dokkaebi-observability", "grafana-dashboard-dokkaebi-platform"),
    ("PersistentVolumeClaim", "dokkaebi-llm", "litellm-postgres-data"),
    ("PersistentVolumeClaim", "dokkaebi-observability", "prometheus-data"),
    ("PersistentVolumeClaim", "dokkaebi-observability", "grafana-data"),
]
for key in required_objects:
    require(key in by_key, f"missing K8S object: {key[0]}/{key[1]}/{key[2]}")


def pod_template(doc: dict[str, Any]) -> dict[str, Any]:
    template = spec(doc).get("template", {})
    return template if isinstance(template, dict) else {}


def pod_spec(doc: dict[str, Any]) -> dict[str, Any]:
    template = pod_template(doc)
    value = template.get("spec")
    return value if isinstance(value, dict) else {}


def primary_container(doc: dict[str, Any]) -> dict[str, Any]:
    containers = pod_spec(doc).get("containers", [])
    if isinstance(containers, list) and containers and isinstance(containers[0], dict):
        return containers[0]
    return {}


def require_probe(doc: dict[str, Any], name: str) -> None:
    container = primary_container(doc)
    require("readinessProbe" in container, f"{name} must define readinessProbe")
    require("livenessProbe" in container, f"{name} must define livenessProbe")


def require_fs_group(doc: dict[str, Any], expected: int) -> None:
    security_context = pod_spec(doc).get("securityContext", {})
    require(security_context.get("fsGroup") == expected, f"{object_key(doc)} must set fsGroup {expected}")
    require(
        security_context.get("fsGroupChangePolicy") == "OnRootMismatch",
        f"{object_key(doc)} must set fsGroupChangePolicy OnRootMismatch",
    )


def require_label(doc: dict[str, Any], label: str, expected: str | None = None) -> None:
    labels = metadata(doc).get("labels", {})
    if not isinstance(labels, dict):
        errors.append(f"{object_key(doc)} missing labels")
        return
    value = labels.get(label)
    require(isinstance(value, str) and bool(value), f"{object_key(doc)} missing label {label}")
    if expected is not None:
        require(value == expected, f"{object_key(doc)} label {label} must be {expected}")


for key in [
    ("Deployment", "dokkaebi-system", "dokkaebi-fire"),
    ("Deployment", "dokkaebi-system", "dokkaebi-fire-green"),
    ("Deployment", "dokkaebi-llm", "litellm"),
    ("Deployment", "dokkaebi-llm", "litellm-postgres"),
    ("Deployment", "dokkaebi-observability", "prometheus"),
    ("Deployment", "dokkaebi-observability", "grafana"),
]:
    doc = by_key.get(key, {})
    require_probe(doc, key[2])
    require_label(doc, "dokkaebi.io/platform-version", "0.1.0-k8s")

green = by_key.get(("Deployment", "dokkaebi-system", "dokkaebi-fire-green"), {})
require(spec(green).get("replicas") == 0, "green Fire candidate must default to replicas 0")
require_label(green, "dokkaebi.io/release-track", "green")
require_label(green, "dokkaebi.io/canary", "true")
green_env = {
    item.get("name"): item.get("value")
    for item in primary_container(green).get("env", []) or []
    if isinstance(item, dict)
}
require(green_env.get("DOKKAEBI_DISPATCH_ENABLED") == "false", "green Fire candidate must start dispatch-disabled")
require(green_env.get("DOKKAEBI_FIRE_MODE") == "candidate-observer", "green Fire candidate must be observer mode")

blue = by_key.get(("Deployment", "dokkaebi-system", "dokkaebi-fire"), {})
blue_selector = spec(blue).get("selector", {}).get("matchLabels", {})
green_selector = spec(green).get("selector", {}).get("matchLabels", {})
require(blue_selector.get("dokkaebi.io/release-track") == "blue", "blue Fire selector must be release-track scoped")
require(green_selector.get("dokkaebi.io/release-track") == "green", "green Fire selector must be release-track scoped")

litellm_deployment = by_key.get(("Deployment", "dokkaebi-llm", "litellm"), {})
require(pod_spec(litellm_deployment).get("automountServiceAccountToken") is False, "LiteLLM must not mount Kubernetes API token")
require_label(litellm_deployment, "dokkaebi.io/litellm-config-version", "litellm-config-v1")

require_fs_group(by_key.get(("Deployment", "dokkaebi-llm", "litellm-postgres"), {}), 999)
require_fs_group(by_key.get(("Deployment", "dokkaebi-observability", "prometheus"), {}), 65534)
require_fs_group(by_key.get(("Deployment", "dokkaebi-observability", "grafana"), {}), 472)

def require_kubernetes_api_egress_policy(key: tuple[str, str, str], subject: str) -> None:
    api_policy = by_key.get(key, {})
    api_meta = metadata(api_policy)
    api_annotations = api_meta.get("annotations", {}) if isinstance(api_meta.get("annotations"), dict) else {}
    require(api_annotations.get("dokkaebi.io/cluster-service-ip-placeholder") == "true", f"{subject} API egress policy must mark service IP placeholder")
    egress = spec(api_policy).get("egress", [])
    require(isinstance(egress, list) and len(egress) == 1, f"{subject} API egress must have exactly one rule")
    if isinstance(egress, list) and egress:
        to = egress[0].get("to", []) if isinstance(egress[0], dict) else []
        ports = egress[0].get("ports", []) if isinstance(egress[0], dict) else []
        require(to == [{"ipBlock": {"cidr": "10.96.0.1/32"}}], f"{subject} API egress must target only placeholder kubernetes.default service IP")
        require(ports == [{"protocol": "TCP", "port": 443}], f"{subject} API egress must target only TCP/443")


require_kubernetes_api_egress_policy(("NetworkPolicy", "dokkaebi-system", "allow-fire-kubernetes-api-egress"), "Fire")
hammer_api_policy = by_key.get(("NetworkPolicy", "dokkaebi-workers", "allow-hammer-kubernetes-api-egress"), {})
hammer_api_selector = spec(hammer_api_policy).get("podSelector", {}).get("matchLabels", {})
require(
    hammer_api_selector == {
        "app.kubernetes.io/name": "dokkaebi-hammer",
        "dokkaebi.io/k8s-api-access": "approved",
    },
    "Hammer API egress must select only approved K8S API Hammer pods",
)
require_kubernetes_api_egress_policy(("NetworkPolicy", "dokkaebi-workers", "allow-hammer-kubernetes-api-egress"), "Hammer")

for doc in documents:
    if doc.get("kind") in {"Deployment", "StatefulSet", "DaemonSet", "Job"}:
        template = spec(doc).get("template", {})
        pod_spec = spec(template) if isinstance(template, dict) else {}
        for container in pod_spec.get("containers", []) or []:
            if not isinstance(container, dict):
                continue
            image = str(container.get("image", ""))
            for forbidden_tag in [":latest", ":main-latest", ":main-stable", "postgres:16-alpine"]:
                require(forbidden_tag not in image, f"{object_key(doc)} uses mutable image reference {image}")
            if metadata(doc).get("name") in {"dokkaebi-fire", "dokkaebi-fire-green"}:
                annotations = pod_template(doc).get("metadata", {}).get("annotations", {})
                require(
                    annotations.get("dokkaebi.io/image-digest-status") == "private-registry-digest-required-before-live-apply",
                    f"{object_key(doc)} must mark private Fire image digest gate",
                )
                require(
                    annotations.get("dokkaebi.io/image-digest-approval-gate") == "explicit-human-approved-fire-build-digest",
                    f"{object_key(doc)} must mark Fire image digest approval gate",
                )
            else:
                require(
                    re.search(r"@sha256:[0-9a-f]{64}$", image) is not None,
                    f"{object_key(doc)} image must be pinned by sha256 digest: {image}",
                )
    if doc.get("kind") != "Secret":
        continue
    meta = metadata(doc)
    labels = meta.get("labels", {}) if isinstance(meta.get("labels"), dict) else {}
    require(labels.get("dokkaebi.io/secret-placeholder") == "true", f"{meta.get('name')} must be marked as a placeholder Secret")
    for field in ["stringData", "data"]:
        values = doc.get(field, {})
        if not isinstance(values, dict):
            continue
        for key, value in values.items():
            text = str(value)
            require(text.startswith(SAFE_PLACEHOLDER_PREFIX), f"{meta.get('name')} {key} must use approved placeholder text")
            for pattern in LIVE_SECRET_PATTERNS:
                if re.search(pattern, text, flags=re.IGNORECASE):
                    errors.append(f"{meta.get('name')} {key} looks like live secret material")

for key in [
    ("PersistentVolumeClaim", "dokkaebi-llm", "litellm-postgres-data"),
    ("PersistentVolumeClaim", "dokkaebi-observability", "prometheus-data"),
    ("PersistentVolumeClaim", "dokkaebi-observability", "grafana-data"),
]:
    claim = by_key.get(key, {})
    meta = metadata(claim)
    annotations = meta.get("annotations", {}) if isinstance(meta.get("annotations"), dict) else {}
    require(annotations.get("dokkaebi.io/host-persistence-placeholder") == "true", f"{key[2]} must mark host persistence placeholder")
    require(spec(claim).get("storageClassName") == "dokkaebi-hostpath-placeholder", f"{key[2]} must use dokkaebi-hostpath-placeholder")

broker_role = by_key.get(("Role", "dokkaebi-workers", "dokkaebi-litellm-virtual-key-secret-writer"), {})
broker_rules = spec(broker_role).get("rules", broker_role.get("rules", []))
require(isinstance(broker_rules, list) and len(broker_rules) == 1, "broker Secret writer Role must have exactly one rule")
if isinstance(broker_rules, list) and broker_rules:
    rule = broker_rules[0]
    resources = set(rule.get("resources", [])) if isinstance(rule, dict) else set()
    verbs = set(rule.get("verbs", [])) if isinstance(rule, dict) else set()
    require(resources == {"secrets"}, "broker Secret writer Role may target only Secrets")
    require(verbs == {"create", "get", "delete"}, "broker Secret writer Role may only create/get/delete")
    require(not {"list", "watch", "*"} & verbs, "broker Secret writer Role must not list/watch Secrets")

for doc in documents:
    if doc.get("kind") != "Role":
        continue
    name = str(metadata(doc).get("name", ""))
    if name == "dokkaebi-litellm-virtual-key-secret-writer":
        continue
    for rule in doc.get("rules", []) or []:
        if isinstance(rule, dict) and "secrets" in rule.get("resources", []):
            errors.append(f"{name} must not grant Secret access")

fixture = load_yaml_documents(Path("k8s/fixtures/accepted/hammer-job-litellm-virtual-key-approved.yaml"))[0]
labels = metadata(fixture).get("labels", {})
containers = spec(spec(fixture).get("template", {})).get("containers", [])
env = containers[0].get("env", []) if containers and isinstance(containers[0], dict) else []
env_by_name = {item.get("name"): item for item in env if isinstance(item, dict)}
virtual_env = env_by_name.get("DOKKAEBI_LITELLM_VIRTUAL_KEY", {})
secret_ref = virtual_env.get("valueFrom", {}).get("secretKeyRef", {}) if isinstance(virtual_env, dict) else {}
grant_id = labels.get("dokkaebi.io/credential-grant-id")
require(secret_ref.get("name") == f"dokkaebi-litellm-virtual-key-{grant_id}", "Hammer fixture must derive virtual-key Secret name from credential grant")
require(secret_ref.get("key") == "api-key", "Hammer fixture must read only api-key from virtual-key Secret")
require(labels.get("dokkaebi.io/litellm-key-scope") == "run-scoped", "Hammer fixture must be run-scoped")
require(labels.get("dokkaebi.io/litellm-key-owner") == "fire-credential-broker", "Hammer fixture must be Fire-broker owned")
require(isinstance(labels.get("dokkaebi.io/run-id"), str) and bool(labels.get("dokkaebi.io/run-id")), "Hammer fixture must carry run id")
for forbidden_env in ["OPENAI_API_KEY", "LITELLM_MASTER_KEY", "GITHUB_TOKEN", "CHATGPT_TOKEN_DIR", "CHATGPT_AUTH_FILE"]:
    require(forbidden_env not in env_by_name, f"Hammer accepted fixture must not receive {forbidden_env}")

self_spoof_text = Path("k8s/fixtures/rejected/litellm-virtual-key-self-spoof.yaml").read_text()
for term in [
    "dokkaebi.io/fixture-request-user: system:serviceaccount:dokkaebi-workers:hammer-k8s-readonly",
    "DOKKAEBI_LITELLM_VIRTUAL_KEY",
    "dokkaebi-litellm-virtual-key-grant-litellm-pdk8s-001",
]:
    require(term in self_spoof_text, f"self-spoof fixture missing {term}")

prometheus_config = by_key[("ConfigMap", "dokkaebi-observability", "prometheus-config")]["data"]["prometheus.yml"]
prometheus_data = yaml.safe_load(prometheus_config)
scrape_configs = prometheus_data.get("scrape_configs", []) if isinstance(prometheus_data, dict) else []
jobs = {item.get("job_name"): item for item in scrape_configs if isinstance(item, dict)}
for job_name in ["dokkaebi-fire", "dokkaebi-litellm", "dokkaebi-work-allocation"]:
    require(job_name in jobs, f"Prometheus config missing scrape job {job_name}")
allowed_labels = {"project", "environment", "component", "route_class", "provider", "model", "team", "approval_gate_status"}
external_labels = set(prometheus_data.get("global", {}).get("external_labels", {}))
require(external_labels <= allowed_labels, "Prometheus external labels must stay bounded")
for job_name, job in jobs.items():
    for static_config in job.get("static_configs", []) or []:
        labels = set((static_config.get("labels") or {}).keys())
        require(labels <= allowed_labels, f"{job_name} uses unbounded Prometheus labels: {', '.join(sorted(labels - allowed_labels))}")

grafana_config = by_key[("ConfigMap", "dokkaebi-observability", "grafana-provisioning")]["data"]
require("datasources.yaml" in grafana_config, "Grafana provisioning missing datasource")
require("dashboard-provider.yaml" in grafana_config, "Grafana provisioning missing dashboard provider")
require("/etc/grafana/dashboards" in grafana_config["dashboard-provider.yaml"], "Grafana provider must read dashboard ConfigMap outside the data PVC")
grafana_dashboard_config = by_key[("ConfigMap", "dokkaebi-observability", "grafana-dashboard-dokkaebi-platform")]["data"]
dashboard = json.loads(grafana_dashboard_config["dokkaebi-platform-dashboard.json"])
dashboard_text = json.dumps(dashboard)
for term in ["dokkaebi_work_allocated_total", "dokkaebi_worker_health", "litellm", "dokkaebi_credential_denial_total"]:
    require(term in dashboard_text, f"Grafana dashboard missing query term: {term}")

doc_text = DOC.read_text(encoding="utf-8")
for term in [
    "active-writer Lease",
    "allow-fire-kubernetes-api-egress",
    "provider egress is intentionally not opened",
    "LiteLLM virtual-key",
    "request.userInfo.username",
    "Grafana",
    "Prometheus",
    "bounded labels",
    "hostPath/PV",
    "fsGroup",
    "tag@sha256",
    "private `ghcr.io/project-dokkaebi/fire:dev-sandbox` placeholder",
    "dokkaebi-fire-green",
    "DOKKAEBI_DISPATCH_ENABLED=false",
    "canary",
    "rollback",
    "GitOps",
    "Production, EKS, live credential",
    "live GitHub Project, and shared-cluster",
    "promotion remain approval-gated",
]:
    require(term in doc_text, f"{DOC} missing text: {term}")

if errors:
    for error in errors:
        print("FAIL " + error, file=sys.stderr)
    sys.exit(1)

print("PASS Dokkaebi K8S LiteLLM/Grafana platform package validation passed")
PY
