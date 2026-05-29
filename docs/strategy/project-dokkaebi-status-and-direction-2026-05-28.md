# Project Dokkaebi status and direction (2026-05-28)

## Current state

Project Dokkaebi is now a bootstrap self-hosting repo for a Symphony-native, human-governed development loop:

```text
Human request -> request-triggered Manager -> GitHub Project / Symphony ProjectScope -> always-on Worker poller -> result packet -> Manager review -> Human Review
```

Implemented baseline:

- Repository-bound ProjectScope: `dokkaebi/project-scopes/project-dokkaebi.yml`.
- Per-project policy: `dokkaebi/policies/project-dokkaebi.yml`.
- Symphony GitHub Project workflow: `dokkaebi/symphony/WORKFLOW.project-dokkaebi.md`.
- Manager/Symphony preflight scripts and Worker env scrubber under `scripts/`.
- Bidirectional observed `Status` ↔ `Dokkaebi Status` sync with terminal approval blocking.
- Local built Symphony escript at `symphony-github-project-tracker/elixir/bin/symphony`.
- GitHub Project: <https://github.com/users/Project-Dokkaebi/projects/1>.

## Current live Project view setup

Created on 2026-05-28 via REST Project view API:

| View | URL | Purpose |
| --- | --- | --- |
| Dokkaebi 00 — All work | <https://github.com/users/Project-Dokkaebi/projects/1/views/2> | Full audit table with both status fields and capability metadata. |
| Dokkaebi 01 — Human Review | <https://github.com/users/Project-Dokkaebi/projects/1/views/3> | Human attention queue. |
| Dokkaebi 02 — Worker queue | <https://github.com/users/Project-Dokkaebi/projects/1/views/4> | Dispatchable/In Progress/Fix Requested board. |
| Dokkaebi 03 — Open nonterminal | <https://github.com/users/Project-Dokkaebi/projects/1/views/5> | Nonterminal work excluding Done/Cancelled/Failed. |

Evidence: `.omx/evidence/project-view-create/*.json`.

## Directional decisions

### 1. Manager is not always-on by default

The Manager should run when a human request, ticket drafting, result review, or human summary is needed. This keeps authority and approval boundaries explicit.

### 2. Symphony/worker side is always-on

The worker side should poll GitHub Project and dispatch eligible ProjectScope items continuously. The safest first self-hosting path is user-level systemd services wrapping existing Dokkaebi scripts.

### 3. GitHub Project is the first human UI

Do not build a rich dashboard yet. Optimize GitHub Project fields/views and keep them aligned with Dokkaebi state. GitHub docs explicitly support table/board/roadmap views, custom fields, and automation/API control: <https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects>.

### 4. Symphony remains the execution layer

OpenAI Symphony's spec focuses on a long-running issue-tracker poller with per-issue workspaces and repo-owned workflow policy: <https://github.com/openai/symphony/blob/main/SPEC.md>. Dokkaebi should sit one layer above it, managing multiple ProjectScopes and human review/evaluation.

### 5. Docker/VM/Kubernetes are provider tiers, not the initial default

Docker restart policies are valid for containerized workers, but the current safest local path uses systemd because existing scripts already enforce kill switch, preflight, workflow selection, and credential scrubbing. Docker worker fleet enablement should wait for explicit provider approval and credential broker maturity.

### 6. `Status = Merging` is a Dokkaebi Merge Gate signal

When a Human changes the GitHub Project `Status` field from `Human Review` to
`Merging`, Dokkaebi should treat that as a **human merge-stage handoff signal**,
not as a generic Symphony Worker task. The preferred future automation is a
separate always-on Merge Gate owned by Dokkaebi/Manager policy:

1. detect Project items where `Status = Merging` and `Dokkaebi Status = Human Review`;
2. verify the actor/provenance represents an approved Human handoff;
3. verify PR mergeability, required checks, and review state;
4. verify permission level allows automation (`docs-only` and narrow `local-code` first;
   keep `provider-change` and `merge-deploy` human-gated until a later policy grants them);
5. set `Dokkaebi Status = Merging`, merge the PR, then set both status fields
   to `Done` only after the merge is observed;
6. on failure, leave an evidence comment and route by ownership: `Fix Requested`
   for author-actionable PR fixes such as failing checks, requested changes, or
   conflicts, and `Blocked` for missing human provenance, insufficient permission,
   unavailable mergeability data, or policy/tooling failures.

Do not route this transition back to a normal Symphony Worker. Workers prepare
changes and evidence; the Merge Gate performs the approval-sensitive closeout.
`Status = Merging` is therefore a Manager-side closeout signal, not a new coding
assignment.

## Near-term roadmap

1. **Stabilize self-hosting v0**
   - Keep `dokkaebi-status-sync.service` and `dokkaebi-symphony.service` running.
   - Validate no dispatchable item is repeated after Human Review.
   - Document service stop/start/log inspection.

2. **Move all work through Human Review**
   - Draft tickets and PRs may be created automatically.
   - Merge/deploy/issue terminal closeout remains human-reviewed.
   - Manager may summarize and recommend; Human performs final merge/deploy authority.

3. **Add better rate-limit/backoff UX**
   - Live GitHub Project checks should report reset time and next safe retry.
   - Offline regressions remain the fallback when rate-limited.

4. **Introduce credential broker before privileged workers**
   - No long-lived Manager PAT copied into Worker environments.
   - GitHub App installation token or equivalent broker should grant short-lived repo/task-scoped access.

5. **Testbed tier after local-basic proves stable**
   - Use Docker/VM/self-hosted runner scale sets for validation environments, not as the first authority boundary.

## Evaluation stop condition for the current milestone

The current milestone is ready for Human Review when:

- QA baseline passes.
- Research/strategy/QA docs exist in Markdown.
- GitHub Project views are created and usable.
- Always-on worker/status sync services are installed and observed running or blocked with clear evidence.
- Usability issues discovered during QA are split into PRs or documented as follow-up review items.
