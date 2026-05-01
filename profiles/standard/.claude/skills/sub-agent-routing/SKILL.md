---
name: sub-agent-routing
description: Use to decide whether to delegate a development task to a sub-agent and which sub-agent fits. Apply at the start of any non-trivial task to optimize cost and quality.
---

# Sub-agent Routing (8-에이전트 표준 셋업)

마스터가 사용자 요청을 받았을 때 **위임 여부와 대상**을 결정하는 절차. 비자명 작업의 시작점에서 자동 활성화.

## 1. 위임 결정 트리

```
요청 도착
   │
   ├─ 한두 줄로 답할 수 있는 질문?  → 마스터 직접 처리
   ├─ 빠른 사실 확인?              → 마스터 직접 처리
   ├─ 다단계 도구 호출 필요?        → 위임
   ├─ 결과가 길어 마스터 컨텍스트를 더럽힐 가능성? → 위임
   ├─ Opus급 깊은 추론이 필요한 단일 분야 작업?    → 위임 (해당 Opus 에이전트)
   └─ 같은 패턴을 반복할 가능성?    → 위임 (학습 비용을 한 번에)
```

## 2. 작업 유형 → 에이전트 매핑

| 작업 유형 | 한국어 키워드 | 에이전트 | 모델 |
|---|---|---|---|
| 아키텍처·ADR·API 설계 | "설계해줘", "ADR 써줘", "트레이드오프" | architect | opus |
| 동시성·메모리·heisenbug | "race", "동시성", "이상한 버그", "메모리 누수" | deep-debugger | opus |
| 보안·핵심 PR 리뷰 | "리뷰해줘" + 보안/핵심 맥락 | pr-reviewer | opus |
| 표준 기능 구현·단순 버그 | "구현해줘", "기능 추가", "고쳐줘" | implementer | sonnet |
| 다중 파일 리팩토링 | "리팩토링", "정리", "구조 개선" | refactorer | sonnet |
| 단위·통합·E2E 테스트 | "테스트 작성", "단위 테스트" | test-writer | sonnet |
| 문서·주석·가이드 | "문서 정리", "README 갱신", "주석" | doc-writer | sonnet |
| 코드 탐색·검색 | "어디 있어?", "찾아줘", "구조 알려줘" | explorer | haiku |

## 3. 비용 가이드

- `model: inherit`(frontmatter 기본값) **금지**. 마스터가 Opus면 inherit 에이전트도 Opus가 되어 비용 4배.
- 새 에이전트를 추가할 때마다 `model` 필드를 명시했는지 점검.
- explorer를 거의 모든 비자명 작업의 첫 호출로 사용 (Haiku, 5배 저렴).

## 4. 위임 명세 4요소 템플릿

서브에이전트에 보내는 메시지는 4요소를 모두 포함해야 한다.

```
의도: [무엇을 왜]
제약: [지켜야 할 것 / 건드리면 안 될 것]
완료 기준: [무엇이 되면 끝인가]
관련 파일: [경로 목록 또는 "explorer로 먼저 확인"]
```

## 5. 라우팅 실패 시그널과 회수

- **잘못된 에이전트로 갔다**: description 트리거 충돌. 가장 일반적인 에이전트(implementer, explorer)의 description을 좁히고 "NOT for ..." 부정 트리거 추가.
- **모든 걸 마스터가 직접 처리한다**: description 키워드가 약함. 한국어 표현을 보강.
- **결과가 장황하다**: 해당 에이전트 본문의 출력 구조 지시를 강화.
- **Opus 호출이 30%를 넘는다**: 라우팅이 잘못됨. 표준 작업이 Opus 에이전트로 흘러가는지 점검.

## 6. 명시적 호출

자동 라우팅이 신뢰가 안 가면 `@architect`, `@implementer` 형식으로 강제 호출. 학습 초기에 자주 쓰면 라우팅 패턴 체득에 도움.
