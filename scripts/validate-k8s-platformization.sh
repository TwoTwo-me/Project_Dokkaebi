#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import sys

try:
    import yaml
except ImportError as exc:
    print(f"FAIL PyYAML is required to validate K8S manifests: {exc}", file=sys.stderr)
    sys.exit(1)

errors: list[str] = []
k8s_evidence_lock_path = Path("docs/enterprise-readiness/k8s-platformization-current-evidence.json")
k8s_fixture_coverage_path = Path("docs/enterprise-readiness/k8s-platformization-fixture-coverage.json")

required_files = [
    Path("docs/adr/0002-k8s-fire-hammer-platformization.md"),
    Path("docs/reports/project-dokkaebi-k8s-handoff.md"),
    Path("docs/enterprise-readiness/k8s-platformization-issues.md"),
    Path("docs/operations/k8s-platformization-fixture-replay-2026-06-14.md"),
    Path("docs/operations/k8s-disposable-api-server-smoke-2026-06-16.md"),
    Path("docs/enterprise-readiness/criteria.json"),
    k8s_evidence_lock_path,
    k8s_fixture_coverage_path,
    Path("k8s/base/kustomization.yaml"),
    Path("k8s/base/namespace.yaml"),
    Path("k8s/base/serviceaccounts.yaml"),
    Path("k8s/base/rbac-fire.yaml"),
    Path("k8s/base/rbac-hammer-profiles.yaml"),
    Path("k8s/base/admission-policy.yaml"),
    Path("k8s/base/networkpolicy.yaml"),
    Path("k8s/fixtures/accepted/hammer-job-no-k8s-approved.yaml"),
    Path("k8s/fixtures/accepted/hammer-job-approved.yaml"),
    Path("k8s/fixtures/accepted/hammer-job-app-deployer-approved.yaml"),
    Path("k8s/fixtures/accepted/hammer-job-job-runner-approved.yaml"),
    Path("k8s/fixtures/rejected/missing-approval-id.yaml"),
    Path("k8s/fixtures/rejected/mismatched-serviceaccount-profile.yaml"),
    Path("k8s/fixtures/rejected/privileged-hostpath.yaml"),
    Path("k8s/fixtures/rejected/secret-env-reference.yaml"),
    Path("k8s/fixtures/rejected/missing-result-packet-sink.yaml"),
    Path("k8s/fixtures/rejected/missing-container-security-context.yaml"),
    Path("k8s/fixtures/rejected/missing-pod-security-context.yaml"),
    Path("k8s/fixtures/rejected/hostnetwork.yaml"),
    Path("k8s/fixtures/rejected/hostport.yaml"),
    Path("k8s/fixtures/rejected/broad-volume-mount.yaml"),
    Path("k8s/fixtures/rejected/hostpid.yaml"),
    Path("k8s/fixtures/rejected/hostipc.yaml"),
    Path("k8s/fixtures/rejected/share-process-namespace.yaml"),
    Path("k8s/fixtures/rejected/init-container-privileged.yaml"),
    Path("k8s/fixtures/rejected/ephemeral-container-privileged.yaml"),
    Path("k8s/fixtures/rejected/root-pod-security-context.yaml"),
    Path("k8s/fixtures/rejected/no-k8s-token-override.yaml"),
    Path("k8s/fixtures/rejected/unapproved-image-profile.yaml"),
    Path("k8s/fixtures/rejected/invalid-result-packet-sink.yaml"),
    Path("k8s/fixtures/rejected/wrong-kind.yaml"),
    Path("k8s/fixtures/rejected/projected-serviceaccount-token.yaml"),
    Path("k8s/fixtures/rejected/projected-secret.yaml"),
    Path("k8s/fixtures/rejected/csi-secret-store.yaml"),
    Path("k8s/fixtures/rejected/image-pull-secrets.yaml"),
    Path("k8s/fixtures/rejected/overlay-traversal-kustomization.yaml"),
    Path("k8s/fixtures/rejected/rbac-extra-workload-permission.yaml"),
    Path("k8s/fixtures/rejected/empty-approval-id.yaml"),
    Path("k8s/fixtures/rejected/empty-credential-grant-id.yaml"),
    Path("k8s/fixtures/rejected/empty-ticket-id.yaml"),
    Path("k8s/fixtures/rejected/container-privileged-only.yaml"),
    Path("k8s/fixtures/rejected/capabilities-add.yaml"),
    Path("k8s/fixtures/rejected/ephemeral-container-secret-env.yaml"),
    Path("k8s/fixtures/rejected/ephemeral-container-root-mount.yaml"),
    Path("k8s/fixtures/rejected/bare-result-packet-sink.yaml"),
    Path("k8s/fixtures/rejected/duplicate-invalid-result-packet-sink.yaml"),
    Path("k8s/fixtures/rejected/duplicate-empty-result-packet-sink.yaml"),
    Path("k8s/fixtures/rejected/init-container-invalid-result-packet-sink.yaml"),
    Path("k8s/fixtures/rejected/init-container-empty-result-packet-sink.yaml"),
    Path("k8s/fixtures/rejected/ephemeral-container-invalid-result-packet-sink.yaml"),
    Path("k8s/fixtures/rejected/ephemeral-container-empty-result-packet-sink.yaml"),
    Path("k8s/fixtures/rejected/empty-resources.yaml"),
    Path("k8s/overlays/local/kustomization.yaml"),
    Path("k8s/overlays/eks/kustomization.yaml"),
]

for path in required_files:
    if not path.is_file():
        errors.append(f"missing file: {path}")

if errors:
    for error in errors:
        print(f"FAIL {error}", file=sys.stderr)
    sys.exit(1)


def read_yaml_documents(path: Path) -> list[dict]:
    try:
        raw_docs = list(yaml.safe_load_all(path.read_text()))
    except yaml.YAMLError as exc:
        errors.append(f"invalid YAML in {path}: {exc}")
        return []
    documents: list[dict] = []
    for doc_index, doc in enumerate(raw_docs, start=1):
        if doc is None:
            continue
        if not isinstance(doc, dict):
            errors.append(f"{path} document {doc_index} must be a Kubernetes mapping")
            continue
        if doc.get("kind") != "List":
            documents.append(doc)
            continue
        items = doc.get("items", [])
        if not isinstance(items, list):
            errors.append(f"{path} document {doc_index} List items must be a list")
            continue
        for item_index, item in enumerate(items, start=1):
            if not isinstance(item, dict):
                errors.append(f"{path} document {doc_index} List item {item_index} must be a mapping")
                continue
            documents.append(item)
    return documents


def load_yaml_mapping(path: Path) -> dict:
    try:
        data = yaml.safe_load(path.read_text())
    except yaml.YAMLError as exc:
        errors.append(f"invalid YAML in {path}: {exc}")
        return {}
    if not isinstance(data, dict):
        errors.append(f"{path} must contain a YAML mapping")
        return {}
    return data


def load_k8s_current_evidence_lock() -> list[str]:
    if not k8s_evidence_lock_path.is_file():
        return []
    try:
        data = json.loads(k8s_evidence_lock_path.read_text())
    except json.JSONDecodeError as exc:
        errors.append(f"invalid JSON in {k8s_evidence_lock_path}: {exc}")
        return []
    if data.get("areaId") != "k8s_platformization":
        errors.append(f"{k8s_evidence_lock_path} areaId must be k8s_platformization")
    evidence = data.get("currentEvidence")
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


