# Worker Route Health And Bootstrap Rebuild Evidence

This report closes the infrastructure route-health gap for issue #103. It
captures sanitized development and approved sandbox preflight evidence for the
four Hammer route classes that Fire may consider: local worktree, SSH worker,
Docker worker, and Kubernetes Job. It also records a named development
bootstrap rebuild check from repository state.

The report is evidence, not a broad authority grant. It does not authorize
production work, credential expansion, persistent infrastructure changes,
Proxmox changes, GitHub Project control-plane mutation, or worker scaling. Any
future dispatch that creates containers, Kubernetes Jobs, remote files, or
shared infrastructure must still cite a ticket-specific Human approval and
return a cleanup receipt.

## Route Health Summary

| Route | Target | Capability result | Dispatch eligibility |
| --- | --- | --- | --- |
| Local worktree | Current development workspace | `git`, `gh`, `bash`, and Docker CLI/daemon are available; local `kubectl` is absent. | Eligible for docs and local validation work. Kubernetes work must route elsewhere. |
| SSH worker | `dokkaebi-hammer` SSH alias | SSH is reachable; `git`, Docker, `kubectl`, Codex CLI, and Codex home are present; `gh` is absent. | Eligible for development and sandbox worker tickets that do not require `gh` on the worker. |
| Docker worker | Local Docker daemon | Docker server `29.1.3` is reachable with no running containers in this preflight. | Eligible for development and sandbox Docker worker tickets after image/profile approval. |
| Kubernetes Job | `dokkaebi-hammer` remote `kind-dokkaebi-hammer` context | The default namespace is reachable; the route can get pods and create/delete jobs. | Eligible for development and sandbox Kubernetes Job tickets after manifest/profile approval. |

## Bootstrap Rebuild Check

The named rebuild target is the Project Dokkaebi development workspace. The
preflight proves the workspace can be reconstructed from checked repository
state and documented validation commands:

1. Start from the Project Dokkaebi repository on `main`.
2. Initialize the `symphony-github-project-tracker` submodule.
3. Verify the root contract and readiness gates.
4. Verify worker route health evidence with the targeted validator.
5. Leave runtime resources untouched unless a later ticket grants route-specific
   creation authority.

No Docker container, Kubernetes object, SSH remote file, credential, production
target, deployment, infrastructure setting, or GitHub Project setting was
created, updated, or deleted during this evidence run.

## Validation

Run:

```bash
bash scripts/validate-worker-route-health-bootstrap.sh
bash scripts/validate-readiness-criteria.sh
bash scripts/validate-contract-docs.sh
```

The targeted validator checks the human-readable report and the structured
control block below. It rejects missing provider classes, missing capability
detection, missing dispatch eligibility, missing skip reasons, missing cleanup
rules, missing approval-gate status, missing bootstrap rebuild proof, missing
validation output, private local paths, secret-like evidence, and unsafe
mutation claims.

The provider entries below are the canonical cleanup rules and skip reasons for
the captured route baseline.

