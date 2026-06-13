# Project Dokkaebi 회사 사용 준비도 평가 보고서

작성일: 2026-06-13  
범위: Project Dokkaebi 루트 저장소와 `symphony-github-project-tracker` 서브모듈  
제외: BM은 평가 범위에서 제외

## Executive Summary

Project Dokkaebi는 “사람이 승인하고, GitHub Project가 상태 원장 역할을 하며, Dokkaebi Fire가 작업을 라우팅하고, Dokkaebi Hammer가 제한된 작업을 실행한다”는 운영 계약이 꽤 선명한 프로젝트다. 특히 GitHub Project `Status`를 라이프사이클 SOT로 고정한 점, Human approval gate, result packet, Git governance, submodule boundary는 회사 내부의 AI 작업 관리 체계로 발전시킬 만한 좋은 뼈대다.

다만 현재 완성도는 “회사에서 바로 프로덕션 운영 가능한 제품”보다는 “감사 가능한 AI 작업 오케스트레이션의 강한 프로토타입”에 가깝다. 핵심 루프와 문서 계약은 성숙하지만, 프로덕션 서비스 운영에 필요한 SLO/SLA, alerting, incident response, backup/restore, DR, immutable audit, compliance package, release/rollback runbook은 저장소 기준으로 거의 비어 있다.

종합 성숙도는 **62%**로 평가한다. 계약/거버넌스는 **82%**, 런타임 오케스트레이션은 **70%**, 보안 경계는 **72%**, 기업 운영성은 **28%** 수준이다. 실제 회사 사용 수준으로 끌어올리려면 기능 추가보다 먼저 “운영 가능한 플랫폼”으로 바꾸는 일이 중요하다.

## 2026-06-13 Readiness Loop Reassessment Note

이 보고서의 0% 표와 “거의 비어 있다”는 문장은 보고서 작성 당시의 baseline 평가다. 이후 readiness loop에서 저장소 근거가 추가되면 현재 점수와 다음 이슈는 `docs/enterprise-readiness/criteria.json`을 기준으로 재평가한다.

SLO/SLA 항목은 이제 `docs/operations/service-level-objectives.md`와 `scripts/validate-service-level-objectives.sh`에 의해 docs-only 초기 SLO, fallback evidence, error-budget policy, review cadence, owner action, availability posture, external SLA boundary가 명시된다. 다만 외부 SLA는 승인되지 않았고, 중앙 metrics ingestion/query/dashboard/alert 평가와 measured SLO evidence는 아직 완료되지 않았다. 추가 완성도는 issue #57의 central metrics backend sandbox 또는 local replay evidence가 있어야만 주장할 수 있다.

## 평가 방법

평가는 BM을 제외하고 실제 회사 내부에서 장기간 사용할 수 있는지를 기준으로 했다. 점수는 다음 의미로 해석한다.

| 점수 | 의미 |
| --- | --- |
| 0% | 있어야 하는 능력이지만 저장소 기준 명시 근거가 없거나 사실상 미구현 |
| 1-30% | 방향성 또는 선언만 있고 운영/구현 증거가 부족 |
| 31-60% | 일부 구현 또는 문서가 있으나 수동 운영/샌드박스 수준 |
| 61-80% | 실제 사용 가능한 핵심 기능이 있으나 기업 운영 통제가 부족 |
| 81-95% | 회사 내부 표준으로 삼을 수 있는 수준, 일부 실증/자동화 필요 |
| 96-100% | 프로덕션 운영과 감사까지 거의 완비 |

주요 근거 파일:

- `README.md`
- `ARCHITECTURE.md`
- `WORKFLOW.md`
- `docs/contracts/manager-contract.md`
- `docs/contracts/hammer-worker-contract.md`
- `docs/policies/authority-and-safety.md`
- `docs/policies/git-governance.md`
- `docs/operations/fire-sandbox-service.md`
- `docs/operations/toolchain-bootstrap.md`
- `plugins/dokkaebi`
- `symphony-github-project-tracker/SPEC.md`
- `symphony-github-project-tracker/elixir/README.md`
- `symphony-github-project-tracker/elixir/lib/symphony_elixir/orchestrator.ex`
- `symphony-github-project-tracker/elixir/lib/symphony_elixir/worker_pool.ex`
- `symphony-github-project-tracker/elixir/lib/symphony_elixir/hammer/router.ex`
- `symphony-github-project-tracker/elixir/lib/symphony_elixir/credential_broker/policy.ex`
- `symphony-github-project-tracker/elixir/docs/observability.md`
- `symphony-github-project-tracker/elixir/docs/logging.md`

