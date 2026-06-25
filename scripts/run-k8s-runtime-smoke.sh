#!/usr/bin/env bash
# noqa: SIZE_OK - end-to-end disposable kind smoke orchestrator; splitting would obscure paired setup/cleanup receipts required by the evidence gate.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CLUSTER_NAME="${DOKKAEBI_K8S_SMOKE_CLUSTER:-dokkaebi-runtime-smoke}"
KIND_VERSION="${DOKKAEBI_KIND_VERSION:-v0.29.0}"
KUBECTL_VERSION="${DOKKAEBI_KUBECTL_VERSION:-v1.30.0}"
KIND_NODE_IMAGE="${DOKKAEBI_KIND_NODE_IMAGE:-kindest/node:v1.30.0}"
HAMMER_IMAGE="ghcr.io/twotwo-me/hammer:dev-sandbox"
FIRE_IMAGE="ghcr.io/project-dokkaebi/fire:dev-sandbox"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dokkaebi-k8s-runtime.XXXXXX")"
BIN_DIR="$WORK_DIR/bin"
KUBECONFIG="$WORK_DIR/kubeconfig"
KIND_BIN=""
KUBECTL_BIN=""
PREV_HAMMER_IMAGE_ID=""
PREV_FIRE_IMAGE_ID=""
export KUBECONFIG

mkdir -p "$BIN_DIR"

log() {
  printf '%s\n' "$*"
}

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

download() {
  url="$1"
  dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$dest" "$url"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
    return
  fi
  echo "curl or wget is required to bootstrap runtime smoke tools" >&2
  exit 69
}

platform_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *) echo "unsupported architecture: $(uname -m)" >&2; exit 70 ;;
  esac
}

image_id() {
  docker image inspect "$1" --format '{{.Id}}' 2>/dev/null || true
}

restore_or_remove_image() {
  image="$1"
  previous_id="$2"
  if [ -n "$previous_id" ]; then
    docker tag "$previous_id" "$image" >/dev/null 2>&1 || true
    log "cleanup_image=$image restored_previous_tag"
    return
  fi
  docker rmi -f "$image" >/dev/null 2>&1 || true
  log "cleanup_image=$image removed_smoke_tag"
}

cleanup() {
  status=$?
  set +e
  if [ -n "${KIND_BIN:-}" ] && [ -x "$KIND_BIN" ]; then
    "$KIND_BIN" delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1
    log "cleanup_kind_cluster=$CLUSTER_NAME deleted"
  fi
  restore_or_remove_image "$HAMMER_IMAGE" "$PREV_HAMMER_IMAGE_ID"
  restore_or_remove_image "$FIRE_IMAGE" "$PREV_FIRE_IMAGE_ID"
  remaining_containers="$(docker ps -a --filter "name=${CLUSTER_NAME}" --format '{{.Names}}' 2>/dev/null || true)"
  if [ -z "$remaining_containers" ]; then
    log "cleanup_kind_containers=$CLUSTER_NAME none"
  else
    log "cleanup_kind_containers=$CLUSTER_NAME remaining:$remaining_containers"
  fi
  rm -rf "$WORK_DIR"
  log "cleanup_work_dir=$WORK_DIR removed"
  exit "$status"
}
trap cleanup EXIT

bootstrap_tools() {
  arch="$(platform_arch)"
  KIND_BIN="$(command -v kind || true)"
  if [ -z "$KIND_BIN" ]; then
    KIND_BIN="$BIN_DIR/kind"
    download "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${arch}" "$KIND_BIN"
    chmod +x "$KIND_BIN"
  fi

  KUBECTL_BIN="$(command -v kubectl || true)"
  if [ -z "$KUBECTL_BIN" ]; then
    KUBECTL_BIN="$BIN_DIR/kubectl"
    download "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl" "$KUBECTL_BIN"
    chmod +x "$KUBECTL_BIN"
  fi

  run "$KIND_BIN" --version
  run "$KUBECTL_BIN" version --client=true --output=yaml
}

