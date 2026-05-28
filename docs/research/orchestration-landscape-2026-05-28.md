# Dokkaebi orchestration landscape research (2026-05-28)

## Executive direction

Dokkaebi should stay domain-specific: **GitHub Projects v2 + in-repo workflow contract + Symphony-style per-issue execution + least-privilege worker plane**. General workflow engines are useful references for durability and observability, but they should not replace the first Dokkaebi control loop until the GitHub Project/Symphony contract is stable.

## Source-backed findings

### OpenAI Symphony

- OpenAI positions Symphony as an open-source Codex orchestration spec/reference that turns project work into isolated autonomous implementation runs. The public repo explicitly points implementers at `SPEC.md` and the experimental Elixir reference implementation: <https://github.com/openai/symphony>.
- The spec defines Symphony as a **long-running automation service** that continuously reads an issue tracker, creates an isolated workspace per issue, and runs a coding agent in that workspace: <https://github.com/openai/symphony/blob/main/SPEC.md>.
- OpenAI's announcement/spec page is the canonical intent source for treating Symphony as a scheduler/runner/tracker-reader layer rather than a manager UI/product: <https://openai.com/ko-KR/index/open-source-codex-orchestration-symphony/>.

**Adopt:** long-running poller, per-issue isolated workspaces, in-repo `WORKFLOW.md`, proof-of-work/result handoff, observability.

**Avoid:** treating Symphony as a complete production product or moving Dokkaebi's Manager duties into Symphony.

### TwoTwo-me/symphony-github-project-tracker

- Local submodule/repo path: `symphony-github-project-tracker/` at commit `f50ce0cb15542e4e2324168a91435f78d1eb028b`.
- It adapts the Symphony idea to GitHub Projects v2, worker OS metadata, Docker/SSH worker pool concepts, and credential-broker boundaries. See `symphony-github-project-tracker/README.md` and `symphony-github-project-tracker/SPEC.md`.
- In this Dokkaebi repo, the wrapper `scripts/dokkaebi-symphony-run.sh` already selects `dokkaebi/symphony/WORKFLOW.project-dokkaebi.md`, checks `dokkaebi/KILL_SWITCH`, derives `GITHUB_GRAPHQL_TOKEN` from `gh` when allowed, runs strict preflight, and starts the built Elixir escript.

**Adopt now:** the local GitHub Project tracker implementation as the worker/Symphony side.

**Defer:** broad Docker worker fleet authority until a narrow provider/helper contract and credential broker are enabled.

### GitHub Projects v2 as control plane

GitHub Projects is a flexible table/board/roadmap surface with custom fields, saved views, bidirectional issue/PR integration, built-in automations, GraphQL/API control, and status updates: <https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects>.

Relevant official docs:

- Fields/custom metadata: <https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields>
- REST Project endpoints including fields/items/views: <https://docs.github.com/en/rest/projects>
- Project view creation API: <https://docs.github.com/en/enterprise-cloud@latest/rest/projects/views?apiVersion=2026-03-10>

**Adopt now:** one human-visible `Status` field and one Symphony/Dokkaebi `Dokkaebi Status` field with strict mirror sync; optimized views for all work, human review, worker queue, and nonterminal items.

**Avoid:** label-only scheduling or hidden Manager memory as the source of truth.

### Always-on worker supervision

Docker officially supports container restart policies (`always`, `unless-stopped`, `on-failure`) and warns that policies apply after a container starts successfully and are container-level behavior: <https://docs.docker.com/engine/containers/start-containers-automatically/>. Docker Compose service definitions can encode service behavior and restart policies: <https://docs.docker.com/reference/compose-file/services/>.

systemd user services are a good local host-native supervision path; `systemd.service` documents restart behavior and service lifecycle primitives: <https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html>.

**Adopt now:** user-level systemd services wrapping the existing Dokkaebi runner and status-sync loop. This keeps Manager request-triggered while making Symphony/status sync always-on.

**Defer:** Docker restart-always for the first self-host path because current Compose packaging is upstream worker-fleet oriented and policy-sensitive.

### General orchestration engines

- Temporal emphasizes durable, fault-tolerant workflow state and human-in-the-loop patterns: <https://temporal.io/>.
- Prefect, Dagster, and Airflow are useful references for scheduling, deployments, assets, lineage, and DAG retries, but they are not the best first source of truth for issue-state-driven coding-agent work.

**Adopt later if needed:** Temporal-style durable execution when Dokkaebi needs crash-resume workflows beyond GitHub Project + Symphony runtime state.

**Avoid now:** introducing a generic workflow engine before the narrower GitHub Project/Symphony loop has real operational evidence.

## Recommended architectural stance

1. **Manager remains request-triggered.** Hermes/Codex Manager runs for intake, ticket drafting, result review, and human summaries.
2. **Worker/Symphony remains always-on.** It polls GitHub Project, dispatches eligible tickets, and moves results to handoff states.
3. **GitHub Project remains the human/control-plane UI.** Views should be optimized rather than replaced by a rich dashboard.
4. **Credential broker before privilege expansion.** Do not copy Manager PATs into workers; prefer short-lived task-scoped credentials later.
5. **Systemd first, Docker worker fleet later.** Use systemd to supervise local Dokkaebi-specific pollers now; revisit Compose/VM/Kubernetes when provider policy is ready.