## 전체 성숙도 대시보드

| 영역 | 현재 완성도 | 판단 |
| --- | ---: | --- |
| 아키텍처/계약 | 88% | Manager, Fire, Hammer, GitHub Project 상태 원장의 경계가 명확함 |
| 핵심 오케스트레이션 | 72% | polling, dispatch, retry, continuation, worker routing이 있음 |
| 인프라 및 플랫폼 | 48% | sandbox/service/worker fleet은 있으나 production topology/HA/DR 부족 |
| 개발 및 품질 | 76% | CI, tests, lint, dialyzer, governance check는 좋으나 운영 E2E가 얇음 |
| 보안 및 권한 | 72% | approval gate와 credential broker는 강하나 enterprise secret lifecycle 부족 |
| 관리 및 거버넌스 | 82% | GitHub Project SOT, issue/result packet, Git governance가 강함 |
| 로깅 및 관측성 | 58% | dashboard/API/logging은 있으나 metrics/tracing/alerting/export 부족 |
| 운영 안정성 및 SRE | 24% | retry와 runbook 일부 외에 SLO, incident, DR, on-call이 없음 |
| 컴플라이언스 및 감사 | 34% | evidence model은 강하지만 retention/export/control mapping 부족 |
| 제품화 및 사용성 | 46% | plugin skillset은 있으나 설치/운영 UX와 admin UI가 부족 |
| 종합 | 62% | 내부 파일럿/샌드박스 운영은 가능, 회사 표준 서비스로는 추가 작업 필요 |

## 있어야 하지만 없는 기능

아래 항목은 회사 사용 수준에서 있어야 하지만 현재 저장소 기준으로 명시 근거가 없거나 실질 구현이 보이지 않아 **0%**로 본다.

| 기능 | 완성도 | 왜 필요한가 | 현재 상태 |
| --- | ---: | --- | --- |
| Incident Response | 0% | 장애 severity, commander, escalation, postmortem이 필요 | 장애 대응 전용 문서/프로세스 없음 |
| On-call / Paging / Alerting | 0% | Fire/worker 장애를 사람이 알아야 함 | dashboard/API는 있으나 alert rule, pager integration 없음 |
| SLO / SLA | 0% | 신뢰성 목표와 error budget이 필요 | uptime, dispatch latency, recovery objective 없음 |
| Backup / Restore / DR | 0% | GitHub Project, workspace, token store, logs 복구가 필요 | reset/rollback note만 있고 RPO/RTO 없음 |
| Compliance Package | 0% | SOC2/ISO/internal audit용 통제 매핑이 필요 | evidence 요구는 있으나 control mapping 없음 |
| Production Release / Rollback Runbook | 0% | 안전한 배포/롤백/maintenance가 필요 | sandbox service runbook 외 production 절차 없음 |
| Central Metrics Backend | 0% | 운영 지표를 장기 저장하고 alert해야 함 | Prometheus/OpenTelemetry/Grafana 연동 없음 |
| Immutable Audit Export | 0% | 승인/작업/토큰 grant 증적을 변조 방지 저장해야 함 | 장기 보존/내보내기 정책 없음 |
| Multi-tenant RBAC | 0% | 여러 팀/프로젝트 등록 시 권한 분리가 필요 | GitHub user allowlist 일부 외 조직 RBAC 없음 |

## 인프라 및 플랫폼

### 현재 완성도

| 세부 파트 | 완성도 | 근거 |
| --- | ---: | --- |
| 로컬/샌드박스 Fire 서비스 | 58% | `docs/operations/fire-sandbox-service.md`에 user-level systemd runbook 존재 |
| Elixir/OTP 서비스 구조 | 82% | `symphony-github-project-tracker/elixir/lib/symphony_elixir.ex`가 Supervisor로 핵심 프로세스 기동 |
| Worker registry/capacity 모델 | 72% | `worker_pool.ex`가 static, external registry, Compose fragment를 통합 |
| SSH worker 운영 | 70% | `hammer/providers/ssh.ex`, `worker_health.ex`, Docker worker fleet guide 존재 |
| Docker worker 운영 | 62% | Docker provider와 compose topology는 있으나 production daemon policy는 승인 게이트 중심 |
| Kubernetes Job route | 38% | `kubernetes_job.ex`가 manifest/runner 구조는 제공하나 cluster lifecycle 통합은 얕음 |
| HA/leader election | 0% | 단일 Fire 기준, leader election/active-passive 설계 없음 |
| 내구 큐/리스 저장소 | 20% | orchestrator state는 in-memory, `SPEC.md`도 retry/running state 미복구를 명시 |
| Backup / Restore / DR | 0% | RPO/RTO, restore drill, backup 대상 정의 없음 |

