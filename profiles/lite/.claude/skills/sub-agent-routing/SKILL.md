---
name: sub-agent-routing
description: Use to decide whether to delegate a development task to a sub-agent and which sub-agent fits. Apply at the start of any non-trivial task to optimize cost and quality.
---

# Sub-agent Routing (Lite — 3-에이전트 셋업)

마스터가 사용자 요청을 받았을 때 **위임 여부와 대상**을 결정하는 절차. 비자명 작업의 시작점에서 자동 활성화.

이 lite 프로필은 표준 8-에이전트의 부분집합(explorer + implementer + test-writer)이다. 나머지 영역은 마스터가 직접 처리한다.

## 1. 위임 결정 트리

```
요청 도착
   │
   ├─ 한두 줄로 답할 수 있는 질문?         → 마스터 직접 처리
   ├─ 빠른 사실 확인?                      → 마스터 직접 처리
   ├─ 코드 탐색·구조 파악 필요?            → explorer
   ├─ 명세 명확한 기능 구현·단순 버그 수정? → implementer
   ├─ 단위·통합·E2E 테스트 작성?           → test-writer
   └─ 그 외 (아키텍처·복잡 버그·리팩토링·문서·보안 리뷰) → 마스터 직접 처리
```

## 2. 작업 유형 → 에이전트 매핑 (3-에이전트)

| 작업 유형 | 한국어 키워드 | 에이전트 | 모델 |
|---|---|---|---|
| 코드 탐색·검색 | "어디 있어?", "찾아줘", "구조 알려줘" | explorer | haiku |
| 표준 기능 구현·단순 버그 | "구현해줘", "기능 추가", "고쳐줘" | implementer | sonnet |
| 단위·통합·E2E 테스트 | "테스트 작성", "단위 테스트" | test-writer | sonnet |
| 그 외 (설계, race, 리뷰, 리팩토링, 문서) | — | **마스터 직접** | (마스터 모델) |

## 3. 마스터 직접 처리 영역 (lite 전용)

이 lite 프로필에서는 다음 작업이 에이전트가 아닌 **마스터에서 직접** 처리된다:

- **아키텍처 결정·ADR**: 마스터가 ADR 초안 작성. 결정 경계가 크면 standard 승격 검토.
- **단순 PR/코드 리뷰**: 마스터 직접 (보안·핵심 영역이 아니라면).
- **복잡 버그 (race·동시성·heisenbug)**: 마스터가 직접 시도. 가설 3회 실패 시 standard 승격.
- **다중 파일 리팩토링**: 마스터 직접 또는 작업을 쪼개서 implementer 반복 호출.
- **문서 작업 (README, 주석, ADR)**: 마스터 직접.
- **보안·핵심 PR 리뷰**: 마스터 직접 또는 standard 승격.

이 영역에서 작업이 누적되면 `docs/profile-selection.md`의 변경 신호 표를 참조해 standard 승격을 검토.

## 4. 비용 가이드

- `model: inherit`(frontmatter 기본값) **금지**. 마스터가 Opus면 inherit 에이전트도 Opus가 되어 비용 4배.
- 새 에이전트를 추가할 때마다 `model` 필드를 명시했는지 점검.
- explorer를 거의 모든 비자명 작업의 첫 호출로 사용 (Haiku, 5배 저렴).

## 5. 위임 명세 4요소 템플릿

서브에이전트에 보내는 메시지는 4요소를 모두 포함해야 한다.

```
의도: [무엇을 왜]
제약: [지켜야 할 것 / 건드리면 안 될 것]
완료 기준: [무엇이 되면 끝인가]
관련 파일: [경로 목록 또는 "explorer로 먼저 확인"]
```

## 6. 라우팅 실패 시그널과 회수

- **마스터가 모든 걸 직접 처리한다**: description 키워드가 약함. 한국어 표현을 보강.
- **잘못된 에이전트로 갔다**: description 트리거 충돌. "NOT for ..." 부정 트리거 추가.
- **결과가 장황하다**: 해당 에이전트 본문의 출력 구조 지시를 강화.

## 7. 명시적 호출

자동 라우팅이 신뢰가 안 가면 `@explorer`, `@implementer`, `@test-writer` 형식으로 강제 호출.
