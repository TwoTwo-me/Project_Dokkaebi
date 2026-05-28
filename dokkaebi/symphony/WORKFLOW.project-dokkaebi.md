---
tracker:
  kind: github-project
  project_id: PVT_kwHOES1Fes4BY7jD
  state_field: Dokkaebi Status
  active_states:
    - Dispatchable
    - In Progress
    - Fix Requested
  wait_states:
    - Intake
    - Clarifying
    - Ready
    - Human Review
    - Merging
    - Blocked
    - Reopened
  terminal_states:
    - Done
    - Failed
    - Cancelled
  blocker_check_states:
    - Dispatchable
  human_review_transition_policy:
    review_state: Human Review
    manager_may_enter_review_state: true
    terminal_approval_transitions:
      - from: Human Review
        to: Merging
        required_origin: human
      - from: Human Review
        to: Done
        required_origin: human
    manager_self_approval: forbidden
    unknown_or_ambiguous_provenance: fail_closed
    enabled_provenance_sources:
      - durable_human_approval_record
    trusted_provenance_verifiers:
      - dokkaebi-github-project-status-adapter
      - dokkaebi-human-approval-record-adapter
      - dokkaebi-approval-broker
    source_verification:
      github_project_status_history_actor: github_project_status_history_query
      durable_human_approval_record: approval_record_path
      future_approved_approval_broker: broker_signed_decision
    approval_required_actions:
      - pr_merge
      - github_issue_close
      - deployment
      - human_review_to_merging_transition
      - human_review_to_done_transition
    approval_action_aliases:
      merge_pr: pr_merge
      repo.pr.merge: pr_merge
      deploy_or_cutover: deployment
      repo.deploy: deployment
      deploy: deployment
    required_transition_record_fields:
      - source_status
      - target_status
      - actor
      - actor_origin
      - provenance_source
      - approved_action
      - linked_ticket_or_item
      - linked_result_packet_or_review
      - provenance_record_id
      - provenance_checked_by
      - provenance_verification_method
      - provenance_evidence_file
      - provenance_evidence_sha256
  whitelist_labels:
    - dokkaebi
    - symphony
  priority_field: Priority
  api_key: $GITHUB_GRAPHQL_TOKEN
github_auth:
  client_id: $SYMPHONY_GITHUB_OAUTH_CLIENT_ID
  scopes: project
  token_path: $SYMPHONY_GITHUB_AUTH_TOKEN_PATH
credential_broker:
  enabled: false
  backend: github_app
  app_id: $SYMPHONY_GITHUB_APP_ID
  installation_id: $SYMPHONY_GITHUB_APP_INSTALLATION_ID
  private_key_path: $SYMPHONY_GITHUB_APP_PRIVATE_KEY_PATH
  default_ttl_seconds: 3600
  auto_grant_mode: all_short_lived_auto
  repo_allowlist:
    - TwoTwo-me/Project_Dokkaebi
  repo_capabilities:
    TwoTwo-me/Project_Dokkaebi:
      - repo.contents.read
      - repo.contents.write_branch
      - repo.pr.write
      - repo.issue.comment
      - project.status.update
  high_risk_capabilities:
    TwoTwo-me/Project_Dokkaebi:
      - project.status.update
      - repo.pr.merge
      - repo.workflow.modify
polling:
  interval_ms: 10000
workspace:
  root: ~/code/dokkaebi-symphony-workspaces
hooks:
  after_create: |
    git clone --depth 1 git@github.com:TwoTwo-me/Project_Dokkaebi.git repository
    cd repository
    git submodule update --init --depth 1 symphony-github-project-tracker || git submodule update --init symphony-github-project-tracker
    if [ -n "${DOKKAEBI_WORKER_REF:-}" ]; then
      case "$DOKKAEBI_WORKER_REF" in
        -*|*..*|*[!A-Za-z0-9._/@-]*)
          echo "Invalid DOKKAEBI_WORKER_REF" >&2
          exit 2
          ;;
      esac
      git fetch --depth 1 origin "$DOKKAEBI_WORKER_REF"
      git checkout --detach FETCH_HEAD
      git rev-parse --short HEAD
    fi
  before_run: |
    cd repository
    git status --short
  after_run: |
    cd repository || exit 0
    git status --short || true
  timeout_ms: 60000
