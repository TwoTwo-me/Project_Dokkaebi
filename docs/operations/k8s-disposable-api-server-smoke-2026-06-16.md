# K8S Disposable API Server Smoke - 2026-06-16

## Scope

This record is local Dokkaebi development evidence for
`k8s_platformization`. It uses a disposable `kind` Kubernetes API server to
prove that the root K8S base applies, route-profile fixtures server-dry-run,
representative unsafe Hammer Jobs are denied by `ValidatingAdmissionPolicy`,
and ServiceAccount RBAC boundaries match the documented can/cannot matrix.

This evidence does not mutate EKS, cloud infrastructure, shared clusters,
production namespaces, remote hosts, credentials, GitHub Projects, or the
Symphony runtime submodule.

## Tooling

Tools were installed under the ignored ULW session directory:

- `.omo/ulw-loop/k8s-100-20260616T110000Z/bin/kind`
- `.omo/ulw-loop/k8s-100-20260616T110000Z/bin/kubectl`

Observed versions:

- `kind v0.29.0`
- `kubectl` client `v1.30.0`
- Kubernetes server `v1.30.0`

## Exact Scenario

Command surface:

```bash
BIN_DIR=.omo/ulw-loop/k8s-100-20260616T110000Z/bin
CLUSTER=dokkaebi-ulw-k8s-100
KUBECONFIG_PATH=.omo/ulw-loop/k8s-100-20260616T110000Z/kubeconfig

"$BIN_DIR/kind" delete cluster --name "$CLUSTER" || true
"$BIN_DIR/kind" create cluster \
  --name "$CLUSTER" \
  --image kindest/node:v1.30.0 \
  --kubeconfig "$KUBECONFIG_PATH" \
  --wait 120s
KUBECONFIG="$KUBECONFIG_PATH" "$BIN_DIR/kubectl" apply -k k8s/base
```

Binary observable:

- PASS only if `kind create cluster` exits `0`.
- PASS only if `kubectl apply -k k8s/base` exits `0`.
- PASS only if RBAC can/cannot commands return the expected `yes` or `no`.
- PASS only if every accepted fixture server-dry-runs successfully.
- PASS only if every representative rejected fixture exits non-zero through
  the API server admission path.
- PASS only after `kind delete cluster --name dokkaebi-ulw-k8s-100` exits `0`
  and no same-name Docker container remains.

## RBAC Can/Cannot Matrix

| Actor | Command | Expected | Observed |
| --- | --- | ---: | ---: |
| `system:serviceaccount:dokkaebi-system:dokkaebi-fire` | `kubectl auth can-i create jobs.batch -n dokkaebi-workers` | yes | yes |
| `system:serviceaccount:dokkaebi-system:dokkaebi-fire` | `kubectl auth can-i get secrets -n dokkaebi-workers` | no | no |
| `system:serviceaccount:dokkaebi-system:dokkaebi-fire` | `kubectl auth can-i create rolebindings.rbac.authorization.k8s.io -n dokkaebi-workers` | no | no |
| `system:serviceaccount:dokkaebi-workers:hammer-k8s-readonly` | `kubectl auth can-i get pods -n dokkaebi-workers` | yes | yes |
| `system:serviceaccount:dokkaebi-workers:hammer-k8s-readonly` | `kubectl auth can-i create jobs.batch -n dokkaebi-workers` | no | no |
| `system:serviceaccount:dokkaebi-workers:hammer-no-k8s` | `kubectl auth can-i get pods -n dokkaebi-workers` | no | no |

## Accepted Fixture Server Dry Run

All accepted fixtures exited `0`:

- `k8s/fixtures/accepted/hammer-job-no-k8s-approved.yaml`
- `k8s/fixtures/accepted/hammer-job-approved.yaml`
- `k8s/fixtures/accepted/hammer-job-app-deployer-approved.yaml`
- `k8s/fixtures/accepted/hammer-job-job-runner-approved.yaml`

## Representative Admission Denials

Every rejected fixture below exited non-zero through
`ValidatingAdmissionPolicy` and the
`dokkaebi-hammer-job-policy-binding`:

- `k8s/fixtures/rejected/missing-approval-id.yaml`
- `k8s/fixtures/rejected/mismatched-serviceaccount-profile.yaml`
- `k8s/fixtures/rejected/privileged-hostpath.yaml`
- `k8s/fixtures/rejected/secret-env-reference.yaml`
- `k8s/fixtures/rejected/hostnetwork.yaml`
- `k8s/fixtures/rejected/hostport.yaml`
- `k8s/fixtures/rejected/no-k8s-token-override.yaml`
- `k8s/fixtures/rejected/image-pull-secrets.yaml`

## Evidence Artifact

Full transcript:

`.omo/ulw-loop/k8s-100-20260616T110000Z/evidence/C002-kind-admission-rbac.txt`

The transcript contains:

- kind cluster creation;
- `kubectl apply -k k8s/base`;
- RBAC can/cannot output;
- accepted fixture server dry-run output;
- rejected fixture admission denial output;
- cleanup command output.

## Cleanup Receipt

Cleanup command:

```bash
.omo/ulw-loop/k8s-100-20260616T110000Z/bin/kind delete cluster \
  --name dokkaebi-ulw-k8s-100
docker ps -a --filter name=dokkaebi-ulw-k8s-100 \
  --format '{{.ID}} {{.Names}} {{.Status}}'
```

Observed cleanup:

- `kind delete cluster --name dokkaebi-ulw-k8s-100` exited `0`.
- The Docker container check returned no same-name containers.

## Residual Risk

This proof raises only the disposable API server admission/RBAC subcriterion.
It does not prove Fire Deployment startup, executed Hammer Job result packets,
GitHub Project reconciliation, EKS identity, or production network enforcement.
Those remain separate K8S issue gates.
