# Codex/OMX Bootstrap Manager Adapter

This adapter is the temporary Manager path for bringing up Dokkaebi before a
fully reviewed Hermes Manager integration exists.

## Role

Codex/OMX may act as the bootstrap Manager when it follows the Dokkaebi Manager
Contract:

- preserve the Human request and constraints;
- write Worker-ready ProjectScope tickets;
- run policy/approval preflight before dispatch;
- avoid direct Worker scheduling when Symphony owns the ProjectScope loop;
- review Worker result packets and summarize evidence back to the Human.

## Hermes status in this environment

Hermes Agent was installed under the user's home directory for bootstrap testing:

- command: `~/.local/bin/hermes`
- code: `~/.local/share/hermes-agent`
- config: `~/.hermes/config.yaml`
- auth store: `~/.hermes/auth.json`

The install used the upstream Hermes Agent installer with `--skip-setup` and
`--skip-browser`. OpenAI Codex OAuth token metadata was imported from the local
Codex auth store into Hermes' own auth store without writing secrets into this
repository or Worker workspaces. `hermes status` reports OpenAI Codex logged in,
and a one-shot smoke test returned `hermes-ok`.

Hermes is therefore available for experimentation, but Dokkaebi core remains
Manager-contract-first and may continue using Codex/OMX as the bootstrap Manager
until a dedicated Hermes adapter runner is implemented and reviewed.

## Auth boundaries

- Existing Codex auth: `~/.codex/auth.json`.
- Hermes auth copy: `~/.hermes/auth.json`.
- GitHub CLI auth: `gh auth status` must include `project` scope for GitHub
  Project v2 setup.
- These Manager credentials must not be copied into Symphony Worker workspaces.
- Worker credentials must later be issued through a credential broker.
- The Symphony Worker command must go through
  `scripts/dokkaebi-codex-worker-app-server.sh`, which scrubs Manager GitHub,
  SSH, cloud, provider, Hermes, and Symphony control-plane environment variables
  before launching `codex app-server`.

## Preflight

```bash
scripts/dokkaebi-manager-preflight.sh
```

The script reports Hermes, Codex, and GitHub Project auth readiness with secret
redaction.

## Bootstrap Manager fallback

If Hermes is unavailable or fails a runtime smoke test, use Codex/OMX as the
Manager adapter for the next action only:

1. Load `dokkaebi/project-scopes/project-dokkaebi.yml`.
2. Load `dokkaebi/policies/project-dokkaebi.yml`.
3. Draft or update one Worker-ready GitHub Project item.
4. Keep the item non-credentialed and `basic` capability for v0.
5. Let Symphony, not the Manager, pick up dispatchable work.
6. Review the result packet before any merge/deploy/credential/provider action.
