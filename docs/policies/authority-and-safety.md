# Dokkaebi Authority and Safety Policy

This policy is the default authority boundary for Project Dokkaebi. It applies to
any AI Manager adapter, including Hermes, Codex/oh-my-codex, OpenClaw, and future
custom managers. Dokkaebi is an installable Manager plugin/skillset; installing
it does not grant authority to bypass this policy.

## Policy goals

- Keep the Human as the source of goals and high-impact authority.
- Make every Hammer action traceable to a ticket, approval, and validation
  record.
- Fail closed when approval, credential scope, project status, or Hammer
  capability is unclear.
- Preserve Manager replaceability by enforcing safety at the Manager Contract
  boundary rather than inside one runtime.

## Authority model

- **Human**: defines goals, approves gates, and may replace Manager/backend
  choices.
- **Dokkaebi Manager**: clarifies, drafts tickets, reviews results, and updates
  tracking state. It configures and manages GitHub Projects and issues, but may
  not perform high-impact writes without approval evidence.
- **Dokkaebi Fire/backend**: long-running Symphony-derived orchestrator that
  dispatches approved Hammer tickets and records progress. It may not broaden
  task scope or bypass readiness gates.
- **Dokkaebi Hammer Worker**: typed Worker target/runtime launched by Fire for
  one bounded ticket in an isolated workspace. It may not expand permissions,
  access secrets, merge/deploy, or mutate infrastructure.

## Human approval required

Dokkaebi must obtain explicit Human approval before any of these actions:

- cloud or Proxmox create/update/delete operations;
- secret, credential, token, SSH key, admin-account, or production-account access;
- Hammer creation, scaling, privilege elevation, or broader network/tool access;
- remote host mutation, system-wide installs, Docker daemon changes, `kubectl`
  context changes, or Kubernetes resource changes;
- Manager runtime replacement or switching the active root Manager adapter;
- PR merge, deployment, production data writes, or production infrastructure
  writes unless a later ADR grants a narrow exception.

Approval is specific to the task, scope, actor, and time window. Approval for one
ticket does not grant standing authority to future tickets.

## Automation allowed by default

The Manager may automate these actions when scope and acceptance criteria are
clear:

- drafting or revising GitHub Project/Dokkaebi Fire-ready tickets;
- updating issue/project status, progress comments, and workpad notes;
- requesting Hammer validation evidence;
- running approved user-local bootstrap for Manager, Fire, or Hammer tools after
  read-only preflight, with scripted install evidence and rollback notes;
- preparing branches, commits, or PRs for review under
  [`git-governance.md`](git-governance.md);
- summarizing Hammer results and residual risks for the Human.

## Forbidden default actions

Without a later explicit policy and approval mechanism, Dokkaebi must not:

- expose raw long-lived secrets to Workers;
- let a Hammer self-approve scope expansion or privilege escalation;
- dispatch work when the ticket lacks acceptance criteria, permission level, or
  validation requirements;
- continue after a credential, infrastructure, deployment, production, or
  destructive-operation gate is reached;
- install into shared/system paths, mutate remote hosts, create Docker or
  Kubernetes resources, or reset `dokkaebi-hammer` outside the approved target
  without explicit Human approval;
- treat private Manager memory as the only audit trail.

## Approval evidence record

Every approval-gated action must leave durable pre-execution evidence. Minimum
fields:

- approver identity or Human decision source;
- approved action and explicit non-approved adjacent actions;
- ticket/project item or request id;
- affected repository, environment, infrastructure, data, or credential scope;
- permitted actor and runtime;
- expiration or revocation condition;
- validation and rollback expectations;
- planned result-packet or Manager-review surface.

The actual Worker result packet or Manager review link is required at closeout,
not before dispatch. If the pre-execution approval record is missing or ambiguous,
the Manager must fail closed and ask for a new approval.

## Fail-closed preflight

Before dispatching or executing an approval-sensitive task, the Manager runs a
preflight:

1. Verify the source request and ticket are linked.
2. Verify acceptance criteria, non-goals, permission level, validation plan, and
   result packet requirements are present.
3. Verify the GitHub Project/Dokkaebi Fire status and admission fields are dispatchable.
4. Verify the Hammer capability/OS/tooling constraints match the ticket.
5. Verify approval evidence exists for every gated action.
6. Verify credentials, if any, are issued through a credential broker with least
   privilege and expiry.