### 부족한 점

현재 인프라 모델은 sandbox와 단일 서비스 운영에 적합하다. `docs/operations/fire-sandbox-service.md`는 service unit, wrapper, logs, workspaces, state API를 안내한다. 그러나 이 문서는 스스로 sandbox guidance이며 production approval이 아니라고 선을 긋는다. 회사 운영에서는 최소 staging/prod topology, HA, backup, restore, deployment ownership이 필요하다.

서브모듈의 `SPEC.md`는 restart recovery가 polling과 workspace reuse에 기반하며 retry timers, running sessions, live worker state는 복구하지 않는다고 명시한다. 이 설계는 단순하고 좋은 프로토타입 선택이지만, 장시간 회사 업무를 처리하는 서비스에서는 중복 dispatch, stale workspace, orphan process, lost retry에 대한 운영 리스크가 된다.

Docker와 Kubernetes는 타입화된 route로 모델링되어 있으나 수준이 다르다. SSH/Compose는 실제 운영에 가까운 반면, Kubernetes provider는 manifest 생성과 runner injection 중심이라 cluster-native reconciliation, pod log collection, job TTL 확인, namespace quota, service account binding, image provenance, cleanup guarantee가 부족하다.

### 발전 방향

1. Fire를 production service로 정의한다: `sandbox`, `staging`, `production` 환경을 분리하고 각 환경의 GitHub Project, worker registry, credential source, log path, dashboard port, owner를 명시한다.
2. 내구 실행 상태를 추가한다: running lease, retry schedule, worker assignment, dispatch attempt를 SQLite/Postgres 또는 GitHub issue comment 기반 durable ledger에 남긴다.
3. HA는 처음부터 복잡하게 가지 말고 active-passive부터 시작한다: Fire instance id, heartbeat, lease TTL, single-writer election을 둔다.
4. Kubernetes는 별도 provider maturity milestone로 분리한다: real `kubectl` apply/watch/logs/delete, namespace quota, serviceAccount, networkPolicy, TTLAfterFinished, image pull policy를 갖춘다.
5. DR runbook을 만든다: GitHub Project config, workflow config, worker registry, OAuth token store, GitHub App private key path, logs, workspace root를 백업/복구 대상으로 분류한다.

## 개발 및 품질

### 현재 완성도

| 세부 파트 | 완성도 | 근거 |
| --- | ---: | --- |
| 계약 문서 일관성 | 88% | `scripts/validate-contract-docs.sh`와 root governance workflow |
| Git governance | 86% | branch, commit body, PR evidence, submodule policy가 있음 |
| Elixir test suite | 78% | `elixir/test/symphony_elixir/*`에 33개 test file 존재 |
| CI | 76% | `make-all`, PR description lint, git-governance workflow 존재 |
| Static analysis | 70% | `credo --strict`, `dialyzer`, format check 포함 |
| Coverage policy | 55% | 100% threshold는 있으나 핵심 운영 모듈 다수가 ignore list에 포함 |
| Live E2E | 45% | `make e2e`가 있으나 credential/isolated external 환경 의존으로 기본 gate는 아님 |
| Performance/soak/fault injection | 0% | 장기 실행, failure injection, load profile 없음 |
| Release engineering | 20% | build/test는 있으나 versioning, release notes, rollout/rollback 절차 부족 |

### 부족한 점

개발 품질의 기본기는 좋다. `symphony-github-project-tracker/elixir/Makefile`은 setup, build, format, lint, coverage, dialyzer를 `make all`로 묶고, GitHub Actions도 이를 실행한다. 루트 저장소도 계약 문서와 plugin package를 검증한다.

문제는 “테스트가 엄격해 보이는 것”과 “운영 위험이 실제로 커버되는 것” 사이에 간극이 있다는 점이다. `mix.exs`의 coverage ignore 목록에는 Orchestrator, AgentRunner, Config, GitHub Client/Adapter, CredentialBroker, Provider, HttpServer 등 중요한 운영 모듈이 다수 포함되어 있다. 따라서 100% coverage threshold는 실제 운영 위험을 대표하지 않는다.

