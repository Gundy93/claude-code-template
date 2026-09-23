# 게이트별 체크리스트

각 항목은 「실행한 것 → 증거 한 줄 → pass/fail」로 적는다. 하나라도 fail이면 기본 제안은 `CHANGES_REQUESTED`.

- **`<scripts>`** — SKILL.md가 알려 준 `scripts/` 절대 경로. `<wt>`는 패킷의 워크트리.
- **base** — 아래 `<base>`는 패킷 헤더 `- base:` 줄의 브랜치다. 패킷을 믿지 말고 `(cd <wt> && sh <scripts>/phase.sh show)`의 `base`와 `git -C <wt> merge-base <base> HEAD`로 다시 확인한다. 스택 PR을 설정 base로 세면 선행 PR의 변경이 섞여 스텁·크기·커밋 검사가 전부 틀린다.
- **테스트 경로 pathspec** — 글롭에 공백·특수 문자가 있어도 깨지지 않게 명령 치환 대신 NUL 구분으로 넘긴다: `(cd <wt> && sh <scripts>/config.sh pathspecs [--exclude] -z) | xargs -0 git -C <wt> <명령> --`.
- **RED sha 이력** — 패킷 헤더의 RED sha가 GATE-1 승인 때의 값과 다르면 헤더의 "RED sha 이력"(스크립트가 자동으로 넣는다 — 마스터가 쓰는 줄이 아니다)에 그 이동이 있어야 한다. 이력의 이동마다 아래 MERGE 대조를 한다. `FORCED`나 "GATE1 재설정"이 붙은 이동은 머지가 아닌 방법으로 기준점을 옮긴 것이므로 사유를 묻는다. 이력에 없는 이동은 fail.
- **testdiff 종료 코드** — 0 무변경 · 1 변경 · 2 검사 불가. 2는 통과가 아니다(sha·설정을 고쳐 다시 돌린다).
- **MERGE 대조** — 이력의 이동(`old → new`)마다, `git -C <wt> diff <old RED> <new RED> -- <포함 pathspec>`이 base 쪽 테스트 변경분(`git -C <wt> diff <old base tip> <new base tip> -- <포함 pathspec>`)과 같은지 먼저 대조한다. 같으면 합친 것뿐이고, 이후 testdiff는 새 redSha 기준이다. 다르면 누군가 테스트를 고친 것이다(fail).

## GATE-1 (RED → GREEN)

1. **계획 줄 ↔ 테스트 1:1** — 계획의 테스트 줄(`- [ ] T<NN>:`) 수와 테스트 이름 `T<NN>:` 수가 같고 이름이 대응한다.
2. **수용 기준 대응** — 테스트가 단정하는 것이 인용된 수용 기준 문장에 있다. 없는 것을 단정하면 fail.
3. **실패 사유** — 테스트를 직접 돌려 전부 실패하고, 실패가 단언·동작 불일치인지 본다. 컴파일만 실패하는 것은 패킷에 사유가 있어야 한다.
4. **비테스트 diff가 스텁뿐** — `(cd <wt> && sh <scripts>/config.sh pathspecs --exclude -z) | xargs -0 git -C <wt> diff <base>...HEAD -- .`을 읽는다. 분기·계산·기본값이 있으면 fail.
5. **저장소 테스트 규약** — CLAUDE.md·테스트 가이드 문서가 있으면 그 규칙(목 경계, 픽스처 위치 등)을 따른다.
6. **비활성화·미완 표시 없음** — `git -C <wt> grep -n -E "@Disabled|\.skip\(|\.only\(|xit\(|TODO|FIXME" -- <변경 파일>`.
7. **가정 번호**가 이슈·계획의 번호와 맞는다.
8. **크기 참고** — `git -C <wt> diff --numstat <base>...HEAD`의 파일 수·최대 줄 수를 패킷과 대조해 **적기만 한다**. 설정 `sizeHint`는 참고 수치이고, 초과는 반려 사유가 아니다.

## GATE-2 (GREEN → REFACTOR)

