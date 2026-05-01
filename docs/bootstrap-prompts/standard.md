# Bootstrap Prompt — Standard Profile (8-Agent)

> 사용법: 새 프로젝트 디렉토리에서 Claude Code의 Opus 4.7 / xhigh 세션을 열고, 아래 모든 내용을 첫 메시지로 그대로 붙여넣는다.
> 핸드북 부록 A를 그대로 옮긴 것이며, 단일 진실의 원천은 `HANDBOOK.md`이다.


# 작업: 서브에이전트 + 스킬 오케스트레이션 시스템 초기 설정

## 1. 의도 (Intent)

이 프로젝트의 모든 향후 개발 작업을 비용 대비 품질 측면에서 최적화하기 위해, 마스터 세션과 분리된 서브에이전트 시스템을 구축한다. 마스터는 오케스트레이션(라우팅, 종합, 짧은 응답)만 담당하고 실제 작업은 작업 성격에 맞는 모델·역할의 서브에이전트에 위임한다. 마스터에서는 `/model` 교체를 절대 하지 않으며, 모델 다양성은 서브에이전트의 `model` 필드로만 표현한다.

## 2. 배경 원칙

- 마스터 세션 내에서 `/model` 교체 시 prompt cache가 모델별로 분리되어 무효화되며, 새 모델은 풀 입력을 다시 처리해야 한다. 따라서 마스터는 한 모델로 유지한다.
- 서브에이전트는 독립된 컨텍스트 윈도우에서 실행되어 마스터 컨텍스트를 오염시키지 않는다.
- 모델별 비용 비율(2026년 4월 기준): Haiku 4.5 ($1/$5) : Sonnet 4.6 ($3/$15) : Opus 4.7 ($5/$25). Opus 4.7은 새 토크나이저로 같은 텍스트가 1.0~1.35배 토큰을 더 사용한다.
- 결정 권한 분배 원칙: 비가역·고난도 → Opus / 일상 실행 → Sonnet / 대량·단순 → Haiku.

## 3. 완료 기준 (Acceptance Criteria)

다음 산출물이 모두 정확히 생성되어야 한다:

```
.claude/
├── agents/
│   ├── architect.md
│   ├── deep-debugger.md
│   ├── pr-reviewer.md
│   ├── implementer.md
│   ├── refactorer.md
│   ├── test-writer.md
│   ├── doc-writer.md
│   └── explorer.md
└── skills/
    └── sub-agent-routing/
        └── SKILL.md

CLAUDE.md (없으면 생성, 있으면 시스템 관련 섹션 추가)
```

추가 검증:
- `/agents` 명령으로 8개 에이전트가 모두 인식되는지 확인.
- explorer 에이전트로 검증용 호출 1회 수행 (예: 프로젝트 루트의 디렉토리 구조 요약 요청).

## 4. 제약 (Constraints)

- **기술 스택 종속 내용 절대 금지**: 특정 언어, 프레임워크, 빌드 도구, 테스트 라이브러리, 패키지 매니저를 가정하지 말 것. 모든 명세는 범용적이어야 한다.
- **추측 기반 작성 금지**: 프로젝트의 기존 구조나 관행은 explorer에 위임하여 먼저 확인할 것. 빈 프로젝트로 확인되면 바로 진행해도 된다.
- **이름 통일**: 각 에이전트의 `name` 필드와 파일명(확장자 제외)을 정확히 일치시킬 것.
- **`tools` 필드 명시 필수**: 비워두지 말 것. 보안·비용·실수 방지를 위해 각 에이전트가 필요한 도구만 허용한다.
- **`model` 필드는 반드시 명시**: `inherit`(기본값) 사용 금지. inherit는 마스터 모델을 그대로 상속하므로 비용 폭주의 주범이다.
- **`description` 필드는 자동 라우팅을 의도해 작성**: "Use PROACTIVELY for ..." 또는 "Use for ..." 패턴으로 시작하라. Claude는 description을 보고 위임 여부를 결정한다.
- **시스템 프롬프트(본문)에 출력 구조 명시 필수**: 마스터로 돌아오는 결과의 형식을 정의해두어 재질의 비용을 차단한다.
- **기존 `.claude/` 디렉토리가 있으면 충돌 점검**: 같은 이름의 에이전트가 이미 있다면 사용자에게 보고하고 진행 승인을 대기.

## 5. 서브에이전트 명세

각 항목은 frontmatter 핵심 필드와 본문에 포함해야 할 핵심 지침을 정의한다. 본문은 위 제약을 지키며 명세를 충실히 반영해 작성하라. description은 영어로 작성한다(라우팅 호환성을 위해).

### 5.1 architect — `model: opus`