<!-- worker-route-health-bootstrap:begin -->
```json
{
  "version": 1,
  "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/103",
  "reportId": "issue-103-worker-route-health-bootstrap-2026-06-14",
  "evidenceDate": "2026-06-14",
  "permissionLevel": "development-and-approved-sandbox-read-only-preflight",
  "approvalGateStatus": "development and approved sandbox preflight only; no production, credential, Proxmox, deployment, infrastructure, GitHub Project control-plane, persistent Docker, persistent Kubernetes, or remote filesystem mutation was performed; any future mutation still requires explicit Human approval for the exact target and operation",
  "preflightPolicy": {
    "mode": "read-only capability detection plus repository validation",
    "noMutation": [
      "no Docker containers created, updated, or deleted",
      "no Kubernetes objects created, updated, or deleted",
      "no SSH remote files created, updated, or deleted",
      "no credentials copied or expanded",
      "no production, deployment, infrastructure, Proxmox, or GitHub Project control-plane mutation"
    ],
    "redaction": "evidence excludes secrets, auth files, tokens, cookies, private keys, and private machine paths"
  },
  "routes": [
    {
      "provider": "local_worktree",
      "target": "current development workspace",
      "evidenceSource": "local preflight output captured on 2026-06-14",
      "capabilityDetection": [
        {
          "check": "git",
          "result": "present: git version 2.43.0"
        },
        {
          "check": "github_cli",
          "result": "present: gh version 2.45.0"
        },
        {
          "check": "shell",
          "result": "present: GNU bash 5.2.21"
        },
        {
          "check": "docker",
          "result": "present: client 29.1.3, server 29.1.3, storage overlayfs, cgroup systemd"
        },
        {
          "check": "kubernetes_cli",
          "result": "absent locally; Kubernetes Job route uses the approved SSH sandbox target"
        }
      ],
      "dispatchEligibility": {
        "status": "eligible_for_docs_and_local_validation",
        "reason": "local route has repository, git, gh, shell, and Docker preflight capability for docs and deterministic validation"
      },
      "skipReasons": [
        "skip Kubernetes Job dispatch from local route because local kubectl is absent",
        "skip production, credential, deployment, infrastructure, and GitHub Project control-plane operations without ticket-specific Human approval"
      ],
      "cleanupRules": [
        "remove temporary worktrees after ticket closeout",
        "do not retain untracked logs containing secrets or private machine state",
        "return git status and submodule status in the result packet"
      ]
    },
    {
      "provider": "ssh_worker",
      "target": "dokkaebi-hammer SSH alias",
      "evidenceSource": "SSH BatchMode preflight output captured on 2026-06-14",
      "capabilityDetection": [
        {
          "check": "ssh",
          "result": "reachable with BatchMode and connect timeout"
        },
        {
          "check": "git",
          "result": "present: git version 2.43.0"
        },
        {
          "check": "docker",
          "result": "present: client 29.5.3, server 29.5.3, storage overlayfs, cgroup systemd"
        },
        {
          "check": "kubernetes_cli",
          "result": "present: kubectl on context kind-dokkaebi-hammer"
        },
        {
          "check": "worker_cli",
          "result": "present: codex-cli 0.139.0 with Codex home present"
        },
        {
          "check": "github_cli",
          "result": "absent on remote target"
        }
      ],
      "dispatchEligibility": {
        "status": "eligible_for_dev_sandbox_ticket",
        "reason": "SSH route has git, Docker, Kubernetes, and worker CLI capability; tickets requiring gh on the worker must skip or bootstrap gh through an approved setup ticket"
      },
      "skipReasons": [
        "skip worker tasks that require gh on the remote host until a ticket approves gh bootstrap",
        "skip credential expansion, persistent remote file writes, and infrastructure mutation without target-specific Human approval"
      ],
      "cleanupRules": [
        "result packet must list remote workspace path category without private path disclosure",
        "remove ticket-scoped worktrees and temporary logs after completion",
        "leave SSH keys, auth stores, and host-level services untouched unless separately approved"
      ]
    },
    {
      "provider": "docker_worker",
      "target": "local Docker daemon",
      "evidenceSource": "local Docker read-only preflight output captured on 2026-06-14",
      "capabilityDetection": [
        {
          "check": "docker_daemon",
          "result": "reachable: server 29.1.3, storage overlayfs, cgroup systemd"
        },
        {
          "check": "running_containers",
          "result": "none listed during preflight"
        },
        {
          "check": "worker_image",
          "result": "not selected by this evidence run; image selection remains ticket-scoped"
        }
      ],
      "dispatchEligibility": {
        "status": "eligible_for_dev_sandbox_ticket",
        "reason": "Docker daemon is reachable for approved development or sandbox worker profiles; this report does not create or select an image"
      },
      "skipReasons": [
        "skip Docker dispatch when the ticket lacks an approved image, mount policy, cleanup rule, and credential boundary",
        "skip broad daemon mutation, persistent volumes, and production workloads without explicit Human approval"
      ],
      "cleanupRules": [
        "name containers with ticket identifiers",
        "remove containers, temporary networks, and ticket-scoped volumes on closeout",
        "record image digest, exit code, logs surface, and Docker cleanup result in the result packet"
      ]
    },
    {
      "provider": "kubernetes_job",
      "target": "dokkaebi-hammer kind-dokkaebi-hammer context",
      "evidenceSource": "remote kubectl read-only preflight output captured on 2026-06-14",
      "capabilityDetection": [
        {
          "check": "context",
          "result": "current context kind-dokkaebi-hammer"
        },
        {
          "check": "node",
          "result": "node dokkaebi-hammer-control-plane visible"
        },
        {
          "check": "namespace",
          "result": "default namespace visible"
        },
        {
          "check": "pod_read",
          "result": "kubectl auth can-i get pods: yes"
        },
        {
          "check": "job_create",
          "result": "kubectl auth can-i create jobs: yes"
        },
        {
          "check": "job_delete",
          "result": "kubectl auth can-i delete jobs: yes"
        }
      ],
      "dispatchEligibility": {
        "status": "eligible_for_dev_sandbox_ticket",
        "reason": "remote Kubernetes context has namespace, node, pod-read, job-create, and job-delete capability for approved sandbox Job profiles"
      },
      "skipReasons": [
        "skip Kubernetes dispatch when the ticket lacks an approved namespace, service account, image, TTL, log collection, and cleanup rule",
        "skip shared-cluster, production, persistent secret, or infrastructure mutation without explicit Human approval"
      ],
      "cleanupRules": [
        "apply only ticket-scoped Job manifests with TTL or explicit delete on closeout",
        "collect pod logs and Job status before deletion",
        "record namespace, service account, image digest, exit status, cleanup command, and delete result in the result packet"
      ]
    }
  ],
  "bootstrapRebuild": {
    "target": "Project Dokkaebi development workspace",
    "sourceOfTruth": [
      "README.md",
      "ARCHITECTURE.md",
      "WORKFLOW.md",
      "docs/operations/toolchain-bootstrap.md",
      "docs/operations/fire-sandbox-service.md",
      "docs/operations/topology-backup-restore-dr.md",
      "symphony-github-project-tracker submodule"
    ],
    "checkedState": {
      "rootMainCommit": "9d6d6ef1ca6e92bef1ac4012e7d0c569981104d7",
      "submoduleCommit": "dbcd306fc230d9fac12a36477c9ccd7494786380",
      "submoduleBranchDescription": "remotes/origin/fix/hammer-worktree-source-gate"
    },
    "rebuildCommands": [
      "git clone https://github.com/TwoTwo-me/Project_Dokkaebi",
      "git submodule update --init --recursive",
      "bash scripts/validate-worker-route-health-bootstrap.sh",
      "bash scripts/validate-readiness-criteria.sh",
      "bash scripts/validate-contract-docs.sh"
    ],
    "validationEvidence": [
      "root repository and submodule commit are recorded",
      "local route preflight captured git, gh, bash, Docker, and local Kubernetes skip reason",
      "SSH route preflight captured remote git, Docker, Kubernetes, worker CLI, Codex home, and gh skip reason",
      "Docker route preflight captured daemon health and empty running-container list",
      "Kubernetes route preflight captured context, node, namespace, pod-read, job-create, and job-delete capability"
    ]
  },
  "validationOutput": [
    "bash scripts/validate-worker-route-health-bootstrap.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS",
    "python3 -m json.tool docs/enterprise-readiness/criteria.json: PASS",
    "git diff --check: PASS"
  ],
  "readinessUpdate": {
    "area": "infrastructure_platform",
    "currentPercent": 100,
    "closedIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/103",
    "evidenceAdded": [
      "docs/operations/worker-route-health-bootstrap-2026-06-14.md",
      "scripts/validate-worker-route-health-bootstrap.sh"
    ]
  },
  "cleanupReceipt": {
    "docker": "no containers were running or created by this evidence run",
    "kubernetes": "no Kubernetes objects were created, updated, or deleted by this evidence run",
    "ssh": "SSH preflight executed read-only commands only",
    "local": "no ticket worktrees, ports, servers, browser contexts, credentials, or control-plane settings were created"
  },
  "residualRisk": [
    "Future live dispatch through Docker or Kubernetes still needs ticket-specific manifest, image, namespace, cleanup, and credential approval.",
    "Remote gh bootstrap remains a separate setup decision if a future SSH worker ticket requires gh on the remote host.",
    "Production worker routes remain disabled until a later ADR or explicit Human approval grants a narrow production exception."
  ],
  "nextAction": "Use this report as the route-health baseline for issue #103 closeout and require future provider changes to refresh the same evidence shape."
}
```
<!-- worker-route-health-bootstrap:end -->