또한 실제 GitHub Project, real Codex app-server, SSH/Docker/K8s worker를 엮은 장기 E2E가 기본 merge gate로 보이지 않는다. 회사 수준에서는 “단위 테스트 통과”뿐 아니라 “새 버전이 실제 작업판에서 issue를 안전하게 처리하고, 실패 시 recover하며, alert를 남기는지”가 필요하다.

### 발전 방향

1. 테스트 피라미드를 운영 위험 기준으로 재정의한다: unit, adapter contract, fake GraphQL integration, live sandbox E2E, soak/fault profile을 분리한다.
2. Coverage ignore 목록을 줄이기보다 “운영 핵심 모듈 risk coverage” 표를 만든다. Orchestrator, AgentRunner, CredentialBroker, GitHub Client는 별도 기준을 둔다.
3. release candidate workflow를 만든다: contract validation, make all, sandbox live dispatch, rollback smoke, security scan, docs consistency를 하나로 묶는다.
4. GitHub Project schema fixture를 versioning한다: Status/Agent/Authorization/Authorized By/Symphony Admission 필드와 option ids를 fixture로 검증한다.
5. fault injection을 추가한다: GitHub API timeout/rate limit, worker unhealthy, Codex stall, workspace hook timeout, Docker image missing, K8s Job failure를 반복 검증한다.

## 보안 및 권한

### 현재 완성도

| 세부 파트 | 완성도 | 근거 |
| --- | ---: | --- |
| Human approval policy | 90% | `docs/policies/authority-and-safety.md`가 high-impact action을 승인 게이트로 둠 |
| Fail-closed preflight | 82% | Manager contract와 workflow에 preflight/blocking 원칙 존재 |
| Credential broker concept | 78% | `manager-contract.md`, `credential_broker/*`, `elixir/README.md`에 broker model 존재 |
| Capability policy | 76% | `credential_broker/policy.ex`가 repo allowlist/capability/high-risk gate 검증 |
| Token redaction | 72% | `credential_broker/redactor.ex`, observability docs에 redacted summary 존재 |
| Secret lifecycle | 42% | local token file/GitHub App path 중심, rotation/KMS/Vault 없음 |
| Sandbox hardening | 38% | Codex sandbox config는 있으나 deployment-specific hardening은 미정 |
| SSO/RBAC | 15% | GitHub login/allowlist 일부 외 Manager UI/RBAC 없음 |
| Threat modeling | 20% | 위험 언급은 있으나 STRIDE/abuse case 문서 없음 |

### 부족한 점

보안 철학은 보수적이다. Manager PAT/OAuth token을 Hammer workspace에 복사하지 말라는 원칙, credential broker, high-risk capability gate, endpoint proof 요구는 방향이 좋다. `OperationGateway`는 raw GraphQL mutation을 operation으로 분류해 policy를 통과시키려 한다.

하지만 회사 보안 기준에서는 아직 “원칙”이 “운영 프로그램”으로 내려오지 않았다. Vault/KMS/SOPS/SealedSecrets 같은 중앙 비밀관리 연동이 없고, token rotation, key revocation drill, access review, break-glass, audit retention이 없다. Docker provider의 secret-like env filtering은 유용하지만, regex 기반이라 모든 secret exfiltration을 막는 보안 경계로 보기 어렵다.

가장 큰 보안 리스크는 작업 입력이 GitHub issue/body/repo content라는 점이다. `SPEC.md`도 externally-controlled content가 harmful command나 data leak을 유도할 수 있다고 경고한다. 그러나 prompt injection 대응, tool allowlist, network egress policy, sandbox escape 대응, repository trust tier는 아직 체계화되어 있지 않다.

### 발전 방향

1. 보안 모델을 문서화한다: actor, asset, trust boundary, attack path, mitigation, residual risk를 threat model로 정리한다.
2. secret lifecycle을 만든다: GitHub App private key, OAuth token store, worker bundle credentials의 rotation/revocation/expiry/audit 절차를 둔다.
3. sandbox profile을 tier로 나눈다: read-only, repo-write, external-write, infra-write 각각 filesystem/network/tool policy를 명시한다.
4. broker를 기본 경로로 강화한다: worker-facing GitHub write는 `github_operation`/OperationGateway를 통하게 하고 raw GraphQL은 trusted-local debug path로 제한한다.
5. RBAC를 추가한다: project admin, issue approver, worker operator, security admin, auditor 역할을 분리한다.
6. supply-chain 보안을 추가한다: pinned GitHub Actions는 일부 존재하지만 dependency audit, SBOM, image signing, base image patch cadence가 필요하다.

