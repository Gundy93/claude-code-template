# Bootstrap Prompt — Lite Profile (3-Agent)

> 사용법: 새 프로젝트 디렉토리에서 Claude Code의 Opus 4.7 / high 세션을 열고, 아래 모든 내용을 첫 메시지로 그대로 붙여넣는다.
> 표준 부트스트랩(`standard.md`)의 부분집합이며, 사이드 프로젝트·단명 프로젝트용 경량 셋업이다.

---

# 작업: 경량 서브에이전트 + 스킬 오케스트레이션 시스템 초기 설정 (Lite)

## 1. 의도 (Intent)

이 프로젝트의 모든 향후 개발 작업을 비용 대비 품질 측면에서 최적화하기 위해, 마스터 세션과 분리된 **3-에이전트 경량 서브에이전트 시스템**을 구축한다. 마스터는 오케스트레이션과 직접 처리(아키텍처·복잡 버그·리뷰·문서 등)를 담당하고, 표준 작업(탐색·구현·테스트)만 서브에이전트에 위임한다. 마스터에서는 `/model` 교체를 절대 하지 않으며, 모델 다양성은 서브에이전트의 `model` 필드로만 표현한다.

이 lite 셋업은 표준 8-에이전트 셋업의 의도적인 부분집합이다. 프로젝트 범위가 커지거나 회귀 위험이 누적되면 standard로 승격한다.

## 2. 배경 원칙

- 마스터 세션 내에서 `/model` 교체 시 prompt cache가 모델별로 분리되어 무효화되며, 새 모델은 풀 입력을 다시 처리해야 한다. 따라서 마스터는 한 모델로 유지한다.
- 서브에이전트는 독립된 컨텍스트 윈도우에서 실행되어 마스터 컨텍스트를 오염시키지 않는다.
- 모델별 비용 비율(2026년 4월 기준): Haiku 4.5 ($1/$5) : Sonnet 4.6 ($3/$15) : Opus 4.7 ($5/$25).
- 결정 권한 분배 원칙: 비가역·고난도 → 마스터 직접(또는 standard 승격) / 일상 실행 → Sonnet 에이전트 / 대량·단순 → Haiku 에이전트.

## 3. 완료 기준 (Acceptance Criteria)

다음 산출물이 모두 정확히 생성되어야 한다:

```
.claude/
├── agents/
│   ├── explorer.md
│   ├── implementer.md
│   └── test-writer.md
└── skills/
    └── sub-agent-routing/
        └── SKILL.md

CLAUDE.md (마스터 직접 처리 영역 명시 포함)
```

추가 검증:
- `/agents` 명령으로 3개 에이전트가 모두 인식되는지 확인.
- explorer 에이전트로 검증용 호출 1회 수행 (예: 프로젝트 루트의 디렉토리 구조 요약 요청).

## 4. 제약 (Constraints)

- **기술 스택 종속 내용 절대 금지**: 특정 언어, 프레임워크, 빌드 도구, 테스트 라이브러리, 패키지 매니저를 가정하지 말 것.
- **추측 기반 작성 금지**: 프로젝트의 기존 구조나 관행은 explorer에 위임하여 먼저 확인할 것.
- **이름 통일**: 각 에이전트의 `name` 필드와 파일명(확장자 제외)을 정확히 일치.
- **`tools` 필드 명시 필수**: 각 에이전트가 필요한 도구만 허용한다.
- **`model` 필드는 반드시 명시**: `inherit` 사용 금지.
- **`description` 필드는 자동 라우팅을 의도해 작성**: "Use PROACTIVELY for ..." 또는 "Use for ..." 패턴.
- **시스템 프롬프트 본문에 출력 구조 명시 필수**.
- **기존 `.claude/` 디렉토리가 있으면 충돌 점검**: 같은 이름 에이전트가 있다면 사용자 승인 대기.

## 5. 서브에이전트 명세 (3개)

### 5.1 explorer — `model: haiku`

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
- 결과는 항상 간결하게. 원시 grep 출력을 그대로 반환하지 말 것.

### 5.2 implementer — `model: sonnet`

```yaml
name: implementer
description: Use PROACTIVELY for standard feature implementation when the spec is clear. The default workhorse for typical development tasks.
model: sonnet
tools: Read, Edit, Write, Glob, Grep, Bash
```

본문 필수 요소:
- 역할: 명세가 명확한 기능 구현·단순 버그 수정.
- 입력 요구 — 의도, 제약, 완료 기준이 명세에 포함되어 있어야 한다. 모호하면 시도 전에 마스터에 질의.
- 출력 구조 — ① 변경 파일 목록 ② 핵심 변경 요약 (3줄 이내) ③ 검증 방법.
- 시작 시 explorer로 프로젝트 코딩 관행을 1회 파악.

