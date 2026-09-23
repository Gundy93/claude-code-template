**[English](README.en.md)** | 한국어

# claude-code-template

Claude Code 프로젝트의 시작점. 신규 프로젝트는 이 템플릿에서 프로필을 골라 복사해 시작한다.

**현재 버전**: v1.0.0

## 📌 최근 업데이트 (v1.0.0 — 2026년 9월, 멀티세션 TDD 플러그인·핸드북 제6부)

- **opt-in 플러그인 `multisession-tdd`**: 이슈마다 워크트리와 마스터 세션을 두고, 별도의 검토 세션이 게이트마다 판정한다. GATE-1 승인 뒤 테스트는 **훅이 동결**한다. 설치는 아래 "선택: 멀티세션 TDD 플러그인".
- **핸드북 제6부 멀티세션**(15~20장, 선택): 왜·언제 세션을 나누는가.
- **lite·standard 프로필과 제1~5부는 무변경**(1.0의 근거는 아래 "버전 정책").

→ 전체 이력: [`CHANGELOG.md`](CHANGELOG.md) · 배경·근거: [`HANDBOOK.md`](HANDBOOK.md) 제6부

## 무엇이 들어 있는가

- **`HANDBOOK.md`** — 서브에이전트 + 스킬 오케스트레이션 핸드북. 단일 진실의 원천.
- **`CHANGELOG.md`** — 버전별 변경 이력 (무엇이·왜 바뀌었는가).
- **`profiles/lite/`** — 단명·소규모 사이드 프로젝트용 경량 셋업 (3개 에이전트).
- **`profiles/standard/`** — 핸드북 풀셋업 (8개 에이전트 + 검증 강도 라우팅 스킬).
- **`docs/`** — 프로필 선택 기준, 부트스트랩 프롬프트, [유지관리 가이드](docs/maintenance-guide.md) (신모델 출시 시 업데이트 절차).
- **`shared/`** — 두 프로필 공통 자산 (유지관리용).
- **`scripts/sync.sh`** — shared/ → profiles/ 동기화 스크립트 (유지관리용).
- **`plugins/multisession-tdd/`** — 선택 설치하는 멀티세션 TDD 플러그인. 저장소 루트의 `.claude-plugin/marketplace.json`이 이 저장소를 플러그인 마켓플레이스로 만든다.

## 빠른 시작 — 두 가지 경로

### 경로 1 — 복사 기반 (기본 권장)

```bash
cd ~/development/new-project
cp -r ~/development/claude-code-template/profiles/standard/. .
# 또는 lite 셋업:
# cp -r ~/development/claude-code-template/profiles/lite/. .
```

profiles/ 디렉토리는 미리 베이크된 부트스트랩 산출물이다. 복사 즉시 `.claude/`가 동작한다. Opus 호출 비용·시간 0.

### 경로 2 — 부트스트랩 프롬프트 (커스터마이즈·재생성용)

```bash
cd ~/development/new-project
# Claude Code의 Opus 5.5 세션을 effort high로 열고: claude --effort high (어려운 부트스트랩만 xhigh)
# docs/bootstrap-prompts/standard.md (또는 lite.md) 내용을 첫 메시지로 붙여넣기
```

도메인 특화 에이전트 추가 등 변형이 필요할 때 사용. 핸드북 §8 권장 방식.

### 선택: 멀티세션 TDD 플러그인

이슈 여러 개를 세션 단위로 동시에 굴린다면 프로필과 별개로 플러그인을 켠다. Claude Code 세션에서:

```
/plugin marketplace add Gundy93/claude-code-template
/plugin install multisession-tdd@claude-code-template
```

언제 쓸 만한지는 핸드북 제6부, 설정과 빠른 시작은 [`plugins/multisession-tdd/README.md`](plugins/multisession-tdd/README.md).

## 프로필 선택 기준 (요약)

