---
name: hammer-bootstrap
description: Use when preparing Dokkaebi Hammer targets for local worktree, SSH, Docker, or Kubernetes execution with read-only preflight, explicit eligibility checks, install evidence, rollback notes, and approval boundaries.
---

# Hammer Bootstrap

Use this skill when a Dokkaebi Hammer target needs setup, reset, or readiness inspection. A Hammer is a typed worker runtime launched by Dokkaebi Fire for one bounded ticket. Bootstrap work is an authority-sensitive operation, not proof that a route is implemented.

## Preflight First

Start with read-only preflight and capture evidence before mutation:

- local worktree: current user, repository path, git status, required commands, disk space, and credential boundary;
- SSH: target host, user, `dokkaebi-hammer` alias, command availability, writable workspace path, and connection mode;
- Docker: daemon availability, image/build eligibility, volume/network needs, and whether the ticket is containerizable;
- Kubernetes: local or remote context, namespace, service account, job eligibility, image pull path, and cluster write authority.

If a route needs a tool, credential, namespace, container, image, volume, or remote path that is not approved, stop and mark the request blocked.

## Eligibility Rules

- Local worktree routes may proceed only when the ticket allows repo-local work and the worktree can be isolated.
- SSH routes may proceed only for the named host/user and approved workspace path.
- Docker routes may receive only work declared containerizable; do not route host-native or credential-sensitive work into a container by default.
- Kubernetes routes may target local or remote clusters, but the cluster location must be explicit. Do not assume the cluster is on the Fire server.

## Install Or Reset

When setup is approved, use scripted steps and record:

- source ticket and approved actor/runtime;
- commands run and concise output;
- installed versions and paths;
- environment changes;
- validation command and outcome;
- rollback notes naming files, directories, containers, jobs, namespaces, or contexts to restore;
- approval-gate status and skipped checks.

`dokkaebi-hammer` reset requests must name the exact target, workspace/cache paths, data to preserve, and rollback or recovery path. Do not delete repositories, SSH keys, credential stores, Fire state, Docker volumes, Kubernetes namespaces, remote home directories, or shared caches unless the ticket grants that exact authority.

## Handoff

Return a readiness packet with provider type, Hammer id, capabilities, health, capacity, isolation mode, credential boundary, validation result, rollback notes, and residual risks. Fire may route work to the Hammer only when this packet matches the ticket and project admission rules.
