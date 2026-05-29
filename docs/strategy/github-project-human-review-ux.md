# GitHub Project human-review UX assessment

Date: 2026-05-28
Project: <https://github.com/users/Project-Dokkaebi/projects/1>
Scope: lane 4, GitHub Project view / Human Review workflow UX.

## What was inspected

Commands run from the worker worktree:

```bash
gh auth status
gh repo view --json nameWithOwner,owner,name,url,description,visibility,defaultBranchRef
gh api graphql -f query='query { rateLimit { limit cost remaining resetAt used } viewer { login } }'
gh project view 1 --owner Project-Dokkaebi --format json
gh api graphql -F login=Project-Dokkaebi -F number=1 -f query='<targeted ProjectV2 fields/items query>'
gh api graphql -F login=Project-Dokkaebi -F number=1 -f query='<targeted ProjectV2 views query>'
gh api graphql -f query='<ProjectV2/ProjectV2View/Mutation introspection queries>'
```

Observed constraints:

- `gh` is authenticated as `Project-Dokkaebi` with `project` and `repo` scopes.
- GraphQL quota was low during inspection: first rate-limit check returned
  `remaining=87`, `resetAt=2026-05-28T19:45:59Z`; after targeted queries,
  `remaining=26`.
- `gh project field-list 1 --owner Project-Dokkaebi --format json` exceeded
  the remaining GraphQL quota, so lane 4 used narrower GraphQL queries.

## Current Project shape

`gh project view 1 --owner Project-Dokkaebi --format json` returned:

- title: `Dokkaebi Bootstrap`
- URL: <https://github.com/users/Project-Dokkaebi/projects/1>
- visibility: private
- fields: `17`
- items: `3`
- readme/short description were empty before this lane's metadata update.

Targeted ProjectV2 field inspection found the important control fields already
exist:

| Field | Type | UX role |
| --- | --- | --- |
| `Status` | single-select | Human-visible board state. |
| `Dokkaebi Status` | single-select | Manager/Symphony state; strict mirror target for `Status`. |
| `Worker Capability` | single-select | Admission hint: `basic`, `container-capable`, `testbed`. |
| `ProjectScope` | text | Scope binding; current value is `project-dokkaebi`. |
| `Permission Level` | single-select | Permission class: `docs-only`, `local-code`, `credentialed`, `provider-change`, `merge-deploy`. |
| `Linked pull requests` | linked PRs | Review/merge evidence surface. |

`Status` and `Dokkaebi Status` both expose the expected options:
`Intake`, `Clarifying`, `Ready`, `Dispatchable`, `In Progress`,
`Human Review`, `Fix Requested`, `Merging`, `Done`, `Reopened`, `Blocked`,
`Failed`, and `Cancelled`.

Targeted item inspection found three current issue items:

| Issue | Title | Status | Dokkaebi Status | Permission Level | Worker Capability |
| --- | --- | --- | --- | --- | --- |
| #1 | Dokkaebi bootstrap: validate ProjectScope runbook consistency | Cancelled | Cancelled | docs-only | basic |
| #2 | Dokkaebi closed-loop validation: branch dokkaebi/closed-loop-20260528 | Done | Done | docs-only | basic |
| #3 | Self-hosting rehearsal: validate human-origin approval gates | Done | Done | docs-only | basic |

The status mirror is currently clean for the inspected items.

## Current view UX

ProjectV2 view inspection found exactly one view:

| View | Layout | Filter | Visible fields | Grouping | Sort |
| --- | --- | --- | --- | --- | --- |
| `View 1` | table | none | `Title`, `Assignees`, `Status`, `Linked pull requests`, `Sub-issues progress` | none | none |

This is usable for a default GitHub table, but it is weak for Dokkaebi's
human-governed workflow because the reviewer cannot see the Manager/Symphony
state mirror, permission level, worker capability, or ProjectScope without
opening item details.

## API limitation found

GraphQL introspection confirms `ProjectV2` exposes `views` and `ProjectV2View`
exposes readable `fields`, `filter`, `groupByFields`, `sortByFields`, and
`verticalGroupByFields`. Mutation introspection found ProjectV2 mutations for
projects, fields, workflows, items, and status updates, but no public mutation
for creating/updating ProjectV2 views. The installed `gh project` command also
has no `view-list`, `view-create`, or `view-edit` subcommand.

Conclusion: direct view layout changes are currently UI/manual work unless a
separate browser automation path is approved. CLI/API-safe lane-4 changes should
focus on documentation, Project metadata, status/readme guidance, and audit
scripts rather than pretending to mutate views through unsupported API calls.

