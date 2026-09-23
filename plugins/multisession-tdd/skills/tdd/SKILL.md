---
name: tdd
description: 이슈 하나를 RED→GATE-1→GREEN→GATE-2→REFACTOR→리뷰→GATE-3→PR 순서로 진행하는 마스터 오케스트레이션. 코드는 서브에이전트가 쓰고, 각 게이트는 별도 검토 세션의 판정을 받는다. 사용자가 /multisession-tdd:tdd <issue>로 직접 호출할 때만 실행된다.
argument-hint: "<issue> [--resume | --status | --abort]"
arguments: [issue, mode]
disable-model-invocation: true
allowed-tools: Bash(sh ${CLAUDE_PLUGIN_ROOT}/scripts/*)
---

# /multisession-tdd:tdd — 이슈 하나의 TDD 마스터

이 세션은 이제 이슈 `$issue`의 **마스터**다. 코드는 서브에이전트가 쓰고, 마스터는 위임·검증·커밋·게이트 발송을 한다.

- 스크립트는 `sh ${CLAUDE_PLUGIN_ROOT}/scripts/<이름>.sh …`로 부른다(따옴표 없이 — 권한 규칙과 맞춘다). 아래의 `phase.sh`, `gate.sh`, `testdiff.sh`, `config.sh`, `wt.sh`는 모두 이 경로다. 서브에이전트에 넘길 때도 이 절대 경로를 적는다.
- 저장소 설정은 main 워크트리의 `.claude/multisession-tdd.json`이다(`config.sh show`). 검사 명령·테스트 글롭·브랜치 패턴·base가 여기서 온다.
- 참조: `${CLAUDE_SKILL_DIR}/gate-packet.md`(패킷·판정 형식), `${CLAUDE_SKILL_DIR}/delegation.md`(위임 프롬프트 4종), `${CLAUDE_SKILL_DIR}/plan-format.md`(계획 파일 최소 형식), `${CLAUDE_SKILL_DIR}/pr-body.md`(PR 본문 기본 템플릿).

## 0. 불변 규칙

- 단계 변경은 **`phase.sh set <PHASE>`로만** 한다. 단계가 의심되면 `phase.sh show`.
- GATE-1 승인 뒤 테스트 경로(설정 `testGlobs`)는 **동결**이다. 동결 단계(GREEN·GATE2·REFACTOR·REVIEW·GATE3·PR·RED_REOPEN)에서는 훅이 편집을 막고, 검토 세션이 `testdiff.sh`로 다시 잡는다. 마스터도 손대지 않는다.
- 커밋은 마스터만 한다. 메시지 규약은 저장소 규약(CLAUDE.md 등)을 따른다. 머지하지 않는다.
- 위임 대상은 이 플러그인의 `multisession-tdd:test-writer`·`multisession-tdd:implementer`·`multisession-tdd:refactorer`·`multisession-tdd:pr-reviewer`와 built-in `Explore`뿐이다. 이 스킬 안에서 다른 자율 실행 모드나 외부 오케스트레이터를 쓰지 않는다 — 단계 전이와 게이트가 우회된다.
- **게이트 패킷을 보낸 뒤에는 턴을 끝내고 기다린다.** 판정은 검토 세션의 메시지로 새 턴에 온다. 「검토 세션 답을 기다리는 중」 한 줄만 남긴다. 서브에이전트에게 검토를 대신 시키지 않는다.
- **그 밖의 단계에서는 할 일이 남은 채 턴을 끝내지 않는다.** 위임 결과를 받으면 검증 → 커밋 → 다음 단계까지 이어 간다. 멈춰도 되는 경우:
  - 위임한 서브에이전트가 백그라운드로 돌고 있을 때 — 끝나면 새 턴이 온다(Stop 훅이 허용한다).
  - 자원 승인 대기 · 검토 세션 회신 대기 · 사용자 결정 대기 · 사용자가 멈추라고 함 — 멈추기 **직전에** `phase.sh wait "<사유>"`를 실행한다. 선언 없이 멈추면 Stop 훅이 되돌려 보낸다. 선언은 한 번 쓰면 지워지므로 멈출 때마다 새로 한다.
- **외부 반영 승인은 검토 세션이 받는다.** push·PR 발행·본문 갱신·코멘트 같은 외부 반영은 검토 세션이 사용자 승인을 받고 판정의 「승인 범위」에 명령을 적어 보낸다. 마스터는 따로 승인 화면을 열지 않고 그 범위만 실행한다. 적혀 있지 않은 외부 반영은 하지 않고 GATE-3 재발송의 「열린 질문」에 원문 초안을 넣어 승인을 청한다.
- 스코프는 계획 문서가 정한다. 문서에 없는 것은 구현하지 않고 가정(`[가정 N]`)이나 질문으로 남긴다.
- **base는 `session.json`의 `base`다**(기본은 설정 `base`, 스택 PR이면 선행 PR 브랜치). diff 범위·크기 집계·merge·PR의 `--base`는 전부 이 값을 쓴다. 아래 `<base>`는 이 값, `<base 브랜치명>`은 원격 이름을 뗀 것이다. 8절 참조.
- **조정 세션의 PAUSE 메시지**를 받으면 도는 위임만 받아 두고 새 위임·커밋·검사를 멈춘 뒤 `phase.sh wait "사용자가 멈추라고 함"`으로 멈춘다. RESUME 메시지가 오면 그 메시지의 「이어갈 일」부터 한다.

## 1. 프리플라이트

1. `$issue`가 비었으면 「`/multisession-tdd:tdd <이슈>` 형태로」 안내하고 끝.
2. `$mode`가 `--status`면 `phase.sh status` 출력 후 끝. `--abort`면 `phase.sh set HALT --note "<사유>"` 후 끝.
3. `phase.sh get`이 성공하면(활성 상태 있음) 재개로 간주한다 — `show`로 단계를 읽고 「이슈 N, <단계>에서 재개」 한 줄을 알린 뒤 그 단계로 간다. 게이트 대기 단계(GATE1/2/3, RED_REOPEN)면 먼저 `gate.sh status`로 판정 파일 유무를 본다.
4. 상태가 없으면 새로 시작한다.
   1. **설정** — `config.sh check`. 설정이 없으면 `config.sh init`으로 예시를 복사하고, 저장소를 훑어 검사 명령·테스트 글롭·base·브랜치 패턴의 초안을 만든 뒤 AskUserQuestion으로 확인받아 채운다. `check`가 OK일 때까지 다음으로 가지 않는다.
   2. **브랜치** — `git fetch && git status --short --branch`. 이 세션이 main 워크트리에 있거나 브랜치가 설정 `branch` 패턴이 아니면, 사용자에게 main 워크트리에서 `sh ${CLAUDE_PLUGIN_ROOT}/scripts/wt.sh $issue <slug> [base]`를 실행하고 새 워크트리에서 세션을 열라고 안내하고 끝(slug는 사용자에게 묻는다). 브랜치에 커밋이 없고 `<base>`보다 뒤져 있으면 `git rebase <base>`.
   3. **계획** — 설정 `planGlob`(`{issue}` 치환)으로 찾는다. 없으면: 설정 `planSkill`이 있으면 「그 스킬로 계획을 만들고 검토받은 뒤 다시 부르라」, 없으면 `plan-format.md` 형식으로 계획을 쓰고 검토 세션에 계획 검토를 받으라고 안내하고 끝. 여럿이면 AskUserQuestion.
   4. **세션 이름** — `ListAgents`로 검토 세션과 자기 이름을 본다. 검토 세션 이름은 `/multisession-tdd:coordinator`의 규약(`review`, `<에픽>-review` 등)을 따르되, 확실하지 않으면 AskUserQuestion으로 받는다. 기본값은 없다. 검토 세션이 없으면 main 워크트리에서 `/multisession-tdd:coordinator`로 세우라고 안내하고 끝.
   5. `phase.sh init $issue --branch <브랜치> --plan <경로> --review <검토 세션> --master <내 세션>`. `phase.sh show`로 base가 의도한 브랜치인지 확인하고 한 줄 알린다.
   6. 계획을 Read해 절차와 테스트 줄을 전부 열거한다. `Explore`에 대상 영역 탐색을 위임해 100줄 이내 요약을 받아 둔다.
   7. 이슈 본문(`gh issue view $issue` 등)에서 막는 미확정 사항을 읽고, 남아 있으면 사용자에게 알린다.

## 2. RED

1. `phase.sh set RED`.
2. `multisession-tdd:test-writer`에 위임(`delegation.md` RED 템플릿 — 계획 경로, 테스트 줄 원문 전부, 수용 기준, Explore 요약).
3. 결과를 마스터가 직접 검증한다 — 테스트를 다시 돌려 실패 수 확인 · `git diff --stat`으로 비테스트 파일이 스텁뿐인지 · 계획 줄↔테스트 1:1 · skip/only 없음.
4. 커밋(테스트).
5. `phase.sh set GATE1` → `gate.sh prepare GATE1` → 출력된 파일을 Edit로 채운다(무엇을 검토하나 · 테스트 표 · 명령과 결과 · 가정) → 파일을 Read해 본문 그대로 `SendMessage(to: <검토 세션>)` → 「GATE-1 대기」 알리고 **턴 종료**.

## 3. 판정 처리(모든 게이트 공통)

1. `gate.sh status`로 이 seq의 판정 파일이 있는지 본다. 없고 메시지로만 받았으면 본문을 `gate.sh path <NN> verdict`가 가리키는 파일에 Write한다.
2. 판정 머리줄의 `seq`·`gate`가 이 패킷과 같은지, `git rev-parse HEAD`가 패킷의 HEAD와 같은지 확인한다(다르면 그 판정을 쓰지 않고 사용자에게 알린다). 그다음 `VERDICT:` 줄을 읽는다.
3. `APPROVED` → 다음 단계. `CHANGES_REQUESTED` → 직전 작업 단계로(`GATE1→RED`, `GATE2→GREEN`, `GATE3→REVIEW`), 피드백 번호를 위임 프롬프트에 그대로 넣어 재작업 → 커밋 → 같은 게이트를 새 seq로 재발송. `REJECTED` → `phase.sh set HALT`, 사용자에게 보고하고 지시를 기다린다(RED_REOPEN의 `REJECTED`만 예외 — 4-R 3항). `RED_REOPEN_APPROVED`는 4-R 2항.

## 4. GREEN

1. `phase.sh set GREEN`.
2. 계획의 절차마다 `multisession-tdd:implementer`에 위임(GREEN 템플릿 — 절차 번호, 통과시킬 테스트, redSha, 동결 규칙). 절차가 복잡하면(공개 API·마이그레이션·동시성) Agent 호출에 `model: opus`.
3. 절차가 끝날 때마다 대상 테스트를 돌리고 계획 파일의 그 절차와 테스트 줄을 `[x]`로 바꾼다.
4. 출력에 `RED-REOPEN 요청` 블록이 있으면 4-R로.
5. 전부 끝나면 설정 `checks` 전부(`config.sh get checks`) → `testdiff.sh`가 UNCHANGED(종료 코드 0. 2는 검사 불가라 통과가 아니다).
6. 커밋 → `phase.sh set GATE2` → `gate.sh prepare GATE2` 채움 → SendMessage → 턴 종료.

### 4-R. RED-REOPEN (GREEN·REFACTOR·REVIEW에서)

1. `phase.sh set RED_REOPEN` → `gate.sh prepare RED_REOPEN` — 대상 테스트 · 근거 · 제안 · 영향 수용 기준 · 대안을 채워 발송 → 턴 종료.
2. `RED_REOPEN_APPROVED` → `phase.sh set RED` → test-writer에 「지목 테스트만 수정」 위임 → 커밋 → `phase.sh set GATE1`(새 redSha) → GATE-1 재발송(새 seq) → 승인 뒤 GREEN부터 다시.
3. `REJECTED` → 요청을 낸 단계로 돌아간다(`phase.sh set GREEN|REFACTOR|REVIEW`) → 해당 에이전트에 「테스트 그대로 + 검토 의견」 재위임.

## 5. REFACTOR

`phase.sh set REFACTOR` → `multisession-tdd:refactorer` 위임(no-op 허용) → `checks` 전부 + `testdiff.sh` → 변경이 있으면 커밋 → `phase.sh set REVIEW`.

## 6. REVIEW → GATE-3

1. `multisession-tdd:pr-reviewer` 위임(REVIEW 템플릿 — diff 범위, 계획 경로, 수용 기준 매핑표).
2. ① 차단은 전부, ② 강력 권고는 수정 또는 사유 기록. 수정은 implementer(테스트 동결 유지). `checks` 전부 + `testdiff.sh` → 커밋.
3. **PR 드라이런** — 계획 체크박스 전부 `[x]` · 미구현·스텁·TODO 없음 · `git diff --numstat <base>...HEAD` 크기(설정 `sizeHint`는 참고 수치다). 본문은 설정 `prSkill`이 있으면 그 스킬의 본문 작성 단계까지만(발행 단계는 하지 않는다), 없으면 `pr-body.md`로 초안을 쓴다.
4. `phase.sh set GATE3` → `gate.sh prepare GATE3`(출력 파일 이름의 `NN`이 이번 seq다) → 본문을 `gate.sh path <NN> pr-body`에 저장 → 패킷에 R-# 해결표와 크기를 채움 → SendMessage → 턴 종료.

## 7. PR

`APPROVED`면 `phase.sh set PR` → 판정의 「승인 범위」대로 발행한다 — `prSkill`이 있으면 그 스킬의 발행 단계, 없으면 `git push -u <원격> <브랜치>` → `gh pr create --base <base 브랜치명> --title … --body-file <pr-body 경로>` → `phase.sh set DONE` → PR URL 보고.

**발행 뒤 리뷰 반영**도 게이트를 거친다 — `phase.sh set REVIEW`(PR·DONE에서 허용, 테스트는 계속 동결) → 수정 위임·검증·커밋 → `phase.sh set GATE3` → GATE-3 재발송(push·본문 갱신·코멘트 회신 초안을 「열린 질문」에) → 판정의 승인 범위만 실행 → `phase.sh set PR` → `DONE`. `phase.sh clear`는 사용자가 원할 때.

## 8. 스택 PR(선행 PR 브랜치 위에서 작업할 때)

선행 이슈의 PR이 발행됐지만 아직 머지되지 않았을 때, 후속 이슈는 그 PR 브랜치를 base로 시작한다.

1. **시작** — `wt.sh <이슈> <slug> <선행 브랜치>`(원격에 있어야 한다). 계획은 선행 PR의 코드가 들어 있는 트리에서 쓴다.
2. **선행 브랜치가 바뀌면**(선행 PR이 리뷰 반영 커밋을 받으면) — `git fetch && git merge <base>`(발행 뒤 rebase·force push 금지, 발행 전이면 rebase 가능). 테스트 경로가 바뀌어도 동결 위반이 아니다. 합친 직후 `phase.sh redsha HEAD --note "merge <base>"`로 동결 기준점을 옮기고(base를 합친 머지 커밋이어야 한다. "Already up to date"로 합칠 것이 없었으면 건너뛴다. 발행 전 rebase였다면 `--force`로 옮기고 패킷에 사유를 적는다), 출력된 `MERGE: old redSha=…, new redSha=…` 줄을 다음 패킷의 「열린 질문·가정」에 그대로 적는다(검토 세션이 테스트 변경분을 대조한다).
3. **GATE-3·PR** — 본문 첫 줄에 `base: #<선행 PR> (<base 브랜치명>) — 선행 머지 뒤 base가 바뀐다`. 크기는 `<base>...HEAD`로 세므로 선행 변경이 섞이지 않는다.
4. **선행 PR이 머지되면** — 조정 세션이 후속 마스터마다 「선행 머지됨 — base 전환」을 보낸다. 받으면: (PR·DONE이면 `phase.sh set REVIEW`) → `git fetch && git merge <설정 base>` → `phase.sh redsha HEAD --note "merge <설정 base>"` → `checks`·`testdiff.sh` → `phase.sh base <설정 base>` → GATE-3 재발송으로 push 승인 → push 뒤 PR의 base가 바뀌었는지 확인(`gh pr view <PR> --json baseRefName`) → 본문 첫 줄 갱신.
5. **머지 순서** — 선행부터. 후속을 먼저 머지하면 선행 변경까지 함께 들어간다.
