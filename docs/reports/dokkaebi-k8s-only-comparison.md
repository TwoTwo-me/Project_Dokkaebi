# Dokkaebi K8S-Only Comparison Report

작성일: 2026-06-14

## 결론

현재 Project Dokkaebi의 성숙도에 가장 좋은 방향은 **즉시 Kubernetes-only로
갈아타는 것**이 아니라, **GitHub Project를 당분간 durable control plane으로
유지하면서 Kubernetes를 Fire/Hammer 실행 격리와 권한 강제 계층으로 먼저
도입하는 것**이다. 그 다음 Kubernetes admission, RBAC, audit, credential
broker, tenant RBAC가 실제 런타임 증거로 안정화되면 자체 관리 솔루션을
GitHub Project 옆에 붙이거나 일부 대체하는 순서가 더 안전하다.

즉, 최종 모양은 Kubernetes-only가 될 수 있다. 다만 그때의 "only"는
GitHub Project를 너무 일찍 버린다는 뜻이 아니라, GitHub가 맡던 lifecycle,
approval, evidence, audit, review queue를 Kubernetes-native 혹은
Dokkaebi-native API로 충분히 재구현한 뒤에 가능한 상태다.

추천 로드맵:

1. **현재 구조 유지 + Kubernetes Job Hammer route 강화**
   - Fire는 기존 GitHub Project를 읽고, Hammer 실행만 Kubernetes Job으로
     격리한다.
   - prompt injection이 들어와도 Job ServiceAccount, namespace, NetworkPolicy,
     admission policy가 실제 권한 한계를 만든다.
2. **Fire 자체를 Kubernetes 내부 서비스로 배치**
   - Fire는 제한된 ServiceAccount로 GitHub Project를 poll하고, 승인된 Job만
     생성한다.
   - Fire의 ServiceAccount는 namespace/job/log 조회와 승인된 Job 생성 정도로
     제한한다.
3. **Dokkaebi management API를 추가하되 GitHub Project와 병행**
   - 자체 API는 tenant, role, approval, route admission, result packet,
     audit query를 담당한다.
   - GitHub Project는 외부 감사와 PR/review 연계를 위해 한동안 mirror 혹은
     source-of-truth 후보로 유지한다.
4. **자체 control plane이 GitHub Project와 동등한 증거를 낼 때 K8S-only 전환**
   - Status lifecycle, issue/workpad, PR/check, result packet, immutable audit,
     approval evidence, access review를 자체 시스템이 모두 제공해야 한다.

## 현재 기능 인벤토리

### Root Project Dokkaebi

Root repository는 실행 backend가 아니라 **계약, 정책, 운영 기준, 검증
게이트**를 담는 상위 Manager 계층이다.

