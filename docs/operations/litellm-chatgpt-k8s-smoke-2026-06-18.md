# LiteLLM ChatGPT Kubernetes Smoke

Date: 2026-06-18

## Purpose

Prove the practical Kubernetes shape behind the optional LiteLLM ChatGPT
homelab gateway guide. This smoke verifies that LiteLLM can run inside a
disposable Kubernetes cluster, read a ChatGPT subscription provider config,
reach the ChatGPT OAuth device-flow gate, and separately prove the
Gateway/virtual-key/worker boundary without putting ChatGPT OAuth material into
Hammer worker pods.

This smoke does not complete a ChatGPT OAuth login and does not call the
ChatGPT subscription backend successfully. That final provider call still
requires an operator-owned ChatGPT account and explicit credential approval.

## Command

```bash
bash scripts/run-litellm-chatgpt-k8s-smoke.sh
```

The runner creates a disposable `kind` cluster named
`dokkaebi-litellm-smoke`, deploys Postgres and LiteLLM in `dokkaebi-llm`, runs
worker Jobs in `dokkaebi-workers`, and deletes the cluster and temporary work
directory on exit.

## What Was Proven

Observed PASS markers from the 2026-06-18 local run:

```text
chatgpt_provider_config_loaded=yes
chatgpt_provider_requires_device_flow=yes
deployment.apps/litellm condition met
virtual_key_generated=yes
models=dokkaebi-litellm-smoke
models_status=200
models_contains_gateway_model=yes
no_auth_models_status=401
gateway_provider_call_status=401
gateway_provider_call=blocked_by_fake_provider_key
worker_gateway_secret_absent=yes
virtual_key_blocked=yes
blocked_key_models_status=401
worker_pod_boundary_ok=yes
PASS LiteLLM ChatGPT Kubernetes smoke completed
cleanup_kind_cluster=dokkaebi-litellm-smoke deleted
cleanup_kind_containers=dokkaebi-litellm-smoke none
```

## Interpretation

The ChatGPT provider config is structurally usable in a Kubernetes LiteLLM Pod:
LiteLLM loaded the `chatgpt/gpt-5.3-codex` and `chatgpt/gpt-5.4` model entries
and then stopped at the expected operator device-flow prompt. Without an
operator OAuth login or pre-mounted ChatGPT token directory, the ChatGPT
provider should not be treated as ready for model traffic.

The Gateway boundary is independently usable in Kubernetes:

- LiteLLM started behind a ClusterIP Service with Postgres-backed key storage.
- `/key/generate` created a task-scoped virtual key for a configured model.
- A worker Job reached `/v1/models` through the LiteLLM Service with only the
  virtual key.
- An unauthenticated worker request was denied with HTTP 401.
- A provider call using a fake upstream provider key was denied with HTTP 401,
  proving the request reached LiteLLM and the upstream auth boundary without
  needing a real provider credential.
- `/key/block` blocked the virtual key, and a follow-up worker request was
  denied with HTTP 401.
- The worker Pod used `automountServiceAccountToken: false` and did not receive
  `CHATGPT_TOKEN_DIR`, `CHATGPT_AUTH_FILE`, `LITELLM_MASTER_KEY`, or the
  LiteLLM Gateway token volume.

## Boundary

The smoke uses only disposable local Kubernetes, fake provider credentials, and
ephemeral LiteLLM virtual keys. It does not persist or publish raw virtual keys,
OAuth files, refresh tokens, cookies, kubeconfigs, or provider credentials.

The ChatGPT OAuth material remains a Gateway-only concern. A real homelab proof
with ChatGPT model output must add a separate operator step:

1. Complete ChatGPT OAuth device-flow login for the operator-owned account.
2. Mount the resulting ChatGPT token directory only into the LiteLLM Gateway
   Pod.
3. Re-run the worker request and confirm the requested model output.
4. Confirm LiteLLM spend/log evidence and key revocation.
5. Confirm worker pod specs, logs, issue evidence, and result packets still do
   not contain ChatGPT OAuth material.

## Cleanup

The runner deletes the `dokkaebi-litellm-smoke` kind cluster, verifies no
same-name kind containers remain, and removes its temporary work directory.

## Residual Risk

- The smoke proves Kubernetes Gateway viability and key boundaries, not a
  successful ChatGPT subscription inference.
- ChatGPT OAuth device-flow login and provider terms remain operator-controlled
  external gates.
- The fake-provider 401 is intentional; it proves request routing and boundary
  behavior without exposing a real provider key.
- This is a local homelab proof, not enterprise production readiness, EKS
  identity validation, or shared-cluster security evidence.
