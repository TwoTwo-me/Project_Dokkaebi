# Project Dokkaebi QA and evaluation plan (2026-05-28)

## Current QA result snapshot

Executed from `/home/koreaplayer99/Project_Dokkaebi` on 2026-05-28 UTC.

Evidence file: `.omx/evidence/G003-qa-baseline-20260528T1937Z.txt`.

| Check | Result | Notes |
| --- | --- | --- |
| `python3 -m py_compile scripts/dokkaebi-project-status-sync.py scripts/test-dokkaebi-project-status-sync.py scripts/dokkaebi-approval-transition-check.py scripts/dokkaebi-worker-result-review.py` | PASS | Python entrypoints compile. |
| `bash -n scripts/...` | PASS | Manager/Symphony/status-sync/service shell scripts parse. |
| `./scripts/test-dokkaebi-project-status-sync.py` | PASS | Covers drift, corrupt state, terminal approval blocking, event-before-state, race guard, all-or-nothing mutation. |
| `./scripts/validate-contract-docs.sh` | PASS | Contract docs are present, linked, and structurally aligned. |
| `DOKKAEBI_WORKER_SANITIZED=1 ./scripts/dokkaebi-symphony-preflight.sh --strict` | PASS with expected warning | Sanitized Worker context intentionally lacks project mutation auth. |
| `git diff --check` | PASS | No whitespace errors. |

Live GitHub GraphQL field/item checks were rate-limited before reset; REST Project view mutation and Project item listing still worked through core REST. Evidence:

- `.omx/evidence/G012-rate-limit-20260528T1941.json`
- `.omx/evidence/project-view-create/*.json`

## QA goals

Dokkaebi should be evaluated as a **human-governed project-management and worker-dispatch system**, not just as a code repo.

1. **Safety correctness**: approval-gated transitions fail closed without human-origin provenance.
2. **State consistency**: human-visible `Status` and Dokkaebi/Symphony `Dokkaebi Status` stay aligned.
3. **Worker readiness**: each dispatchable item has ProjectScope, permission, capability, validation, and result packet expectations.
4. **Runtime reliability**: always-on pollers restart safely, honor kill switches, and do not leak Manager credentials.
5. **Manager quality**: Manager summaries cite durable evidence and route uncertain work to Human Review.
6. **Usability**: a human can open GitHub Project and immediately see what needs attention.

## Evaluation rubric

| Area | Pass criteria | Failure signal |
| --- | --- | --- |
| Project model | `README.md`, `ARCHITECTURE.md`, `WORKFLOW.md`, ProjectScope YAML, policy YAML, and Symphony workflow agree on IDs/statuses. | Inconsistent status names, hidden state, or undocumented authority. |
| Approval gates | `Human Review -> Merging/Done`, issue close, merge, deploy, credentials, and provider mutation require trusted provenance. | Manager self-approval or ambiguous provenance accepted. |
| Worker isolation | Worker launcher scrubs GitHub/SSH/cloud/manager/provider/model API env vars before `codex app-server`. | Raw Manager tokens visible to workers. |
| Status sync | Bidirectional observed sync applies only clean nonterminal drift and blocks races/terminal approvals. | Bootstrap guessing, partial mutation, or unverified terminal promotion. |
| QA harness | Static checks and targeted regression tests are runnable without credentials; live checks have explicit auth/rate-limit evidence. | A live failure is reported as pass or has no fallback evidence. |
| Always-on runtime | systemd services or equivalent are enabled, restart on transient failure, stop cleanly on kill switch, and expose logs/status. | Long-running manager daemon replaces request-triggered manager or service loops leak credentials. |
| Human UX | Project views show all work, human review queue, worker queue, and open nonterminal work with mirrored status fields. | Human cannot tell what to approve or what worker is doing. |

## QA cadence

### Per local change

```bash
python3 -m py_compile scripts/dokkaebi-project-status-sync.py scripts/test-dokkaebi-project-status-sync.py scripts/dokkaebi-approval-transition-check.py scripts/dokkaebi-worker-result-review.py
bash -n scripts/dokkaebi-manager-preflight.sh scripts/dokkaebi-symphony-preflight.sh scripts/validate-contract-docs.sh scripts/dokkaebi-project-status-sync-loop.sh scripts/dokkaebi-symphony-run.sh scripts/dokkaebi-codex-worker-app-server.sh scripts/dokkaebi-service-loop.sh scripts/dokkaebi-install-user-services.sh
./scripts/test-dokkaebi-project-status-sync.py
./scripts/validate-contract-docs.sh
DOKKAEBI_WORKER_SANITIZED=1 ./scripts/dokkaebi-symphony-preflight.sh --strict
git diff --check
```

### Per live Project mutation

```bash
gh api rate_limit --jq '{core:.resources.core,graphql:.resources.graphql}'
./scripts/dokkaebi-project-status-sync.py --json
./scripts/dokkaebi-project-status-sync.py --direction bidirectional --apply --record-state --json
```

If GraphQL rate limit is exhausted, record the reset time and rely only on offline no-network tests until reset.

### Per always-on service rollout

```bash
./scripts/dokkaebi-symphony-preflight.sh --strict
./scripts/dokkaebi-install-user-services.sh
systemctl --user status dokkaebi-status-sync.service dokkaebi-symphony.service
journalctl --user -u dokkaebi-status-sync.service -n 80 --no-pager
journalctl --user -u dokkaebi-symphony.service -n 80 --no-pager
curl -fsS http://127.0.0.1:${DOKKAEBI_SYMPHONY_PORT:-4000}/api/v1/state
```

## Current usability findings and PR split

| Finding | Impact | PR shape |
| --- | --- | --- |
| Python cache files appeared as untracked noise. | Reviewers see non-product files in `git status`. | `.gitignore` update for `__pycache__/`, `*.py[cod]`. |
| Always-on worker registration was implicit. | Operator cannot tell how to start/stop local pollers safely. | Add systemd unit templates, installer, and runbook. |
| Project direction/QA knowledge was spread across chat/evidence. | Human review requires reconstructing context manually. | Add research, QA, and strategy Markdown docs. |
| GitHub rate-limit blocks live Project verification. | Manager preflight can look like a product failure. | Add QA guidance and future enhancement for rate-limit-aware retry/backoff. |
| GitHub Project views were not human-optimized. | Human and Dokkaebi state can be correct but hard to inspect. | Create saved views and document expected layout. |