| 영역 | 현재 기능 | 근거 |
| --- | --- | --- |
| Product framing | Human -> Dokkaebi Manager -> GitHub Project -> Dokkaebi Fire -> Dokkaebi Hammer -> verifiable result return 구조를 정의한다. | `README.md` |
| Manager strategy | Hermes-first, contract-first 전략. Hermes, Codex/oh-my-codex, OpenClaw, future adapters가 같은 Manager Contract를 구현해야 한다. | `README.md`, `docs/contracts/manager-contract.md` |
| Architecture | Human, Manager, Fire, Hammer, credential broker, approval gate, trust boundary, result flow, audit surface를 문서화한다. | `ARCHITECTURE.md` |
| Workflow | Intake, Clarifying, Ready, Dispatchable, In Progress, Needs Review/Human Review, Fix Requested, Merging, Done, Reopened, Blocked, Failed, Cancelled 상태 모델을 정의한다. | `WORKFLOW.md` |
| Manager contract | Human intent 보존, worker-ready ticket 작성, fail-closed preflight, result review, audit trail, Git governance 적용을 요구한다. | `docs/contracts/manager-contract.md` |
| Hammer contract | `local_worktree`, `ssh`, `docker`, `kubernetes_job` worker profile과 isolation, credential mode, cleanup/result metadata를 정의한다. | `docs/contracts/hammer-worker-contract.md` |
| Authority policy | cloud/Proxmox, secret/credential, Hammer creation/scaling/elevation, remote host/Docker/Kubernetes mutation, Manager replacement, merge/deploy/production write를 Human approval gate로 둔다. | `docs/policies/authority-and-safety.md` |
| Credential boundary | Manager PAT, OAuth token, SSH key, kubeconfig, cloud credential을 Hammer prompt/log/result packet에 복사하지 않고 brokered, scoped, expiring grant만 허용한다. | `docs/policies/authority-and-safety.md`, `docs/contracts/manager-contract.md` |
| Multi-tenant RBAC | tenant, role taxonomy, permission matrix, admission/authorization checks, project/repo/credential/worker route boundaries, access review를 docs-only 기준과 runtime evidence 기준으로 정의한다. | `docs/policies/multi-tenant-rbac.md`, `docs/policies/runtime-multi-tenant-rbac-2026-06-14.md` |
| Prompt-injection controls | issue body, PR comment, repository file, result packet text를 prompt injection surface로 보고, fail-closed preflight와 approval evidence를 요구한다. | `docs/policies/security-threat-model-and-prompt-injection-controls.md` |
| Git governance | GitHub Flow, branch naming, rationale-preserving commits, PR evidence, submodule boundary, required status checks를 정의한다. | `docs/policies/git-governance.md` |
| Worker ticket/result packet | ticket의 scope, acceptance criteria, permission, validation, result packet shape와 result evidence schema를 제공한다. | `docs/templates/worker-ticket.md`, `docs/templates/worker-result-packet.md` |
| Enterprise readiness | company-readiness criteria, development loop, runtime quality gate, SRE, compliance, backup/restore, audit, metrics, on-call, release rollback 기준을 둔다. | `docs/enterprise-readiness/criteria.json`, `docs/enterprise-readiness/development-loop.md` |
| Plugin package | `plugins/dokkaebi` 아래 project-admin, issue-intake, manager-review, fire-ops, hammer-bootstrap skill을 제공하고 validator로 패키징을 검사한다. | `plugins/dokkaebi/`, `scripts/validate-dokkaebi-plugin.sh` |
| Validation gates | contract docs, readiness, security, RBAC, governance, SRE, compliance, operations 문서 검증 스크립트가 존재한다. | `scripts/validate-contract-docs.sh`, `scripts/validate-*.sh` |

현재 Root의 핵심 성숙도는 "실행 자동화"가 아니라 **자동화가 무엇을 해도 되는지
판단하는 계약과 증거 체계**에 있다.

### Symphony / Dokkaebi Fire backend

`symphony-github-project-tracker` submodule은 현재 Dokkaebi Fire의
실행 backend 후보이며, Elixir/OTP reference implementation이 들어 있다.

