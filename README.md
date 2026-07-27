**[English](README.en.md)** | 한국어

# claude-code-template

Claude Code 프로젝트의 시작점. 신규 프로젝트는 이 템플릿에서 프로필을 골라 복사해 시작한다.

**현재 버전**: v0.6.0

## 📌 최근 업데이트 (v0.6.0 — 2026년 7월, Claude Opus 5 반영)

- **Opus 티어 이전**: `model: opus` 별칭이 **Opus 5**로 자동 승격(Claude Code v2.1.219+). **단가($5/$25)가 4.8과 같고 토크나이저도 같은 세대**라 티어 배정 근거와 토큰 예산은 그대로 — 8개 에이전트 파일의 `model`·`effort`도 무변경. 단 **단가가 같다고 청구서가 같지는 않다**: thinking 기본 ON·길어진 산출물·늘어난 위임이 사용량을 올리는 방향이다.
- **행동 변화 대응 운영 지침 신설**: Opus 5는 자체 검증을 알아서 하고, 위임을 4.8보다 **과하게** 하며, 응답·산출물이 길고 작업 범위를 넓힌다. 이에 맞춰 §9.2 위임 상한과 §12.9~§12.11(과잉검증·장황함·범위 확장) 함정을 추가했다. **검증 지시는 고쳐 쓰지 말고 삭제**가 정답이다.
- **effort 권장 방향 전환**: 4.7·4.8의 "코딩·에이전틱이면 xhigh에서 시작"이 Opus 5에서는 **"기본값 high에서 시작"**으로 바뀌었다(low·medium을 비용 레버로 적극 활용).
- **전 문서 정합성 감사**: 캐시 최소 토큰(Opus 5는 512로 절반)·fast mode 지원 범위·토크나이저 인용의 stale 사실을 정정했다.

→ 전체 이력: [`CHANGELOG.md`](CHANGELOG.md) · 배경·근거: [`HANDBOOK.md`](HANDBOOK.md) §3~5·§9·§11~12

## 무엇이 들어 있는가

- **`HANDBOOK.md`** — 서브에이전트 + 스킬 오케스트레이션 핸드북. 단일 진실의 원천.
- **`CHANGELOG.md`** — 버전별 변경 이력 (무엇이·왜 바뀌었는가).
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
# Claude Code의 Opus 5 / high 세션을 열고 (어려운 부트스트랩만 xhigh)
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

- VERSION 파일이 단일 진실의 원천 (현재 `v0.6.0`).
- 핸드북·프로필·부트스트랩 프롬프트가 같은 버전을 공유.
- 큰 변경 시에만 마이너 증가, 호환성 깨질 때만 메이저 증가.
- 핸드북 자체에 변경이 있으면 템플릿 버전도 함께 올린다.

## 변경 이력

버전별 전체 변경 기록은 [`CHANGELOG.md`](CHANGELOG.md)에 있다. 최신 요약은 위 "📌 최근 업데이트" 참조.

## 디렉토리 구조

```
claude-code-template/
├── README.md                    # 이 파일
├── CHANGELOG.md                 # 버전별 변경 이력
├── HANDBOOK.md                  # 핸드북 사본 (단일 진실의 원천)
├── VERSION                      # v0.6.0
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