def load_fixture_coverage_matrix() -> dict:
    if not k8s_fixture_coverage_path.is_file():
        return {}
    try:
        data = json.loads(k8s_fixture_coverage_path.read_text())
    except json.JSONDecodeError as exc:
        errors.append(f"invalid JSON in {k8s_fixture_coverage_path}: {exc}")
        return {}
    if data.get("areaId") != "k8s_platformization":
        errors.append(f"{k8s_fixture_coverage_path} areaId must be k8s_platformization")
    if data.get("matrixVersion") != 1:
        errors.append(f"{k8s_fixture_coverage_path} matrixVersion must be 1")
    if data.get("issueGate") != "k8s-admission-policy-gate":
        errors.append(f"{k8s_fixture_coverage_path} issueGate must be k8s-admission-policy-gate")
    for field in ["acceptedFixtures", "rejectedFixtures", "nonAdmissionControlFixtures"]:
        if not isinstance(data.get(field), list) or not data.get(field):
            errors.append(f"{k8s_fixture_coverage_path} {field} must be a non-empty list")
    return data


def require_unique_coverage_entries(entries: list[dict], field: str) -> None:
    seen_ids: set[str] = set()
    seen_paths: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            errors.append(f"{k8s_fixture_coverage_path} {field} entries must be mappings")
            continue
        coverage_id = entry.get("coverageId")
        path = entry.get("path")
        if not isinstance(coverage_id, str) or not coverage_id:
            errors.append(f"{k8s_fixture_coverage_path} {field} entry missing coverageId")
        elif coverage_id in seen_ids:
            errors.append(f"{k8s_fixture_coverage_path} duplicate coverageId: {coverage_id}")
        else:
            seen_ids.add(coverage_id)
        if not isinstance(path, str) or not path:
            errors.append(f"{k8s_fixture_coverage_path} {field} entry missing path")
        elif path in seen_paths:
            errors.append(f"{k8s_fixture_coverage_path} duplicate fixture path: {path}")
        else:
            seen_paths.add(path)
        if isinstance(path, str) and not Path(path).is_file():
            errors.append(f"{k8s_fixture_coverage_path} fixture path does not exist: {path}")


fixture_coverage_matrix = load_fixture_coverage_matrix()
require_unique_coverage_entries(
    fixture_coverage_matrix.get("acceptedFixtures", [])
    if isinstance(fixture_coverage_matrix.get("acceptedFixtures"), list)
    else [],
    "acceptedFixtures",
)
require_unique_coverage_entries(
    fixture_coverage_matrix.get("rejectedFixtures", [])
    if isinstance(fixture_coverage_matrix.get("rejectedFixtures"), list)
    else [],
    "rejectedFixtures",
)
require_unique_coverage_entries(
    fixture_coverage_matrix.get("nonAdmissionControlFixtures", [])
    if isinstance(fixture_coverage_matrix.get("nonAdmissionControlFixtures"), list)
    else [],
    "nonAdmissionControlFixtures",
)


base_dir = Path("k8s/base")
base_kustomization = load_yaml_mapping(base_dir / "kustomization.yaml")
unexpected_base_keys = set(base_kustomization) - {"apiVersion", "kind", "resources"}
if unexpected_base_keys:
    errors.append(
        "k8s/base/kustomization.yaml may only declare resources; unexpected keys: "
        + ", ".join(sorted(unexpected_base_keys))
    )
if base_kustomization.get("kind") != "Kustomization":
    errors.append("k8s/base/kustomization.yaml kind must be Kustomization")
base_resources = base_kustomization.get("resources", [])
if not isinstance(base_resources, list):
    errors.append("k8s/base/kustomization.yaml resources must be a list")
    base_resources = []

required_base_resources = {
    "namespace.yaml",
    "serviceaccounts.yaml",
    "rbac-fire.yaml",
    "rbac-hammer-profiles.yaml",
    "admission-policy.yaml",
    "networkpolicy.yaml",
}
listed_base_resources = {
    resource for resource in base_resources if isinstance(resource, str)
}
for resource in sorted(required_base_resources - listed_base_resources):
    errors.append(f"k8s/base/kustomization.yaml missing resource: {resource}")

manifest_paths: list[Path] = []
for resource in base_resources:
    if not isinstance(resource, str):
        errors.append(f"k8s/base/kustomization.yaml has non-string resource: {resource!r}")
        continue
    resource_path = Path(resource)
    if resource_path.is_absolute() or ".." in resource_path.parts:
        errors.append(f"k8s/base/kustomization.yaml resource must stay under k8s/base: {resource}")
        continue
    manifest_path = base_dir / resource_path
    if not manifest_path.is_file():
        errors.append(f"k8s/base/kustomization.yaml resource is not a file: {resource}")
        continue
    if manifest_path.suffix not in {".yaml", ".yml"}:
        errors.append(f"k8s/base/kustomization.yaml resource must be YAML: {resource}")
        continue
    manifest_paths.append(manifest_path)

documents: list[dict] = []
for manifest_path in manifest_paths:
    documents.extend(read_yaml_documents(manifest_path))

by_kind_name: dict[tuple[str, str, str], dict] = {}
for doc in documents:
    kind = str(doc.get("kind", ""))
    metadata = doc.get("metadata", {}) if isinstance(doc.get("metadata"), dict) else {}
    name = str(metadata.get("name", ""))
    namespace = str(metadata.get("namespace", ""))
    by_kind_name[(kind, namespace, name)] = doc

for key in [
    ("Namespace", "", "dokkaebi-system"),
    ("Namespace", "", "dokkaebi-workers"),
    ("ServiceAccount", "dokkaebi-system", "dokkaebi-fire"),
    ("ServiceAccount", "dokkaebi-workers", "hammer-no-k8s"),
    ("ServiceAccount", "dokkaebi-workers", "hammer-k8s-readonly"),
    ("ServiceAccount", "dokkaebi-workers", "hammer-k8s-app-deployer"),
    ("ServiceAccount", "dokkaebi-workers", "hammer-k8s-job-runner"),
    ("ServiceAccount", "dokkaebi-workers", "hammer-breakglass"),
    ("Role", "dokkaebi-workers", "dokkaebi-fire-job-orchestrator"),
    ("Role", "dokkaebi-workers", "hammer-k8s-readonly"),
    ("Role", "dokkaebi-workers", "hammer-k8s-app-deployer"),
    ("Role", "dokkaebi-workers", "hammer-k8s-job-runner"),
    ("RoleBinding", "dokkaebi-workers", "dokkaebi-fire-job-orchestrator"),
    ("RoleBinding", "dokkaebi-workers", "hammer-k8s-readonly"),
    ("RoleBinding", "dokkaebi-workers", "hammer-k8s-app-deployer"),
    ("RoleBinding", "dokkaebi-workers", "hammer-k8s-job-runner"),
    ("ValidatingAdmissionPolicy", "", "dokkaebi-hammer-job-policy"),
    ("ValidatingAdmissionPolicyBinding", "", "dokkaebi-hammer-job-policy-binding"),
    ("NetworkPolicy", "dokkaebi-workers", "default-deny-hammer-workers"),
    ("NetworkPolicy", "dokkaebi-workers", "allow-dns-egress"),
    ("NetworkPolicy", "dokkaebi-system", "default-deny-fire-system"),
    ("NetworkPolicy", "dokkaebi-system", "allow-fire-dns-egress"),
]:
    if key not in by_kind_name:
        errors.append(f"missing K8S object: {key[0]}/{key[1]}/{key[2]}")