## 관리 및 거버넌스

### 현재 완성도

| 세부 파트 | 완성도 | 근거 |
| --- | ---: | --- |
| GitHub Project `Status` SOT | 90% | README, ARCHITECTURE, WORKFLOW, Manager contract에 반복 정의 |
| Work intake contract | 84% | `docs/templates/worker-ticket.md`, `plugins/dokkaebi/skills/issue-intake` |
| Manager review contract | 82% | `docs/templates/worker-result-packet.md`, `plugins/dokkaebi/skills/manager-review` |
| GitHub Flow/Git governance | 86% | branch naming, commit rationale, PR requirements, submodule policy |
| Brownfield/Greenfield project admin | 70% | `github-project-v2-symphony-playbook.md`, `project-admin` skill |
| Change management | 32% | PR governance는 있으나 production change calendar/approval board 없음 |
| Human approval audit | 64% | approval evidence minimum은 있으나 immutable store/retention 없음 |
| Multi-project portfolio management | 58% | `tracker.projects` registry exists, portfolio reporting 없음 |

### 부족한 점

관리/거버넌스는 이 프로젝트의 강점이다. GitHub Project `Status`를 lifecycle source of truth로 삼고, comments/PR/logs/result packet은 evidence surface로 분리한 결정은 회사 운영에 맞다. 일반 사용자와 AI worker가 같은 project board에서 공존하기 위한 Agent, Authorization, Authorized By, Symphony Admission 필드도 합리적이다.

다만 거버넌스가 실제 조직 운영으로 확대되려면 역할과 책임이 더 필요하다. 누가 project schema를 바꿀 수 있는지, 누가 `Authorization=Approved`를 줄 수 있는지, 승인 권한이 만료되면 누가 정리하는지, Human Review 상태가 오래 머물면 어떤 escalation이 일어나는지 정의되어 있지 않다.

Git governance도 잘 되어 있지만 branch protection/ruleset이 실제 GitHub 설정에 적용되어야 강제력이 생긴다. 문서는 필요한 check를 요구하라고 말하지만, 저장소 내부 파일만으로 GitHub ruleset 적용 여부는 보장되지 않는다.

### 발전 방향

1. Project governance matrix를 만든다: project owner, approver, Fire operator, Hammer operator, security reviewer, auditor를 분리한다.
2. GitHub Project field schema를 versioned contract로 만든다: field name, option name, semantic mapping, allowed mutator, rollback path를 기록한다.
3. Human Review SLA를 둔다: 예를 들어 2영업일 이상 Human Review면 reminder, 5영업일이면 Blocked 또는 owner escalation.
4. GitHub ruleset 설정을 코드화한다: Terraform/GitHub CLI script/OPA policy로 branch protection, required checks, review rule을 재현 가능하게 만든다.
5. Closeout reconciliation을 자동화한다: issue Status, PR review/check/merge state, result packet, workpad comment를 비교해 mismatch를 표시한다.

## 로깅 및 관측성

### 현재 완성도

| 세부 파트 | 완성도 | 근거 |
| --- | ---: | --- |
| State API | 72% | `/api/v1/state`, `/api/v1/refresh`, per-issue endpoint 존재 |
| Dashboard | 68% | LiveView dashboard와 terminal dashboard 개념 존재 |
| Worker pool visibility | 70% | workers counts, unavailable reasons, routing metadata 노출 |
| Credential broker visibility | 62% | grant/bundle/event summary와 token fingerprint 노출 |
| Logging conventions | 58% | issue_id, issue_identifier, session_id, routing context 규약 존재 |
| Rotating log file | 55% | `LogFile`이 rotating disk log handler 구성 |
| Metrics backend | 0% | Prometheus/OpenTelemetry metric exporter 없음 |
| Distributed tracing | 0% | trace/span/correlation backend 없음 |
| Alerting | 0% | alert rule, pager, notification sink 없음 |
| Audit export | 0% | immutable audit/event stream/export 없음 |

### 부족한 점

관측성은 “로컬 운영자가 현재 상태를 본다”는 목적에는 쓸 수 있다. `/api/v1/state`는 running/retrying, worker pool, project registry, token totals, rate limits, credential broker summary를 제공한다. logging docs도 issue/session 중심 key=value 로그를 요구한다.

