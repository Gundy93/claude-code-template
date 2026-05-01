---
name: test-strategy-routing
description: Use during issue decomposition (master planning stage) to assign verification strategy labels (TDD/Review/None) to each issue. Apply when breaking down work into issues, not when executing tasks.
---

# Test Strategy Routing — 검증 강도 라우팅

이슈를 분해할 때 각 이슈에 검증 전략 라벨을 부여한다. **활성화 시점은 마스터 플래닝 단계** — 이슈 분해 시점이지, 작업 실행 시점이 아니다.

## 1. 라벨 정의

| 라벨 | 의미 |
|---|---|
| **[TDD]** | 테스트 우선 작성 후 구현. test-writer → implementer 순서. |
| **[Review]** | 멀티 에이전트 리뷰 + 핵심 로직 핀포인트 단위 테스트. implementer → pr-reviewer (+ 일부 test-writer). |
| **[None]** | 검증 작업 없음. 셋업·환경 변수·boilerplate. implementer 단독. |

## 2. 라벨 부여 기준

### [TDD] 신호
- 결정적 입출력 (같은 입력 → 같은 출력)
- 회귀 위험이 누적되는 영역 (한 번 깨지면 다른 곳도 깨짐)
- 엣지 케이스를 사전 열거 가능
- mock 비용이 낮음 (외부 의존 적음)

### [Review] 신호
- UI 렌더링·시각적 확인이 더 빠름
- 외부 서비스 호출 (API, DB, 메시지 큐)
- 디자인·가독성 종속
- mock 비용이 결정적 입출력 가치보다 큼

### [None] 신호
- 일회성 셋업 (디렉토리 생성, 의존성 설치)
- 환경 변수·설정 파일 추가
- boilerplate (자동 생성으로 충분)

## 3. 재라우팅 트리거 (라벨 결정 후 작업 중 발견되면 라벨 교체)

| 초기 라벨 | 재라우팅 조건 | 새 라벨 |
|---|---|---|
| [TDD] | 구현 중 외부 의존성·UI 결합이 발견되어 mock 비용이 결정적 입출력 가치보다 큼 | [Review] |
| [TDD] | 엣지 케이스가 사실상 무한해 열거 불가능 (자유 텍스트, 시각적 레이아웃 등) | [Review] |
| [Review] | 같은 모듈에서 회귀가 2회 이상 발생 → 핀포인트 단위 테스트가 부족 | [TDD] |
| [Review] | 외부 호출 영역이 표준 프로토콜로 좁혀져 결정적 입출력으로 격리 가능 | [TDD] |
| [None] | 셋업 영역에 검증 가능한 변환 로직이 추가됨 (단순 환경 변수 → 파싱·매핑 함수) | [TDD] |
| [None] | 셋업이 정합성 보장 영역(권한·세션·결제 키)을 건드림 | [Review] |

## 4. 라벨 결정 워크플로우 (이슈 분해 시)

```
이슈 도착
   │
   ├─ "검증 가능한 변환 로직이 있는가?"
   │     ├─ 아니오 → [None]
   │     └─ 예 ↓
   │
   ├─ "결정적 입출력이고 mock 비용 낮음?"
   │     ├─ 예 → [TDD]
   │     └─ 아니오 ↓
   │
   └─ [Review]
```

## 5. 사용 패턴 예시

- **신규 도메인 함수 추가**: 결정적 입출력, 엣지 케이스 열거 가능 → [TDD]
- **외부 API 통합 화면**: UI + 외부 호출 → [Review]
- **CI 환경 변수 추가**: 검증 가능 로직 없음 → [None]
- **인증 미들웨어 변경**: 정합성 보장 영역 → [Review]
- **CSV 파싱 함수**: 결정적 입출력, mock 거의 불필요 → [TDD]

## 6. sub-agent-routing과의 차이

| 측면 | sub-agent-routing | test-strategy-routing |
|---|---|---|
| 활성화 시점 | 작업이 들어올 때마다 | 마스터 플래닝 단계 (이슈 분해 시) |
| 결정 대상 | 누구에게 위임할지 | 어떤 검증 강도로 갈지 |
| 출력 | 에이전트 이름 | 라벨 ([TDD]/[Review]/[None]) |

두 스킬은 **순차적으로** 작동한다 — 먼저 test-strategy-routing이 이슈에 라벨을 붙이고, 작업 실행 단계에서 sub-agent-routing이 어떤 에이전트로 보낼지 결정한다.
