# Worker CLI Auth Propagation

This runbook defines how the Dokkaebi development and sandbox environment
propagates Codex CLI authentication to trusted Hammer worker runtimes.
OpenAI's Codex authentication guide documents the same headless-machine pattern:
copy file-based `~/.codex/auth.json` only to trusted machines and treat it like a
password.

It is a development/sandbox operating rule, not a production credential policy.
Production services, shared worker pools, Proxmox lifecycle automation,
Kubernetes persistent secrets, and broader credential authority still require
explicit Human approval under
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Current Approval Scope

The Human approved using the current environment's Codex auth as the source for
worker authentication on 2026-06-13.

Allowed scope:

- source: current user's file-based Codex auth at `$HOME/.codex/auth.json`;
- target class: trusted private dev/sandbox Hammer workers controlled by this
  Project Dokkaebi environment;
- current SSH target: `dokkaebi-hammer`;
- allowed purpose: unblock Codex CLI execution for Dokkaebi product development,
  sandbox issue processing, and worker-route testing;
- expiration: until the Human revokes this development rule, the source auth is
  rotated, or a target becomes shared/untrusted/production.

This approval does not authorize copying GitHub Manager tokens, SSH private
keys, kubeconfig files, Proxmox credentials, GitHub App private keys, or any
other broad secret into worker spaces. It also does not authorize Proxmox
resource mutation, Docker daemon mutation, Kubernetes secret creation, or
production deployment.

## Rules

- Treat `auth.json` like a password. Do not commit it, paste it into issues,
  include it in logs, or summarize its contents.
- Copy only from `$HOME/.codex/auth.json` after confirming the file exists and is
  readable.
- Install it only at the worker user's `$HOME/.codex/auth.json`.
- Keep target file permissions at `0600` and parent directory permissions no
  broader than `0700`.
- Prefer SSH stdin transfer so the secret does not appear in command arguments,
  shell history, tickets, or process listings.
- Keep Docker workers on the existing read-only bind mount pattern; do not bake
  `auth.json` into images.
- Do not create Kubernetes Secrets for Codex auth without a separate approval
  that names the cluster, context, namespace, secret name, lifetime, and cleanup
  expectation.

## SSH Worker Install

Use this pattern for a trusted SSH worker:

```bash
target=dokkaebi-hammer
src="$HOME/.codex/auth.json"

test -r "$src"
ssh -o BatchMode=yes "$target" \
  'umask 077;
   mkdir -p "$HOME/.codex" "$HOME/.local/state/dokkaebi/hammer/workspaces";
   tmp="$HOME/.codex/auth.json.tmp.$$";
   cat > "$tmp";
   test -s "$tmp";
   chmod 600 "$tmp";
   mv "$tmp" "$HOME/.codex/auth.json";
   test -r "$HOME/.codex/auth.json"' < "$src"
```

The command reads the local auth file through stdin and writes it atomically on
the worker. It should print no token material.

## Verification

Verify only metadata and executable readiness:

```bash
ssh -o BatchMode=yes dokkaebi-hammer \
  'stat -c "auth_path=%n mode=%a owner=%U" "$HOME/.codex/auth.json";
   stat -c "workspace_path=%n mode=%a owner=%U" "$HOME/.local/state/dokkaebi/hammer/workspaces";
   codex --version'
```

Expected result:

- `auth.json` exists on the worker account;
- file mode is `600`;
- workspace root exists and is user-owned;
- `codex --version` runs without requiring an interactive install.

Do not run an arbitrary Codex task as a health check unless the ticket or manual
test explicitly authorizes a model invocation.

## Rotation And Revocation

When local Codex auth is rotated, recopy it to each trusted dev/sandbox worker.
When a worker is retired or becomes untrusted, remove the copied cache:

```bash
ssh -o BatchMode=yes dokkaebi-hammer 'rm -f "$HOME/.codex/auth.json"'
```

If the source auth is suspected to be exposed, revoke or refresh the source
credential before restoring worker auth.
