# claude-code-template

Claude Code 프로젝트의 시작점. 신규 프로젝트는 이 템플릿에서 프로필을 골라 복사해 시작한다.

**현재 버전**: v0.1.0

## 무엇이 들어 있는가

- **`HANDBOOK.md`** — 서브에이전트 + 스킬 오케스트레이션 핸드북. 단일 진실의 원천.
- **`profiles/lite/`** — 단명·소규모 사이드 프로젝트용 경량 셋업 (3개 에이전트).
- **`profiles/standard/`** — 핸드북 풀셋업 (8개 에이전트 + 검증 강도 라우팅 스킬).
- **`docs/`** — 프로필 선택 기준, 부트스트랩 프롬프트, [유지관리 가이드](docs/maintenance-guide.md) (신모델 출시 시 업데이트 절차).
- **`shared/`** — 두 프로필 공통 자산 (유지관리용).
- **`scripts/sync.sh`** — shared/ → profiles/ 동기화 스크립트 (유지관리용).

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
# Claude Code의 Opus 4.7 / xhigh 세션을 열고
# docs/bootstrap-prompts/standard.md (또는 lite.md) 내용을 첫 메시지로 붙여넣기
```

도메인 특화 에이전트 추가 등 변형이 필요할 때 사용. 핸드북 §8 권장 방식.

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

[`HANDBOOK.md`](HANDBOOK.md) — 5부 + 5개 부록. 시간이 없다면 부록 A의 부트스트랩 프롬프트만 봐도 시작 가능.

## 버전 정책

- VERSION 파일이 단일 진실의 원천 (현재 `v0.1.0`).
- 핸드북·프로필·부트스트랩 프롬프트가 같은 버전을 공유.
- 큰 변경 시에만 마이너 증가, 호환성 깨질 때만 메이저 증가.
- 핸드북 자체에 변경이 있으면 템플릿 버전도 함께 올린다.

## 디렉토리 구조

```
claude-code-template/
├── README.md                    # 이 파일
├── HANDBOOK.md                  # 핸드북 사본 (단일 진실의 원천)
├── VERSION                      # v0.1.0
├── docs/
│   ├── profile-selection.md     # 경량 vs 표준 결정 기준
│   └── bootstrap-prompts/
│       ├── lite.md              # 경량 셋업 프롬프트
│       └── standard.md          # 표준 셋업 프롬프트
├── profiles/
│   ├── lite/                    # 3-에이전트 경량 셋업 (복사용)
│   └── standard/                # 8-에이전트 풀셋업 (복사용)
├── shared/                      # 두 프로필 공통 원본 (유지관리용)
└── scripts/
    └── sync.sh                  # shared/ → profiles/ 동기화 (유지관리용)
```

## 라이선스·기여

이 템플릿은 개인 사용을 위해 작성되었다. 자유롭게 포크·수정.
