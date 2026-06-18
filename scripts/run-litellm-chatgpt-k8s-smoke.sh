#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CLUSTER_NAME="${DOKKAEBI_LITELLM_SMOKE_CLUSTER:-dokkaebi-litellm-smoke}"
KIND_NODE_IMAGE="${DOKKAEBI_KIND_NODE_IMAGE:-kindest/node:v1.30.0}"
LITELLM_IMAGE="${DOKKAEBI_LITELLM_IMAGE:-ghcr.io/berriai/litellm-database:main-latest}"
POSTGRES_IMAGE="${DOKKAEBI_POSTGRES_IMAGE:-postgres:16-alpine}"
CURL_IMAGE="${DOKKAEBI_CURL_IMAGE:-curlimages/curl:8.8.0}"
MASTER_KEY="${DOKKAEBI_LITELLM_MASTER_KEY:-sk-dokkaebi-litellm-smoke-master}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dokkaebi-litellm-k8s.XXXXXX")"
KUBECONFIG="$WORK_DIR/kubeconfig"
KIND_BIN="${KIND_BIN:-$(command -v kind || true)}"
KUBECTL_BIN="${KUBECTL_BIN:-$(command -v kubectl || true)}"
export KUBECONFIG

log() {
  printf '%s\n' "$*"
}

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

cleanup() {
  status=$?
  set +e
  if [ -n "${KIND_BIN:-}" ] && [ -x "$KIND_BIN" ]; then
    "$KIND_BIN" delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1
    log "cleanup_kind_cluster=$CLUSTER_NAME deleted"
  fi
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

require_tools() {
  if [ -z "$KIND_BIN" ] || [ ! -x "$KIND_BIN" ]; then
    echo "kind is required; install it in PATH before running this smoke" >&2
    exit 69
  fi
  if [ -z "$KUBECTL_BIN" ] || [ ! -x "$KUBECTL_BIN" ]; then
    echo "kubectl is required; install it in PATH before running this smoke" >&2
    exit 69
  fi
  run "$KIND_BIN" --version
  run "$KUBECTL_BIN" version --client=true --output=yaml
}

create_cluster() {
  run "$KIND_BIN" delete cluster --name "$CLUSTER_NAME"
  run "$KIND_BIN" create cluster --name "$CLUSTER_NAME" --image "$KIND_NODE_IMAGE" --kubeconfig "$KUBECONFIG"
  run "$KUBECTL_BIN" cluster-info
}

write_common_manifests() {
  cat > "$WORK_DIR/common.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: dokkaebi-llm
---
apiVersion: v1
kind: Namespace
metadata:
  name: dokkaebi-workers
---
apiVersion: v1
kind: Secret
metadata:
  name: litellm-env
  namespace: dokkaebi-llm
type: Opaque
stringData:
  LITELLM_MASTER_KEY: ${MASTER_KEY}
  DATABASE_URL: postgresql://litellm:litellm-smoke-pass@postgres.dokkaebi-llm.svc.cluster.local:5432/litellm
  OPENAI_API_KEY: sk-dokkaebi-litellm-smoke-provider
  POSTGRES_DB: litellm
  POSTGRES_USER: litellm
  POSTGRES_PASSWORD: litellm-smoke-pass
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: dokkaebi-llm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: ${POSTGRES_IMAGE}
          imagePullPolicy: IfNotPresent
          envFrom:
            - secretRef:
                name: litellm-env
          ports:
            - containerPort: 5432
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "litellm", "-d", "litellm"]
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: dokkaebi-llm
spec:
  selector:
    app: postgres
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
EOF
}

write_litellm_deployment() {
  config_name="$1"
  cat > "$WORK_DIR/litellm-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm
  namespace: dokkaebi-llm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: litellm
  template:
    metadata:
      labels:
        app: litellm
    spec:
      containers:
        - name: litellm
          image: ${LITELLM_IMAGE}
          imagePullPolicy: IfNotPresent
          args: ["--config", "/app/proxy_config.yaml", "--port", "4000"]
          envFrom:
            - secretRef:
                name: litellm-env
          env:
            - name: CHATGPT_TOKEN_DIR
              value: /var/lib/litellm-chatgpt
            - name: CHATGPT_AUTH_FILE
              value: auth.json
          ports:
            - containerPort: 4000
          volumeMounts:
            - name: config
              mountPath: /app/proxy_config.yaml
              subPath: config.yaml
              readOnly: true
            - name: chatgpt-token-dir
              mountPath: /var/lib/litellm-chatgpt
          readinessProbe:
            httpGet:
              path: /health/readiness
              port: 4000
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 30
      volumes:
        - name: config
          configMap:
            name: ${config_name}
        - name: chatgpt-token-dir
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: litellm
  namespace: dokkaebi-llm
spec:
  selector:
    app: litellm
  ports:
    - name: http
      port: 4000
      targetPort: 4000
EOF
}