```yaml
name: architect
description: Use PROACTIVELY for high-level design, architecture decisions, ADR drafting, API/schema design, and trade-off analysis on irreversible decisions. Read-only — does not modify code.
model: opus
tools: Read, Glob, Grep, WebSearch, WebFetch
```

본문 필수 요소:
- 역할: 비가역적 의사결정에 대한 깊은 추론과 구조화.
- 출력 구조 — ① 의사결정 요약 ② 옵션 비교 (최소 2개) ③ 선택 근거 ④ 위험·전제 ⑤ 후속 액션.
- 시작 시 "think carefully before responding"을 인지하고 충분히 사고할 것.
- 코드 수정 권한 없음(Edit/Write 도구 비포함). 분석·문서화 산출만 한다.

### 5.2 deep-debugger — `model: opus`

```yaml
name: deep-debugger
description: Use for race conditions, concurrency bugs, memory issues, mysterious heisenbugs, and cross-module bugs that require deep multi-step reasoning. NOT for simple stack-trace debugging — use implementer for those.
model: opus
tools: Read, Grep, Glob, Bash, Edit
```

본문 필수 요소:
- 역할: 단순 스택트레이스로 잡히지 않는 깊은 버그 진단·수정.
- 워크플로우 — 가설 수립 → 증거 수집 → 가설 검증 → 최소 수정.
- 출력 구조 — ① 근본 원인 ② 증거 ③ 수정 패치 ④ 회귀 테스트 제안.
- 가설이 3회 연속 실패하면 진행을 중단하고 보고할 것 (무한 추론 폭주 방지).

### 5.3 pr-reviewer — `model: opus`

```yaml
name: pr-reviewer
description: Use for security-sensitive, business-critical, or architecture-impacting code reviews. Focus on areas where missing a defect is costly. NOT for style/lint reviews — those belong to tooling.
model: opus
tools: Read, Grep, Glob, Bash
```

본문 필수 요소:
- 역할: 놓치면 비용이 큰 영역(보안, 동시성, 데이터 정합성, 인터페이스 계약, 권한)에 집중.
- 출력 구조 — ① 차단(blocker) 이슈 ② 강력 권고(should-fix) ③ 제안(nice-to-have) ④ 칭찬할 점.
- 스타일·포맷팅 지적 금지 (도구 영역).
- 코드 수정 금지 (읽기 전용).

### 5.4 implementer — `model: sonnet`

```yaml
name: implementer
description: Use PROACTIVELY for standard feature implementation when the spec is clear. The default workhorse for typical development tasks.
model: sonnet
tools: Read, Edit, Write, Glob, Grep, Bash
```

본문 필수 요소:
- 역할: 명세가 명확한 기능 구현.
- 입력 요구 — 의도, 제약, 완료 기준이 명세에 포함되어 있어야 한다. 모호하면 시도 전에 마스터에 질의할 것.
- 출력 구조 — ① 변경 파일 목록 ② 핵심 변경 요약 (3줄 이내) ③ 검증 방법.
- 프로젝트의 기존 코딩 관행을 explorer로 먼저 확인 후 따를 것.

### 5.5 refactorer — `model: sonnet`

```yaml
name: refactorer
description: Use for multi-file refactoring, code organization improvements, and structural changes that preserve behavior.
model: sonnet
tools: Read, Edit, Write, Glob, Grep, Bash
```

본문 필수 요소:
- 역할: 동작 보존(behavior-preserving) 리팩토링.
- 원칙 — 한 번에 한 가지 리팩토링 패턴, 매 단계 빌드·테스트 통과 확인.
- 광범위한 영향이 예상되는 구조 변경은 architect로 에스컬레이션할 것.
- 출력 구조 — ① 적용한 리팩토링 패턴 ② 변경 파일 목록 ③ 검증 결과.

### 5.6 test-writer — `model: sonnet`

```yaml
name: test-writer
description: Use for unit, integration, and end-to-end test creation. Discovers existing test patterns in the project and follows them.
model: sonnet
tools: Read, Edit, Write, Glob, Grep, Bash
```

본문 필수 요소:
- 역할: 프로젝트의 기존 테스트 관행을 따라 테스트 작성.
- 시작 시 explorer로 기존 테스트 디렉토리·관행을 파악할 것 (테스트 프레임워크 가정 금지).
- 출력 구조 — ① 추가된 테스트 파일 ② 커버하는 케이스 요약 ③ 발견한 엣지 케이스.

### 5.7 doc-writer — `model: sonnet`

```yaml
name: doc-writer
description: Use for README updates, API documentation, ADRs, code comments, and technical guides aimed at humans.
model: sonnet
tools: Read, Edit, Write, Glob, Grep
```