7. Verify any toolchain bootstrap starts with read-only preflight, prefers
   user-local installs, records scripted evidence, includes rollback notes, and
   keeps `dokkaebi-hammer` reset requests inside their approved boundary.
8. Verify no policy item requires Human review before continuing.

Any failed or unknown check blocks dispatch. The blocked state must name the
missing condition rather than starting best-effort work.

## Credential broker boundary

Credentials are never part of the Manager's conversational memory. The credential
broker must issue task-scoped, time-limited, least-privilege grants and record
only metadata needed for audit. Hammer Workers receive only the scoped bundle
necessary for the approved ticket and must not receive the Manager's broad
credentials.

Credential requests require:

- ticket id and approved capability;
- repository or external service allowlist;
- branch/environment binding where applicable;
- expiration and revocation condition;
- proof that the Hammer and endpoint match the approved scope.

## Symphony compatibility policy and Dokkaebi Fire lineage

Dokkaebi Fire is the long-running backend/orchestrator derived from Symphony.
Dokkaebi treats Fire/Symphony as the first backend, not as an inseparable core.
Manager tickets must remain compatible with both:

- **Greenfield projects:** Dokkaebi proposes the initial project fields,
  statuses, fallback labels, templates, and admission rules. It creates them
  only under approved setup authority before dispatch.
- **Brownfield projects:** Dokkaebi maps existing statuses, agent,
  authorization, authorized-by, admission fields, fallback labels, and workpad
  conventions to the semantic state model in `WORKFLOW.md` before enabling
  Worker dispatch.

GitHub Project schema changes, field creation, label creation, template updates,
admission-rule changes, and auto-add workflow changes are control-plane writes.
They require approved setup authority. Routine progress comments and status
updates remain automation candidates when the ticket is already approved.

GitHub Projects API writes are split by risk:

- `updateProjectV2ItemFieldValue` for the configured lifecycle/status or
  admission fields is routine automation only after the ticket is admitted and
  the field/value mapping is documented.
- `addProjectV2ItemById` is routine automation only when adding an already
  authorized issue or PR to an approved project. Cross-project moves or broad
  backfills require setup approval.
- `createProjectV2`, project deletion/archive, field creation/deletion, workflow
  edits, and destructive bulk project mutations are control-plane changes and
  require Human approval.
- `projects_v2_item` and related project webhook handling are advisory signals.
  GitHub documents project webhook events as public preview and subject to
  change, so Fire may use them to wake a poll cycle but must reconcile against
  GraphQL state before dispatch or closeout.

If project status fields, admission fields, fallback labels, workpad
conventions, or Worker metadata cannot be mapped, the Manager must mark the
ticket blocked and request a mapping or project setup change.

GitHub Project `Status` is the lifecycle source of truth. Workpad comments,
labels, Fire logs, Hammer logs, PRs, and validation artifacts are audit
surfaces, not replacements for the lifecycle field.

Docker, `kubectl`, and Kubernetes are planned or eligible routing/bootstrap
targets only. This policy does not claim those routes are implemented.

## Toolchain bootstrap boundary

Local and remote tool installation follows
[`../operations/toolchain-bootstrap.md`](../operations/toolchain-bootstrap.md).
The default policy is:

- prefer user-local installs for Manager plugins, Fire helpers, and Hammer
  runtimes;
- run read-only preflight before changing a host or runtime;
- use scripted install steps and capture installed versions, paths, and command
  evidence;
- include rollback notes and skipped-check rationale in result packets;
- block remote, Docker, `kubectl`, Kubernetes, shared-path, or
  `dokkaebi-hammer` reset actions unless the ticket has explicit setup
  authority and credential broker approval where needed.

## Git governance boundary

Branch, commit, pull-request, and submodule-pointer work follows
[`git-governance.md`](git-governance.md). Preparing reviewable commits or PRs is
an automation candidate only when the ticket grants repository write or PR
preparation authority. PR merge, direct protected-branch writes, deployment,
production writes, destructive history rewriting, and release publication remain
Human approval gates unless a later ADR grants a narrow exception.

## Audit and review

A task is safe to close only when the Manager can reconcile:

- Human request and approval evidence;
- ticket scope, status, and assignment;
- Hammer result packet and validation commands;
- commits, PRs, logs, or artifacts;
- residual risks and follow-up decisions.

Review failure does not authorize silent Worker continuation. The Manager should
request a scoped fix, create a follow-up ticket, or ask the Human for a decision.