write_chatgpt_config() {
  cat > "$WORK_DIR/chatgpt-config.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: litellm-config-chatgpt
  namespace: dokkaebi-llm
data:
  config.yaml: |
    model_list:
      - model_name: chatgpt/gpt-5.3-codex
        model_info:
          mode: responses
        litellm_params:
          model: chatgpt/gpt-5.3-codex
      - model_name: chatgpt/gpt-5.4
        model_info:
          mode: responses
        litellm_params:
          model: chatgpt/gpt-5.4
    general_settings:
      master_key: os.environ/LITELLM_MASTER_KEY
      database_url: os.environ/DATABASE_URL
EOF
}

write_gateway_config() {
  cat > "$WORK_DIR/gateway-config.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: litellm-config-gateway
  namespace: dokkaebi-llm
data:
  config.yaml: |
    model_list:
      - model_name: dokkaebi-litellm-smoke
        model_info:
          mode: responses
        litellm_params:
          model: openai/gpt-4o-mini
          api_key: os.environ/OPENAI_API_KEY
    general_settings:
      master_key: os.environ/LITELLM_MASTER_KEY
      database_url: os.environ/DATABASE_URL
EOF
}

apply_common_and_wait_postgres() {
  run "$KUBECTL_BIN" apply -f "$WORK_DIR/common.yaml"
  if ! run "$KUBECTL_BIN" wait --namespace dokkaebi-llm --for=condition=available deployment/postgres --timeout=180s; then
    "$KUBECTL_BIN" get pods --namespace dokkaebi-llm -o wide || true
    "$KUBECTL_BIN" describe deployment postgres --namespace dokkaebi-llm || true
    "$KUBECTL_BIN" describe pods --namespace dokkaebi-llm -l app=postgres || true
    "$KUBECTL_BIN" logs --namespace dokkaebi-llm -l app=postgres --all-containers=true --tail=100 || true
    exit 74
  fi
}

apply_chatgpt_device_flow_probe() {
  write_litellm_deployment litellm-config-chatgpt
  run "$KUBECTL_BIN" apply -f "$WORK_DIR/chatgpt-config.yaml"
  run "$KUBECTL_BIN" apply -f "$WORK_DIR/litellm-deployment.yaml"
  run "$KUBECTL_BIN" wait --namespace dokkaebi-llm --for=condition=Ready=False pod -l app=litellm --timeout=180s || true
  litellm_pod="$("$KUBECTL_BIN" get pod --namespace dokkaebi-llm -l app=litellm -o jsonpath='{.items[0].metadata.name}')"
  for _ in $(seq 1 60); do
    "$KUBECTL_BIN" logs --namespace dokkaebi-llm "$litellm_pod" > "$WORK_DIR/chatgpt-probe.log" 2>&1 || true
    if grep -F "Sign in with ChatGPT using device code" "$WORK_DIR/chatgpt-probe.log" >/dev/null \
      && grep -F "chatgpt/gpt-5.3-codex" "$WORK_DIR/chatgpt-probe.log" >/dev/null; then
      log "chatgpt_provider_config_loaded=yes"
      log "chatgpt_provider_requires_device_flow=yes"
      break
    fi
    sleep 5
  done
  if ! grep -F "Sign in with ChatGPT using device code" "$WORK_DIR/chatgpt-probe.log" >/dev/null; then
    "$KUBECTL_BIN" get pods --namespace dokkaebi-llm -o wide || true
    "$KUBECTL_BIN" logs --namespace dokkaebi-llm "$litellm_pod" --tail=200 || true
    echo "LiteLLM ChatGPT provider did not reach the expected device-flow gate" >&2
    exit 76
  fi
  run "$KUBECTL_BIN" delete deployment litellm --namespace dokkaebi-llm
  run "$KUBECTL_BIN" delete service litellm --namespace dokkaebi-llm
  run "$KUBECTL_BIN" delete configmap litellm-config-chatgpt --namespace dokkaebi-llm
}

