# 변경 이력 (Changelog)

이 저장소(`claude-code-template`)의 버전별 변경 기록이다. 형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 느슨히 따르고 [유의적 버전](https://semver.org/lang/ko/)을 사용한다. 변경의 단일 진실의 원천은 `VERSION`과 `HANDBOOK.md`이며, 이 파일은 그 요약·색인이다.

> 버전 정책: 큰 변경(모델·가격·effort·새 에이전트)은 **minor**, 호환성이 깨지면 **major**. 핸드북 자체에 변경이 있으면 템플릿 버전도 함께 올린다.

---

## [Unreleased]

- (현재 비어 있음 — 다음 변경은 여기 누적)

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