## Safe optimization applied

Lane 4 updated the GitHub Project short description and readme using
`gh project edit` so the Project itself tells reviewers how to use `Human
Review` and why terminal moves need human-origin approval. This is a metadata
optimization, not a schema/status/view-layout mutation.

Applied command shape:

```bash
gh project edit 1 --owner Project-Dokkaebi \
  --description '<human-review focused description>' \
  --readme '<short reviewer instructions and recommended view recipe>' \
  --format json
```

Post-update verification:

- `gh project view 1 --owner Project-Dokkaebi --format json` returned the new
  short description and readme.
- After the GraphQL quota reset,
  `python3 scripts/dokkaebi-project-status-sync.py --json` returned
  `ok=true`, `itemsChecked=3`, and `updates=[]`, confirming the metadata update
  did not create status mirror drift.


## 2026-05-28 late update: direct view creation succeeded

The earlier API-limitation note above was superseded by a later leader-lane
REST check using the current Projects v2 views endpoint and the authenticated
`Project-Dokkaebi` account. Four saved views were created directly without UI
automation:

| View | URL | Purpose |
| --- | --- | --- |
| `Dokkaebi 00 — All work` | <https://github.com/users/Project-Dokkaebi/projects/1/views/2> | Full audit table baseline. |
| `Dokkaebi 01 — Human Review` | <https://github.com/users/Project-Dokkaebi/projects/1/views/3> | Human attention queue. |
| `Dokkaebi 02 — Worker queue` | <https://github.com/users/Project-Dokkaebi/projects/1/views/4> | Dispatchable/In Progress/Fix Requested queue. |
| `Dokkaebi 03 — Open nonterminal` | <https://github.com/users/Project-Dokkaebi/projects/1/views/5> | Open work excluding terminal statuses. |

Evidence lives under `.omx/evidence/project-view-create/*.json`. Future view
audits should treat these saved views as the current human-facing baseline and
only fall back to manual UI changes when a field/layout operation is not exposed
by the API.

## Manual fallback view recipe

If a future Project field/layout option cannot be changed through the available
API/CLI surface, configure the Project UI manually as follows:

1. Rename `View 1` to `Human Review / Dispatch`.
2. Keep table layout.
3. Show these columns, in this order:
   1. `Title`
   2. `Status`
   3. `Dokkaebi Status`
   4. `Permission Level`
   5. `Worker Capability`
   6. `ProjectScope`
   7. `Linked pull requests`
   8. `Assignees`
   9. `Updated`
4. Group by `Status` so humans review `Human Review`, `Blocked`, and
   `Fix Requested` queues first.
5. Sort by `Updated` descending.
6. Optional saved views:
   - `Needs Human Review`: filter `status:"Human Review"`.
   - `Blocked / Approval Required`: filter `status:Blocked` or permission levels
     that imply credential/provider/merge-deploy authority.
   - `Dispatch Queue`: filter `status:Dispatchable`.


## `Merging` status semantics

`Merging` should mean that a Human has moved an item out of review and into the
approval-sensitive closeout lane. It should not send the item back to a normal
Symphony Worker queue. Future Dokkaebi automation should handle this through a
Merge Gate that checks human provenance, PR mergeability, required checks, review
state, and permission level before it performs `gh pr merge` or equivalent.

Until that Merge Gate exists, changing `Status` to `Merging` is only a visible
Human intent marker. It does not automatically change `Dokkaebi Status` or merge
the PR.

## Human Review workflow guardrails

- Manager/Worker automation may move complete evidence to `Human Review`.
- `Human Review` is a review request, not closeout approval.
- `Human Review -> Merging` and `Human Review -> Done` require human-origin
  provenance under `dokkaebi/policies/project-dokkaebi.yml`.
- If `Status` and `Dokkaebi Status` drift, run
  `scripts/dokkaebi-project-status-sync.py --json` first. Use `--apply` only for
  non-terminal repairs or when the policy-approved provenance path is present.
- Prefer linked PRs/result packets before moving out of `Human Review`.

## Follow-up recommendations

1. Add a small view-audit helper if repeated Project UX audits become common;
   it should read views/fields/items and fail if the view hides required
   Dokkaebi fields.
2. Do not add or mutate Project schema fields for UX until the approval policy
   explicitly authorizes that schema change.
3. Re-run this audit after GraphQL quota resets if a broader item sample is
   needed.