| 영역 | 현재 기능 | 근거 |
| --- | --- | --- |
| Tracker polling | GitHub Projects v2 issue/project state를 polling하고 active issue를 dispatch한다. | `symphony-github-project-tracker/SPEC.md`, `symphony-github-project-tracker/elixir/README.md` |
| Workflow loader | repository-owned `WORKFLOW.md`의 YAML front matter와 prompt body를 읽고 runtime config를 만든다. | `symphony-github-project-tracker/SPEC.md`, `symphony-github-project-tracker/elixir/WORKFLOW.md` |
| Orchestrator | poll tick, concurrency, running/claimed/retry/completed state, retry backoff, reconciliation을 담당한다. | `symphony-github-project-tracker/SPEC.md`, `symphony-github-project-tracker/elixir/lib/symphony_elixir/orchestrator.ex` |
| Workspace manager | issue별 workspace를 만들고 cleanup hook을 실행한다. | `symphony-github-project-tracker/SPEC.md`, `symphony-github-project-tracker/elixir/lib/symphony_elixir/workspace.ex` |
| Codex runner | Codex app-server mode를 workspace 안에서 실행하고 issue context와 workflow prompt를 전달한다. | `symphony-github-project-tracker/elixir/README.md`, `symphony-github-project-tracker/elixir/lib/symphony_elixir/agent_runner.ex` |
| GitHub auth | PAT/env token과 OAuth Device Login token storage를 지원한다. | `symphony-github-project-tracker/elixir/README.md`, `symphony-github-project-tracker/elixir/lib/symphony_elixir/github/` |
| Credential broker | GitHub App installation token backend, repo allowlist, capability matrix, high-risk capability gate, operation gateway, grant/bundle metadata store를 제공한다. | `symphony-github-project-tracker/elixir/lib/symphony_elixir/credential_broker/` |
| Tenant RBAC runtime gate | dispatch, credential grant, worker route 전에 tenant, project, repo, role, permission, approval, credential, route scope를 확인하고 fail-closed한다. | `symphony-github-project-tracker/elixir/lib/symphony_elixir/tenant_rbac.ex` |
| Typed Hammer routing | `local_worktree`, `ssh`, `docker`, `kubernetes_job` route를 구분하고 containerizable, image/profile, kube context, namespace, tenant route 조건을 검사한다. | `symphony-github-project-tracker/elixir/lib/symphony_elixir/hammer/router.ex` |
| Provider behavior | Hammer provider behavior가 prepare/run/status/logs/stop/cleanup/health callback을 정의한다. | `symphony-github-project-tracker/elixir/lib/symphony_elixir/hammer/provider.ex` |
| Worker pool | SSH worker, Docker Compose worker registry fragment, OS metadata, health/capacity, least-loaded routing을 다룬다. | `symphony-github-project-tracker/elixir/lib/symphony_elixir/worker_pool.ex`, `symphony-github-project-tracker/docs/docker-compose-worker-fleet-guide.md` |
| Docker lane | Manager container와 SSH worker container fleet를 Docker Compose로 실행하고 worker scale/registry를 운영한다. | `symphony-github-project-tracker/docker/`, `symphony-github-project-tracker/docker-compose.yml` |
| Observability | Phoenix dashboard, `/api/v1/state`, `/api/v1/<issue_identifier>`, `/api/v1/refresh` JSON API를 제공한다. | `symphony-github-project-tracker/elixir/README.md`, `symphony-github-project-tracker/elixir/lib/symphony_elixir_web/` |
| Validation | `make all`, specs check, PR body check, tenant RBAC sandbox, live E2E 조건이 문서화되어 있다. | `symphony-github-project-tracker/elixir/README.md`, `symphony-github-project-tracker/elixir/mix.exs` |

중요한 현재 한계:

- Root는 대부분 docs/policy/contract 기반이고, 많은 "enterprise readiness" 항목은
  실제 production control plane이 아니라 검증 가능한 설계와 sandbox evidence다.
- Kubernetes route는 contract와 typed route에 들어와 있지만, K8S 자체를 Dokkaebi의
  단일 lifecycle source로 쓰는 management plane은 아직 없다.
- GitHub Project `Status`가 lifecycle source of truth다. K8S-only로 가려면 이
  역할을 대체할 API, UI, audit, transition policy가 필요하다.

## K8S-only가 의미하는 구조

여기서 K8S-only는 두 가지를 동시에 포함한다.

1. **Local Kubernetes**
   - kind, k3d, minikube, Docker Desktop Kubernetes, k3s 등에서 Fire와 Hammer를
     실행한다.
   - 개발, sandbox, disposable smoke, local RBAC/admission replay에 좋다.
   - control plane, audit sink, storage, ingress, image registry, secret backend,
     node lifecycle은 운영자가 직접 책임진다.
2. **Managed Kubernetes, 예: EKS**
   - AWS가 Kubernetes control plane 일부를 운영하고, managed node group이나
     managed add-on을 활용할 수 있다.
   - EKS access entries, IRSA, EKS Pod Identity로 IAM principal과 workload
     identity를 분리할 수 있다.
   - 그래도 namespace/RBAC/admission/network/secrets/audit 설계와 Dokkaebi
     policy mapping은 Dokkaebi 쪽 책임이다.