apply_gateway_and_wait() {
  write_litellm_deployment litellm-config-gateway
  run "$KUBECTL_BIN" apply -f "$WORK_DIR/gateway-config.yaml"
  run "$KUBECTL_BIN" apply -f "$WORK_DIR/litellm-deployment.yaml"
  if ! run "$KUBECTL_BIN" wait --namespace dokkaebi-llm --for=condition=available deployment/litellm --timeout=300s; then
    "$KUBECTL_BIN" get pods --namespace dokkaebi-llm -o wide || true
    "$KUBECTL_BIN" describe deployment litellm --namespace dokkaebi-llm || true
    "$KUBECTL_BIN" describe pods --namespace dokkaebi-llm -l app=litellm || true
    "$KUBECTL_BIN" logs --namespace dokkaebi-llm -l app=litellm --all-containers=true --tail=200 || true
    exit 74
  fi
  run "$KUBECTL_BIN" get pods --namespace dokkaebi-llm -o wide
  run "$KUBECTL_BIN" get svc --namespace dokkaebi-llm
}

run_curl_job() {
  namespace="$1"
  name="$2"
  script="$3"
  print_logs="${4:-yes}"
  cat > "$WORK_DIR/${name}.yaml" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${name}
  namespace: ${namespace}
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: curl
          image: ${CURL_IMAGE}
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh", "-ceu"]
          args:
            - |
$(printf '%s\n' "$script" | sed 's/^/              /')
EOF
  run "$KUBECTL_BIN" apply -f "$WORK_DIR/${name}.yaml"
  if ! run "$KUBECTL_BIN" wait --namespace "$namespace" --for=condition=complete "job/$name" --timeout=180s; then
    "$KUBECTL_BIN" describe job "$name" --namespace "$namespace" || true
    "$KUBECTL_BIN" logs --namespace "$namespace" "job/$name" --all-containers=true || true
    exit 75
  fi
  if [ "$print_logs" = "yes" ]; then
    log "logs_start namespace=$namespace job=$name"
    "$KUBECTL_BIN" logs --namespace "$namespace" "job/$name"
    log "logs_end namespace=$namespace job=$name"
  fi
}

generate_virtual_key() {
  script='
base_url="http://litellm.dokkaebi-llm.svc.cluster.local:4000"
response="$(curl -sS -w "\nhttp_status=%{http_code}\n" \
  -H "Authorization: Bearer '"$MASTER_KEY"'" \
  -H "Content-Type: application/json" \
  -d "{\"models\":[\"dokkaebi-litellm-smoke\"],\"duration\":\"1h\",\"key_alias\":\"dokkaebi-litellm-k8s-smoke\"}" \
  "$base_url/key/generate")"
printf "%s\n" "$response"
printf "%s\n" "$response" | grep -F "http_status=200" >/dev/null
'
  run_curl_job dokkaebi-llm litellm-keygen "$script" no
  "$KUBECTL_BIN" logs --namespace dokkaebi-llm job/litellm-keygen > "$WORK_DIR/keygen.log"
  python3 - "$WORK_DIR/keygen.log" "$WORK_DIR/virtual-key.txt" <<'PY'
import json
import sys
from pathlib import Path

raw = Path(sys.argv[1]).read_text(encoding="utf-8")
payload = raw.split("\nhttp_status=", 1)[0].strip()
data = json.loads(payload)
key = data.get("key")
if not isinstance(key, str) or not key.startswith("sk-"):
    raise SystemExit("virtual key missing from LiteLLM key/generate response")
Path(sys.argv[2]).write_text(key, encoding="utf-8")
print("virtual_key_generated=yes")
print("virtual_key_token_id=" + str(data.get("token_id", "unknown")))
print("models=" + ",".join(data.get("models", [])))
PY
}

create_worker_secret() {
  virtual_key="$(cat "$WORK_DIR/virtual-key.txt")"
  "$KUBECTL_BIN" create secret generic litellm-worker-virtual-key \
    --namespace dokkaebi-workers \
    --from-literal=DOKKAEBI_LITELLM_VIRTUAL_KEY="$virtual_key" \
    --dry-run=client -o yaml > "$WORK_DIR/worker-secret.yaml"
  run "$KUBECTL_BIN" apply -f "$WORK_DIR/worker-secret.yaml"
  log "worker_virtual_key_secret=created namespace=dokkaebi-workers key=DOKKAEBI_LITELLM_VIRTUAL_KEY"
}

