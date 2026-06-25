#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${DOKKAEBI_K8S_E2E_EVIDENCE_DIR:-${DOKKAEBI_E2E_EVIDENCE_DIR:-.omo/ulw-loop/evidence/k8s-platform-e2e-${timestamp}}}"
SUMMARY="$EVIDENCE_DIR/summary.txt"
RUNTIME_MODE="${DOKKAEBI_K8S_E2E_RUNTIME:-require}"
runtime_skipped=0
litellm_runtime_skipped=0
mkdir -p "$EVIDENCE_DIR"
: > "$SUMMARY"

log() {
  printf '%s\n' "$*" | tee -a "$SUMMARY"
}

run_capture() {
  name="$1"
  shift
  log "RUN $name: $*"
  set +e
  "$@" >"$EVIDENCE_DIR/${name}.txt" 2>&1
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    log "PASS $name"
    return
  fi
  log "FAIL $name status=$status"
  sed -n '1,220p' "$EVIDENCE_DIR/${name}.txt" >&2 || true
  exit "$status"
}

have_runtime_tools() {
  command -v docker >/dev/null 2>&1 \
    && command -v kind >/dev/null 2>&1 \
    && command -v kubectl >/dev/null 2>&1 \
    && docker info >/dev/null 2>&1
}

case "$RUNTIME_MODE" in
  auto | require | skip)
    ;;
  *)
    log "FAIL runtime_mode=$RUNTIME_MODE reason=expected_auto_require_or_skip"
    exit 64
    ;;
esac

log "evidence_dir=$EVIDENCE_DIR"
log "runtime_mode=$RUNTIME_MODE"

run_capture k8s-base-render kubectl kustomize k8s/base
log "PASS k8s base rendered"

run_capture validate-k8s-platformization bash scripts/validate-k8s-platformization.sh
run_capture validate-k8s-litellm-grafana-platform bash scripts/validate-k8s-litellm-grafana-platform.sh
run_capture validate-k8s-result-reconciliation bash scripts/validate-k8s-result-reconciliation.sh
run_capture validate-k8s-platform-e2e bash scripts/validate-k8s-platform-e2e.sh
run_capture validate-readiness-criteria bash scripts/validate-readiness-criteria.sh
run_capture validate-enterprise-scorecard bash scripts/validate-enterprise-scorecard.sh
run_capture validate-all bash scripts/validate-all.sh

if [ "$RUNTIME_MODE" = "require" ] && [ "${DOKKAEBI_SKIP_RUNTIME_SMOKE:-0}" = "1" ]; then
  log "FAIL runtime_smoke=required reason=DOKKAEBI_SKIP_RUNTIME_SMOKE_not_allowed_in_require_mode"
  exit 69
elif [ "${DOKKAEBI_SKIP_RUNTIME_SMOKE:-0}" = "1" ] || [ "$RUNTIME_MODE" = "skip" ]; then
  runtime_skipped=1
  log "runtime_smoke=skipped reason=explicit_static_mode_or_DOKKAEBI_SKIP_RUNTIME_SMOKE"
elif have_runtime_tools; then
  run_capture k8s-runtime-smoke bash scripts/run-k8s-runtime-smoke.sh
elif [ "$RUNTIME_MODE" = "require" ]; then
  log "FAIL runtime_smoke=required reason=missing_docker_kind_kubectl_or_docker_daemon"
  exit 69
else
  runtime_skipped=1
  log "runtime_smoke=skipped reason=missing_docker_kind_kubectl_or_docker_daemon"
fi

if [ "$RUNTIME_MODE" = "require" ] && [ "${DOKKAEBI_SKIP_LITELLM_RUNTIME_SMOKE:-0}" = "1" ]; then
  log "FAIL litellm_runtime_smoke=required reason=DOKKAEBI_SKIP_LITELLM_RUNTIME_SMOKE_not_allowed_in_require_mode"
  exit 69
elif [ "${DOKKAEBI_SKIP_LITELLM_RUNTIME_SMOKE:-0}" = "1" ] || [ "$RUNTIME_MODE" = "skip" ]; then
  litellm_runtime_skipped=1
  log "litellm_runtime_smoke=skipped reason=explicit_static_mode_or_DOKKAEBI_SKIP_LITELLM_RUNTIME_SMOKE"
elif have_runtime_tools; then
  run_capture litellm-chatgpt-k8s-smoke bash scripts/run-litellm-chatgpt-k8s-smoke.sh
elif [ "$RUNTIME_MODE" = "require" ]; then
  log "FAIL litellm_runtime_smoke=required reason=missing_docker_kind_kubectl_or_docker_daemon"
  exit 69
else
  litellm_runtime_skipped=1
  log "litellm_runtime_smoke=skipped reason=missing_docker_kind_kubectl_or_docker_daemon"
fi

if [ "$runtime_skipped" -eq 0 ] && [ "$litellm_runtime_skipped" -eq 0 ]; then
  log "PASS Dokkaebi K8S platform E2E completed"
else
  log "PASS Dokkaebi K8S platform static E2E completed"
  log "scorecard_100_point_claim=not_allowed_without_required_runtime_smokes"
fi