가능한 target topology:

```text
Human / Manager adapter outside cluster
  -> Dokkaebi Management API or GitHub Project adapter
  -> Dokkaebi Fire Deployment inside cluster
  -> Kubernetes API admission/RBAC
  -> one Job per Hammer ticket
  -> result packet, logs, artifacts, PR/check evidence
```

더 강한 K8S-only topology:

```text
Human / Manager adapter
  -> Dokkaebi API
  -> WorkRequest CRD or internal DB
  -> Fire controller
  -> Hammer Job
  -> ResultPacket CRD or audit DB
  -> Manager review UI/API
```

이 두 번째 구조가 진짜 K8S-only에 가깝지만, 사실상 GitHub Project가 제공하던
issue lifecycle, status field, comments/workpad, review visibility, search,
permissions, audit trail을 직접 만드는 일이다.

## 권한 모델

Kubernetes가 좋은 점은 prompt나 issue text가 아니라 **API server 권한 계층**에서
실제 가능 행동을 제한할 수 있다는 점이다. 다만 이것은 자동으로 되지 않는다.
Manager/Fire/Hammer 권한을 분리해서 설계해야 한다.

### 권장 Kubernetes principal

| Principal | Kubernetes identity | 허용 권한 | 금지 권한 |
| --- | --- | --- | --- |
| Human operator | OIDC/IAM principal 또는 EKS access entry | cluster admin break-glass, setup approval 시 제한적 mutation | 상시 worker credential 사용 |
| Dokkaebi Fire | `ServiceAccount/dokkaebi-fire` | approved namespace에서 Job create/get/list/watch, Pod/log read, non-secret ConfigMap read, external grant metadata read, ResultPacket write | Secret get/list/watch, cluster-wide secret read, RBAC mutate, namespace create/delete, deployment mutate, node mutate |
| Hammer Job | ticket별 또는 route별 `ServiceAccount/dokkaebi-hammer-*` | assigned workspace PVC/emptyDir, scoped network, broker endpoint, repository credential bundle read | Kubernetes API broad access, Secret list, namespace escape, RBAC mutate, other tenant resources |
| Credential broker | `ServiceAccount/dokkaebi-credential-broker` | short-lived credential issuance metadata, external secret provider access | raw broad token disclosure to Hammer logs/prompts |
| Admission controller | `ServiceAccount/dokkaebi-admission` | validate/mutate only Dokkaebi resources and Jobs | arbitrary workload mutation outside policy |

### Enforcement mapping

| Dokkaebi concept | K8S enforcement |
| --- | --- |
| Permission level | Role/RoleBinding and admission policy |
| Worker route boundary | namespace, ServiceAccount, Job template, allowed image/profile |
| Tenant boundary | namespace per tenant or namespace plus tenant labels and admission checks |
| Credential grant | external secret provider, projected short-lived token, IRSA/Pod Identity on EKS |
| Approval gate | immutable approval record checked by Fire before Job creation and by admission before persistence |
| Result packet | CRD/status subresource, object storage artifact, GitHub PR/check link, or audit DB row |
| Cleanup | Job TTL, finalizer, PVC retention policy, explicit cleanup receipt |
| Audit | Kubernetes audit log plus Dokkaebi result/audit package |

## 프롬프트 인젝션과 외부/내부 사용자 문제

사용자 우려는 타당하다. GitHub issue가 외부 사용자에게 열려 있으면 issue body는
untrusted input이다. 내부 사용자라 해도 RBAC상 같은 권한을 가져서는 안 된다.
따라서 "누가 issue를 썼는가"와 "Fire/Hammer가 어떤 권한을 받는가"를 직접
연결하면 안 된다.

안전한 처리 원칙:

1. **Issue text는 instruction이 아니라 evidence/input으로 취급**
   - Manager가 원문을 보존하되, 실행 instruction은 worker-ready ticket으로
     재작성한다.
   - repository file, PR comment, result packet도 동일하게 untrusted input이다.