for doc in documents:
    kind = doc.get("kind")
    if kind in {"ClusterRole", "ClusterRoleBinding"}:
        errors.append(f"cluster-scoped RBAC object is forbidden: {kind}")

forbidden_resources = {
    "secrets",
    "roles",
    "rolebindings",
    "clusterroles",
    "clusterrolebindings",
    "namespaces",
    "nodes",
    "persistentvolumes",
    "customresourcedefinitions",
}
for doc in documents:
    if doc.get("kind") != "Role":
        continue
    metadata = doc.get("metadata", {}) if isinstance(doc.get("metadata"), dict) else {}
    role_name = metadata.get("name", "<missing>")
    for rule in doc.get("rules", []):
        resources = set(rule.get("resources", []))
        forbidden = sorted(resources & forbidden_resources)
        if forbidden:
            errors.append(f"{role_name} grants forbidden resources: {', '.join(forbidden)}")
        verbs = set(rule.get("verbs", []))
        if "*" in resources or "*" in verbs:
            errors.append(f"{role_name} must not use wildcard resources or verbs")


def normalize_rule(rule: dict) -> tuple[tuple[str, ...], tuple[str, ...], tuple[str, ...]]:
    return (
        tuple(sorted(str(item) for item in rule.get("apiGroups", []))),
        tuple(sorted(str(item) for item in rule.get("resources", []))),
        tuple(sorted(str(item) for item in rule.get("verbs", []))),
    )


expected_role_rules: dict[str, set[tuple[tuple[str, ...], tuple[str, ...], tuple[str, ...]]]] = {
    "dokkaebi-fire-job-orchestrator": {
        (("batch",), ("jobs",), ("create", "delete", "get", "list", "watch")),
        (("",), ("pods",), ("get", "list", "watch")),
        (("",), ("pods/log",), ("get",)),
        (("",), ("events",), ("get", "list", "watch")),
        (("",), ("configmaps",), ("get", "list", "watch")),
    },
    "hammer-k8s-readonly": {
        (("",), ("configmaps", "events", "pods", "pods/log"), ("get", "list", "watch")),
        (("batch",), ("jobs",), ("get", "list", "watch")),
    },
    "hammer-k8s-app-deployer": {
        (("apps",), ("deployments", "replicasets", "statefulsets"), ("get", "list", "watch")),
        (("",), ("configmaps", "events", "pods", "pods/log", "services"), ("get", "list", "watch")),
    },
    "hammer-k8s-job-runner": {
        (("batch",), ("jobs",), ("create", "delete", "get", "list", "patch", "update", "watch")),
        (("",), ("configmaps", "events", "pods", "pods/log"), ("get", "list", "watch")),
    },
}


def role_errors(role: dict) -> list[str]:
    found: list[str] = []
    metadata = role.get("metadata", {}) if isinstance(role.get("metadata"), dict) else {}
    role_name = str(metadata.get("name", "<missing>"))
    expected = expected_role_rules.get(role_name)
    if expected is None:
        return [f"undocumented Role is forbidden: {role_name}"]
    actual = {
        normalize_rule(rule)
        for rule in role.get("rules", [])
        if isinstance(rule, dict)
    }
    if actual != expected:
        found.append(f"{role_name} must match exact approved RBAC rules")
    return found


for doc in documents:
    if doc.get("kind") == "Role":
        errors.extend(role_errors(doc))

no_k8s = by_kind_name.get(("ServiceAccount", "dokkaebi-workers", "hammer-no-k8s"), {})
if no_k8s.get("automountServiceAccountToken") is not False:
    errors.append("hammer-no-k8s must set automountServiceAccountToken: false")

breakglass = by_kind_name.get(("ServiceAccount", "dokkaebi-workers", "hammer-breakglass"), {})
if breakglass.get("automountServiceAccountToken") is not False:
    errors.append("hammer-breakglass must set automountServiceAccountToken: false until approved")

expected_role_ref_by_binding = {
    ("dokkaebi-workers", "dokkaebi-fire-job-orchestrator"): "dokkaebi-fire-job-orchestrator",
    ("dokkaebi-workers", "hammer-k8s-readonly"): "hammer-k8s-readonly",
    ("dokkaebi-workers", "hammer-k8s-app-deployer"): "hammer-k8s-app-deployer",
    ("dokkaebi-workers", "hammer-k8s-job-runner"): "hammer-k8s-job-runner",
}
expected_subjects_by_binding = {
    ("dokkaebi-workers", "dokkaebi-fire-job-orchestrator"): {
        ("ServiceAccount", "dokkaebi-system", "dokkaebi-fire"),
    },
    ("dokkaebi-workers", "hammer-k8s-readonly"): {
        ("ServiceAccount", "dokkaebi-workers", "hammer-k8s-readonly"),
    },
    ("dokkaebi-workers", "hammer-k8s-app-deployer"): {
        ("ServiceAccount", "dokkaebi-workers", "hammer-k8s-app-deployer"),
    },
    ("dokkaebi-workers", "hammer-k8s-job-runner"): {
        ("ServiceAccount", "dokkaebi-workers", "hammer-k8s-job-runner"),
    },
}

for doc in documents:
    if doc.get("kind") != "RoleBinding":
        continue
    metadata = doc.get("metadata", {}) if isinstance(doc.get("metadata"), dict) else {}
    binding_name = metadata.get("name", "<missing>")
    binding_namespace = metadata.get("namespace", "")
    binding_key = (str(binding_namespace), str(binding_name))
    role_ref = doc.get("roleRef", {}) if isinstance(doc.get("roleRef"), dict) else {}
    role_ref_name = role_ref.get("name", "<missing>")
    expected_role_ref_name = expected_role_ref_by_binding.get(binding_key)
    if role_ref.get("apiGroup") != "rbac.authorization.k8s.io":
        errors.append(f"{binding_name} roleRef must use rbac.authorization.k8s.io")
    if role_ref.get("kind") != "Role":
        errors.append(f"{binding_name} roleRef must reference a namespaced Role")
    elif ("Role", binding_namespace, str(role_ref_name)) not in by_kind_name:
        errors.append(f"{binding_name} roleRef references missing Role: {role_ref_name}")
    if expected_role_ref_name is None:
        errors.append(f"undocumented RoleBinding is forbidden: {binding_name}")
    elif role_ref_name != expected_role_ref_name:
        errors.append(f"{binding_name} roleRef must reference approved Role {expected_role_ref_name}")
    expected_subjects = expected_subjects_by_binding.get(binding_key)
    actual_subjects = {
        (
            str(subject.get("kind", "")),
            str(subject.get("namespace", binding_namespace)),
            str(subject.get("name", "")),
        )
        for subject in doc.get("subjects", [])
        if isinstance(subject, dict)
    }
    if expected_subjects is None:
        pass
    elif actual_subjects != expected_subjects:
        errors.append(f"{binding_name} must bind only its approved ServiceAccount subject")
    for subject in doc.get("subjects", []):
        if not isinstance(subject, dict):
            errors.append(f"{binding_name} subject must be a mapping")
            continue
        subject_name = subject.get("name")
        if subject_name in {"hammer-no-k8s", "hammer-breakglass"}:
            errors.append(f"{binding_name} must not bind inactive profile: {subject_name}")


