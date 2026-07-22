# 변경 이력 (Changelog)

이 저장소(`claude-code-template`)의 버전별 변경 기록이다. 형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 느슨히 따르고 [유의적 버전](https://semver.org/lang/ko/)을 사용한다. 변경의 단일 진실의 원천은 `VERSION`과 `HANDBOOK.md`이며, 이 파일은 그 요약·색인이다.

> 버전 정책: 큰 변경(모델·가격·effort·새 에이전트)은 **minor**, 호환성이 깨지면 **major**. 핸드북 자체에 변경이 있으면 템플릿 버전도 함께 올린다.

---

## [Unreleased]

- (현재 비어 있음 — 다음 변경은 여기 누적)

---

## [v0.5.0] — 2026-07-22 — Fable 5 재검토 반영 (의사결정 가이드 재도입)

v0.3.0에서 접근 제한으로 철회했던 **Fable 5** 가이드를 재검토해 재도입한 사이클 — v0.4.0 Notes의 "별도 사이클에서 접근성·비용·'Opus 위 티어' 배치를 재검토한다" 예고를 회수한다. 미국 수출통제(2026-06-12)로 중단됐던 접근이 06-30 해제·07-01 재배포를 거쳐 **07-20 Max·Team Premium 플랜 정식 편입**(주간 한도의 50%, Pro는 크레딧+$100 1회)으로 안정됐고, 재배포 후 실사용 데이터가 쌓여 근거 기반 재검토가 가능해졌다. 핵심 결론: **8개 에이전트 default 무변경** — Fable 5는 §5.4의 수동 에스컬레이션 전용으로 편입하되, 마스터의 "세션 시작 시 선택"은 개방한다.

### Added — 추가
- **핸드북 §5.4 재도입·전면 갱신**: "상위 능력이 필요할 때 — Opus effort↑ vs Fable 5". 철회 전(PR #4) 버전 대비 갱신점 — ① **`fable` 별칭 공식 지원**(Claude Code v2.1.170+, 철회 전 "별칭 없음"은 stale 정정), ② **Max·Team Premium 정식 편입** 메모(비용 계산은 표준 API $10/$50 기준 유지 + 플랜 관점 병기 — 구독 사용자는 달러 비용 대신 한도 소모가 실질 비용), ③ **금지선 갱신** — 보안 리뷰(pr-reviewer) 금지 신설(안전 분류기가 방어적 보안 감사까지 오탐 + refusal 시 Opus 4.8 자동 폴백 → 한도만 더 쓰고 사실상 Opus 결과), 마스터는 "도중 교체 금지 유지·**시작 시 선택 개방**"으로 완화(Fable 이득이 장기 자율·병렬 오케스트레이션에 집중 + 분업 구조가 2× 소모와 상보적), ④ **Fable 고유 제약 요약**(thinking 상시 on·prefill 불가·30일 보존·fast mode 미지원·캐시 최소 2048토큰·과잉 처방 프롬프트 지양).
- **모델 레이어 편입**: §3.1 모델 표 Fable 행($10/$50, 기본추천 Opus 4.8 유지 명시), §3.2(Opus 4.8과 동일 토크나이저 — 이동 시 토큰 재계량 불필요), §3.3(1M 목록), §4.1(effort 표 5행 + Fable 메모 — 전 레벨 지원·기본 high·thinking 파라미터 생략), §4.4(적응형 추론 상시 on 계약), §5.1 매트릭스 메모("어떤 행도 Fable로 치환 안 됨"), 부록 D 용어집(Fable 5·Mythos 5), 부록 E 출처(공식 문서 5종 + 근거 3줄, 공식/관찰 구분).
- **부트스트랩 §2에 Fable 비배정 명시** (standard·lite ×2 + 부록 A 동기화) — 부트스트랩 산출물이 Fable을 에이전트에 배정하지 않도록 가드.

### Unchanged — 의도적으로 그대로 둔 것
- **8개 에이전트 default·3원칙·아키텍처 골격**: architect·deep-debugger·pr-reviewer = Opus 4.8, Sonnet·Haiku 티어 불변, `model`·`effort` frontmatter 무수정. 근거 — Fable의 이득은 길고 복잡한 자율 작업에 집중되고(SWE-bench Pro 80.3% vs 69.2%, 공식) 격리된 단일 호출(서브에이전트)은 격차가 작은 영역인데(관찰) 단가는 2×. pr-reviewer는 위 분류기 오탐·자동 폴백 때문에 승격 실익이 음수.
- **§12.1**(마스터 세션 도중 `/model` 교체 금지 — 캐시 보호)과 **§8.2** 부트스트랩 권장(Opus 4.8/high).
- **README.en.md**: 버전·가격·모델명 미포함 정책으로 무변경(per-cycle churn 0).

### Notes — 근거 (공식/관찰 구분)
- 공식 확인: $10/$50·1M/128K·Opus 4.8과 동일 토크나이저·effort 전 레벨(기본 high)·thinking 상시 on·`fable` 별칭·refusal 시 Opus 4.8 자동 폴백(설정 가능)·SWE-bench Pro 80.3% vs 69.2%·07-20 플랜 편입.
- 실사용 관찰(커뮤니티, 2026-07): 짧고 스코프 명확한 작업에서 격차 축소, 응답 60초~수분(vs Opus 3~15초), 인가된 방어적 보안 감사·SSH/iptables/syscall 용어 오탐 보고. 관찰은 본문에 "관찰"로 표기해 공식 사실과 구분.

### Maintenance — 유지관리
- `VERSION` v0.4.0 → v0.5.0. 7개 버전 스탬프 정합(VERSION·HANDBOOK 첫 줄·README·부트스트랩 ×2·CLAUDE.md ×2). `scripts/sync.sh --check` → OK(`shared/` 무변경 — default 불변이므로 에이전트 원본 불변).
- `docs/maintenance-guide.md`: §1 아래 **"새 티어 메모" 재도입·확장**(기존 family 위 새 티어 = 경량 추가 원칙 + "접근 정책 유동기엔 [Unreleased], 안정 후 minor 승격" 교훈), §7에 **사이클 3 결과** 추가(철회-재도입 왕복이 "default 무변경·단독 bump 없음" 정책의 회수 가능성을 실증, 재도입 시 이전 문서 사실 명제 전수 재검증 교훈).
- **리뷰 반영**: 부록 A §2 라인의 v0.4.0 유래 드리프트(Sonnet 괄호구 누락) 정합 — 부록 A와 `docs/bootstrap-prompts/standard.md`의 해당 라인이 다시 byte-identical. `best` 별칭에 공식 근거 라벨 부여, §5.4의 §2.3 인용을 §8.2 단독으로 정밀화.

---

## [v0.4.0] — 2026-07-01 — Claude Sonnet 5 반영

2026-06-30 출시된 **Claude Sonnet 5**를 반영한 두 번째 모델 유지관리 사이클(T1). 아키텍처와 **Opus 티어는 그대로 두고**, Sonnet 티어의 모델·가격·토크나이저·effort 레이어만 갱신했다. `model: sonnet` 별칭이 Claude Code 기본값으로 Sonnet 5를 가리키므로 **에이전트 파일은 한 줄도 바뀌지 않았다**(family alias 자동 승격). 핵심은 모델명 치환이 아니라 **새 토크나이저(~30%)·적응형 추론 기본 ON·xhigh 지원 편입 + stale 사실 정정**이다.

### Changed — 바뀜
- **Sonnet 티어 이전**: `model: sonnet` 별칭 → **Sonnet 5**(Claude Code 기본값). implementer·refactorer·test-writer·doc-writer가 파일 수정 없이 자동 승격. Sonnet 4.6은 "직전 Sonnet"으로 재배치. 배정 티어(3원칙)는 불변.
- **가격**: Sonnet 5 표준 **$3/$15**(4.6과 동일), 2026-08-31까지 **인트로 $2/$10**. 핸드북 §1.1·§3.1·§5·§11.5·부록 A와 부트스트랩 가격 줄 갱신.
- **§3.2 토크나이저 일반화**: "새 토크나이저 = Opus 4.7+ 전용"에서 **"Opus 4.7 이후 + Sonnet 5"**로 확장. Sonnet 5는 4.6 대비 **~30% 토큰 증가**(공식 확인), Sonnet 4.6·Haiku 4.5는 구 토크나이저(무인플레). drop-in 교체지만 토큰 재계량·`max_tokens` 절단 주의 명시.

### Added — 추가
- **effort 표(§4.1)에 Sonnet 5**: low/medium/high/xhigh/max 지원 — **xhigh 신규 획득**(4.6은 미지원). 기본 effort **high**(공식 확인).
- **적응형 추론(§4.4)에 Sonnet 5 편입**: Sonnet 5는 적응형 추론 **기본 ON**(4.6은 OFF), 수동 extended thinking 제거(400), 비기본 sampling 파라미터 400, Priority Tier 미지원 — Opus 4.8과 같은 계약.
- **출처(부록 E)**: Sonnet 5 공식 문서 3종(What's new·소개·마이그레이션 가이드)과 토크나이저·effort 근거 줄 추가. 용어집(xhigh·적응형 추론·1M)에 Sonnet 5 반영.

### Unchanged — 의도적으로 그대로 둔 것
- **아키텍처 골격·Opus 티어**: architect·deep-debugger·pr-reviewer = Opus 4.8 유지(비가역·보안·최고난도 추론은 Anthropic도 Opus 우위로 명시). 마스터 Opus 4.8/high 유지, 8개 역할 분담·3원칙·위임 4요소 불변.
- **에이전트 frontmatter**: `model` 별칭·Opus 3개의 `effort` 필드 무수정. effort 필드는 여전히 **Opus 에이전트에만** 부여(정책 유지 — Sonnet 에이전트는 기본값 사용).
- **범위**: 전략 가이드 보강(Sonnet 마스터 비용 레버·에스컬레이션 기준·Opus 호출 비율 지표)과 Sonnet 에이전트 effort 필드 도입은 이번 사이클 제외.

### Fixed — 정정
- **§4.5 stale 사실**: "Sonnet·Haiku 에이전트에서는 effort가 무시된다"는 Sonnet 5부터 오류 → "Sonnet 5는 effort를 지원하나 본 템플릿은 기본값(적응형 추론 ON) 사용"으로 정정(정책은 유지, 사실만 수정).

### Notes — 관찰 (미채택)
- **Fable 5**: 공식 모델 개요에 `claude-fable-5`가 GA로 노출됨($10/$50, "가장 유능한 널리 공개된 모델"). v0.3.0에서 접근 제한으로 철회했던 상태와 상충하나, 이번 Sonnet 5 사이클 범위 밖 — 별도 사이클에서 접근성·비용·"Opus 위 티어" 배치를 재검토한다.

### Maintenance — 유지관리
- `VERSION` v0.3.0 → v0.4.0. 7개 버전 스탬프 정합(VERSION·HANDBOOK 첫 줄·README·부트스트랩 ×2·CLAUDE.md ×2). `scripts/sync.sh --check` → OK(`shared/` 무변경 — 별칭만 쓰므로 에이전트 원본 불변).
- `docs/maintenance-guide.md`: **모델 사이클 표본 n=1 → n=2**로 갱신. §7에 "사이클 2 결과" 추가 — cadence "4주 이내" 2회 연속 준수 기록, "같은-family T1이 토크나이저·thinking 기본값 변화를 동반할 수 있다"는 새 관찰과 T1 체크리스트 항목 권고.
- `README.en.md`: 버전·가격·모델명 미포함 정책으로 **무변경**(per-cycle churn 0).

---

## [v0.3.0] — 2026-06-14 — 토큰 절감 레퍼런스 검토 반영 + 영어 진입점

외부 토큰 절감 레퍼런스 10종을 검토해 **0-인프라로 채택 가능한 원리만** 핸드북에 흡수한 콘텐츠 사이클(트리거 T6/T7). 모델·effort·아키텍처는 v0.2.0(Opus 4.8) 그대로다.

### Added — 추가
- **토큰 절감 레버 2종 (핸드북 §11)**: ① §11.7 '도구·명령 출력 컴팩션' — 시끄러운 bash/test/build/툴 출력을 마스터 컨텍스트에 넣기 전 필터·추출(§11.3이 *서브에이전트* 산출물을 다룬다면 이 레버는 *도구* 산출물). ② §11.8 '컨텍스트 위생' — 자동 로드 표면 최소화·무거운 산출물 참조화·완료 작업 아카이브(§11.4 캐싱과 상보). "비용 레버 여섯 가지" → "여덟 가지"로, §11 TOC에 잔존하던 "다섯 가지" 표기도 정정.
- **§14.3에 토큰 절감 MCP 후보 명시**: 대형 코드베이스에서 §11.7·§11.8을 자동화할 외부 MCP 후보(Code Review Graph, Context Mode, Claude Context)를 출처·의존성·비용 주의와 함께 추가. 환경 내장 LSP·ast_grep 우선 확인 권고 병기. 템플릿 무번들 원칙은 유지(도구는 프로젝트가 선택적으로 마운트).
- **영어 진입점 (i18n)**: `README.en.md`(한 화면 분량 영어 개요)를 추가하고 `README.md` 상단에 `[English] | 한국어` 전환 링크를 둠. 한국어 문서가 canonical로 유지되며, 영어판에는 버전·가격·모델명을 넣지 않아 per-cycle churn 0. (v0.2.0 사이클에 작성, 이번 릴리즈에 동봉.)

### Removed — 제거
- **Fable 5 의사결정 가이드 (철회)**: `[Unreleased]` 초안에 경량 추가했던 Fable 5(`claude-fable-5`, Opus 위 티어) 의사결정 가이드를 철회. 2026-06 미국 정부의 접근 제한으로 사용 불가가 되어 정식 반영 전 원복 — `HANDBOOK.md` §3.1·§4.1·§5.1·§5.4 및 `docs/maintenance-guide.md` T1 메모를 pre-Fable 상태로. 정식 릴리즈에 포함된 적은 없으며, 철회 사실만 기록으로 남긴다.

### Notes — 검토했으나 미채택 (근거)
외부 토큰 절감 레퍼런스 10종 검토 결과, 다음은 의도적으로 반영하지 않았다:
- **token-optimizer-mcp** (ooples): 메커니즘·벤치마크 문서가 부재해 95% 절감 주장을 검증 불가 — 보류.
- **외부 바이너리·프록시 동봉(RTK 등) / 벡터 검색 인프라(Claude Context의 Milvus+임베딩)**: 복사 기반·무번들 정체성과 충돌. 원리는 §11.7에, 도구는 §14.3 '선택적 후보'로만 반영.
- **Caveman 풀 'caveman voice'**: 출력 토큰은 줄지만 한국어 전문 문서 톤·마스터의 종합 책무(§9.4)와 충돌. 간결성 *원리*는 이미 §11.3·§9.4에 존재.
- **CLAUDE.md 간결성 규칙 세트**(claude-token-efficient 등): 이번 사이클 보류 — CLAUDE.md는 캐시 민감(§11.4)이고 핵심 규칙이 이미 존재. 추후 1회성 안정 추가로 재검토 가능.
- **이미 충분히 커버됨**: Token Savior(심볼 탐색) = 환경 LSP/ast_grep, Token Optimizer(델타 재독·스켈레톤) = §11.2 explorer-first.

### Maintenance — 유지관리
- `VERSION` v0.2.0 → v0.3.0. 7개 버전 스탬프 정합 확인. `scripts/sync.sh --check` → OK(`shared/` 무변경).
- `docs/maintenance-guide.md`: 콘텐츠 사이클(T6/T7)이라 모델 cadence 표본은 1회로 유지 — §2·§7의 "v0.3.0에서 재조정" 예고를 "다음 모델 사이클"로 정정(cadence 재조정은 다음 T1에서).

---

## [v0.2.0] — 2026-05-30 — Claude Opus 4.8 반영

2026-05-28 출시된 **Claude Opus 4.8**을 반영한 첫 유지관리 사이클. 아키텍처는 그대로 두고 **모델·effort 배정 레이어**만 갱신하고 4.8 신기능을 편입했다. 모델명 일괄 치환이 아니라 **effort 기본값 하향 + 신규 비용 레버 편입**이 핵심이다.

### Changed — 바뀜
- **모델 이전**: 마스터와 Opus 에이전트(`architect`·`deep-debugger`·`pr-reviewer`)를 Opus 4.7 → **Opus 4.8**로. 표준 가격은 불변($5 / $25 per MTok). 4.7은 "직전 플래그십"으로 재배치.
- **effort 기본값 하향**: Opus 4.8 기본 effort가 **high**로 내려옴(4.7은 xhigh). 4.8은 같은 effort로 더 좋은 결과를 내므로 가성비 매트릭스·부트스트랩 권장 effort를 한 단계 낮춤(예: 아키텍처 xhigh→high). 부트스트랩 세션 권장: "Opus 4.7 / xhigh" → **"Opus 4.8 / high"** (어려운 부트스트랩만 xhigh).
- **토크나이저**: Opus 4.8은 4.7과 **동일 토크나이저**(같은 텍스트 최대 35% 토큰 증가)를 쓴다 — 문서 표기를 "Opus 4.7 이후(4.8 포함)"로 정리.

### Added — 추가
- **서브에이전트 `effort` frontmatter 필드 채택**: 공식 지원으로 확인되어 Opus 에이전트에 명시 — `architect`·`deep-debugger` = `high`, `pr-reviewer` = `xhigh`. Opus 4.8+에서만 적용되고 Sonnet/Haiku 에이전트에는 부여하지 않음. 구버전·폴백 대비로 본문 시스템 프롬프트 백스톱 지시도 병행.
- **신규 비용/지연 레버**: 핸드북 11장에 **fast mode**($10 / $50, 2.5× 속도; 이전 세대 대비 3× 저렴) 추가 → "비용 레버 다섯 가지"가 "여섯 가지"로. **dynamic workflows / `ultracode`** 분기를 §10.4 대형 리팩토링에 편입(수동 8-에이전트 라우팅의 보완, 대체 아님). **대화 도중 `system` 항목**과 **1,024토큰 캐시 최소값**을 캐싱 절(§11.4)에 반영.
- **배치 가격 갱신**: Opus 4.8 배치 **$2.50 / $12.50**(공식 확인).
- **관찰 갱신**: "low effort 4.8 ≈ max effort 4.7"(SWE-Bench Pro, 시스템 카드 Fig 8.2.A). 정직성 향상(코드 결함을 그냥 넘기는 비율 4.7 대비 약 4× 감소), 툴 트리거 개선.
- **변경 이력 체계**: 이 `CHANGELOG.md` 신설 + README 상단 "최근 업데이트" 콜아웃.

### Unchanged — 의도적으로 그대로 둔 것
- 아키텍처 골격: 마스터 오케스트레이션, 8개 역할 분담, 격리된 컨텍스트, 캐시 보호(마스터 `/model` 교체 금지), Haiku 우선 탐색, 명시적 `model` 필드, 위임 4요소 템플릿.
- Sonnet·Haiku 배정과 3원칙(비가역=Opus / 일상=Sonnet / 대량=Haiku). "Opus 4.8/low가 Sonnet/high보다 싸면서 낫다"는 행은 없음(4.8은 $5/$25 + 토크나이저 인플레이션, Sonnet은 $3/$15).

### Maintenance — 유지관리
- `VERSION` v0.1.0 → v0.2.0. 7개 버전 스탬프 정합 확인. `scripts/sync.sh --check` → OK(`shared/` 무변경).
- `docs/maintenance-guide.md`를 사이클-1 학습으로 보완: 영향 파일 매핑 빈틈(README·`effort` 필드) 반영, "변경 이력 갱신" 절차 단계 추가, worked example 추가.

> 자세한 근거·맥락: `HANDBOOK.md` §3(모델·가격), §4(effort), §5(가성비 매트릭스), §11(비용 레버).

---

## [v0.1.0] — 2026-04 — 최초 릴리즈

- Claude Opus 4.7 기준 서브에이전트 오케스트레이션 템플릿 초판.
- 구성: 핸드북(5부 + 5개 부록), `lite`(3 에이전트)·`standard`(8 에이전트) 프로필, 부트스트랩 프롬프트, 라우팅 스킬, 유지관리 가이드, `scripts/sync.sh`.