build_smoke_images() {
  PREV_HAMMER_IMAGE_ID="$(image_id "$HAMMER_IMAGE")"
  PREV_FIRE_IMAGE_ID="$(image_id "$FIRE_IMAGE")"

  mkdir -p "$WORK_DIR/hammer-image" "$WORK_DIR/fire-image"
  cp k8s/runtime-smoke/hammer-result-packet.sh "$WORK_DIR/hammer-image/hammer-result-packet.sh"
  cp k8s/runtime-smoke/fire-create-hammer-job.sh "$WORK_DIR/fire-image/fire-create-hammer-job.sh"

  cat > "$WORK_DIR/hammer-image/Dockerfile" <<'EOF'
FROM busybox:1.36.1
COPY hammer-result-packet.sh /hammer-result-packet.sh
RUN chmod 0555 /hammer-result-packet.sh
USER 1000:1000
ENTRYPOINT ["/bin/sh", "/hammer-result-packet.sh"]
EOF

  cat > "$WORK_DIR/fire-image/Dockerfile" <<'EOF'
FROM curlimages/curl:8.8.0
COPY fire-create-hammer-job.sh /fire-create-hammer-job.sh
USER root
RUN chmod 0555 /fire-create-hammer-job.sh
USER 1000:1000
ENTRYPOINT ["/bin/sh", "/fire-create-hammer-job.sh"]
EOF

  run docker build -q -t "$HAMMER_IMAGE" "$WORK_DIR/hammer-image"
  run docker build -q -t "$FIRE_IMAGE" "$WORK_DIR/fire-image"
}

expect_can_i() {
  subject_namespace="$1"
  subject_name="$2"
  verb="$3"
  resource="$4"
  namespace="$5"
  expected="$6"
  set +e
  actual="$("$KUBECTL_BIN" auth can-i "$verb" "$resource" \
    --namespace "$namespace" \
    --as "system:serviceaccount:${subject_namespace}:${subject_name}")"
  status=$?
  set -e
  log "can_i subject=${subject_namespace}/${subject_name} verb=$verb resource=$resource namespace=$namespace actual=$actual expected=$expected"
  if [ "$status" -ne 0 ] && [ "$actual" != "no" ]; then
    echo "kubectl auth can-i failed unexpectedly" >&2
    exit 71
  fi
  if [ "$actual" != "$expected" ]; then
    echo "unexpected kubectl auth can-i result" >&2
    exit 71
  fi
}

wait_for_job() {
  namespace="$1"
  name="$2"
  if ! run "$KUBECTL_BIN" wait --namespace "$namespace" --for=condition=complete "job/$name" --timeout=180s; then
    log "job_wait_failed namespace=$namespace job=$name"
    "$KUBECTL_BIN" get job "$name" --namespace "$namespace" -o yaml || true
    "$KUBECTL_BIN" get pods --namespace "$namespace" -o wide || true
    "$KUBECTL_BIN" describe job "$name" --namespace "$namespace" || true
    "$KUBECTL_BIN" describe pods --namespace "$namespace" -l "job-name=$name" || true
    "$KUBECTL_BIN" logs --namespace "$namespace" "job/$name" --all-containers=true || true
    return 1
  fi
  run "$KUBECTL_BIN" get job "$name" --namespace "$namespace" -o json
  log "logs_start namespace=$namespace job=$name"
  "$KUBECTL_BIN" logs --namespace "$namespace" "job/$name"
  log "logs_end namespace=$namespace job=$name"
}

assert_hammer_log() {
  namespace="$1"
  name="$2"
  expected_ticket="$3"
  expected_profile="$4"
  expected_service_account="$5"
  log_output="$("$KUBECTL_BIN" logs --namespace "$namespace" "job/$name")"
  printf '%s\n' "$log_output" | grep -F "result_packet_status=accepted" >/dev/null
  printf '%s\n' "$log_output" | grep -F "ticket_id=$expected_ticket" >/dev/null
  printf '%s\n' "$log_output" | grep -F "route_profile=$expected_profile" >/dev/null
  printf '%s\n' "$log_output" | grep -F "service_account=$expected_service_account" >/dev/null
  printf '%s\n' "$log_output" | grep -F "log_surface=kubectl logs pod/" >/dev/null
  log "result_metadata_ok job=$name ticket=$expected_ticket route=$expected_profile serviceAccount=$expected_service_account"
}

job_json_field() {
  namespace="$1"
  name="$2"
  expression="$3"
  "$KUBECTL_BIN" get job "$name" --namespace "$namespace" -o json \
    | python3 -c "import json,sys; data=json.load(sys.stdin); print($expression)"
}

assert_job_metadata() {
  namespace="$1"
  name="$2"
  expected_profile="$3"
  expected_service_account="$4"
  expected_image="$5"
  actual_profile="$(job_json_field "$namespace" "$name" "data['metadata']['labels']['dokkaebi.io/route-profile']")"
  actual_service_account="$(job_json_field "$namespace" "$name" "data['spec']['template']['spec']['serviceAccountName']")"
  actual_image="$(job_json_field "$namespace" "$name" "data['spec']['template']['spec']['containers'][0]['image']")"
  succeeded="$(job_json_field "$namespace" "$name" "data.get('status', {}).get('succeeded', 0)")"
  log "job_metadata job=$name route=$actual_profile serviceAccount=$actual_service_account image=$actual_image succeeded=$succeeded"
  if [ "$actual_profile" != "$expected_profile" ] \
    || [ "$actual_service_account" != "$expected_service_account" ] \
    || [ "$actual_image" != "$expected_image" ] \
    || [ "$succeeded" != "1" ]; then
    echo "job metadata did not match expected result packet route" >&2
    exit 72
  fi
  image_id="$("$KUBECTL_BIN" get pods --namespace "$namespace" -l "job-name=$name" -o json \
    | python3 -c "import json,sys; data=json.load(sys.stdin); items=data.get('items', []); statuses=items[0].get('status', {}).get('containerStatuses', []) if items else []; print(statuses[0].get('imageID', '') if statuses else '')")"
  if [ -z "$image_id" ]; then
    echo "pod imageID was missing for completed job" >&2
    exit 72
  fi
  log "job_runtime_image_id job=$name imageID=$image_id"
}