def validate_default_deny(namespace: str, name: str, subject: str) -> None:
    policy = by_kind_name.get(("NetworkPolicy", namespace, name), {})
    spec = policy.get("spec", {}) if isinstance(policy.get("spec"), dict) else {}
    policy_types = set(spec.get("policyTypes", []))
    if policy_types != {"Ingress", "Egress"}:
        errors.append(f"{name} must deny both ingress and egress")
    if spec.get("podSelector") != {}:
        errors.append(f"{name} must select all {subject} pods")
    if spec.get("ingress") not in (None, []):
        errors.append(f"{name} must not allow ingress")
    if spec.get("egress") not in (None, []):
        errors.append(f"{name} must not allow egress")


validate_default_deny("dokkaebi-workers", "default-deny-hammer-workers", "worker")
validate_default_deny("dokkaebi-system", "default-deny-fire-system", "Fire")

allowed_network_policies = {
    ("dokkaebi-workers", "default-deny-hammer-workers"),
    ("dokkaebi-workers", "allow-dns-egress"),
    ("dokkaebi-system", "default-deny-fire-system"),
    ("dokkaebi-system", "allow-fire-dns-egress"),
}
for doc in documents:
    if doc.get("kind") != "NetworkPolicy":
        continue
    metadata = doc.get("metadata", {}) if isinstance(doc.get("metadata"), dict) else {}
    name = metadata.get("name", "<missing>")
    namespace = metadata.get("namespace", "")
    if (namespace, name) not in allowed_network_policies:
        errors.append(f"undocumented NetworkPolicy is forbidden: {name}")


def validate_dns_policy(namespace: str, name: str, subject: str) -> None:
    dns_policy = by_kind_name.get(("NetworkPolicy", namespace, name), {})
    dns_spec = dns_policy.get("spec", {}) if isinstance(dns_policy.get("spec"), dict) else {}
    if set(dns_spec.get("policyTypes", [])) != {"Egress"}:
        errors.append(f"{name} must be egress-only")
    if dns_spec.get("podSelector") != {}:
        errors.append(f"{name} must select all {subject} pods")
    if dns_spec.get("ingress") not in (None, []):
        errors.append(f"{name} must not allow ingress")
    dns_egress = dns_spec.get("egress", [])
    if len(dns_egress) != 1 or not isinstance(dns_egress[0], dict):
        errors.append(f"{name} must define exactly one egress rule")
        return
    rule = dns_egress[0]
    if not rule:
        errors.append(f"{name} must not use a catch-all egress rule")
    if set(rule) != {"to", "ports"}:
        errors.append(f"{name} may only declare to and ports")
    destinations = rule.get("to", [])
    ports = rule.get("ports", [])
    expected_destination = {
        "namespaceSelector": {
            "matchLabels": {
                "kubernetes.io/metadata.name": "kube-system",
            },
        },
        "podSelector": {
            "matchLabels": {
                "k8s-app": "kube-dns",
            },
        },
    }
    if not isinstance(destinations, list) or destinations != [expected_destination]:
        errors.append(f"{name} must target only kube-system DNS pods")
    expected_ports = {("UDP", 53), ("TCP", 53)}
    actual_ports: set[tuple[str, int]] = set()
    invalid_port = False
    if not isinstance(ports, list):
        invalid_port = True
    else:
        for port in ports:
            if not isinstance(port, dict) or set(port) != {"protocol", "port"}:
                invalid_port = True
                continue
            try:
                port_number = int(port.get("port", 0))
            except (TypeError, ValueError):
                invalid_port = True
                continue
            actual_ports.add((str(port.get("protocol", "")), port_number))
    if invalid_port or len(ports) != 2 or actual_ports != expected_ports:
        errors.append(f"{name} must allow only TCP/UDP port 53")


validate_dns_policy("dokkaebi-workers", "allow-dns-egress", "worker")
validate_dns_policy("dokkaebi-system", "allow-fire-dns-egress", "Fire")

admission_policy = by_kind_name.get(("ValidatingAdmissionPolicy", "", "dokkaebi-hammer-job-policy"), {})
policy_spec = admission_policy.get("spec", {}) if isinstance(admission_policy.get("spec"), dict) else {}
if policy_spec.get("failurePolicy") != "Fail":
    errors.append("dokkaebi-hammer-job-policy must fail closed")
resource_rules = (
    policy_spec.get("matchConstraints", {}).get("resourceRules", [])
    if isinstance(policy_spec.get("matchConstraints"), dict)
    else []
)
expected_resource_rule = {
    "apiGroups": ["batch"],
    "apiVersions": ["v1"],
    "operations": ["CREATE", "UPDATE"],
    "resources": ["jobs"],
}
if resource_rules != [expected_resource_rule]:
    errors.append("dokkaebi-hammer-job-policy must match only batch/v1 Jobs on CREATE and UPDATE")