1. **전체 검사 통과** — 설정 `checks`를 직접 실행한다.
2. **테스트 동결** — `sh <scripts>/testdiff.sh -C <wt>`(redSha는 상태에서 읽는다) → 종료 코드 0. CHANGED(1)면 사유를 불문하고 `CHANGES_REQUESTED`다(테스트를 고치려면 RED-REOPEN 경로. base 병합은 위 MERGE 줄 대조로 처리).
3. **스코프** — 변경 파일이 계획의 파일 목록 안. 테스트가 요구하지 않는 분기·옵션이 없다. 계획 밖 파일이 있으면 사유를 요구한다.
4. **잔존물 없음** — `TODO|FIXME|skip|only`, RED 스텁의 예외 문구.
5. **계획 체크박스**가 이번 절차만큼 `[x]`.
6. **생성 산출물** — 저장소가 코드 생성(API 타입 등)을 쓰면, 원천이 바뀐 만큼 재생성돼 커밋에 들었다.
7. **규약 스팟체크** — 저장소 CLAUDE.md의 금지 사항(로그 출력 방식, 계층 규칙 등).
8. **가정 표시** `[가정 N]`가 코드에 있다.

## GATE-3 (REVIEW → PR)

1. **사전 리뷰** R-# 전부 해결 또는 사유. 차단이 남아 있으면 fail.
2. **testdiff** 종료 코드 0(다시 돌린다).
3. **PR 본문** — 저장소 PR 규약(없으면 `tdd/pr-body.md`)을 따르고, 계획 경로 · 크기 · 검증(명령·결과)을 담는다. 이슈를 닫을 PR이면 **`Closes #<이슈>` 줄**이 있다 — 제목의 번호나 「#이슈 참조」만으로는 닫히지 않는다. 이 키워드는 PR이 기본 브랜치를 대상으로 할 때만 동작하므로, 스택 PR은 base가 기본 브랜치로 바뀐 뒤 머지돼야 닫힌다.
4. **크기 재계산** — `git -C <wt> diff --numstat <base>...HEAD`로 다시 세어 패킷과 대조한다. 참고 수치일 뿐 초과는 반려 사유가 아니다.
5. **계획 체크박스** 전부 `[x]`.
6. **커밋 메시지** — 저장소 규약. `git -C <wt> log <base>..HEAD --no-merges --format='%s%n%b'`(base 쪽 커밋을 세지 않게 브랜치 커밋만).
7. **시험 머지** — `git -C <wt> merge-tree --write-tree <base> HEAD`(충돌 없음)와 `git -C <wt> merge-base --is-ancestor <base> HEAD`. 스택 PR이면 설정 base와도 한 번 더 돌려 선행 머지 뒤 충돌을 미리 본다(참고, 반려 사유 아님).
   - **base 반영 방식** — PR 발행 전은 `git rebase <base>`, 발행 뒤는 `git merge <base>`(force push 금지). MERGE 줄이 있으면 위 대조를 한다.
   - **스택 PR** — 실행 명령은 `gh pr create --base <base 브랜치명>`. 본문 첫 줄에 `base: #<선행 PR>`이 있는가. 선행이 머지된 뒤의 재발송이면 설정 base가 merge됐는지, 상태의 base가 바뀌었는지(`phase.sh show`), 본문 base 문구가 갱신됐는지 보고, push 뒤 PR base가 설정 base로 바뀌었는지는 다음 재발송에서 확인한다.
8. **검사 결과의 신뢰도** — 검사가 몇 초 만에 끝났거나 빌드 도구가 캐시 적중으로 테스트 실행을 건너뛰었으면 그 통과는 근거가 아니다. **기대 건수**(base 단독 N + 이 PR이 더한 M)를 먼저 계산하고 실행 건수와 대조한다. 적으면 이 PR 테스트가 돌지 않은 것이다.
9. 그 뒤 승인 절차 → AskUserQuestion.

## RED_REOPEN

1. 인용된 스펙·수용 기준 문장이 실제 문서와 같다.
2. 테스트가 틀린 것인지, 구현이 어려워 회피하려는 것인지 — 대안 칸을 본다.
3. 제안 수정이 지목한 테스트에 한정된다.
4. 승인하면 마스터가 새 redSha로 GATE-1을 다시 보낸다는 것을 사용자에게 알린다.
