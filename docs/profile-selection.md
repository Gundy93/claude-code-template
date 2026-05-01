# Profile Selection — 경량 vs 표준 결정 기준

신규 프로젝트 시작 시 `profiles/lite/`와 `profiles/standard/` 중 어느 쪽을 복사할지 결정하는 기준.

## 1. 경량(Lite) 프로필을 선택하는 신호

다음 중 **3개 이상** 해당하면 lite를 권장한다:

- 단일 사이클로 완결되는 프로젝트 (한 차례 만들고 검증 후 마무리).
- **도메인 로직 핵심 파일 5개 이하** 또는 **전체 예상 코드량 1,000줄 이하**.
  - (단일 지표가 아닌 이중 지표 — 프레임워크에 따라 보일러플레이트 비율이 다르므로.)
- 도메인 로직보다 UI/통합이 중심 (랜딩 페이지, 마케팅 사이트, 단순 CRUD).
- 검증 후 폐기 또는 다른 프로젝트로 흡수될 가능성이 높음.
- 협업자 1명 이하.

## 2. 표준(Standard) 프로필을 선택하는 신호

다음 중 **3개 이상** 해당하면 standard를 권장한다:

- 다중 사이클 운영 (지속적으로 기능 추가·개선·유지보수).
- 도메인 로직이 두꺼움 (비즈니스 규칙·계산·정합성 보장이 핵심).
- 회귀 위험이 누적되는 영역 (한 번 깨지면 다른 곳도 깨질 수 있음).
- 보안/동시성/데이터 정합성이 핵심.
- **외부 사용자가 실제 접근하는 서비스** (웹 앱, 공개 API). 보안 리뷰·아키텍처 결정의 실용적 필요성이 즉시 발생.
- 협업자 2명 이상.
- 6개월 이상 유지될 예정.

## 3. 경계 사례 — 변형 셋업

명확히 한쪽으로 떨어지지 않는 경계 사례에는 부분 변형이 가능:

### 3-A. "단명하지만 검증 데이터의 신뢰도가 중요"한 경우
- 예: 랜딩 페이지인데 A/B 테스트·분석 데이터의 정확도가 사업 결정에 영향.
- 권장: **경량 + test-strategy-routing 스킬만 추가**. 검증 강도 라우팅을 통해 핵심 데이터 처리 부분만 [TDD]로 갈 수 있게 함.
- 추가 절차: `profiles/standard/.claude/skills/test-strategy-routing/`을 lite 프로젝트의 `.claude/skills/`로 복사.

### 3-B. "경량이지만 1회성 아키텍처 결정이 필요"한 경우
- 예: 단일 사이클이지만 통신 프로토콜 결정(REST vs WebSocket)이 한 번 있는 경우.
- 권장: **경량 + architect 단발 호출**. architect 에이전트를 영구 설치하지 않고, 결정 시점에 마스터에서 `@architect` 형식으로 명시 호출하거나, standard에서 architect 명세만 임시 복사 후 사용.

### 3-C. "프로토타입에서 시작해 빠르게 standard로 넘어갈 가능성"이 큰 경우
- 권장: **처음부터 standard**. lite에서 standard로 전환하는 비용보다 처음부터 풀셋업이 저렴.

## 4. 프로필 변경 신호 — 경량에서 표준으로 승격

lite로 시작했지만 다음 신호가 누적되면 standard로 승격을 검토한다:

| 신호 | 임계 |
|---|---|
| deep-debugger급 버그 (race·메모리·heisenbug) 발생 | **2회 이상** |
| 같은 모듈을 revisit | **3회 이상** (아키텍처 리뷰 필요 신호) |
| 한 사이클에서 TDD 라우팅 이슈가 연속 발생 | **3개 이상** (회귀 위험 누적) |
| 보안·정합성 영역(인증·세션·결제·권한) 변경 | **자주 발생** |
| 협업자 합류 | **2명 이상이 됨** |
| 유지 기간 예상이 늘어남 | **6개월 초과** |
| 외부 사용자가 접근하기 시작함 | 발생 즉시 |

## 5. Lite ↔ Standard 전환 레시피

lite에서 standard로 승격하기로 결정한 시점에 다음 5단계를 수행한다:

```
1. profiles/standard/.claude/agents/ 에서 lite에 없는 5개를
   (architect, deep-debugger, pr-reviewer, refactorer, doc-writer)
   현재 프로젝트의 .claude/agents/로 복사.

2. profiles/standard/.claude/skills/test-strategy-routing/ 디렉토리를
   현재 프로젝트의 .claude/skills/로 복사.

3. profiles/standard/.claude/skills/sub-agent-routing/SKILL.md 의
   에이전트 매핑 표(8행)로 현재 SKILL.md를 덮어쓰기.

4. CLAUDE.md 의 "마스터 직접 처리 영역" 섹션 제거,
   8-에이전트 요약 표·라우팅 규칙으로 교체 (profiles/standard/CLAUDE.md 참조).

5. /agents 로 8개 인식 확인. explorer 검증 호출 1회.
```

전환이 정확히 동작하려면 lite와 standard의 공통 부분(explorer/implementer/test-writer 본문, sub-agent-routing 헤더 구조)이 정말 동일해야 한다. 이를 위해 두 프로필은 `shared/agents/` 의 동일 원본을 참조한다.

## 6. 결정이 어려울 때

위 신호 카운트가 애매하면 다음 두 질문으로 판단:

1. **"이 프로젝트가 6개월 후에도 굴러가야 하는가?"** → Yes면 standard 권장.
2. **"이 프로젝트의 버그가 다른 사람에게 비용을 만드는가?"** (사용자, 동료, 외부 시스템) → Yes면 standard 권장.

둘 다 No면 lite로 시작해도 안전. 운영 중 신호가 누적되면 §5 전환 레시피로 승격.

---

> 이 문서는 핸드북 §5 매트릭스, §14 진화 가이드를 기반으로 한다.