expected_policy_validations = [
    (
        "Hammer Jobs selected for this binding must stay in dokkaebi-workers",
        "object.metadata.namespace == 'dokkaebi-workers'",
    ),
    (
        "Hammer Jobs must include non-empty Dokkaebi routing, approval, credential, and image-profile labels",
        "'dokkaebi.io/ticket-id' in object.metadata.labels && object.metadata.labels['dokkaebi.io/ticket-id'] != '' && 'dokkaebi.io/tenant-id' in object.metadata.labels && object.metadata.labels['dokkaebi.io/tenant-id'] != '' && 'dokkaebi.io/approval-id' in object.metadata.labels && object.metadata.labels['dokkaebi.io/approval-id'] != '' && 'dokkaebi.io/route-profile' in object.metadata.labels && object.metadata.labels['dokkaebi.io/route-profile'] != '' && 'dokkaebi.io/credential-grant-id' in object.metadata.labels && object.metadata.labels['dokkaebi.io/credential-grant-id'] != '' && 'dokkaebi.io/image-profile' in object.metadata.labels && object.metadata.labels['dokkaebi.io/image-profile'] != ''",
    ),
    (
        "Hammer Jobs must use an approved image profile",
        "object.metadata.labels['dokkaebi.io/image-profile'] == 'dokkaebi-hammer-dev-sandbox' && object.spec.template.spec.containers.all(c, c.image == 'ghcr.io/project-dokkaebi/hammer:dev-sandbox') && (!has(object.spec.template.spec.initContainers) || object.spec.template.spec.initContainers.all(c, c.image == 'ghcr.io/project-dokkaebi/hammer:dev-sandbox')) && (!has(object.spec.template.spec.ephemeralContainers) || object.spec.template.spec.ephemeralContainers.all(c, c.image == 'ghcr.io/project-dokkaebi/hammer:dev-sandbox'))",
    ),
    (
        "Hammer Job route profile must match its ServiceAccount and no-k8s token boundary",
        "(object.metadata.labels['dokkaebi.io/route-profile'] == 'hammer-no-k8s' && object.spec.template.spec.serviceAccountName == 'hammer-no-k8s' && has(object.spec.template.spec.automountServiceAccountToken) && object.spec.template.spec.automountServiceAccountToken == false) || (object.metadata.labels['dokkaebi.io/route-profile'] == 'hammer-k8s-readonly' && object.spec.template.spec.serviceAccountName == 'hammer-k8s-readonly') || (object.metadata.labels['dokkaebi.io/route-profile'] == 'hammer-k8s-app-deployer' && object.spec.template.spec.serviceAccountName == 'hammer-k8s-app-deployer') || (object.metadata.labels['dokkaebi.io/route-profile'] == 'hammer-k8s-job-runner' && object.spec.template.spec.serviceAccountName == 'hammer-k8s-job-runner')",
    ),
    ("Hammer Jobs must not use imagePullSecrets", "!has(object.spec.template.spec.imagePullSecrets) || object.spec.template.spec.imagePullSecrets.size() == 0"),
    ("Hammer Jobs must not use hostNetwork", "!has(object.spec.template.spec.hostNetwork) || object.spec.template.spec.hostNetwork == false"),
    ("Hammer containers must not use hostPort", "object.spec.template.spec.containers.all(c, !has(c.ports) || c.ports.all(p, !has(p.hostPort) || p.hostPort == 0)) && (!has(object.spec.template.spec.initContainers) || object.spec.template.spec.initContainers.all(c, !has(c.ports) || c.ports.all(p, !has(p.hostPort) || p.hostPort == 0)))"),
    ("Hammer Jobs must not use hostPID", "!has(object.spec.template.spec.hostPID) || object.spec.template.spec.hostPID == false"),
    ("Hammer Jobs must not use hostIPC", "!has(object.spec.template.spec.hostIPC) || object.spec.template.spec.hostIPC == false"),
    ("Hammer Jobs must not share process namespaces", "!has(object.spec.template.spec.shareProcessNamespace) || object.spec.template.spec.shareProcessNamespace == false"),
    (
        "Hammer Jobs must use a non-root pod security context with RuntimeDefault seccomp",
        "has(object.spec.template.spec.securityContext) && object.spec.template.spec.securityContext.runAsNonRoot == true && object.spec.template.spec.securityContext.runAsUser > 0 && object.spec.template.spec.securityContext.seccompProfile.type == 'RuntimeDefault'",
    ),
    (
        "Hammer containers must use the approved non-root security context",
        "object.spec.template.spec.containers.all(c, has(c.securityContext) && (!has(c.securityContext.privileged) || c.securityContext.privileged == false) && c.securityContext.allowPrivilegeEscalation == false && c.securityContext.readOnlyRootFilesystem == true && c.securityContext.runAsNonRoot == true && c.securityContext.runAsUser > 0 && c.securityContext.seccompProfile.type == 'RuntimeDefault' && 'ALL' in c.securityContext.capabilities.drop && (!has(c.securityContext.capabilities.add) || c.securityContext.capabilities.add.size() == 0))",
    ),
    (
        "Hammer init and ephemeral containers must use the approved non-root security context",
        "(!has(object.spec.template.spec.initContainers) || object.spec.template.spec.initContainers.all(c, has(c.securityContext) && (!has(c.securityContext.privileged) || c.securityContext.privileged == false) && c.securityContext.allowPrivilegeEscalation == false && c.securityContext.readOnlyRootFilesystem == true && c.securityContext.runAsNonRoot == true && c.securityContext.runAsUser > 0 && c.securityContext.seccompProfile.type == 'RuntimeDefault' && 'ALL' in c.securityContext.capabilities.drop && (!has(c.securityContext.capabilities.add) || c.securityContext.capabilities.add.size() == 0))) && (!has(object.spec.template.spec.ephemeralContainers) || object.spec.template.spec.ephemeralContainers.all(c, has(c.securityContext) && (!has(c.securityContext.privileged) || c.securityContext.privileged == false) && c.securityContext.allowPrivilegeEscalation == false && c.securityContext.readOnlyRootFilesystem == true && c.securityContext.runAsNonRoot == true && c.securityContext.runAsUser > 0 && c.securityContext.seccompProfile.type == 'RuntimeDefault' && 'ALL' in c.securityContext.capabilities.drop && (!has(c.securityContext.capabilities.add) || c.securityContext.capabilities.add.size() == 0)))",
    ),
    (
        "Hammer containers must declare resource requests and limits",
        "object.spec.template.spec.containers.all(c, has(c.resources) && has(c.resources.requests) && c.resources.requests.size() > 0 && has(c.resources.limits) && c.resources.limits.size() > 0) && (!has(object.spec.template.spec.initContainers) || object.spec.template.spec.initContainers.all(c, has(c.resources) && has(c.resources.requests) && c.resources.requests.size() > 0 && has(c.resources.limits) && c.resources.limits.size() > 0))",
    ),
    (
        "Hammer Jobs must not mount hostPath, Secret, projected token, projected Secret, or CSI secret-store volumes",
        "!has(object.spec.template.spec.volumes) || object.spec.template.spec.volumes.all(v, !has(v.hostPath) && !has(v.secret) && (!has(v.projected) || v.projected.sources.all(s, !has(s.secret) && !has(s.serviceAccountToken))) && (!has(v.csi) || v.csi.driver != 'secrets-store.csi.k8s.io'))",
    ),
    (
        "Hammer containers must not mount broad filesystem roots",
        "object.spec.template.spec.containers.all(c, !has(c.volumeMounts) || c.volumeMounts.all(m, m.mountPath != '/')) && (!has(object.spec.template.spec.initContainers) || object.spec.template.spec.initContainers.all(c, !has(c.volumeMounts) || c.volumeMounts.all(m, m.mountPath != '/'))) && (!has(object.spec.template.spec.ephemeralContainers) || object.spec.template.spec.ephemeralContainers.all(c, !has(c.volumeMounts) || c.volumeMounts.all(m, m.mountPath != '/')))",
    ),
    (
        "Hammer containers must not reference Secrets through env",
        "object.spec.template.spec.containers.all(c, (!has(c.envFrom) || c.envFrom.all(e, !has(e.secretRef))) && (!has(c.env) || c.env.all(e, !has(e.valueFrom) || !has(e.valueFrom.secretKeyRef)))) && (!has(object.spec.template.spec.initContainers) || object.spec.template.spec.initContainers.all(c, (!has(c.envFrom) || c.envFrom.all(e, !has(e.secretRef))) && (!has(c.env) || c.env.all(e, !has(e.valueFrom) || !has(e.valueFrom.secretKeyRef))))) && (!has(object.spec.template.spec.ephemeralContainers) || object.spec.template.spec.ephemeralContainers.all(c, (!has(c.envFrom) || c.envFrom.all(e, !has(e.secretRef))) && (!has(c.env) || c.env.all(e, !has(e.valueFrom) || !has(e.valueFrom.secretKeyRef)))))",
    ),
    (
        "Hammer Jobs must declare an approved durable result packet sink matching the ticket id",
        "object.spec.template.spec.containers.all(c, !has(c.env) || c.env.all(e, e.name != 'DOKKAEBI_RESULT_PACKET_SINK' || e.value == 'github-workpad://Project_Dokkaebi_K8S/issues/' + object.metadata.labels['dokkaebi.io/ticket-id'])) && (!has(object.spec.template.spec.initContainers) || object.spec.template.spec.initContainers.all(c, !has(c.env) || c.env.all(e, e.name != 'DOKKAEBI_RESULT_PACKET_SINK' || e.value == 'github-workpad://Project_Dokkaebi_K8S/issues/' + object.metadata.labels['dokkaebi.io/ticket-id']))) && (!has(object.spec.template.spec.ephemeralContainers) || object.spec.template.spec.ephemeralContainers.all(c, !has(c.env) || c.env.all(e, e.name != 'DOKKAEBI_RESULT_PACKET_SINK' || e.value == 'github-workpad://Project_Dokkaebi_K8S/issues/' + object.metadata.labels['dokkaebi.io/ticket-id']))) && object.spec.template.spec.containers.exists(c, has(c.env) && c.env.exists(e, e.name == 'DOKKAEBI_RESULT_PACKET_SINK' && e.value == 'github-workpad://Project_Dokkaebi_K8S/issues/' + object.metadata.labels['dokkaebi.io/ticket-id']))",
    ),
]
actual_policy_validations = [
    (validation.get("message", ""), validation.get("expression", ""))
    for validation in policy_spec.get("validations", [])
    if isinstance(validation, dict)
]
if actual_policy_validations != expected_policy_validations:
    errors.append("dokkaebi-hammer-job-policy validations must match exact approved CEL expressions")

