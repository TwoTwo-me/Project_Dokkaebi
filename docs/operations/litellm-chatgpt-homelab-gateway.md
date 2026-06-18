# Optional LiteLLM ChatGPT Homelab Gateway

This runbook defines an optional homelab pattern for using a personal ChatGPT
Pro/Max subscription through LiteLLM without copying broad OAuth material into
Dokkaebi Fire or Hammer runtimes.

It is not a Dokkaebi product requirement. Dokkaebi core should depend on a
credential-brokered LLM endpoint contract, not on LiteLLM, ChatGPT subscription
accounts, or any one provider. Enterprise installations will usually manage
provider API keys, budgets, audit logs, and model access through their own
approved gateway or through LiteLLM with enterprise-owned credentials.

This pattern is useful for a personal developer or homelab operator who wants a
practical bridge:

```text
Dokkaebi Fire or Hammer
  -> task-scoped LiteLLM virtual key
  -> LiteLLM Gateway
  -> ChatGPT OAuth device-flow token store
  -> ChatGPT subscription backend
```

## Boundary

ChatGPT OAuth tokens must stay in the LiteLLM Gateway boundary. A Hammer pod,
worker workspace, issue body, prompt, log, result packet, Docker image, or
Kubernetes Secret must not contain the raw ChatGPT OAuth file, refresh token,
browser session, or `CHATGPT_TOKEN_DIR` contents.

Allowed for a homelab proof:

- a LiteLLM Gateway controlled by the personal operator;
- a local or private Postgres database for LiteLLM virtual keys and spend logs;
- a task-scoped LiteLLM virtual key issued to a Fire or Hammer route;
- model allowlists, budget, RPM/TPM, duration, and key revocation;
- redacted request ids, key ids, usage, model, route, ticket id, and closeout
  evidence.

Not authorized by this runbook:

- making LiteLLM mandatory for Dokkaebi users;
- treating a personal ChatGPT subscription as an enterprise production
  credential;
- copying ChatGPT OAuth material into Fire or Hammer;
- bypassing provider terms, account limits, or Human approval gates;
- shared-cluster, production, EKS, cloud, or credential mutation without
  explicit approval under
  [`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## LiteLLM Configuration Shape

LiteLLM documents ChatGPT subscription access through the `chatgpt/` provider
route with OAuth device-flow authentication. The provider is native to the
Responses API, and Chat Completions calls are bridged for supported models.

Example `config.yaml` shape:

```yaml
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
```

Relevant LiteLLM settings for this pattern:

- `CHATGPT_TOKEN_DIR`: token storage directory for the Gateway only;
- `CHATGPT_AUTH_FILE`: auth file name, default `auth.json`;
- `DATABASE_URL`: Postgres URL for virtual keys and spend logs;
- `LITELLM_MASTER_KEY`: admin key used to create, inspect, block, and unblock
  virtual keys.

Do not put `CHATGPT_TOKEN_DIR`, `CHATGPT_AUTH_FILE`, ChatGPT OAuth contents, or
the LiteLLM master key into Hammer job specs.

## Kubernetes Shape

For a private homelab Kubernetes proof, keep the Gateway in its own namespace,
for example `dokkaebi-llm`.

Recommended boundaries:

- LiteLLM Gateway Service is reachable from Fire and approved Hammer routes;
- ChatGPT OAuth token storage is mounted only into the Gateway pod;
- LiteLLM master key and database URL are mounted only into the Gateway admin
  path;
- Hammer jobs receive only a short-lived LiteLLM virtual key, preferably through
  the credential broker bundle for that ticket;
- NetworkPolicy allows Hammer egress to the LiteLLM Gateway and denies direct
  egress to the ChatGPT backend unless the ticket explicitly grants it;
- result packets record key id or safe fingerprint, model, usage, request id,
  route profile, ticket id, and revocation result, never raw token material.

## Practical Verification

This is the real-surface proof expected before calling the homelab pattern
working. It requires a Human/operator OAuth device-flow login and therefore is
not a repository-only validation.

1. Start LiteLLM with the ChatGPT provider config.
2. Complete the OAuth device-flow login on the operator-owned account.
3. Generate a task-scoped LiteLLM virtual key for the allowed ChatGPT models.
4. Run one Fire or Hammer request through the LiteLLM Gateway using only that
   virtual key.
5. Confirm LiteLLM records the request in spend/log views by key, model, and
   user or team.
6. Block or delete the virtual key.
7. Re-run the same worker request and confirm it is denied.
8. Inspect the Hammer pod spec, env, mounted volumes, logs, issue evidence, and
   result packet for absence of ChatGPT OAuth material.

Example smoke request shape:

```bash
curl "$LITELLM_BASE_URL/v1/responses" \
  -H "Authorization: Bearer $DOKKAEBI_LITELLM_VIRTUAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "chatgpt/gpt-5.3-codex",
    "input": "Return the literal string dokkaebi-litellm-smoke-ok."
  }'
```

Expected evidence:

- response contains the requested literal smoke string;
- LiteLLM spend/log entry exists for the virtual key;
- no raw ChatGPT OAuth material appears in Hammer logs or result packets;
- blocked or deleted virtual key prevents the same request from succeeding.

## Product Position

Dokkaebi should document this as an optional operating recipe, not a platform
dependency. The product-facing contract should remain:

- Fire and Hammer call an approved LLM gateway endpoint;
- credential broker issues scoped, expiring grants;
- operators choose the backing provider and account model;
- audit evidence is durable and redacted;
- production use requires an approved enterprise credential strategy.

For an individual developer, LiteLLM plus the ChatGPT subscription provider can
replace repeated OAuth copying with a local gateway, virtual keys, spend logs,
and revocation checks. For an enterprise, the same Gateway pattern can be used
with organization-approved API keys or provider accounts, but Dokkaebi must not
force the ChatGPT subscription path.

## Residual Risks

- ChatGPT subscription access depends on OAuth device-flow state controlled by
  the operator account.
- Provider behavior, limits, supported models, and acceptable use are governed
  by the provider and may differ from ordinary API-key usage.
- LiteLLM strips or ignores provider-rejected fields such as token-limit fields
  and metadata for the ChatGPT subscription provider, so Dokkaebi audit metadata
  must live in the LiteLLM key/log/result-packet layer.
- A homelab proof does not prove enterprise production readiness, shared-cluster
  security, EKS identity, or organization compliance.
