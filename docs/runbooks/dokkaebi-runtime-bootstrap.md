# Dokkaebi runtime bootstrap runbook

This runbook starts the first runnable Dokkaebi loop for this repository by
using the existing `symphony-github-project-tracker` implementation instead of
rebuilding Symphony inside Dokkaebi.

## Boundaries

- ProjectScope: `dokkaebi/project-scopes/project-dokkaebi.yml`
- Policy: `dokkaebi/policies/project-dokkaebi.yml`
- Symphony workflow: `dokkaebi/symphony/WORKFLOW.project-dokkaebi.md`
- Existing Symphony implementation: `symphony-github-project-tracker/`

Do not copy Manager tokens into Worker workspaces, merge PRs, deploy, mutate
infrastructure, or enable host Docker authority as part of this bootstrap.

## 1. Preflight

```bash
scripts/dokkaebi-symphony-preflight.sh
```

Use strict mode when a CI-style failure is desired:

```bash
scripts/dokkaebi-symphony-preflight.sh --strict
```

The preflight checks the local ProjectScope files, parses the Symphony workflow
front matter, verifies that the existing Symphony implementation is present, and
reports runtime/auth blockers without printing secrets.

## 2. Build existing Symphony if needed

The upstream local path expects Elixir/mix or mise:

```bash
cd symphony-github-project-tracker/elixir
mix setup
mix escript.build
```

or:

```bash
cd symphony-github-project-tracker/elixir
mise exec -- mix setup
mise exec -- mix escript.build
```

This repository does not vendor a new Symphony implementation. It passes the
Dokkaebi workflow file to the existing tracker service.

## 3. GitHub Project auth

The workflow stores the GitHub Project v2 node id in
`dokkaebi/symphony/WORKFLOW.project-dokkaebi.md` and
`dokkaebi/project-scopes/project-dokkaebi.yml`. Runtime auth is supplied only to
the Symphony tracker process:

```bash
export GITHUB_GRAPHQL_TOKEN='...'
```

If using `gh`, the token must include project scope, and
`scripts/dokkaebi-symphony-run.sh` may derive the exact Symphony runtime token
from `gh auth token` when `GITHUB_GRAPHQL_TOKEN` is not already exported:

```bash
gh auth refresh -h github.com -s project
```

Strict preflight verifies the exact `GITHUB_GRAPHQL_TOKEN` that Symphony will use
by querying GitHub's token-scope response headers. Verifying unrelated `gh auth`
state is not sufficient for a mutating runtime.

The current bootstrap policy forbids copying this Manager token into Worker
workspaces. Worker credentials must later come from a broker. The configured
Codex Worker command uses `scripts/dokkaebi-codex-worker-app-server.sh`, which
scrubs GitHub, SSH, cloud, provider, Hermes, and Symphony control-plane
credentials before launching `codex app-server`.
It still preserves Codex model-runtime auth via `CODEX_HOME`; that is not a
general-purpose credential grant to Workers.

Validate the scrubber without printing secrets:

```bash
GITHUB_GRAPHQL_TOKEN=sentinel GH_TOKEN=sentinel \
  scripts/dokkaebi-codex-worker-app-server.sh --check-sanitizer
```

## 4. Run Symphony against Project Dokkaebi

```bash
scripts/dokkaebi-symphony-run.sh
```

Useful overrides:

```bash
DOKKAEBI_SYMPHONY_PORT=4010 scripts/dokkaebi-symphony-run.sh
DOKKAEBI_BUILD_SYMPHONY=1 scripts/dokkaebi-symphony-run.sh
DOKKAEBI_WORKER_REF=refs/heads/my-branch scripts/dokkaebi-symphony-run.sh
```

The run script supplies the explicit Symphony guardrail acknowledgement flag and
passes `dokkaebi/symphony/WORKFLOW.project-dokkaebi.md` to the existing escript.
When `DOKKAEBI_WORKER_REF` is set, the `after_create` hook fetches that branch,
SHA, or pull-request ref into the Worker checkout before execution. Unsafe ref
syntax fails closed.
`scripts/dokkaebi-symphony-preflight.sh --strict` also blocks when
`dokkaebi/KILL_SWITCH` exists.

After a Worker produces a result packet, the Manager must ingest the packet and
move the custom `Dokkaebi Status` field out of active states before continuing an
unattended poll loop. `Human Review`, `Fix Requested`, or `Blocked` are the safe
post-result states; leaving a completed item as `Dispatchable` can repeat
dispatch.

The GitHub Project's human-visible `Status` field is a strict mirror of
`Dokkaebi Status`. It must have the same option set and the same value on every
item. Before starting or resuming a Manager/Symphony loop, run:

```bash
scripts/dokkaebi-project-status-sync.py --json
```

If drift is reported and the Dokkaebi field is trusted as authoritative, repair
the human mirror with:

```bash
scripts/dokkaebi-project-status-sync.py --apply --json
```

## 5. First test item

The first live item is `basic`, docs-only, and non-credentialed. It validates
that the Manager can create a Worker-ready ticket, Symphony can see it as
dispatchable, and the Worker can return a result packet for Manager review. If
GitHub Project auth is not available, use the dry-run artifact under
`.omx/evidence/` as the blocked-boundary record.

For validation of new Manager-authored artifacts, dispatch against a committed
branch or PR by setting `DOKKAEBI_WORKER_REF`. A Worker checkout created from
remote `main` cannot see uncommitted Manager-local files.

## 6. Human Review terminal approval gate

Before a Manager, Symphony adapter, or future approval broker treats a status
transition as terminal approval, validate the transition record locally:

```bash
scripts/dokkaebi-approval-transition-check.py --record transition.json --json
```

The transition record must include `source_status`, `target_status`, `actor`,
`actor_origin`, `provenance_source`, `approved_action`,
`linked_ticket_or_item`, `linked_result_packet_or_review`,
`provenance_record_id`, `provenance_checked_by`, and
`provenance_verification_method`, `provenance_evidence_file`, and
`provenance_evidence_sha256`. `Human Review` → `Merging`,
`Human Review` → `Done`, and GitHub issue close require human-origin,
source-specific provenance. Manager-authored, untrusted, or ambiguous terminal
transitions are blocked rather than treated as approval.

For local/bootstrap validation, source-specific provenance must be represented
by a durable evidence file and SHA-256 hash plus existing linked result/review
evidence. Bootstrap v0 enables only `durable_human_approval_record`; GitHub
status-history records and future broker decisions fail closed until their
adapters authenticate live API output or verify a broker signature. The checker
rejects forged records that only copy accepted verifier/source strings without
enabled source-specific evidence.

## 7. Worker result ingestion and Manager review

When Symphony or a Worker returns a packet matching
[`docs/templates/worker-result-packet.md`](../templates/worker-result-packet.md),
the Manager should review it before changing terminal status:

```bash
scripts/dokkaebi-worker-result-review.py worker-result.md --json
```

The review helper checks required packet sections, acceptance statuses,
validation evidence, blockers, and scope-control signals. It may recommend
`Human Review`, `Fix Requested`, or `Blocked`. It never authorizes merge,
deployment, GitHub issue close, `Done` closeout, or `Human Review` → `Merging` /
`Done`; those remain guarded by the terminal approval gate above.