admission_binding = by_kind_name.get(
    ("ValidatingAdmissionPolicyBinding", "", "dokkaebi-hammer-job-policy-binding"),
    {},
)
binding_spec = admission_binding.get("spec", {}) if isinstance(admission_binding.get("spec"), dict) else {}
if binding_spec.get("policyName") != "dokkaebi-hammer-job-policy":
    errors.append("dokkaebi-hammer-job-policy-binding must bind dokkaebi-hammer-job-policy")
if binding_spec.get("validationActions") != ["Deny"]:
    errors.append("dokkaebi-hammer-job-policy-binding must deny invalid Jobs")
namespace_selector = (
    binding_spec.get("matchResources", {}).get("namespaceSelector", {})
    if isinstance(binding_spec.get("matchResources"), dict)
    else {}
)
expected_namespace_selector = {
    "matchLabels": {
        "kubernetes.io/metadata.name": "dokkaebi-workers",
    },
}
if namespace_selector != expected_namespace_selector:
    errors.append("dokkaebi-hammer-job-policy-binding must scope to dokkaebi-workers")


def overlay_errors(overlay: Path) -> list[str]:
    found: list[str] = []
    overlay_data = load_yaml_mapping(overlay)
    unexpected_overlay_keys = set(overlay_data) - {"apiVersion", "kind", "resources"}
    if unexpected_overlay_keys:
        found.append(
            f"{overlay} may only declare apiVersion, kind, and resources; unexpected keys: "
            + ", ".join(sorted(unexpected_overlay_keys))
        )
    if overlay_data.get("kind") != "Kustomization":
        found.append(f"{overlay} kind must be Kustomization")
    resources = overlay_data.get("resources", [])
    if not isinstance(resources, list):
        found.append(f"{overlay} resources must be a list")
        resources = []
    if resources != ["../../base"]:
        found.append(f"{overlay} resources must be exactly ../../base")
    return found


for overlay in [Path("k8s/overlays/local/kustomization.yaml"), Path("k8s/overlays/eks/kustomization.yaml")]:
    errors.extend(overlay_errors(overlay))

overlay_rejected_expectations = {
    Path("k8s/fixtures/rejected/overlay-traversal-kustomization.yaml"): "resources must be exactly ../../base",
}
for rejected_overlay, expected_error in overlay_rejected_expectations.items():
    fixture_errors = overlay_errors(rejected_overlay)
    if not fixture_errors:
        errors.append(f"{rejected_overlay} should be rejected but has no overlay errors")
        continue
    if not any(expected_error in fixture_error for fixture_error in fixture_errors):
        errors.append(
            f"{rejected_overlay} missing expected rejection {expected_error}; got {', '.join(fixture_errors)}"
        )


def load_single_yaml(path: Path) -> dict:
    docs = read_yaml_documents(path)
    if len(docs) != 1:
        errors.append(f"{path} must contain exactly one YAML document")
        return {}
    return docs[0]


def pod_spec(job: dict) -> dict:
    spec = job.get("spec", {}) if isinstance(job.get("spec"), dict) else {}
    template = spec.get("template", {}) if isinstance(spec.get("template"), dict) else {}
    return template.get("spec", {}) if isinstance(template.get("spec"), dict) else {}


def container_specs(job: dict) -> list[dict]:
    spec = pod_spec(job)
    containers = spec.get("containers", [])
    return [container for container in containers if isinstance(container, dict)]


def named_container_specs(job: dict) -> list[tuple[str, dict]]:
    spec = pod_spec(job)
    containers: list[tuple[str, dict]] = []
    for field, label in [
        ("containers", "container"),
        ("initContainers", "initContainer"),
        ("ephemeralContainers", "ephemeralContainer"),
    ]:
        for container in spec.get(field, []) or []:
            if isinstance(container, dict):
                containers.append((label, container))
    return containers


profile_service_accounts = {
    "hammer-no-k8s": "hammer-no-k8s",
    "hammer-k8s-readonly": "hammer-k8s-readonly",
    "hammer-k8s-app-deployer": "hammer-k8s-app-deployer",
    "hammer-k8s-job-runner": "hammer-k8s-job-runner",
}
image_profile_images = {
    "dokkaebi-hammer-dev-sandbox": "ghcr.io/project-dokkaebi/hammer:dev-sandbox",
}
approved_result_sink_prefix = "github-workpad://Project_Dokkaebi_K8S/issues/"


