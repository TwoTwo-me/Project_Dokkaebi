# Dokkaebi always-on worker services runbook

## Goal

Keep the **worker/Symphony side** always-on while keeping the **Manager side** request-triggered.

Services:

- `dokkaebi-status-sync.service` — mirrors GitHub Project `Status` and `Dokkaebi Status` continuously.
- `dokkaebi-symphony.service` — runs the Dokkaebi-specific Symphony ProjectScope poller.

## Why systemd first

Systemd user services use the existing Dokkaebi runner scripts and therefore preserve:

- `dokkaebi/KILL_SWITCH` checks;
- `scripts/dokkaebi-symphony-preflight.sh --strict`;
- `scripts/dokkaebi-codex-worker-app-server.sh` credential scrubbing;
- local `gh auth` token derivation in `scripts/dokkaebi-symphony-run.sh`;
- normal `journalctl --user` logs.

Docker restart policies are appropriate later for containerized worker fleets; see Docker's restart-policy docs: <https://docs.docker.com/engine/containers/start-containers-automatically/>.

## Install/update

```bash
./scripts/dokkaebi-install-user-services.sh
```

This copies templates from `ops/systemd/` into `~/.config/systemd/user/`, reloads systemd, and enables/starts both services.

## Inspect

```bash
systemctl --user status dokkaebi-status-sync.service dokkaebi-symphony.service
journalctl --user -u dokkaebi-status-sync.service -n 80 --no-pager
journalctl --user -u dokkaebi-symphony.service -n 80 --no-pager
curl -fsS http://127.0.0.1:${DOKKAEBI_SYMPHONY_PORT:-4000}/api/v1/state
```

## Stop

Preferred policy stop:

```bash
touch dokkaebi/KILL_SWITCH
systemctl --user stop dokkaebi-status-sync.service dokkaebi-symphony.service
```

Remove the kill switch only when the reason for stopping is resolved:

```bash
rm dokkaebi/KILL_SWITCH
systemctl --user start dokkaebi-status-sync.service dokkaebi-symphony.service
```

## Survive logout

Current login linger may be disabled. To keep user services running after logout, enable linger from an authorized admin shell:

```bash
loginctl enable-linger koreaplayer99
```

## Failure policy

`docs/qa/project-dokkaebi-qa-evaluation-2026-05-28.md` defines the QA evidence expected for service rollout. Transient GitHub API/rate-limit failures should restart through `scripts/dokkaebi-service-loop.sh`; kill switch exits stop cleanly.