agent:
  max_concurrent_agents: 1
  max_turns: 12
  max_retry_backoff_ms: 300000
  max_concurrent_agents_by_state:
    Dispatchable: 1
    In Progress: 1
    Fix Requested: 1
codex:
  command: /home/koreaplayer99/Project_Dokkaebi/scripts/dokkaebi-codex-worker-app-server.sh
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
---

You are a Dokkaebi Worker handling GitHub Project item `{{ issue.identifier }}`
inside the `project-dokkaebi` ProjectScope.

Issue context:

- Identifier: `{{ issue.identifier }}`
- Title: `{{ issue.title }}`
- Current status: `{{ issue.state }}`
- Labels: `{{ issue.labels }}`
- URL: `{{ issue.url }}`

Description:

{% if issue.description %}
{{ issue.description }}
{% else %}
No description was provided. Stop as blocked unless the issue body contains a
clear Worker-ready ticket with acceptance criteria, scope, permission level,
validation plan, and result-packet requirements.
{% endif %}

## Required posture

1. Work only inside the `repository/` checkout in this workspace.
2. Treat the issue body as the Worker ticket. Do not expand scope from adjacent
   discoveries.
3. Fail closed when approval, credential, capability, provider, or validation
   requirements are missing or contradictory.
4. Do not request or copy broad Manager credentials. Credentialed work requires a
   brokered grant and explicit ticket permission.
5. Do not merge, deploy, mutate infrastructure, enable host Docker authority, or
   alter production data.
6. Keep evidence durable: update the configured workpad/comment/PR surface and
   return a result packet matching `docs/templates/worker-result-packet.md`.
7. If blocked, report the exact missing condition and move/leave the item in the
   configured blocked or review state rather than improvising.

## Status routing

- `Dispatchable`: begin the ticket, move to `In Progress` if the available
  GitHub operation path permits status updates, then execute.
- `In Progress`: continue from existing workspace and workpad evidence.
- `Fix Requested`: inspect Manager/Human feedback, address only in-scope fixes,
  and return to `Human Review` with fresh validation evidence.
- `Human Review`, `Merging`, `Ready`, `Blocked`, `Done`, `Failed`, `Cancelled`:
  do not start new implementation work unless the issue body explicitly says the
  current state is dispatchable under this workflow.

## Human Review provenance

The Manager or Worker may move a complete result packet into `Human Review`.
That transition is a request for review, not terminal approval. The
`Human Review` → `Merging` and `Human Review` → `Done` transitions count as
approval only when the transition provenance is human-origin and linked to the
ticket/result evidence through a trusted provenance verifier. A Manager-authored
terminal transition or GitHub issue close is self-approval and must fail closed.
If the actor, origin, verifier, source-specific record id, or evidence source is
unavailable or ambiguous, leave the item in `Human Review` or move it to
`Blocked` with the missing provenance condition.

## Repeat-dispatch guard

The custom `Dokkaebi Status` field is authoritative for this workflow; the native
GitHub Project `status` field is informational. Symphony must not be left to
repeat an already-completed `Dispatchable` item unattended. After a Worker
produces a complete result packet, the Manager-controlled ingestion step must
review the packet and move the custom `Dokkaebi Status` out of active states
(`Human Review`, `Fix Requested`, or `Blocked`) before continued polling is
treated as safe.

## Execution checklist

1. Read `WORKFLOW.md`, `docs/contracts/manager-contract.md`,
   `docs/policies/authority-and-safety.md`, and the source ticket.
2. Confirm that the ticket includes goal, acceptance criteria, non-goals,
   permission level, ProjectScope, required capability, validation plan, and
   result-packet requirements.
3. Record a short plan in the durable workpad/review surface before edits.
4. Make the smallest scoped change.
5. Run the validation requested by the ticket. If validation cannot run, explain
   why and provide the strongest available substitute evidence.
6. Produce a result packet with changed files, commands run, outcomes,
   acceptance-criteria evidence, blockers, residual risks, and recommended next
   Manager action.
7. Return to `Human Review` only when the result packet is complete and no
   approval-gated action remains unhandled.
