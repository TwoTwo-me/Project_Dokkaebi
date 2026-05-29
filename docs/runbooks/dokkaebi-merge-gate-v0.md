# Dokkaebi Merge Gate v0 runbook

Merge Gate v0 is a local, fail-closed guard for PR-backed GitHub Project items
that are already in the merge lane. It does not replace Human Review and it does
not merge by default.

## Candidate selector

A candidate must be a Pull Request project item where both fields are aligned:

- `Status = Merging`
- `Dokkaebi Status = Merging`

Items outside that exact dual-`Merging` state are ignored by the gate. If the two
status fields drift, run the status sync/preflight flow first instead of using the
merge gate to normalize them.

## Required gates

For every candidate, `scripts/dokkaebi-merge-gate.py` checks:

1. human-origin approval provenance validates through
   `scripts/dokkaebi-approval-transition-check.py`;
2. the PR is open and not draft;
3. PR mergeability is known and clean/mergeable;
4. status checks are available and all reported checks pass;
5. the permission level is eligible for v0 automation.

`docs-only` and narrow `local-code` candidates may be planned by v0.
`provider-change`, `merge-deploy`, and credentialed candidates remain blocked for
human/manual handling in v0 even when every other gate passes.

## Dry-run first

Dry-run is the default and emits a JSON plan:

```bash
scripts/dokkaebi-merge-gate.py \
  --transition-record .omx/evidence/provenance/transition.json \
  --json
```

When GitHub Project discovery is undesirable or GraphQL quota is low, pass local
candidate input instead:

```bash
scripts/dokkaebi-merge-gate.py \
  --candidate-file .omx/evidence/merge-gate-candidates.json \
  --transition-record .omx/evidence/provenance/transition.json \
  --json
```

The JSON plan reports ready candidates with intended terminal state `Done`.
Blocked candidates recommend `Blocked` or `Fix Requested` depending on the
failure. Missing/unknown status checks block rather than being treated as pass.

## Apply and merge semantics

`--apply` is explicit and conservative. In v0 it still will not merge a PR unless
`--merge` is also supplied. The actual PR merge path is double-gated:

```bash
scripts/dokkaebi-merge-gate.py --apply --merge --transition-record transition.json --json
```

Do not run `--apply --merge` until a human has reviewed the dry-run JSON plan and
confirmed that the candidate PR is intended to move from `Merging` to `Done`.
If `dokkaebi/KILL_SWITCH` exists, apply mode fails closed.
