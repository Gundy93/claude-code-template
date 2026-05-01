# Maintenance Guide — 새 모델·핸드북 업데이트 시 수정 가이드

> **이 가이드는 v0.1.0 초안이다.** 트리거 분류·영향 파일은 안정적이지만, cadence·임계값은 잠정값이다 — 실제 업데이트를 1~2번 거친 뒤 v0.2.0에서 보완한다.

## 0. 핵심 통찰 — 무엇이 자동으로 따라오고 무엇이 안 따라오는가

에이전트 frontmatter의 `model: opus / sonnet / haiku`는 **family alias**다. Claude Code가 현재 디폴트(Opus 4.7, Sonnet 4.6, Haiku 4.5)로 자동 해석한다. **신모델이 나와도 에이전트 파일들은 거의 건드릴 필요가 없다**.

업데이트 부담은 주로 **버전·가격·effort·고유명을 명시한 텍스트**에 집중된다:
- `HANDBOOK.md` (§3 가격, §3.2 토크나이저, §4 effort, §3.1 모델 표)
- `docs/bootstrap-prompts/*.md` (§2 배경 원칙, §10 effort)
- `profiles/*/CLAUDE.md` (모델명 등장 부분)
- `README.md` (현재 버전·정책 문장)

이 사실이 이 가이드의 실용적 토대다.

---

## 1. 업데이트 트리거 (어떤 일이 생겼을 때 업데이트하는가)

| ID | 트리거 | 예시 | 우선순위 |
|---|---|---|---|
| T1 | 같은 family의 신 모델 stable 출시 | Opus 4.8 | **major** |
| T2 | 모델 deprecation·sunset 공지 | Opus 4.6 sunset | **critical** |
| T3 | 새 effort 레벨 추가 | xhigh가 4.7에서 도입됐던 것처럼 | major |
| T4 | 가격·토크나이저 변경 | $/MTok 조정 또는 새 토크나이저 | major |
| T5 | Claude Code / sub-agent의 새 도구·feature | `memory: project` 같은 신규 frontmatter 필드 | minor |
| T6 | 핸드북 자체의 새 버전 발행 | 핸드북 §11에 새 비용 레버 추가 등 | minor~major |
| T7 | Anthropic 공식 best-practices 업데이트 | 모델 사용 권장값 변경 | minor |

### "지금은 업데이트하지 않는다" 신호 (anti-pattern)

- 모델이 **preview/beta**로 공개되었지만 stable이 아님
- 가격이 **한시적 프로모션**
- effort 레벨이 **베타 라벨**로 표시됨
- best-practices 글이 **draft·preview** 상태
- 단순 typo 수정 — 다음 minor에 묶어 처리

---

## 2. Cadence (언제 업데이트하는가)

| 우선순위 | 권장 cadence | 잠정값 근거 |
|---|---|---|
| critical (T2) | sunset 일자 **2주 전까지** 완료 | sunset 후에도 코드는 동작하지만 비용·정책 위험 |
| major (T1·T3·T4) | stable 출시 **4주 이내** | 너무 일찍 옮기면 회귀, 너무 늦으면 새 효율 못 누림 |
| minor (T5·T7) | **분기별 일괄** 처리 | 자잘한 변동을 매번 따라가면 캐시 무효화 부담 |
| 선택 (T6) | 핸드북 영향 범위에 따라 분류 후 위 규칙 적용 | — |

**cadence는 v0.1.0 잠정값**이다. 실제 운영 후 v0.2.0에서 조정.

---

## 3. 영향 파일 매핑 (트리거 → 어떤 파일을 건드리는가)