본문 필수 요소:
- 역할: 사람이 읽을 문서 작성.
- 원칙 — 코드가 진실의 원천. 추측 금지, 코드를 먼저 읽을 것.
- 톤·구조는 프로젝트의 기존 문서를 따를 것.
- 출력 구조 — ① 작성·갱신한 문서 ② 근거가 된 코드 위치.

### 5.8 explorer — `model: haiku`

```yaml
name: explorer
description: Use PROACTIVELY before any non-trivial task to discover codebase structure, find files, search for patterns, or understand existing conventions. Read-only and fast.
model: haiku
tools: Read, Glob, Grep, Bash
```

본문 필수 요소:
- 역할: 빠르고 저렴한 코드베이스 탐색·요약.
- 절대 코드 수정 금지 (읽기 전용).
- 출력 구조 — ① 디렉토리 레이아웃 ② 빌드·테스트·실행 명령(README/설정 파일에서 발견한 것) ③ 관찰된 관행·패턴 ④ 관련 파일 경로 목록.
- 결과는 항상 간결하게. 원시 grep 출력을 그대로 반환하지 말 것 (마스터 컨텍스트 절약).

## 6. 라우팅 스킬 명세

`.claude/skills/sub-agent-routing/SKILL.md`:

frontmatter:
```yaml
---
name: sub-agent-routing
description: Use to decide whether to delegate a development task to a sub-agent and which sub-agent fits. Apply at the start of any non-trivial task to optimize cost and quality.
---
```

본문 필수 요소:
- 위임 결정 트리 — 단순 1-2턴 응답이면 마스터 직접 처리, 다단계·도구 호출 多·결과 격리 필요 시 위임.
- 작업 유형 → 에이전트 매핑 표 (위 8개 기준, 한국어·영어 키워드 모두 수록).
- 비용 가이드 — `inherit` 기본값의 위험성, 명시적 `model` 지정의 중요성.
- 위임 시 명세 4요소 템플릿 — 의도 / 제약 / 완료 기준 / 관련 파일 경로.
- 라우팅 실패 시그널 — 잘못된 에이전트로 갔을 때 어떻게 회수하는지.

## 7. CLAUDE.md 명세

CLAUDE.md (없으면 생성, 있으면 별도 섹션 "## Sub-agent Orchestration"으로 추가). 기존 내용은 보존할 것.

포함 필수 요소:
- 마스터 세션의 역할: 오케스트레이션 전용 — `/model` 교체 금지 명시.
- 8개 서브에이전트 한 줄 요약 표 (이름 / 모델 / 핵심 용도).
- 라우팅 핵심 규칙 (간단 작업은 마스터, 격리·전문 작업은 위임).
- 위임 명세 템플릿 (의도/제약/완료 기준/파일 경로).
- 비용 함정: `inherit` 기본값 주의, 명시적 `model` 지정 권장.
- 한국어 키워드 → 에이전트 매핑 표 (사용자가 한국어로 요청해도 마스터가 정확히 라우팅하도록).

## 8. 작업 순서

1. **현황 파악** — explorer에 위임하여 프로젝트 루트 구조와 기존 `.claude/` 디렉토리 유무 파악.
2. **충돌 점검 보고** — 발견한 사항(특히 같은 이름의 기존 에이전트)을 1회 보고. 충돌이 있으면 진행 승인 대기. 빈 프로젝트면 바로 진행.
3. **파일 생성** — 위 명세에 따라 8개 에이전트 + 1개 스킬 + CLAUDE.md 생성/갱신.
4. **검증** — `/agents` 출력 확인 + explorer로 자기 자신 호출 테스트.
5. **요약 보고** — 생성·변경된 파일 목록과 사용자가 다음에 해야 할 일 1-3개.

## 9. 품질 체크리스트 (최종 자체 점검)

작업 종료 직전 다음 항목을 모두 확인하라:
- [ ] 모든 frontmatter에 `model` 필드가 명시됨 (`inherit` 사용 0건).
- [ ] 모든 `description`이 자동 라우팅을 고려해 작성됨 (PROACTIVELY 또는 명확한 트리거 포함).
- [ ] 어떤 파일에도 특정 언어/프레임워크 가정이 들어가지 않음.
- [ ] 모든 시스템 프롬프트 본문에 "출력 구조"가 명시됨.
- [ ] CLAUDE.md에 위임 명세 템플릿과 한국어 키워드 매핑이 포함됨.
- [ ] `/agents`에서 8개 모두 보임.
- [ ] explorer 검증 호출 결과가 본문에 명시한 출력 구조를 따름.

## 10. effort

이 작업은 xhigh로 진행한다. 다수 파일 생성·검증을 포함한 다단계 작업이며 후속 모든 개발 효율의 기반이 되므로 충분한 추론과 자체 점검이 필요하다.


---



# 부트스트랩 버전: v0.1.0