2. **역할/tenant/approval은 issue prose에서 추론하지 않음**
   - GitHub user/team, project field, identity provider claim, Dokkaebi tenant
     registry, approval record에서만 권한을 계산한다.
3. **Fire preflight와 Kubernetes admission을 이중화**
   - Fire가 잘못된 Job을 만들려고 해도 admission이 거부해야 한다.
   - admission은 ServiceAccount, namespace, image/profile, labels, tenant,
     approval id, credential grant id를 검사한다.
4. **Hammer에는 broad K8S 권한을 주지 않음**
   - Hammer Job은 기본적으로 Kubernetes API access token mount를 끄거나,
     필요 시 최소 권한 ServiceAccount만 사용한다.
5. **Credential broker는 prompt를 믿지 않음**
   - grant request는 ticket id, repo/service allowlist, branch/environment,
     capability, approval id, endpoint proof가 맞을 때만 발급된다.
6. **감사와 closeout은 prompt 밖 durable surface에 저장**
   - Manager memory나 agent chat이 approval/result의 유일한 기록이면 실패로 본다.

위 설계에서는 prompt injection이 "도깨비 방망이에게 cluster-admin을 요구하는
문장"을 포함해도, Hammer Job의 ServiceAccount와 NetworkPolicy, admission policy,
credential broker가 실제 권한을 차단한다.

## GitHub Project 중심 vs 자체 관리 솔루션

| 기준 | GitHub Project 중심 유지 | 자체 management solution 포함 |
| --- | --- | --- |
| 빠른 실현성 | 높음. 이미 현재 architecture와 Fire가 여기에 맞춰져 있다. | 낮음. issue/status/comment/review/audit/UI를 다시 만들어야 한다. |
| 개발자 workflow | PR, review, checks, issue history와 자연스럽게 연결된다. | GitHub와 다시 연동하거나 대체 UX를 만들어야 한다. |
| 외부 사용자 issue intake | GitHub permission과 moderation을 활용할 수 있지만 injection input은 여전히 존재한다. | intake부터 role/tenant를 강하게 통제할 수 있지만 제품 구현 비용이 크다. |
| RBAC 정밀도 | GitHub Project field와 org/team 권한만으로는 K8S runtime 권한까지 정밀하게 적용하기 어렵다. | Dokkaebi tenant/role/permission 모델을 1급 객체로 만들 수 있다. |
| Audit | GitHub issue/PR/check history가 강한 외부 감사 surface다. | 자체 immutable audit를 잘 만들면 더 강하지만, 직접 보증해야 한다. |
| 운영 복잡도 | 낮음. 외부 SaaS에 lifecycle 일부를 맡긴다. | 높음. API, DB, migration, backup/restore, HA, on-call이 필요하다. |
| K8S-only 일관성 | 낮음. lifecycle source가 cluster 밖에 남는다. | 높음. WorkRequest/ResultPacket/Approval을 cluster-native로 만들 수 있다. |
| 성숙도 영향 | 지금 단계에서는 안정성에 유리하다. | 너무 이르면 scope 폭발. 후반에는 enterprise maturity를 높일 수 있다. |

판단:

- **단기**: GitHub Project보다 자체 관리 솔루션이 더 이득이라고 보기 어렵다.
  현재 Dokkaebi의 계약은 GitHub Project `Status`를 lifecycle source로 삼고 있고,
  Symphony도 여기에 최적화되어 있다.
- **중기**: 자체 관리 솔루션의 일부는 필요하다. 특히 tenant RBAC, approval record,
  credential grant, worker route admission, result packet query는 GitHub Project
  field만으로는 부족하다.
- **장기**: 자체 management plane이 이득이다. 다만 GitHub를 완전히 버리기보다
  GitHub PR/check/review와 연결되는 adapter를 유지하는 편이 성숙도와 사용자
  채택에 좋다.

따라서 권장 목표는 "GitHub Project 제거"가 아니라
**Dokkaebi-native authority plane 추가 후 GitHub Project adapter화**다.

## Kubernetes-only 장점