그러나 회사 운영에서는 dashboard가 있어도 alert가 없으면 장애를 놓친다. log file이 있어도 중앙 수집/보존/검색/권한 분리가 없으면 감사와 장애 분석에 약하다. 현재는 Prometheus metric, OpenTelemetry trace, structured JSON log, SIEM export, alertmanager, dashboard history가 보이지 않는다.

또 하나의 문제는 observability endpoint 인증/노출 정책이다. 현재 router는 read-mostly API를 제공하지만, production 환경에서 이 API가 어떤 network boundary, authn/authz, rate limit, data redaction policy 아래 노출되어야 하는지 부족하다.

### 발전 방향

1. Metrics exporter를 추가한다: dispatch attempts, active runs, retry queue, worker availability, GitHub API failures, Codex stalls, token usage, broker denials.
2. Structured JSON logs를 지원한다: issue_id, project_key, session_id, worker_id, provider, attempt, event_type을 필드화한다.
3. Alert rules를 만든다: no workers available, retry queue growth, GitHub auth missing, Project fetch failure, stuck run, broker policy denial spike, dashboard unavailable.
4. OpenTelemetry trace를 최소 도입한다: project poll -> issue admission -> dispatch -> worker run -> result/retry까지 correlation id를 연결한다.
5. Observability API 보안 정책을 둔다: local-only default, auth proxy option, redaction guarantee, no raw token, per-project visibility.

## 운영 안정성 및 SRE

### 현재 완성도

| 세부 파트 | 완성도 | 근거 |
| --- | ---: | --- |
| Retry/backoff | 68% | Orchestrator retry queue와 exponential backoff 존재 |
| Stalled run handling | 60% | codex stall timeout 기반 restart/backoff 존재 |
| Worker health | 55% | SSH health probe와 worker statuses 존재 |
| Manual troubleshooting | 44% | observability docs와 Docker fleet guide에 troubleshooting 존재 |
| Capacity management | 48% | max concurrent agents, per-state/per-host limit 존재 |
| Incident Response | 0% | severity/escalation/postmortem 없음 |
| On-call / Paging / Alerting | 0% | 운영 알림/rota 없음 |
| SLO / SLA | 0% | service objective/error budget 없음 |
| Backup / Restore / DR | 0% | RPO/RTO/restore drill 없음 |
| Production Release / Rollback Runbook | 0% | production 배포/롤백 절차 없음 |

### 부족한 점

SRE 관점에서 현재 구현은 “실패를 완전히 무시하지 않는다”는 점이 좋다. retry, backoff, stalled run, worker health, no capacity 상태가 있다. 하지만 이것들은 service reliability primitives이지 SRE program은 아니다.

회사가 사용하려면 장애가 발생했을 때 누가, 어떤 severity로, 어떤 timeline 안에, 어떤 communication channel로, 어떤 rollback/mitigation을 수행하는지가 필요하다. 현재 저장소에는 incident response, on-call, paging, SLO/SLA, DR 같은 운영 체계가 보이지 않는다.

또한 scheduler state가 in-memory라는 점은 단일 프로세스 장애나 재시작에서 작업 중복/누락 가능성을 만든다. GitHub Project SOT가 있더라도 running lease와 retry timer가 사라지면 동일 issue가 재디스패치될 수 있다. 회사 사용에서는 이것을 허용하더라도 “idempotent worker contract”와 “resume policy”가 필요하다.

### 발전 방향

1. SLO를 작게 시작한다: Fire availability, poll success rate, dispatch latency, stuck-run detection time, worker capacity availability.
2. Incident runbook을 추가한다: SEV0-3, commander, communication, mitigation, rollback, postmortem template.
3. Paging 없이도 alert channel부터 만든다: GitHub issue/comment, Slack/Discord webhook, email 중 하나로 시작한다.
4. Durable lease를 추가한다: issue별 active run id, worker id, lease_until, attempt id를 GitHub comment 또는 DB에 남긴다.
5. DR drill을 정기화한다: workflow config restore, worker registry restore, token store revoke/recreate, project schema export/import, workspace cleanup.

## 컴플라이언스 및 감사

### 현재 완성도

| 세부 파트 | 완성도 | 근거 |
| --- | ---: | --- |
| Evidence model | 78% | worker ticket/result packet/PR governance가 증거 중심 |
| Approval evidence minimum | 72% | approver, action, scope, actor/runtime, expiry 요구 |
| Git auditability | 82% | commit rationale, PR body, submodule gitlink policy |
| Credential broker metadata | 60% | grant/bundle/token fingerprint 개념 존재 |
| Retention policy | 0% | 보존 기간/삭제 정책 없음 |
| Audit export | 0% | 감사 제출용 export format 없음 |
| Control mapping | 0% | SOC2/ISO/internal controls 매핑 없음 |
| Legal hold / data deletion | 0% | 보존 잠금/삭제 요청 처리 없음 |
| Access review cadence | 10% | authorized users config는 있으나 정기 검토 없음 |