| 트리거 | 반드시 수정 | 검토 필요 | 거의 안 건드림 |
|---|---|---|---|
| T1 신 모델 | HANDBOOK.md §3, bootstrap-prompts/*.md §2 | profiles/*/CLAUDE.md (모델명) | agents/*.md (family alias) |
| T2 deprecation | HANDBOOK.md §3·§13.2, bootstrap-prompts/*.md §2 | profiles/*/CLAUDE.md, README.md | agents/*.md |
| T3 새 effort | HANDBOOK.md §4·부록 D, bootstrap-prompts/*.md §10 | profiles/*/CLAUDE.md (effort 언급 시) | agents/*.md |
| T4 가격 변경 | HANDBOOK.md §3 | bootstrap-prompts/*.md §2 | agents/*.md |
| T5 새 도구·feature | HANDBOOK.md §14, 가능하면 신규 에이전트 명세 | profiles/standard/.claude/agents/* (선택 도입) | — |
| T6 핸드북 새 버전 | HANDBOOK.md 전체 | 위 모든 파일 cross-check | — |
| T7 best-practices | HANDBOOK.md (해당 절), CLAUDE.md (안내문) | bootstrap-prompts/*.md | — |

**주의**: `shared/agents/*.md`를 수정했으면 반드시 `scripts/sync.sh` 실행. `--check`로 drift 검증.

---

## 4. 업데이트 절차

```
1) Diff
   - 새 핸드북(또는 Anthropic 공지) ↔ 현재 HANDBOOK.md
   - diff를 §1 트리거 분류로 매핑

2) 수정
   - §3 영향 파일 매핑에 따라 파일 단위로 변경
   - shared/ 수정 시 ./scripts/sync.sh

3) 버전 결정 (사용자 §3.6 정책)
   - 호환성 깨짐 (필드 제거, 에이전트 삭제 등) → major (v0.1.0 → v1.0.0)
   - 큰 변경 (모델·가격·effort·새 에이전트 추가) → minor (v0.1.0 → v0.2.0)
   - 자잘한 문서 보완 → 다음 minor에 묶음

4) 버전 스탬프 갱신 (7곳)
   - VERSION, HANDBOOK.md 첫 줄, README.md, 두 bootstrap-prompts, 두 CLAUDE.md
   - 일괄 치환: sed/grep으로 검증
   - grep -rn "v<NEW>" --include="*.md" --include=VERSION → 7개 파일에서 매칭 확인

5) 검증
   - ./scripts/sync.sh --check  → drift 없음
   - bootstrap prompts §3 트리 == profiles 실제 트리 (동일 검사 둘 다)
   - agents frontmatter에 inherit 0건
   - architect tools에 Edit/Write 미포함 (standard)
   - deep-debugger 본문에 "가설 3회" 명시 (standard)

6) (선택) 부트스트랩 동등성 테스트
   - 빈 디렉토리에서 docs/bootstrap-prompts/standard.md를 Opus에 실행
   - 결과를 profiles/standard/와 diff
   - frontmatter·도구·model은 정확 일치, 본문 문장 차이는 수용
```

---

## 5. 버전 부여 예시 (감을 잡기 위한 케이스)

| 변경 | 버전 |
|---|---|
| 핸드북 §3 모델 표에 Opus 4.8 1행 추가, bootstrap §10 effort 권장값 갱신 | minor (v0.1.0 → v0.2.0) |
| 새 에이전트 `security-auditor` 추가 (도메인 특화, §14.2 가이드) | minor |
| architect `tools`에서 WebSearch 제거 (외부 영향) | **major** (호환성 깨짐) |
| 검증 강도 라우팅에 4번째 라벨 도입 (예: [Manual]) | minor |
| HANDBOOK.md typo 수정 1건 | 다음 minor에 묶음 (단독 bump 안 함) |
| 모델 deprecation에 따라 family alias 디폴트가 자동 변경됐을 뿐 | (Anthropic 측 변경) — 가격·effort 변동이 동반되면 minor |

---

## 6. 호환성 정책 — 기존 프로젝트는 자동 업데이트되지 않는다

복사 기반 워크플로우의 본질적 비용:
- `cp -r profiles/standard/. <new-project>/` 후, 그 프로젝트는 템플릿과 분리됨
- 템플릿 v0.2.0이 나와도 기존 프로젝트는 v0.1.0 그대로

기존 프로젝트가 새 버전 혜택을 받으려면 **세 가지 선택지**:
1. **수동 diff/merge** — `diff -r` 로 변경된 파일만 식별, 의도된 차이를 보존하면서 머지.
2. **선택적 복사** — 변경 영향 큰 파일만 (예: HANDBOOK.md, bootstrap-prompts) 덮어쓰기.
3. **재 부트스트랩** — 새 버전의 `docs/bootstrap-prompts/standard.md`를 Opus 4.X에 실행 (Opus 호출 비용 발생).

신규 프로젝트는 항상 최신 템플릿을 받는다.

---

## 7. 진화 노트 — v0.2.0에서 보완할 것

이 가이드 자체가 미숙한 영역이 있다. 첫 업데이트 사이클을 거친 후 다음을 검토:
- §2 cadence 임계값이 실제 운영에서 맞았는가?
- §3 영향 파일 매핑에서 빠진 파일이 있었는가?
- §5 버전 부여 예시를 더 추가할 수 있는가?
- 부트스트랩 동등성 테스트(§4-6)를 자동화할 가치가 있는가?
- 호환성 정책(§6)에 마이그레이션 스크립트를 더할 가치가 있는가?

---

> 이 가이드는 핸드북 §14 "시스템 진화시키기"의 정신을 따른다 — **점진적으로 손보되, 매 변경 후 검증한다**.
