# Dokkaebi Fire Sandbox Service

Dokkaebi Fire is the long-running backend watcher. It should stay on for a
sandbox GitHub Project so admitted issues can be dispatched even when the
Manager plugin is not currently loaded. The Manager remains an on-demand
planning and project-configuration surface; Fire is the daemon-like service.

This runbook documents the user-level `systemd` pattern used for the sandbox
service. Treat it as sandbox operations guidance, not production approval.
Production services, shared hosts, persistent clusters, and broader worker
authority still require explicit Human approval under
[`docs/policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Current Sandbox Shape

Default local service values:

| Setting | Value |
| --- | --- |
| Service name | `dokkaebi-fire-sandbox.service` |
| Project | `Dokkaebi Sandbox` |
| Project URL | `https://github.com/users/Project-Dokkaebi/projects/2` |
| Dashboard | `http://127.0.0.1:4052/` |
| State API | `http://127.0.0.1:4052/api/v1/state` |
| Workflow config | `$HOME/.config/dokkaebi/fire/sandbox-WORKFLOW.md` |
| Start wrapper | `$HOME/.local/bin/dokkaebi-fire-sandbox-start` |
| Logs | `$HOME/.local/state/dokkaebi/fire/sandbox/logs` |
| Workspaces | `$HOME/.local/state/dokkaebi/fire/sandbox/workspaces` |

The sandbox service should only dispatch items that satisfy all admission
gates:

- `Status` is `Todo` or `In Progress`.
- `Agent` is `Dokkaebi+Symphony`.
- `Authorization` is `Approved`.
- `Symphony Admission` is `Yes`.
- Current concurrency is below the configured Fire limit.

Items in `Human Review`, `Blocked`, or `Done` are not active dispatch targets.

## Register The Service

Authenticate the GitHub CLI first. The service wrapper reads the token at
runtime, so the token is not stored in tracked files or the unit file.

```bash
gh auth status
gh auth refresh -s repo -s project
```

Create local config and state directories:

```bash
mkdir -p "$HOME/.config/dokkaebi/fire"
mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/state/dokkaebi/fire/sandbox/logs"
mkdir -p "$HOME/.local/state/dokkaebi/fire/sandbox/workspaces"
```

Create `$HOME/.config/dokkaebi/fire/sandbox-WORKFLOW.md` from the backend
workflow format in
[`symphony-github-project-tracker/elixir/WORKFLOW.md`](../../symphony-github-project-tracker/elixir/WORKFLOW.md).
The config should use `$GITHUB_GRAPHQL_TOKEN` for `tracker.api_key` and should
keep the sandbox admission fields explicit.

Create `$HOME/.local/bin/dokkaebi-fire-sandbox-start`:

```bash
#!/usr/bin/env bash
set -euo pipefail

export GITHUB_GRAPHQL_TOKEN="$(gh auth token)"

cd "<repo-root>/symphony-github-project-tracker/elixir"
exec "$HOME/.local/bin/mise" exec -- ./bin/symphony \
  --i-understand-that-this-will-be-running-without-the-usual-guardrails \
  --logs-root "$HOME/.local/state/dokkaebi/fire/sandbox/logs" \
  --port 4052 \
  "$HOME/.config/dokkaebi/fire/sandbox-WORKFLOW.md"
```

Make it executable:

```bash
chmod 700 "$HOME/.local/bin/dokkaebi-fire-sandbox-start"
```

Create `$HOME/.config/systemd/user/dokkaebi-fire-sandbox.service`:

```ini
[Unit]
Description=Dokkaebi Fire sandbox GitHub Project watcher
Documentation=https://github.com/TwoTwo-me/Project_Dokkaebi
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.local/bin/dokkaebi-fire-sandbox-start
Restart=always
RestartSec=15
WorkingDirectory=<repo-root>/symphony-github-project-tracker/elixir
Environment=HOME=%h
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
NoNewPrivileges=false

[Install]
WantedBy=default.target
```

Register and start it:

```bash
systemctl --user daemon-reload
systemctl --user enable --now dokkaebi-fire-sandbox.service
```

Only enable user lingering when the host owner has approved Fire to survive
logout:

```bash
loginctl enable-linger "$USER"
```

## Verify Operation

Check service state:

```bash
systemctl --user is-enabled dokkaebi-fire-sandbox.service
systemctl --user is-active dokkaebi-fire-sandbox.service
systemctl --user status dokkaebi-fire-sandbox.service
```

Follow logs:

```bash
journalctl --user -u dokkaebi-fire-sandbox.service -f
```

Check the Fire state API:

```bash
curl -sS http://127.0.0.1:4052/api/v1/state
```

Expected healthy state:

- The service is `enabled` and `active`.
- The API returns the configured sandbox project title and project URL.
- `active_agents` reflects currently dispatched workers.
- Idle projects report no worker only when no admitted active issue exists.

## Manage The Service

Restart after workflow or backend changes:

```bash
systemctl --user restart dokkaebi-fire-sandbox.service
```

Stop temporarily without removing autostart:

```bash
systemctl --user stop dokkaebi-fire-sandbox.service
```

Disable and stop:

```bash
systemctl --user disable --now dokkaebi-fire-sandbox.service
```

After changing the unit file:

```bash
systemctl --user daemon-reload
systemctl --user restart dokkaebi-fire-sandbox.service
```

## Troubleshooting

If the state API returns authentication errors, run:

```bash
gh auth status
gh auth refresh -s repo -s project
systemctl --user restart dokkaebi-fire-sandbox.service
```

If no work is dispatched, inspect the GitHub Project item fields first. Fire
should stay idle unless `Status`, `Agent`, `Authorization`, and
`Symphony Admission` all match the sandbox admission gates.

If the dashboard port is already in use, change both the wrapper `--port`
argument and any local dashboard link that points at the old port.

If worker execution requires Docker, Kubernetes, or SSH routes, confirm the
route profile is authorized in the workflow config before dispatch. The local
sandbox service may use `danger-full-access` only as a host-specific workaround
when the normal workspace sandbox cannot run; prefer a tighter worker sandbox
whenever the host supports it.