### 5.3 test-writer — `model: sonnet`

```yaml
name: test-writer
description: Use for unit, integration, and end-to-end test creation. Discovers existing test patterns in the project and follows them.
model: sonnet
tools: Read, Edit, Write, Glob, Grep, Bash
```

본문 필수 요소:
- 역할: 프로젝트의 기존 테스트 관행을 따라 테스트 작성.
- 시작 시 explorer로 기존 테스트 디렉토리·관행 파악 (테스트 프레임워크 가정 금지).
- 출력 구조 — ① 추가된 테스트 파일 ② 커버하는 케이스 요약 ③ 발견한 엣지 케이스.

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
- 위임 결정 트리 — 단순 1-2턴 응답이면 마스터 직접, 다단계·도구 호출 多·결과 격리 필요 시 위임.
- 작업 유형 → 에이전트 매핑 (3-에이전트 표; 그 외 작업은 "마스터 직접 처리" 또는 standard 승격).
- 비용 가이드 — `inherit` 기본값의 위험성, 명시적 `model` 지정의 중요성.
- 위임 명세 4요소 템플릿 — 의도 / 제약 / 완료 기준 / 관련 파일 경로.
- **마스터 직접 처리 영역 섹션** — 아키텍처·복잡 버그·PR 리뷰·리팩토링·문서 작업이 lite에서는 마스터로 간다는 점 명시.

## 7. CLAUDE.md 명세 (Lite 전용)

CLAUDE.md (없으면 생성, 있으면 별도 섹션 "## Sub-agent Orchestration"으로 추가). 기존 내용은 보존.

포함 필수 요소:
- 마스터 세션의 역할: 오케스트레이션 + 표준 외 영역 직접 처리. `/model` 교체 금지 명시.
- 3개 서브에이전트 한 줄 요약 표 (이름 / 모델 / 핵심 용도).
- **마스터 직접 처리 영역 명시 섹션** — 아키텍처·deep-debugger·pr-reviewer·refactorer·doc-writer 영역이 lite에서는 마스터 직접.
- **Standard 승격 신호 1줄** — "이 영역에서 작업이 누적되면 docs/profile-selection.md 변경 신호 표 참조."
- 라우팅 핵심 규칙 (간단 작업은 마스터, 위 3개 영역은 위임, 그 외는 마스터 직접).
- 위임 명세 템플릿 (의도/제약/완료 기준/파일 경로).
- 비용 함정: `inherit` 기본값 주의, 명시적 `model` 지정 권장.
- 한국어 키워드 → 에이전트 매핑 표 (3행 + "그 외 → 마스터 직접 처리").

## 8. 작업 순서

1. **현황 파악** — explorer에 위임하여 프로젝트 루트 구조와 기존 `.claude/` 디렉토리 유무 파악.
2. **충돌 점검 보고** — 발견한 사항을 1회 보고. 충돌이 있으면 진행 승인 대기.
3. **파일 생성** — 위 명세에 따라 3개 에이전트 + 1개 스킬 + CLAUDE.md 생성/갱신.
4. **검증** — `/agents` 출력 확인 + explorer로 자기 자신 호출 테스트.
5. **요약 보고** — 생성·변경된 파일 목록과 사용자가 다음에 해야 할 일 1-3개.

## 9. 품질 체크리스트 (최종 자체 점검)

- [ ] 모든 frontmatter에 `model` 필드가 명시됨 (`inherit` 사용 0건).
- [ ] 모든 `description`이 자동 라우팅을 고려해 작성됨.
- [ ] 어떤 파일에도 특정 언어/프레임워크 가정이 들어가지 않음.
- [ ] 모든 시스템 프롬프트 본문에 "출력 구조"가 명시됨.
- [ ] CLAUDE.md에 위임 4요소 템플릿과 한국어 키워드 매핑이 포함됨.
- [ ] CLAUDE.md에 **마스터 직접 처리 영역**이 명시됨.
- [ ] CLAUDE.md에 standard 승격 신호 참조가 있음.
- [ ] `/agents`에서 3개 모두 보임.
- [ ] explorer 검증 호출 결과가 본문에 명시한 출력 구조를 따름.

## 10. effort

이 작업은 **high**로 진행한다. 표준 부트스트랩보다 작업량이 적어 xhigh는 불필요. 단, 파일 생성·검증은 충실히 수행.

---

# 부트스트랩 버전: v0.1.0