### 부족한 점

감사 가능성의 철학은 매우 강하다. Manager memory가 SOT가 아니며, GitHub Project fields, issue comments, PRs, commits, logs, result packet이 evidence surface라는 원칙은 좋다. 하지만 audit program은 evidence를 남기는 것만으로 끝나지 않는다.

현재 부족한 것은 증적의 보존 기간, 저장 위치, 검색/내보내기 방식, 누가 조회 가능한지, 법적 보존 또는 삭제 요청을 어떻게 처리하는지다. credential broker도 token fingerprint와 redaction은 있지만, 감사 이벤트를 immutable sink로 보내는 구조는 보이지 않는다.

컴플라이언스 관점에서는 “이 통제가 어떤 요구사항을 만족하는가”가 필요하다. 예를 들어 SOC2 CC6 access control, CC7 change management, CC8 change management, availability/security criteria 등에 매핑해야 한다.

### 발전 방향

1. Audit event schema를 만든다: approval, dispatch, credential grant, worker start/stop, PR open/review/merge decision, project status transition.
2. Retention policy를 둔다: logs 30/90/365일, audit events 1년 이상, secret material 즉시 삭제 등.
3. Export path를 만든다: JSONL/CSV/Markdown evidence bundle로 issue 단위 감사 패키지를 생성한다.
4. Control mapping 문서를 추가한다: 내부 보안 기준 또는 SOC2/ISO 항목에 Dokkaebi controls를 연결한다.
5. Quarterly access review를 정의한다: Authorized By allowlist, GitHub App installations, worker registry, service units, token stores.

## 제품화 및 사용성

### 현재 완성도

| 세부 파트 | 완성도 | 근거 |
| --- | ---: | --- |
| Manager plugin package | 62% | `plugins/dokkaebi/.codex-plugin/plugin.json`과 5개 skill 존재 |
| Skill coverage | 68% | project-admin, issue-intake, manager-review, fire-ops, hammer-bootstrap |
| Quickstart | 50% | root README와 Fire sandbox runbook 존재 |
| Operator UX | 42% | CLI/API/dashboard는 있으나 admin UI와 guided setup 부족 |
| Install/upgrade UX | 36% | local plugin validation은 있으나 package distribution/upgrade path 부족 |
| Multi-project UX | 46% | `tracker.projects`와 docs는 있으나 project onboarding automation 부족 |
| Human review UX | 40% | process는 있으나 PR/project view를 묶는 review packet UI 없음 |
| Admin API | 30% | observability API는 read-mostly, control API는 제한적 |
| Multi-tenant product boundary | 0% | tenant/project/team isolation model 없음 |

### 부족한 점

`plugins/dokkaebi`는 Manager가 따라야 할 판단 흐름을 제공하는 skill bundle로는 좋다. 그러나 회사 사용자는 “문서와 스킬을 읽고 수동으로 맞추는 시스템”보다 “안전하게 설정하고, 상태를 보고, 승인하고, 복구하는 제품”을 기대한다.

현재는 GitHub Project fields, worker registry, Fire config, credential broker, service unit, GitHub App 권한이 여러 문서에 분산되어 있다. 숙련된 operator는 따라갈 수 있지만 일반 팀이 셀프서비스로 onboarding하기에는 어렵다.

Human Review도 아직 사용자가 PR view, Project view, issue comment, result packet을 오가며 판단해야 한다. Dokkaebi가 review packet을 만들어 도와줄 수는 있지만, 공식 approve는 PR에서 수행해야 한다. 이 차이를 UI/문서/자동 reconcile로 낮춰야 한다.

### 발전 방향

1. Project onboarding wizard를 만든다: Greenfield/Brownfield 선택, field discovery, dry-run, required fields, admission mapping, rollback note.
2. Fire admin CLI/API를 정리한다: project registry validate, worker registry validate, admission diagnose, review packet generate, stuck run reconcile.
3. Human Review packet을 자동 생성한다: PR diff/checks/reviews, result packet, acceptance criteria, risk, recommended decision.
4. Plugin distribution을 정리한다: versioning, changelog, compatibility matrix, install/update/remove guide.
5. 운영자 dashboard를 확장한다: project별 backlog, active runs, blocked reasons, worker health, review queue, stale Human Review.

