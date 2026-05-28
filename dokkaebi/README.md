# Dokkaebi runtime bootstrap artifacts

This directory is the first concrete ProjectScope binding for running Dokkaebi
against this repository.

It is intentionally configuration-first:

- `project-scopes/project-dokkaebi.yml` binds this Git repository to a
  Dokkaebi `ProjectScope` and the Symphony-native execution layer.
- `policies/project-dokkaebi.yml` records the per-project authority, Worker, and
  runtime-provider policy for this scope.
- `symphony/WORKFLOW.project-dokkaebi.md` is the Symphony workflow contract that
  can be passed to the GitHub Project tracker implementation after the remote
  GitHub Project is created and its id is known.
- `approvals/` stores durable Human approval records for control-plane setup.

No secrets belong in these files. Runtime tokens and provider credentials must
be supplied through the credential broker or environment variable indirection
called out by the scope and workflow files.

The workflow's Codex Worker command goes through
`../scripts/dokkaebi-codex-worker-app-server.sh` to remove Manager/control-plane
credential environment variables before the Worker process starts.