| 신호 | Lite | Standard |
|---|---|---|
| 단일 사이클 완결 | ✓ | |
| 1,000줄 이하 또는 핵심 파일 5개 이하 | ✓ | |
| UI·통합 중심 | ✓ | |
| 협업자 1명 이하 | ✓ | |
| 6개월 이상 유지 | | ✓ |
| 도메인 로직이 두꺼움 | | ✓ |
| 보안·동시성·정합성 핵심 | | ✓ |
| 외부 사용자 접근 (웹 앱·공개 API) | | ✓ |
| 협업자 2명 이상 | | ✓ |

세부 기준과 경계 사례, lite ↔ standard 전환 레시피는 [`docs/profile-selection.md`](docs/profile-selection.md).

## 결정이 어렵다면

다음 두 질문으로 판단:

1. **"이 프로젝트가 6개월 후에도 굴러가야 하는가?"** → Yes면 standard.
2. **"이 프로젝트의 버그가 다른 사람에게 비용을 만드는가?"** → Yes면 standard.

둘 다 No면 lite로 시작. 신호가 누적되면 [전환 레시피](docs/profile-selection.md#5-lite--standard-전환-레시피)로 승격.

## 핸드북부터 읽고 싶다면

[`HANDBOOK.md`](HANDBOOK.md) — 6부 + 5개 부록(제6부 멀티세션은 선택). 시간이 없다면 부록 A의 부트스트랩 프롬프트만 봐도 시작 가능.

## 버전 정책

- VERSION 파일이 단일 진실의 원천 (현재 `v1.0.0`).
- 핸드북·프로필·부트스트랩 프롬프트·플러그인(`plugin.json`의 `version`)이 같은 버전을 공유.
- 큰 변경 시에만 마이너 증가, 호환성 깨질 때만 메이저 증가.
- v1.0.0은 호환성을 깬 버전이 아니라 **다른 사람이 의존할 공개 인터페이스가 처음 생긴 버전**이다(유의적 버전에서 0.x는 초기 개발 단계). v1.0.0부터 **플러그인 이름·스킬 이름·저장소 설정 파일 스키마·프로필의 파일 구조**를 공개 인터페이스로 보고, 이것을 깨는 변경은 메이저다.
- 핸드북 자체에 변경이 있으면 템플릿 버전도 함께 올린다.

## 변경 이력

버전별 전체 변경 기록은 [`CHANGELOG.md`](CHANGELOG.md)에 있다. 최신 요약은 위 "📌 최근 업데이트" 참조.

## 디렉토리 구조

```
claude-code-template/
├── README.md                    # 이 파일
├── README.en.md                 # 영문 README
├── CHANGELOG.md                 # 버전별 변경 이력
├── HANDBOOK.md                  # 핸드북 사본 (단일 진실의 원천)
├── VERSION                      # v1.0.0
├── .claude-plugin/
│   └── marketplace.json         # 이 저장소를 플러그인 마켓플레이스로 등록
├── docs/
│   ├── profile-selection.md     # 경량 vs 표준 결정 기준
│   ├── maintenance-guide.md     # 새 모델·핸드북 업데이트 절차
│   └── bootstrap-prompts/
│       ├── lite.md              # 경량 셋업 프롬프트
│       └── standard.md          # 표준 셋업 프롬프트
├── profiles/
│   ├── lite/                    # 3-에이전트 경량 셋업 (복사용)
│   └── standard/                # 8-에이전트 풀셋업 (복사용)
├── plugins/
│   └── multisession-tdd/        # 선택 설치 플러그인 (스킬·에이전트·훅·스크립트·테스트)
├── shared/                      # 두 프로필 공통 원본 (유지관리용)
└── scripts/
    └── sync.sh                  # shared/ → profiles/ 동기화 (유지관리용)
```

## 라이선스·기여

이 템플릿은 개인 사용을 위해 작성되었다. 자유롭게 포크·수정.