create_worker_smoke_job() {
  cat > "$WORK_DIR/worker-smoke.yaml" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: litellm-worker-smoke
  namespace: dokkaebi-workers
  labels:
    dokkaebi.io/ticket-id: pdk8s-litellm-smoke-001
    dokkaebi.io/route-profile: hammer-no-k8s
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        dokkaebi.io/ticket-id: pdk8s-litellm-smoke-001
        dokkaebi.io/route-profile: hammer-no-k8s
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      containers:
        - name: worker
          image: ${CURL_IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - name: DOKKAEBI_LITELLM_VIRTUAL_KEY
              valueFrom:
                secretKeyRef:
                  name: litellm-worker-virtual-key
                  key: DOKKAEBI_LITELLM_VIRTUAL_KEY
          command: ["/bin/sh", "-ceu"]
          args:
            - |
              base_url="http://litellm.dokkaebi-llm.svc.cluster.local:4000"
              models_status="\$(curl -sS -o /tmp/models.json -w "%{http_code}" \
                -H "Authorization: Bearer \$DOKKAEBI_LITELLM_VIRTUAL_KEY" \
                "\$base_url/v1/models")"
              printf "models_status=%s\n" "\$models_status"
              grep -F "dokkaebi-litellm-smoke" /tmp/models.json >/dev/null
              printf "models_contains_gateway_model=yes\n"

              no_auth_status="\$(curl -sS -o /tmp/no-auth.json -w "%{http_code}" "\$base_url/v1/models")"
              printf "no_auth_models_status=%s\n" "\$no_auth_status"
              test "\$no_auth_status" != "200"

              response_status="\$(curl -sS -o /tmp/response.json -w "%{http_code}" \
                -H "Authorization: Bearer \$DOKKAEBI_LITELLM_VIRTUAL_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"model\":\"dokkaebi-litellm-smoke\",\"input\":\"Return the literal string dokkaebi-litellm-smoke-ok.\"}" \
                "\$base_url/v1/responses" || true)"
              printf "gateway_provider_call_status=%s\n" "\$response_status"
              if [ "\$response_status" = "200" ]; then
                grep -F "dokkaebi-litellm-smoke-ok" /tmp/response.json >/dev/null
                printf "gateway_provider_call=success\n"
              else
                grep -Ei "auth|token|credential|openai|error|unauthorized|forbidden" /tmp/response.json >/dev/null
                printf "gateway_provider_call=blocked_by_fake_provider_key\n"
              fi

              if [ -n "\${CHATGPT_TOKEN_DIR:-}" ] || [ -n "\${CHATGPT_AUTH_FILE:-}" ] || [ -n "\${LITELLM_MASTER_KEY:-}" ]; then
                echo "worker unexpectedly received gateway-only env" >&2
                exit 1
              fi
              printf "worker_gateway_secret_absent=yes\n"
EOF
  run "$KUBECTL_BIN" apply -f "$WORK_DIR/worker-smoke.yaml"
  if ! run "$KUBECTL_BIN" wait --namespace dokkaebi-workers --for=condition=complete job/litellm-worker-smoke --timeout=180s; then
    "$KUBECTL_BIN" describe job litellm-worker-smoke --namespace dokkaebi-workers || true
    "$KUBECTL_BIN" logs --namespace dokkaebi-workers job/litellm-worker-smoke --all-containers=true || true
    exit 75
  fi
  log "logs_start namespace=dokkaebi-workers job=litellm-worker-smoke"
  "$KUBECTL_BIN" logs --namespace dokkaebi-workers job/litellm-worker-smoke
  log "logs_end namespace=dokkaebi-workers job=litellm-worker-smoke"
}