- **실행 격리 표준화**: Hammer 하나를 Job 하나로 만들면 workspace, lifecycle,
  logs, cleanup, resource quota를 표준화할 수 있다.
- **권한 강제 지점 증가**: RBAC, ServiceAccount, admission, NetworkPolicy,
  Secret policy가 prompt와 별개의 강제 계층이 된다.
- **로컬/운영 parity**: local K8S에서 admission/RBAC/Job manifest를 검증하고,
  EKS에서 거의 같은 control을 운영할 수 있다.
- **관찰성 통합**: Job/Pod status, events, logs, metrics, audit log를 Fire
  observability에 결합할 수 있다.
- **확장성**: Hammer parallelism, queue pressure, resource requests/limits,
  node pool placement를 Kubernetes scheduler에 맡길 수 있다.
- **권한 분리 설계가 명료함**: Fire, Hammer, credential broker, admission
  controller가 각각 다른 ServiceAccount를 가진다.
- **EKS의 workload identity 활용**: IRSA나 EKS Pod Identity로 AWS 권한을
  Pod/ServiceAccount 단위로 제한할 수 있다.

## Kubernetes-only 단점

- **control plane 재구현 비용**: GitHub Project가 제공하던 lifecycle, discussion,
  review, search, permissions, notification, audit UX를 직접 대체해야 한다.
- **운영 표면 증가**: local K8S만으로도 ingress, image registry, secret store,
  audit sink, storage, upgrades, backup/restore, admission controller 운영이 필요하다.
- **권한 오설정 위험**: Kubernetes RBAC는 강력하지만, 잘못된 ClusterRoleBinding,
  default ServiceAccount token, broad Secret read가 있으면 위험이 커진다.
- **prompt injection이 사라지지는 않음**: 단지 피해 반경을 줄일 뿐이다. issue
  intake와 ticket transformation에는 여전히 injection 검사가 필요하다.
- **EKS 비용과 복잡도**: cluster/node/add-on 비용, IAM integration, network,
  IRSA/Pod Identity, log/audit pipeline이 생긴다.
- **GitHub와의 연결은 여전히 필요**: 실제 코드 변경은 PR/check/review와 연결되어야
  하므로 GitHub를 완전히 제거해도 repository governance 통합은 남는다.
- **로컬 K8S와 EKS의 차이**: local cluster에서 통과한 policy가 IAM, CNI,
  load balancer, audit, storage 차이 때문에 EKS에서 그대로 충분하지 않을 수 있다.

## 관리 방안

### Admission policy

Admission은 Fire가 생성하는 Job을 cluster에 저장하기 전 마지막 fail-closed gate다.
최소 검사:

- `dokkaebi.io/ticket-id`
- `dokkaebi.io/tenant-id`
- `dokkaebi.io/approval-id`
- `dokkaebi.io/route-profile`
- `dokkaebi.io/credential-grant-id`
- allowed image/profile
- namespace and ServiceAccount match
- resource request/limit present
- no hostPath, privileged, hostNetwork, hostPort, hostPID, hostIPC, broad volume mount
- result packet sink declared

### Namespace strategy

초기에는 **tenant별 namespace**가 이해하기 쉽다.

- `dokkaebi-system`: Fire, broker, admission, observability
- `dokkaebi-tenant-alpha`: tenant alpha Hammer Jobs
- `dokkaebi-tenant-beta`: tenant beta Hammer Jobs

나중에 tenant 수가 늘면 namespace-per-tenant와 namespace-per-environment를
혼합하되, tenant label과 admission 검사를 유지한다.

### RBAC strategy

- Fire는 Job create/read/log 정도만 가진다.
- Hammer는 기본 Kubernetes API 권한이 없거나, ticket-specific resource만 read/write한다.
- Credential broker는 Secret 자체보다 external secret backend와 metadata store를 다룬다.
- RBAC mutation은 Human-approved setup pipeline만 수행한다.
- break-glass ClusterRole은 상시 binding하지 않고 approval/expiry/audit를 요구한다.

### Network strategy