## 우선순위 로드맵

| Phase | 기간 | 목표 | 주요 산출물 | 완료 기준 |
| --- | --- | --- | --- | --- |
| Phase 0 | 1-2주 | 현 상태를 회사 운영 baseline으로 고정 | readiness report, known gaps, project schema inventory, service inventory | 어떤 환경이 sandbox/staging/prod인지 명확 |
| Phase 1 | 2-4주 | 안전 운영 최소조건 | incident runbook, alert rules, SLO draft, durable lease design, backup inventory | 장애를 사람이 알고 대응할 수 있음 |
| Phase 2 | 4-8주 | 핵심 런타임 강화 | durable scheduler store, reconciliation engine, worker lease, metrics exporter, structured logs | 재시작/장애 후 중복/누락을 통제 |
| Phase 3 | 8-12주 | 보안/감사 패키지 | credential rotation, audit event schema, retention policy, RBAC draft, compliance mapping | 승인/credential/dispatch 감사 가능 |
| Phase 4 | 12-16주 | 프로덕션 배포 체계 | Helm/K8s or systemd prod runbook, release/rollback, staging live E2E, chaos/fault tests | 반복 가능한 release candidate gate |
| Phase 5 | 16주+ | 제품화 | onboarding wizard, admin UI/API, review packet UX, multi-project portfolio reporting | 일반 팀이 독립적으로 적용 가능 |

## 권장 아키텍처 진화

1. **GitHub Project SOT는 유지한다.** GitHub Project `Status`는 사람이 보는 운영판과 AI dispatch를 같은 평면에 묶는 강한 선택이다. 대신 Fire 내부 상태를 durable lease/event로 보강한다.
2. **Dokkaebi Fire를 control plane으로 격상한다.** 단순 poller가 아니라 project registry, worker registry, credential broker, reconciliation, observability, audit export를 담당하는 backend가 되어야 한다.
3. **Dokkaebi Hammer를 provider별 maturity로 나눈다.** local_worktree/SSH는 stable, Docker는 beta, Kubernetes Job은 alpha처럼 수준을 명시하고 route별 요구사항을 다르게 둔다.
4. **승인은 Project와 PR 양쪽을 reconcile한다.** Project의 Human Review는 workflow state, PR Approve는 GitHub merge gate다. Dokkaebi는 두 상태를 합쳐 review packet과 closeout suggestion을 만든다.
5. **운영 증거를 자동 생성한다.** result packet, validation output, logs, broker grants, project transitions를 issue 단위 evidence bundle로 묶는다.

## 논의용 질문

1. 회사 사용의 첫 목표는 “내부 개발팀 파일럿”인가, “프로덕션 운영 자동화”인가? 전자는 Phase 1까지만으로도 가능하지만 후자는 Phase 4까지 필요하다.
2. Fire의 durable store를 GitHub issue/comment 중심으로 둘 것인가, 별도 DB로 둘 것인가? 감사성과 단순성은 GitHub가 좋고, query/performance/lease에는 DB가 좋다.
3. Kubernetes를 핵심 route로 만들 것인가, 고립 실행 옵션으로만 둘 것인가? 핵심 route라면 cluster policy와 Job lifecycle 구현이 우선순위가 된다.
4. Human approval의 공식 표면은 어디인가? GitHub Project field, issue comment command, PR review, external approval system 중 어떤 조합을 표준으로 삼을지 정해야 한다.
5. 감사 증적 보존 기간과 접근 권한은 누가 소유할 것인가? 보안/법무/개발조직의 책임 경계를 정해야 한다.

## 결론

Project Dokkaebi는 회사에서 AI 작업을 관리하기 위한 핵심 철학이 좋다. “도깨비가 사람의 의도를 구조화하고, 도깨비 불이 GitHub Project를 감시하며, 도깨비 방망이가 제한된 작업을 실행한다”는 모델은 실제 조직에 맞게 확장할 수 있다.

다만 지금 상태에서 바로 회사 표준 운영 도구로 쓰려면 위험하다. 핵심 결론은 단순하다. **계약과 거버넌스는 강하고, 런타임은 작동 가능한 수준이며, 기업 운영 체계는 아직 비어 있다.** 다음 발전은 새로운 기능을 많이 붙이는 것보다 SLO, incident, alerting, durable state, audit retention, release/rollback 같은 운영 기본기를 채우는 방향이어야 한다.