block_virtual_key_and_assert_denied() {
  virtual_key="$(cat "$WORK_DIR/virtual-key.txt")"
  cat > "$WORK_DIR/key-block.yaml" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: litellm-key-block
  namespace: dokkaebi-llm
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: curl
          image: ${CURL_IMAGE}
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh", "-ceu"]
          args:
            - |
              response="\$(curl -sS -w "\\nhttp_status=%{http_code}\\n" \
                -H "Authorization: Bearer ${MASTER_KEY}" \
                -H "Content-Type: application/json" \
                -d "{\"key\":\"${virtual_key}\"}" \
                "http://litellm.dokkaebi-llm.svc.cluster.local:4000/key/block")"
              printf "%s\n" "\$response"
              printf "%s\n" "\$response" | grep -E "http_status=20[0-9]" >/dev/null
EOF
  run "$KUBECTL_BIN" apply -f "$WORK_DIR/key-block.yaml"
  run "$KUBECTL_BIN" wait --namespace dokkaebi-llm --for=condition=complete job/litellm-key-block --timeout=180s
  log "virtual_key_blocked=yes"

  cat > "$WORK_DIR/blocked-worker.yaml" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: litellm-blocked-key-smoke
  namespace: dokkaebi-workers
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      containers:
        - name: curl
          image: ${CURL_IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - name: DOKKAEBI_LITELLM_VIRTUAL_KEY
              valueFrom:
                secretKeyRef:
                  name: litellm-worker-virtual-key
                  key: DOKKAEBI_LITELLM_VIRTUAL_KEY
          command: ["/bin/sh", "-ceu"]
          args:
            - |
              status="\$(curl -sS -o /tmp/blocked.json -w "%{http_code}" \
                -H "Authorization: Bearer \$DOKKAEBI_LITELLM_VIRTUAL_KEY" \
                "http://litellm.dokkaebi-llm.svc.cluster.local:4000/v1/models" || true)"
              printf "blocked_key_models_status=%s\n" "\$status"
              test "\$status" != "200"
EOF
  run "$KUBECTL_BIN" apply -f "$WORK_DIR/blocked-worker.yaml"
  run "$KUBECTL_BIN" wait --namespace dokkaebi-workers --for=condition=complete job/litellm-blocked-key-smoke --timeout=180s
  "$KUBECTL_BIN" logs --namespace dokkaebi-workers job/litellm-blocked-key-smoke
}

assert_boundary() {
  "$KUBECTL_BIN" get pod --namespace dokkaebi-workers -l job-name=litellm-worker-smoke -o json \
    > "$WORK_DIR/worker-pod.json"
  python3 - "$WORK_DIR/worker-pod.json" <<'PY'
import json
import sys

pod = json.load(open(sys.argv[1], encoding="utf-8"))["items"][0]
spec = pod["spec"]
containers = spec["containers"]
if spec.get("automountServiceAccountToken") is not False:
    raise SystemExit("worker pod must set automountServiceAccountToken=false")
env_names = [env["name"] for c in containers for env in c.get("env", [])]
if env_names != ["DOKKAEBI_LITELLM_VIRTUAL_KEY"]:
    raise SystemExit(f"unexpected worker env names: {env_names!r}")
volume_names = [volume["name"] for volume in spec.get("volumes", [])]
for forbidden in ["litellm-env", "chatgpt-token-dir"]:
    if forbidden in volume_names:
        raise SystemExit(f"worker pod contains forbidden gateway-only volume: {forbidden}")
secret_refs = json.dumps(
    [env.get("valueFrom", {}).get("secretKeyRef", {}) for c in containers for env in c.get("env", [])],
    sort_keys=True,
)
for forbidden in ["LITELLM_MASTER_KEY", "CHATGPT_TOKEN_DIR", "CHATGPT_AUTH_FILE"]:
    if forbidden in secret_refs:
        raise SystemExit(f"worker pod contains forbidden gateway-only secret reference: {forbidden}")
print("worker_pod_boundary_ok=yes")
PY
}

capture_cluster_state() {
  run "$KUBECTL_BIN" get all --namespace dokkaebi-llm
  run "$KUBECTL_BIN" get all --namespace dokkaebi-workers
  litellm_pod="$("$KUBECTL_BIN" get pod --namespace dokkaebi-llm -l app=litellm -o jsonpath='{.items[0].metadata.name}')"
  log "litellm_logs_tail_start pod=$litellm_pod"
  "$KUBECTL_BIN" logs --namespace dokkaebi-llm "$litellm_pod" --tail=80
  log "litellm_logs_tail_end pod=$litellm_pod"
}

main() {
  require_tools
  create_cluster
  write_common_manifests
  write_chatgpt_config
  write_gateway_config
  apply_common_and_wait_postgres
  apply_chatgpt_device_flow_probe
  apply_gateway_and_wait
  generate_virtual_key
  create_worker_secret
  create_worker_smoke_job
  block_virtual_key_and_assert_denied
  assert_boundary
  capture_cluster_state
  log "PASS LiteLLM ChatGPT Kubernetes smoke completed"
}

main "$@"