apply_and_assert_accepted_fixture() {
  fixture="$1"
  name="$("$KUBECTL_BIN" apply -f "$fixture" -o jsonpath='{.metadata.name}')"
  echo
  log "accepted_fixture_applied path=$fixture job=$name"
  wait_for_job "dokkaebi-workers" "$name"
  profile="$(job_json_field dokkaebi-workers "$name" "data['metadata']['labels']['dokkaebi.io/route-profile']")"
  service_account="$(job_json_field dokkaebi-workers "$name" "data['spec']['template']['spec']['serviceAccountName']")"
  ticket="$(job_json_field dokkaebi-workers "$name" "data['metadata']['labels']['dokkaebi.io/ticket-id']")"
  assert_job_metadata "dokkaebi-workers" "$name" "$profile" "$service_account" "$HAMMER_IMAGE"
  assert_hammer_log "dokkaebi-workers" "$name" "$ticket" "$profile" "$service_account"
}

apply_and_assert_litellm_virtual_key_fixture() {
  secret_name="dokkaebi-litellm-virtual-key-grant-litellm-pdk8s-001"
  work_secret="$WORK_DIR/litellm-virtual-key-secret.yaml"
  cat > "$work_secret" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: dokkaebi-litellm-virtual-key-grant-litellm-pdk8s-001
  namespace: dokkaebi-workers
  labels:
    app.kubernetes.io/name: dokkaebi-litellm-virtual-key
    app.kubernetes.io/part-of: dokkaebi
    dokkaebi.io/litellm-key-scope: run-scoped
    dokkaebi.io/litellm-key-owner: fire-credential-broker
    dokkaebi.io/run-id: run-pdk8s-litellm-001
type: Opaque
stringData:
  api-key: REPLACE_WITH_APPROVED_RUN_SCOPED_LITELLM_VIRTUAL_KEY_SMOKE
EOF

  run "$KUBECTL_BIN" create \
    --as=system:serviceaccount:dokkaebi-system:dokkaebi-credential-broker \
    -f "$work_secret"
  log "litellm_virtual_key_secret_created_by_broker=$secret_name"

  name="$("$KUBECTL_BIN" create \
    --as=system:serviceaccount:dokkaebi-system:dokkaebi-fire \
    -f k8s/fixtures/accepted/hammer-job-litellm-virtual-key-approved.yaml \
    -o jsonpath='{.metadata.name}')"
  echo
  log "accepted_fixture_applied_by_fire path=k8s/fixtures/accepted/hammer-job-litellm-virtual-key-approved.yaml job=$name"
  wait_for_job "dokkaebi-workers" "$name"
  assert_job_metadata "dokkaebi-workers" "$name" hammer-k8s-readonly hammer-k8s-readonly "$HAMMER_IMAGE"
  assert_hammer_log "dokkaebi-workers" "$name" PDK8S-LITELLM-001 hammer-k8s-readonly hammer-k8s-readonly
  log "litellm_virtual_key_job_created_by_fire=$name"

  run "$KUBECTL_BIN" delete secret "$secret_name" \
    --namespace dokkaebi-workers \
    --as=system:serviceaccount:dokkaebi-system:dokkaebi-credential-broker
  log "litellm_virtual_key_secret_deleted_by_broker=$secret_name"
}

assert_rejected_fixture_denied_for_fire() {
  set +e
  output="$("$KUBECTL_BIN" create \
    --as=system:serviceaccount:dokkaebi-system:dokkaebi-fire \
    --dry-run=server \
    -f k8s/fixtures/rejected/missing-approval-id.yaml 2>&1)"
  status=$?
  set -e
  printf '%s\n' "$output"
  if [ "$status" -eq 0 ]; then
    echo "Fire ServiceAccount unexpectedly bypassed admission for rejected fixture" >&2
    exit 73
  fi
  printf '%s\n' "$output" | grep -F "ValidatingAdmissionPolicy 'dokkaebi-hammer-job-policy'" >/dev/null
  printf '%s\n' "$output" | grep -F "Hammer Jobs must include non-empty Dokkaebi routing" >/dev/null
  log "fire_rejected_fixture_denied=missing-approval-id"
}