- Hammer namespace default-deny egress/ingress.
- 허용 egress:
  - GitHub API / Git remote
  - model/Codex endpoint
  - credential broker endpoint
  - artifact/log endpoint
- tenant 간 Pod 통신은 기본 차단.
- Fire와 broker 접근은 필요한 route만 허용.

### Secret strategy

- Kubernetes Secret은 가능한 secret material의 최종 저장소가 아니라 projection
  또는 external secret bridge로 취급한다.
- EKS에서는 IRSA 또는 EKS Pod Identity로 AWS 권한을 ServiceAccount에 묶는다.
- Hammer result packet, logs, prompts에는 raw credential을 금지한다.
- Fire와 Hammer는 기본적으로 Kubernetes Secret `get/list/watch` 권한을 받지 않는다.
  Kubernetes RBAC의 Secret read는 metadata-only가 아니라 secret value 노출로 이어질
  수 있으므로, Secret 접근은 ticket-specific Human approval, named secret, reason,
  expiry, cleanup evidence가 있을 때만 별도 RoleBinding으로 부여한다.
- 가능한 경우 Secret 직접 읽기 대신 credential broker의 external metadata/grant
  store와 projected short-lived credential을 사용한다.

### Audit strategy

감사 소스:

- Dokkaebi approval record
- Fire dispatch decision
- Kubernetes admission allow/deny
- Kubernetes audit log
- credential broker grant/deny metadata
- Hammer Job identity/log/result packet
- PR/check/review evidence

closeout은 이 소스들을 하나의 result packet으로 묶어야 한다.

## 개발 계획

### Phase 0: 현 상태 기준선 고정

목표: 현재 GitHub Project 중심 계약과 Symphony backend가 무엇을 제공하는지
변하지 않게 기록한다.

산출물:

- 현재 기능 inventory report
- Kubernetes authority mapping ADR draft
- report validation script 혹은 checklist

검증:

- `bash scripts/validate-contract-docs.sh`
- root/submodule status capture

### Phase 1: Kubernetes Job Hammer route를 first-class로 강화

목표: Fire는 GitHub Project를 계속 쓰되, Hammer 실행 substrate로 Kubernetes Job을
안전하게 사용한다.

필요 작업:

- `kubernetes_job` provider의 manifest schema 확정
- fake manifest runner와 local K8S smoke runner 분리
- Job labels/annotations 표준화
- ServiceAccount/Role/RoleBinding/NetworkPolicy template 추가
- cleanup receipt와 result packet metadata 강화

성공 기준:

- containerizable ticket만 Kubernetes route로 dispatch된다.
- context/namespace/image/profile 누락 시 fail-closed한다.
- Hammer Job이 broad Secret/RBAC 권한 없이 실행된다.

### Phase 2: Fire in Kubernetes

목표: Dokkaebi Fire를 Deployment로 배치하고, 제한된 권한으로 Hammer Jobs를 생성한다.

필요 작업:

- Fire container image와 Helm/Kustomize manifests
- Fire ServiceAccount least-privilege Role
- ConfigMap/Secret externalization
- observability service와 `/api/v1/state` ingress/port-forward guide
- local K8S + EKS deployment runbook

성공 기준:

- local K8S에서 Fire가 GitHub Project를 poll하고 approved Job만 만든다.
- Fire ServiceAccount로 namespace/RBAC/Secret broad mutation이 거부된다.
- EKS preflight에서 access entry, IRSA/Pod Identity, audit/logging readiness를 확인한다.

### Phase 3: Dokkaebi authority plane

목표: GitHub Project field만으로 부족한 tenant/RBAC/approval/credential/route
판단을 Dokkaebi-native API로 분리한다.

필요 작업:

- WorkRequest, ApprovalRecord, CredentialGrant, WorkerRoute, ResultPacket model
- GitHub Project adapter: 기존 issue/project를 WorkRequest로 normalize
- Kubernetes admission adapter: WorkRequest/ApprovalRecord를 Job admission에서 조회
- audit query API
- Manager review API

성공 기준:

- 외부 issue text가 role/permission을 직접 만들 수 없다.
- 내부 사용자도 role에 따라 route/credential/action이 다르게 deny/allow된다.
- denial은 result/audit package로 남는다.

### Phase 4: 자체 management UI/API 병행 운영

목표: GitHub Project와 자체 관리 솔루션을 병행하며 기능 격차를 줄인다.

필요 작업:

- queue/status/review dashboard
- approval UI
- result packet review UI
- RBAC/access review UI
- GitHub issue/PR/check back-linking
- immutable audit export

성공 기준:

- Manager가 GitHub Project 없이도 pending/in-progress/review/done lifecycle을
  inspect할 수 있다.
- 그러나 PR/check/review integration은 유지된다.

### Phase 5: K8S-only 전환 결정

목표: GitHub Project를 source-of-truth에서 adapter/evidence surface로 낮출 수
있는지 결정한다.

전환 조건:

- 자체 WorkRequest lifecycle이 GitHub Project Status와 동등하거나 더 강한 audit를 낸다.
- approval evidence와 access review가 자체 시스템에서 완결된다.
- Kubernetes admission/RBAC/NetworkPolicy/Secret controls가 local K8S와 EKS에서 모두 검증된다.
- backup/restore, DR, on-call, incident response, release rollback, compliance export가 준비된다.
- GitHub PR/check/review는 repository governance adapter로 유지된다.

## 최종 비교

현재 구조는 maturity 면에서 **계약과 감사 가능성**이 강하다. GitHub Project가
이미 lifecycle source, issue context, review visibility, PR/check 연결을 제공하기
때문이다. 반면 runtime authority를 Kubernetes 수준에서 강제하는 힘은 아직 충분히
활용하지 못한다.

K8S-only 구조는 maturity 면에서 **실행 격리와 권한 강제력**을 크게 올릴 수 있다.
하지만 control plane을 직접 운영하는 순간 제품, 보안, SRE, compliance 책임이
한꺼번에 늘어난다. 너무 이른 K8S-only 전환은 성숙도를 올리기보다 현재 확보한
GitHub Project 기반 감사성과 workflow 단순성을 잃게 만들 수 있다.

따라서 가장 실현 가능한 성숙도 경로는:

```text
GitHub Project source of truth
  + Kubernetes Job Hammer execution
  + Fire inside Kubernetes
  + Dokkaebi-native authority plane
  + management UI/API
  -> optional K8S-only source of truth
```

이 경로라면 도깨비 불은 Kubernetes 내부에서 제한된 권한으로 도깨비 방망이를 만들고
관리할 수 있고, 도깨비 방망이는 실제 서비스 또는 작업 단위를 생성/수정하되
ServiceAccount, RBAC, NetworkPolicy, admission, credential broker가 허용한 범위만
수행한다. 사용자는 도깨비 자체를 외부에서 사용하되, issue 처리 과정에 필요한
인프라 권한은 prompt가 아니라 승인 기록과 runtime policy로 녹일 수 있다.

## 공식 Kubernetes/EKS 근거

- Kubernetes RBAC: <https://kubernetes.io/docs/reference/access-authn-authz/rbac/>
- Kubernetes RBAC good practices: <https://kubernetes.io/docs/concepts/security/rbac-good-practices/>
- Kubernetes ServiceAccounts: <https://kubernetes.io/docs/concepts/security/service-accounts/>
- Kubernetes NetworkPolicy: <https://kubernetes.io/docs/concepts/services-networking/network-policies/>
- Kubernetes admission controllers: <https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/>
- Kubernetes validating admission policy: <https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/>
- Kubernetes audit logging: <https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/>
- Kubernetes Secrets good practices: <https://kubernetes.io/docs/concepts/security/secrets-good-practices/>
- AWS EKS access entries: <https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html>
- AWS EKS access policies: <https://docs.aws.amazon.com/eks/latest/userguide/access-policies.html>
- AWS EKS IRSA: <https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html>
- AWS EKS Pod Identity: <https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html>
- AWS EKS managed node groups: <https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html>