def admission_errors(job: dict) -> list[str]:
    found: list[str] = []
    if job.get("apiVersion") != "batch/v1":
        found.append("apiVersion must be batch/v1")
    if job.get("kind") != "Job":
        found.append("kind must be Job")
    if found:
        return found
    metadata = job.get("metadata", {}) if isinstance(job.get("metadata"), dict) else {}
    labels = metadata.get("labels", {}) if isinstance(metadata.get("labels"), dict) else {}
    for label in [
        "dokkaebi.io/ticket-id",
        "dokkaebi.io/tenant-id",
        "dokkaebi.io/approval-id",
        "dokkaebi.io/route-profile",
        "dokkaebi.io/credential-grant-id",
        "dokkaebi.io/image-profile",
    ]:
        if not labels.get(label):
            found.append(f"missing label {label}")
    if metadata.get("namespace") != "dokkaebi-workers":
        found.append("namespace must be dokkaebi-workers")

    profile = labels.get("dokkaebi.io/route-profile")
    expected_service_account = profile_service_accounts.get(profile)
    spec = pod_spec(job)
    if expected_service_account is None:
        found.append(f"unknown route profile {profile}")
    elif spec.get("serviceAccountName") != expected_service_account:
        found.append("route profile and ServiceAccount mismatch")
    if profile == "hammer-no-k8s" and spec.get("automountServiceAccountToken") is not False:
        found.append("hammer-no-k8s must not mount Kubernetes API token")
    image_profile = labels.get("dokkaebi.io/image-profile")
    expected_image = image_profile_images.get(image_profile)
    if expected_image is None:
        found.append("unapproved image profile")
    if spec.get("imagePullSecrets"):
        found.append("imagePullSecrets are forbidden")

    if spec.get("hostNetwork") is True:
        found.append("hostNetwork is forbidden")
    if spec.get("hostPID") is True:
        found.append("hostPID is forbidden")
    if spec.get("hostIPC") is True:
        found.append("hostIPC is forbidden")
    if spec.get("shareProcessNamespace") is True:
        found.append("shareProcessNamespace is forbidden")
    pod_security_context = spec.get("securityContext", {})
    if not isinstance(pod_security_context, dict) or not pod_security_context:
        found.append("pod securityContext is required")
    else:
        if pod_security_context.get("runAsNonRoot") is not True:
            found.append("pod runAsNonRoot true is required")
        run_as_user = pod_security_context.get("runAsUser")
        if not isinstance(run_as_user, int) or run_as_user <= 0:
            found.append("pod non-root runAsUser is required")
        seccomp_profile = pod_security_context.get("seccompProfile", {})
        if not isinstance(seccomp_profile, dict) or seccomp_profile.get("type") != "RuntimeDefault":
            found.append("pod RuntimeDefault seccompProfile is required")
    for volume in spec.get("volumes", []) or []:
        if not isinstance(volume, dict):
            continue
        if "hostPath" in volume:
            found.append("hostPath volume is forbidden")
        if "secret" in volume:
            found.append("Secret volume is forbidden")
        projected = volume.get("projected", {})
        if isinstance(projected, dict):
            for source in projected.get("sources", []) or []:
                if not isinstance(source, dict):
                    continue
                if "serviceAccountToken" in source:
                    found.append("projected serviceAccountToken volume is forbidden")
                if "secret" in source:
                    found.append("projected Secret volume is forbidden")
        csi = volume.get("csi", {})
        if isinstance(csi, dict) and csi.get("driver") == "secrets-store.csi.k8s.io":
            found.append("CSI secret-store volume is forbidden")

    containers = container_specs(job)
    if not containers:
        found.append("job must define at least one container")
    saw_result_sink = False
    for container_kind, container in named_container_specs(job):
        if expected_image is not None and container.get("image") != expected_image:
            found.append(f"{container_kind} image must match approved image profile")
        security_context = container.get("securityContext", {})
        if not isinstance(security_context, dict) or not security_context:
            found.append(f"{container_kind} securityContext is required")
        else:
            if security_context.get("privileged") is True:
                found.append(f"{container_kind} privileged container is forbidden")
            if security_context.get("allowPrivilegeEscalation") is not False:
                found.append(f"{container_kind} allowPrivilegeEscalation false is required")
            if security_context.get("readOnlyRootFilesystem") is not True:
                found.append(f"{container_kind} readOnlyRootFilesystem true is required")
            if security_context.get("runAsNonRoot") is not True:
                found.append(f"{container_kind} runAsNonRoot true is required")
            run_as_user = security_context.get("runAsUser")
            if not isinstance(run_as_user, int) or run_as_user <= 0:
                found.append(f"{container_kind} non-root runAsUser is required")
            seccomp_profile = security_context.get("seccompProfile", {})
            if not isinstance(seccomp_profile, dict) or seccomp_profile.get("type") != "RuntimeDefault":
                found.append(f"{container_kind} RuntimeDefault seccompProfile is required")
            capabilities = security_context.get("capabilities", {})
            drops = capabilities.get("drop", []) if isinstance(capabilities, dict) else []
            if "ALL" not in drops:
                found.append(f"{container_kind} must drop ALL capabilities")
            adds = capabilities.get("add", []) if isinstance(capabilities, dict) else []
            if adds:
                found.append(f"{container_kind} capabilities.add is forbidden")
        if container_kind in {"container", "initContainer"}:
            for port in container.get("ports", []) or []:
                if isinstance(port, dict) and port.get("hostPort") not in (None, 0):
                    found.append(f"{container_kind} hostPort is forbidden")
            resources = container.get("resources", {}) if isinstance(container.get("resources"), dict) else {}
            if not resources.get("requests") or not resources.get("limits"):
                found.append(f"{container_kind} must define resource requests and limits")
        for volume_mount in container.get("volumeMounts", []) or []:
            if not isinstance(volume_mount, dict):
                continue
            if volume_mount.get("mountPath") == "/":
                found.append(f"{container_kind} broad volume mount is forbidden")
        for env_from in container.get("envFrom", []) or []:
            if isinstance(env_from, dict) and "secretRef" in env_from:
                found.append(f"{container_kind} Secret envFrom is forbidden")
        for env in container.get("env", []) or []:
            if not isinstance(env, dict):
                continue
            if env.get("name") == "DOKKAEBI_RESULT_PACKET_SINK":
                sink = str(env.get("value", ""))
                ticket_id = str(labels.get("dokkaebi.io/ticket-id", ""))
                expected_sink = approved_result_sink_prefix + ticket_id
                if container_kind == "container":
                    saw_result_sink = True
                if ticket_id and sink == expected_sink:
                    pass
                elif not ticket_id and sink.startswith(approved_result_sink_prefix):
                    pass
                else:
                    found.append("result packet sink must match ticket id")
            value_from = env.get("valueFrom", {})
            if isinstance(value_from, dict) and "secretKeyRef" in value_from:
                found.append(f"{container_kind} Secret env valueFrom is forbidden")
    if not saw_result_sink:
        found.append("missing DOKKAEBI_RESULT_PACKET_SINK")
    return found


accepted_fixture_expectations = {
    Path(str(entry.get("path", ""))): (
        str(entry.get("routeProfile", "")),
        str(entry.get("serviceAccount", "")),
    )
    for entry in fixture_coverage_matrix.get("acceptedFixtures", [])
    if isinstance(entry, dict)
}
expected_accepted_profiles = set(profile_service_accounts)
actual_accepted_profiles = {profile for profile, _ in accepted_fixture_expectations.values()}
if actual_accepted_profiles != expected_accepted_profiles:
    errors.append(
        "accepted fixture matrix must cover every approved route profile: "
        + ", ".join(sorted(expected_accepted_profiles))
    )
for accepted_fixture, (expected_profile, expected_service_account) in accepted_fixture_expectations.items():
    job = load_single_yaml(accepted_fixture)
    accepted_errors = admission_errors(job)
    if accepted_errors:
        errors.append(f"{accepted_fixture} should be accepted but has errors: {', '.join(accepted_errors)}")
        continue
    metadata = job.get("metadata", {}) if isinstance(job.get("metadata"), dict) else {}
    labels = metadata.get("labels", {}) if isinstance(metadata.get("labels"), dict) else {}
    spec = pod_spec(job)
    if labels.get("dokkaebi.io/route-profile") != expected_profile:
        errors.append(f"{accepted_fixture} route profile must be {expected_profile}")
    if spec.get("serviceAccountName") != expected_service_account:
        errors.append(f"{accepted_fixture} ServiceAccount must be {expected_service_account}")

matrix_rejected_entries = [
    entry
    for entry in fixture_coverage_matrix.get("rejectedFixtures", [])
    if isinstance(entry, dict)
]
exact_rejected_expectations = {
    Path(str(entry.get("path", ""))): entry.get("expectedErrors", [])
    for entry in matrix_rejected_entries
}
for rejected_fixture, expected_errors in exact_rejected_expectations.items():
    if not isinstance(expected_errors, list) or not all(isinstance(item, str) for item in expected_errors):
        errors.append(f"{rejected_fixture} expectedErrors must be a list of strings")