assert_litellm_self_spoof_denied_for_hammer() {
  runtime_fixture="$WORK_DIR/litellm-virtual-key-self-spoof-runtime.yaml"
  grep -v "dokkaebi.io/fixture-request-user:" \
    k8s/fixtures/rejected/litellm-virtual-key-self-spoof.yaml > "$runtime_fixture"
  set +e
  output="$("$KUBECTL_BIN" create \
    --as=system:serviceaccount:dokkaebi-workers:hammer-k8s-job-runner \
    --dry-run=server \
    -f "$runtime_fixture" 2>&1)"
  status=$?
  set -e
  printf '%s\n' "$output"
  if [ "$status" -eq 0 ]; then
    echo "Hammer ServiceAccount unexpectedly self-spoofed LiteLLM virtual-key Secret access" >&2
    exit 73
  fi
  printf '%s\n' "$output" | grep -F "ValidatingAdmissionPolicy 'dokkaebi-hammer-job-policy'" >/dev/null
  printf '%s\n' "$output" | grep -F "Hammer containers may reference only broker-issued LiteLLM virtual-key Secrets through env" >/dev/null
  log "hammer_litellm_virtual_key_self_spoof_denied=hammer-k8s-job-runner"
}

main() {
  bootstrap_tools
  build_smoke_images

  run "$KIND_BIN" create cluster --name "$CLUSTER_NAME" --image "$KIND_NODE_IMAGE" --wait 120s
  run "$KIND_BIN" load docker-image "$HAMMER_IMAGE" --name "$CLUSTER_NAME"
  run "$KIND_BIN" load docker-image "$FIRE_IMAGE" --name "$CLUSTER_NAME"

  run "$KUBECTL_BIN" apply -k k8s/base
  run "$KUBECTL_BIN" create configmap dokkaebi-fire-smoke-hammer-job \
    --namespace dokkaebi-system \
    --from-file=hammer-job.json=k8s/runtime-smoke/hammer-job-fire-created-approved.json

  expect_can_i dokkaebi-system dokkaebi-fire create jobs.batch dokkaebi-workers yes
  expect_can_i dokkaebi-system dokkaebi-fire get secrets dokkaebi-workers no
  expect_can_i dokkaebi-system dokkaebi-fire create rolebindings.rbac.authorization.k8s.io dokkaebi-workers no
  expect_can_i dokkaebi-system dokkaebi-credential-broker create secrets dokkaebi-workers yes
  expect_can_i dokkaebi-system dokkaebi-credential-broker list secrets dokkaebi-workers no
  expect_can_i dokkaebi-workers hammer-no-k8s get pods dokkaebi-workers no
  expect_can_i dokkaebi-workers hammer-k8s-readonly get pods dokkaebi-workers yes
  expect_can_i dokkaebi-workers hammer-k8s-readonly create jobs.batch dokkaebi-workers no
  expect_can_i dokkaebi-workers hammer-k8s-job-runner create jobs.batch dokkaebi-workers yes
  expect_can_i dokkaebi-workers hammer-k8s-job-runner get secrets dokkaebi-workers no

  run "$KUBECTL_BIN" apply -f k8s/runtime-smoke/fire-job-orchestrator-smoke.yaml
  wait_for_job dokkaebi-system fire-k8s-runtime-smoke
  wait_for_job dokkaebi-workers hammer-ticket-pdk8s-fire-runtime-001
  assert_job_metadata dokkaebi-workers hammer-ticket-pdk8s-fire-runtime-001 hammer-k8s-job-runner hammer-k8s-job-runner "$HAMMER_IMAGE"
  assert_hammer_log dokkaebi-workers hammer-ticket-pdk8s-fire-runtime-001 PDK8S-FIRE-RUNTIME-001 hammer-k8s-job-runner hammer-k8s-job-runner
  assert_rejected_fixture_denied_for_fire

  apply_and_assert_accepted_fixture k8s/fixtures/accepted/hammer-job-no-k8s-approved.yaml
  apply_and_assert_accepted_fixture k8s/fixtures/accepted/hammer-job-approved.yaml
  apply_and_assert_accepted_fixture k8s/fixtures/accepted/hammer-job-app-deployer-approved.yaml
  apply_and_assert_accepted_fixture k8s/fixtures/accepted/hammer-job-job-runner-approved.yaml
  apply_and_assert_litellm_virtual_key_fixture
  assert_litellm_self_spoof_denied_for_hammer

  run "$KUBECTL_BIN" get jobs --namespace dokkaebi-workers
  run "$KUBECTL_BIN" get pods --namespace dokkaebi-workers
  log "PASS k8s runtime smoke completed"
}

main "$@"
