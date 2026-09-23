# multisession-tdd

이슈 하나를 **워크트리 하나 + 마스터 세션 하나**로 맡기고, 별도의 **검토 세션**이 게이트마다 판정하는 멀티세션 TDD 오케스트레이션 플러그인이다. 마스터는 코드를 쓰지 않고 서브에이전트에 위임·검증·커밋·게이트 발송만 한다. RED에서 쓴 테스트는 GATE-1 승인 뒤 **훅이 동결**한다.

왜 이렇게 나누는지, 언제 쓸 만한지는 [핸드북 제6부](../../HANDBOOK.md#제6부--멀티세션)에 있다. 이 문서는 설치와 사용법만 다룬다.

```
RED ──GATE-1──▶ GREEN ──GATE-2──▶ REFACTOR ─▶ REVIEW ──GATE-3──▶ PR ─▶ DONE
 │  (테스트 동결)   │                                    (외부 반영 승인)
 └◀─ RED_REOPEN ◀──┘  테스트가 틀렸으면 검토 세션의 승인을 받아 되돌린다
```

## 구성

| 종류 | 이름 | 하는 일 |
|---|---|---|
| 스킬 | `/multisession-tdd:tdd <이슈>` | 마스터. 위 상태 머신을 따라 위임·검증·커밋·패킷 발송 |
| 스킬 | `/multisession-tdd:gate-review <이슈> [--latest]` | 검토 세션. 패킷을 읽기 전용으로 검증하고 사람의 결정을 받아 판정 회신 |
| 스킬 | `/multisession-tdd:coordinator [에픽]` | 검토·조정 세션 세우기. 에픽 분해, 계획 검토, 자원 교통정리, base 전환 전파 |
| 스킬 | `/multisession-tdd:pause-resume pause\|resume` | 모든 세션에 정지·재개 전파 |
| 에이전트 | `test-writer` (opus / high) | RED — 계획의 테스트 줄을 실패하는 테스트로 |
| 에이전트 | `implementer` (sonnet) | GREEN·리뷰 수정 — 동결된 테스트를 통과시키는 최소 구현 |
| 에이전트 | `refactorer` (sonnet) | REFACTOR — 동작 보존 |
| 에이전트 | `pr-reviewer` (opus / xhigh) | GATE-3 전 사전 리뷰(읽기 전용) |
| 훅 | PreToolUse `guard.sh` | GREEN 이후 테스트 경로 편집 차단 · 검토 세션의 타 워크트리 편집 차단 |
| 훅 | SessionStart `context.sh` | 이 워크트리의 상태 요약을 컨텍스트에 넣는다 |
| 훅 | Stop `stop-guard.sh` | 할 일이 남은 단계에서 대기 선언 없이 턴을 끝내면 되돌린다. 위임한 서브에이전트가 백그라운드로 돌고 있으면 허용하고(셸 작업은 해당 없음), 같은 멈춤에서는 최대 2회만 막는다 |

모든 스킬은 사용자가 직접 부를 때만 실행된다(`disable-model-invocation`). 에이전트는 `tdd` 스킬이 위임할 때만 쓰인다.

## 전제조건

- **Claude Code**
  - 세션 간 메시징(`SendMessage`·`ListAgents`)은 켜는 설정 없이 쓴다. 최소 버전은 macOS·Linux·WSL 2 v2.1.224, 네이티브 Windows v2.1.234, 서드파티 제공자(Amazon Bedrock 등)나 feature-flag fetching을 끈 환경 v2.1.248이다. 스킬이 `ListAgents`에서 자기 세션 이름을 읽으므로 **v2.1.239 이상**을 권한다. `/list-agents`가 동작하면 메시징이 켜진 것이다.
  - 메시지가 닿지 않는 경우: 받는 세션의 `crossSessionInbound`가 `hold`·`refuse`일 때, 보내는 세션에서 `SendMessage`·`ListAgents`가 deny 규칙에 걸렸을 때, 그리고 **권한 모드가 다른 세션 사이**(한쪽만 권한 확인을 건너뛰는 모드)에서 설정 없이 메시지를 주고받을 때 — 받는 쪽이 승인 창을 띄우고 5분간 답이 없으면 버린다. 마스터와 검토 세션을 같은 권한 모드로 열거나 `crossSessionInbound`를 `accept`로 둔다. 판정은 파일에도 남으므로 놓친 메시지는 `--resume`으로 파일에서 읽는다.
  - 사용자 설정의 `/config` 행은 v2.1.269 이상에서 보인다.
- **셸 도구** — POSIX `sh`, `git` 2.38 이상(스크립트는 2.31, 검토 체크리스트의 `merge-tree --write-tree`가 2.38), `jq`. PR 발행에 `gh`. 스크립트는 macOS·Linux(dash 포함)에서 검증했다. 네이티브 Windows는 검증하지 않았다.
- **권한 창** — 스킬의 `allowed-tools`는 스킬을 부른 그 턴에만 적용된다. 여러 턴에 걸친 작업에서 권한 창이 자주 뜨면 두 가지를 해 둔다. 첫 창에 나온 스크립트 경로를 `/permissions`에서 `Bash(sh <경로>/scripts/*)`로 허용하고, 패킷·판정 파일이 있는 상태 루트(`config.sh root` 출력)를 `/add-dir`이나 settings의 `additionalDirectories`로 작업 디렉토리에 더한다(작업 디렉토리 밖이라 편집마다 확인을 받는다).
- **저장소 설정 파일**은 `.claude/` 아래라 처음 채울 때 한 번 확인을 받는다.
- 이 플러그인은 실험 기능인 Agent Teams를 쓰지 않는다. 세션은 사용자가 터미널마다 직접 연다.

## 설치

```
/plugin marketplace add Gundy93/claude-code-template
/plugin install multisession-tdd@claude-code-template
```

버전은 `plugin.json`의 `version`으로 고정된다. 새 버전은 `/plugin marketplace update claude-code-template` 뒤 `claude plugin update multisession-tdd@claude-code-template`로 받는다.

## 설정

### 사용자 설정 (`/plugin configure` 또는 `/config`)

| 키 | 기본값 | 뜻 |
|---|---|---|
| `approval_skill` | `""` | 외부 반영(push·PR 발행·코멘트) 전에 승인 화면을 여는 스킬 이름. 비우면 게시될 원문 전체를 채팅에 싣고 선택창으로 승인받는다 |
| `choice_skill` | `""` | 트레이드오프가 있는 결정 전에 비교 화면을 여는 스킬 이름. 비우면 선택창 미리보기로 비교한다 |

### 저장소 설정 — `.claude/multisession-tdd.json`

저장소마다 다른 값은 사용자 설정(사용자 전역)에 담을 수 없어서 저장소 파일에 둔다. **main 워크트리의 파일 하나**를 모든 워크트리가 읽으므로 커밋하지 않아도 된다. 처음 `/multisession-tdd:tdd`를 부르면 예시(`config.example.json`)를 복사하고 저장소를 훑어 초안을 만든 뒤 확인받는다.

| 키 | 예 | 뜻 |
|---|---|---|
| `checks` | `["npm test", "npm run lint"]` | 전체 검사 명령. GREEN·REFACTOR 끝과 검토에서 전부 돌린다 |
| `testGlobs` | `["**/*.test.ts", "**/src/test/**"]` | 동결 대상 테스트 경로(git glob). 저장소 루트 기준이며, 모든 깊이를 뜻하려면 `**/`로 시작한다 |
| `branch` | `feature/{issue}-{slug}` | 이슈 브랜치 패턴 |
| `base` | `origin/main` | 기본 base(`<원격>/<브랜치>`) |
| `worktreeRoot` | `../{repo}-wt` | 워크트리를 만들 곳. 상대 경로는 main 워크트리 기준 |
| `planGlob` | `["plans/issue-{issue}*.md"]` | 계획 파일 위치 |
| `planSkill` / `prSkill` | `""` | 저장소에 계획·PR 스킬이 있으면 그 이름. 비우면 내장 형식(`skills/tdd/plan-format.md`, `pr-body.md`) |
| `copyOnWorktree` | `[".env.local"]` | 워크트리를 만들 때 main에서 복사할 추적되지 않는 파일 |
| `sizeHint` | `{"files": 10, "lines": 200}` | PR 크기 참고 수치. 반려 사유가 아니다 |
| `resources` | `["전체 빌드 검사", "DB 컨테이너"]` | 한 번에 한 세션만 쓸 자원. 비우면 대기열 절차를 건너뛴다 |

`config.sh check`가 필수 키와 형식을 검사한다.

## 빠른 시작

1. **검토 세션** — main 워크트리에서 `claude -n review` → `/multisession-tdd:coordinator`. 에픽을 맡기려면 `/multisession-tdd:coordinator <에픽>`(세션 이름은 `<에픽>-review`).
2. **워크트리** — 검토 세션에 이슈 42를 `login-form`이라는 이름으로 시작하겠다고 하면 스크립트 절대 경로가 들어간 `wt.sh 42 login-form` 명령을 알려 준다. main 워크트리의 터미널에서 실행한다(검토 세션은 브랜치를 만들지 않는다). 선행 PR 위에 쌓을 때는 세 번째 인수로 그 브랜치를 준다.
3. **계획** — 새 워크트리에서 `claude -n 42-login-form`을 열어 계획을 쓰고(`planSkill` 또는 `plan-format.md`), 검토 세션에 계획 검토를 받는다.
4. **마스터** — 같은 세션에서 `/multisession-tdd:tdd 42`. 이후 게이트마다 패킷이 검토 세션으로 가고, 검토 세션에서 `/multisession-tdd:gate-review 42 --latest`로 판정한다.
5. **자리를 비울 때** — 조정 세션에서 `/multisession-tdd:pause-resume pause <사유>`, 돌아와서 `resume`.

## 상태와 기록

- 위치: `${MSTDD_HOME:-${XDG_STATE_HOME:-~/.local/state}/multisession-tdd}`(이하 루트) 아래 `state/<워크트리 키>/`(단계·세션 정보·로그)와 `gates/<저장소>-<해시>/<이슈>/`(패킷·판정·PR 본문 초안 — 저장소마다 분리), 기계 전체가 같이 쓰는 `resource-queue.md`·`pause-*.md`. `config.sh root`·`config.sh gates`가 실제 경로를 알려 준다.
- 루트를 바꾸려면 셸 프로필이 아니라 settings의 `env`에 `MSTDD_HOME`을 둔다. 훅과 Bash 도구가 같은 값을 봐야 한다.
- 플러그인 데이터 디렉토리(`${CLAUDE_PLUGIN_DATA}`)를 쓰지 않는 이유: 플러그인을 제거하면 그 디렉토리가 기본으로 지워지는데, 게이트 기록은 플러그인과 상관없이 남아야 하는 검토 이력이다. `~/.claude` 아래도 쓰지 않는다 — Claude Code가 민감한 경로로 다뤄 패킷을 쓸 때마다 확인을 받고, 허용 규칙으로도 미리 풀 수 없다.
- 활성 상태가 없는 디렉토리에서는 세 훅이 아무 일도 하지 않는다(jq를 확인하는 것 외에). 이 플러그인을 켜 둬도 다른 프로젝트 세션에는 영향이 없다.
- `wt.sh rm`은 워크트리를 지우면서 그 상태를 비활성화한다. 같은 경로에 다시 만든 워크트리는 낡은 단계를 이어받지 않는다.

## 안전 모델과 한계

- 훅은 상태 파일과 설정의 **글롭만** 읽는다. 설정의 명령(`checks`)은 훅이 실행하지 않고, 모델이 그 세션의 일반 Bash 권한으로 실행한다.
- 설정은 저장소가 주는 값이라 믿지 않는다. base의 원격은 실제로 있는 원격이어야 하고 `-`로 시작할 수 없다. `copyOnWorktree`·`planGlob`은 저장소 안의 상대 경로만 받는다. `config.sh check`가 둘 다 검사한다.
- 동결 단계에서 판정할 수 없으면 **막는다**(fail-closed). 설정이 없거나 `testGlobs`가 비었을 때, jq가 없을 때, 경로에 `.`·`..` 표기가 남아 있을 때가 여기에 해당한다. 경로는 git 기준으로, 대소문자를 무시하고 비교하므로 심볼릭 링크·`./`·대소문자 표기로 우회되지 않는다.
- guard는 Edit·Write·MultiEdit·NotebookEdit 도구만 본다. Bash로 테스트 파일을 바꾸는 우회는 GATE-2·3의 `testdiff.sh`가 잡는다(커밋과 워킹트리 모두). testdiff는 0 무변경 · 1 변경 · 2 검사 불가로 끝나며, 2는 통과가 아니다.
- 글롭은 git glob으로 쓴다. guard에서는 `*`가 `/`도 넘으므로 git보다 넓게 막는다(예: `src/*.test.ts`가 `src/a/b.test.ts`도 막는다). 모든 깊이를 뜻하려면 `**/`로 시작한다.
- Stop 가드는 세션이 아니라 워크트리 단위로 걸린다. 마스터 말고 다른 세션을 같은 워크트리에서 열면 그 세션도 가드를 받는다.

## 테스트

```sh
sh plugins/multisession-tdd/tests/hooks.test.sh
```

임시 디렉토리(심볼릭 링크 경로 그대로)에 원격·main 저장소·워크트리를 만들고, 훅 입력 JSON을 흘려 exit 코드와 출력을 대조한다. 상태 머신, Stop 차단, 동결과 그 우회 시도, 타 워크트리 차단, testdiff, 패킷, 스택 base, 악성 설정, 워크트리 제거·재부착을 다룬다.