non_admission_rejected_fixtures = {
    Path(str(entry.get("path", "")))
    for entry in fixture_coverage_matrix.get("nonAdmissionControlFixtures", [])
    if isinstance(entry, dict)
}
actual_admission_rejected_fixtures = {
    path for path in Path("k8s/fixtures/rejected").glob("*.yaml")
    if path not in non_admission_rejected_fixtures
}
missing_exact_fixtures = sorted(actual_admission_rejected_fixtures - set(exact_rejected_expectations))
extra_exact_fixtures = sorted(set(exact_rejected_expectations) - actual_admission_rejected_fixtures)
if missing_exact_fixtures:
    errors.append(
        "rejected admission fixtures missing exact expectations: "
        + ", ".join(str(path) for path in missing_exact_fixtures)
    )
if extra_exact_fixtures:
    errors.append(
        "exact expectations reference missing rejected fixtures: "
        + ", ".join(str(path) for path in extra_exact_fixtures)
    )
for exact_fixture, expected_errors in exact_rejected_expectations.items():
    fixture_errors = admission_errors(load_single_yaml(exact_fixture))
    if fixture_errors != expected_errors:
        errors.append(
            f"{exact_fixture} must fail only for {', '.join(expected_errors)}; "
            f"got {', '.join(fixture_errors) if fixture_errors else '<none>'}"
        )

for entry in fixture_coverage_matrix.get("nonAdmissionControlFixtures", []):
    if not isinstance(entry, dict):
        continue
    rejected_fixture = Path(str(entry.get("path", "")))
    expected_error = str(entry.get("expectedErrorContains", ""))
    if not expected_error:
        errors.append(f"{rejected_fixture} missing expectedErrorContains")
        continue
    if "overlay-traversal" in str(entry.get("coverageId", "")):
        fixture_errors = overlay_errors(rejected_fixture)
        if not fixture_errors:
            errors.append(f"{rejected_fixture} should be rejected but has no overlay errors")
            continue
        if not any(expected_error in fixture_error for fixture_error in fixture_errors):
            errors.append(
                f"{rejected_fixture} missing expected rejection {expected_error}; got {', '.join(fixture_errors)}"
            )
        continue
    docs = read_yaml_documents(rejected_fixture)
    fixture_errors: list[str] = []
    for doc in docs:
        if doc.get("kind") == "Role":
            fixture_errors.extend(role_errors(doc))
    if not fixture_errors:
        errors.append(f"{rejected_fixture} should be rejected but has no RBAC errors")
        continue
    if not any(expected_error in fixture_error for fixture_error in fixture_errors):
        errors.append(
            f"{rejected_fixture} missing expected rejection {expected_error}; got {', '.join(fixture_errors)}"
        )

criteria = json.loads(Path("docs/enterprise-readiness/criteria.json").read_text())
areas = {
    area.get("id"): area
    for area in criteria.get("areas", [])
    if isinstance(area, dict) and area.get("id")
}
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
                if not isinstance(evidence_path, str) or not Path(evidence_path).exists():
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


k8s_area = areas.get("k8s_platformization")
if not k8s_area:
    errors.append("criteria.json missing k8s_platformization area")
else:
    if k8s_area.get("currentPercent") in (None, 100):
        errors.append("k8s_platformization must remain below 100 until runtime evidence closes it")
    require_exact_k8s_current_evidence(k8s_area)
    validate_k8s_subcriteria(k8s_area)
    next_issues = k8s_area.get("nextIssues", [])
    if len(next_issues) < 5:
        errors.append("k8s_platformization must publish at least five issue candidates")
    for issue in next_issues:
        title = issue.get("title", "<missing>")
        if issue.get("publicationStatus") != "candidate-not-published":
            errors.append(f"{title} must be marked candidate-not-published")
        issue_body_path = issue.get("issueBodyPath", "")
        if not issue_body_path.startswith("docs/enterprise-readiness/k8s-platformization-issues.md#"):
            errors.append(f"{title} missing issueBodyPath anchor")
        authority = issue.get("authorityRequirement", "")
        if "explicit Human approval" not in authority:
            errors.append(f"{title} must preserve explicit Human approval boundary")
        validations = issue.get("validationRequired", [])
        if "bash scripts/validate-k8s-platformization.sh" not in validations:
            errors.append(f"{title} must require validate-k8s-platformization.sh")

issue_text = Path("docs/enterprise-readiness/k8s-platformization-issues.md").read_text()
for required_text in [
    "does not create GitHub issues",
    "approval",
    "k8s-admission-policy-gate",
    "fire-k8s-deployment-smoke",
    "hammer-job-profile-smoke",
    "k8s-result-packet-reconciliation",
    "eks-identity-and-secret-boundary",
]:
    if required_text not in issue_text:
        errors.append(f"k8s issue backlog missing text: {required_text}")

required_issue_section_commands = {
    "fire-k8s-deployment-smoke": [
        "bash scripts/validate-enterprise-scorecard.sh",
        "bash scripts/validate-all.sh",
    ],
    "hammer-job-profile-smoke": [
        "bash scripts/validate-enterprise-scorecard.sh",
        "bash scripts/validate-all.sh",
    ],
    "k8s-result-packet-reconciliation": [
        "bash scripts/validate-enterprise-scorecard.sh",
        "bash scripts/validate-all.sh",
    ],
    "eks-identity-and-secret-boundary": [
        "bash scripts/validate-enterprise-scorecard.sh",
        "bash scripts/validate-all.sh",
    ],
}
for section, commands in required_issue_section_commands.items():
    marker = f"## {section}"
    start = issue_text.find(marker)
    if start == -1:
        errors.append(f"k8s issue backlog missing section: {section}")
        continue
    next_section = issue_text.find("\n## ", start + len(marker))
    section_text = issue_text[start:] if next_section == -1 else issue_text[start:next_section]
    for command in commands:
        if command not in section_text:
            errors.append(f"{section} missing validation command: {command}")

replay_text = Path("docs/operations/k8s-platformization-fixture-replay-2026-06-14.md").read_text()
for required_text in [
    "Iteration Boundary",
    "Admission Fixture Matrix",
    "Fire Static Can/Cannot Matrix",
    "Hammer Profile Matrix",
    "Reconciliation Replay",
    "EKS Identity And Secret Boundary",
    "Approval-Gate Status",
    "intentionally leaves the readiness area below",
    "No live GitHub issue, GitHub Project, Kubernetes",
]:
    if required_text not in replay_text:
        errors.append(f"K8S fixture replay missing text: {required_text}")

adr_text = Path("docs/adr/0002-k8s-fire-hammer-platformization.md").read_text()
for required_text in [
    "GitHub Project `Status` as the lifecycle source of truth",
    "Secret read/list/watch",
    "Hammer uses route-specific ServiceAccounts",
    "Admission policy remains a fail-closed gate",
]:
    if required_text not in adr_text:
        errors.append(f"K8S ADR missing guardrail text: {required_text}")

if errors:
    for error in errors:
        print("FAIL " + error, file=sys.stderr)
    sys.exit(1)

print("PASS Dokkaebi K8S platformization loop and manifests are structurally valid")
PY
