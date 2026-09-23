#!/bin/sh
# 훅·스크립트 회귀 테스트. 임시 디렉토리에 원격(bare)·main 저장소·워크트리를 만들고 실제로 실행한다.
#   sh plugins/multisession-tdd/tests/hooks.test.sh      (필요: git, jq)
set -u
S=$(cd "$(dirname "$0")/../scripts" && pwd -P)
T=$(mktemp -d)   # 정규화하지 않는다 — macOS의 /var → /private/var 같은 심볼릭 링크 경로로 우회를 시험한다
trap 'rm -rf "$T"' EXIT
export MSTDD_HOME="$T/home"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
pass=0; fail=0
ok() { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
ng() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; sed 's/^/     /' "$T/err" 2>/dev/null | head -5; }
# expect <기대 rc> <이름> <명령…>  — stdout은 $T/out, stderr는 $T/err
expect() { want=$1; name=$2; shift 2; "$@" >"$T/out" 2>"$T/err"; rc=$?; if [ "$rc" -eq "$want" ]; then ok "$name"; else ng "$name (rc=$rc, 기대 $want)"; fi; }
has() { if grep -q -- "$2" "$T/$1"; then ok "$3"; else ng "$3 ('$2' 없음: $(head -c 200 "$T/$1"))"; fi; }
hasnt() { if grep -q -- "$2" "$T/$1"; then ng "$3 ('$2' 있음)"; else ok "$3"; fi; }
hook() { jq -n --arg c "$2" --arg f "${3:-}" '{cwd:$c, tool_input:{file_path:$f}}' | sh "$S/$1"; }
hooknb() { jq -n --arg c "$1" --arg f "$2" '{cwd:$c, tool_input:{notebook_path:$f}}' | sh "$S/guard.sh"; }
stopbg() { jq -n --arg c "$1" '{cwd:$c, stop_hook_active:false, background_tasks:[{id:"t1",type:"subagent",status:"running"}]}' | sh "$S/stop-guard.sh"; }
stop() { jq -n --arg c "$1" --argjson a "$2" '{cwd:$c, stop_hook_active:$a}' | sh "$S/stop-guard.sh"; }
in_dir() { d=$1; shift; (cd "$d" && "$@"); }

# ── 준비: 원격, main 저장소(설정은 커밋하지 않는다 — 워크트리가 main의 사본을 읽는지 본다)
git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$T/repo" 2>/dev/null
R="$T/repo"
mkdir -p "$R/src" "$R/.claude" "$R/plans"
echo 'export const a = 1' > "$R/src/app.ts"
git -C "$R" add . && git -C "$R" commit -qm init && git -C "$R" push -q origin main
cat > "$R/.claude/multisession-tdd.json" <<'EOF'
{ "checks": ["true"], "testGlobs": ["**/*.test.ts", "test/fixtures/**", "**/test-setup.ts", "src/**/spec/*.ts", "**/*.ipynb"],
  "branch": "feature/{issue}-{slug}", "base": "origin/main", "worktreeRoot": "../{repo}-wt",
  "planGlob": ["plans/issue-{issue}*.md"], "copyOnWorktree": [".env.local"], "sizeHint": {"files": 10, "lines": 200} }
EOF
echo 'SECRET=x' > "$R/.env.local"
printf -- '- [ ] T01: 로그인 실패 시 오류를 보인다\n' > "$R/plans/issue-7-login.md"

echo "# 설정·글롭"
expect 0 "config check 통과" in_dir "$R" sh "$S/config.sh" check
expect 1 "설정 없는 저장소는 check 실패" in_dir "$T/origin.git" sh "$S/config.sh" check
expect 0 "pathspecs" in_dir "$R" sh "$S/config.sh" pathspecs --exclude
has out ':(exclude,glob)\*\*/\*.test.ts' "exclude pathspec 형식"
expect 0 "branch 렌더링" in_dir "$R" sh "$S/config.sh" branch 7 login
has out 'feature/7-login' "branch = feature/7-login"
(
  . "$S/lib.sh"
  for c in "src/a.test.ts|**/*.test.ts|0" "a.test.ts|**/*.test.ts|0" "test-setup.ts|**/test-setup.ts|0" \
           "test/fixtures/h.ts|test/fixtures/**|0" "lib/test/fixtures/h.ts|test/fixtures/**|1" "src/app.ts|**/*.test.ts|1" \
           "src/spec/b.ts|src/**/spec/*.ts|0" "src/x/spec/b.ts|src/**/spec/*.ts|0" "lib/spec/b.ts|src/**/spec/*.ts|1"; do
    p=${c%%|*}; r=${c#*|}; g=${r%|*}; want=${r#*|}
    match_glob "$p" "$g"; got=$?
    if [ "$got" -eq "$want" ]; then echo "ok   match_glob $p ~ $g"; else echo "FAIL match_glob $p ~ $g (got $got)"; fi
  done
) > "$T/glob"; cat "$T/glob"
pass=$((pass + $(grep -c '^ok' "$T/glob"))); fail=$((fail + $(grep -c '^FAIL' "$T/glob")))

echo "# 상태 없음 — 전부 통과"
expect 0 "guard: 상태 없음" hook guard.sh "$R" "$R/src/a.test.ts"
expect 0 "guard: git 밖" hook guard.sh / /tmp/x.txt
expect 0 "stop: 상태 없음" stop "$R" false
hasnt out block "stop: 상태 없음이면 출력 없음"
expect 0 "context: 상태 없음" hook context.sh "$R"
hasnt out 상태 "context: 상태 없음이면 출력 없음"

echo "# wt.sh"
expect 0 "wt 생성" in_dir "$R" sh "$S/wt.sh" 7 login
W="$T/repo-wt/7-login"
[ -d "$W" ] && ok "워크트리 경로 {repo}-wt" || ng "워크트리 경로"
[ "$(git -C "$W" rev-parse --abbrev-ref HEAD)" = feature/7-login ] && ok "브랜치" || ng "브랜치"
[ -f "$W/.env.local" ] && ok "copyOnWorktree" || ng "copyOnWorktree"
[ -f "$W/plans/issue-7-login.md" ] && ok "planGlob 복사" || ng "planGlob 복사"
expect 1 "없는 base 거부" in_dir "$R" sh "$S/wt.sh" 9 nope feature/none
expect 1 "이슈 문자 검사" in_dir "$R" sh "$S/wt.sh" '7;x' bad
expect 0 "워크트리에서 main 설정 읽기" in_dir "$W" sh "$S/config.sh" check

echo "# phase.sh"
expect 0 "init" in_dir "$W" sh "$S/phase.sh" init 7 --branch feature/7-login --plan plans/issue-7-login.md --review review --master 7-login
expect 0 "show" in_dir "$W" sh "$S/phase.sh" show
has out '"base": "origin/main"' "base = wt가 남긴 값"
expect 1 "init 중복 거부" in_dir "$W" sh "$S/phase.sh" init 7 --branch b --plan p --review r --master m
expect 1 "INIT→GREEN 거부" in_dir "$W" sh "$S/phase.sh" set GREEN
expect 0 "INIT→RED" in_dir "$W" sh "$S/phase.sh" set RED

echo "# Stop 훅 (RED)"
expect 0 "stop 1회: 막음" stop "$W" false
has out '"decision": "block"' "stop 1회 block"
expect 0 "stop 2회: 막음" stop "$W" true
has out block "stop 2회 block"
expect 0 "stop 3회: 통과" stop "$W" true
hasnt out block "stop 3회 통과(무한 되돌림 방지)"
expect 0 "wait 선언" in_dir "$W" sh "$S/phase.sh" wait "사용자 결정 대기"
expect 0 "stop: wait 표식이면 통과" stop "$W" false
hasnt out block "wait 표식 통과"
expect 0 "stop: 표식은 한 번만" stop "$W" false
has out block "표식 소비 뒤 다시 막음"

echo "# guard (RED — 테스트 편집 허용)"
expect 0 "RED: 테스트 편집 허용" hook guard.sh "$W" "$W/src/a.test.ts"
mkdir -p "$W/test/fixtures"
echo 'it("T01")' > "$W/src/a.test.ts"; echo 'export {}' > "$W/test/fixtures/h.ts"
git -C "$W" add . && git -C "$W" commit -qm "test: T01"
expect 0 "RED→GATE1" in_dir "$W" sh "$S/phase.sh" set GATE1
expect 0 "stop: 게이트 대기는 통과" stop "$W" false
hasnt out block "GATE1 대기 통과"

echo "# gate.sh"
expect 0 "prepare GATE1" in_dir "$W" sh "$S/gate.sh" prepare GATE1
P=$(cat "$T/out")
[ -f "$P" ] && ok "패킷 파일 생성" || ng "패킷 파일"
head -1 "$P" | grep -q '^MSTDD GATE1 7 seq=01 master=7-login resend=0' && ok "패킷 헤더" || ng "패킷 헤더: $(head -1 "$P")"
grep -q 'src/a.test.ts' "$P" && ok "numstat 포함" || ng "numstat"
expect 0 "prepare --resend" in_dir "$W" sh "$S/gate.sh" prepare GATE1 --resend
has out '01-GATE1.md' "resend는 seq 유지"
G7="$(in_dir "$R" sh "$S/config.sh" gates)/7"
printf 'MSTDD VERDICT 7 seq=01 gate=GATE1\nVERDICT: APPROVED\n' > "$G7/01-verdict.md"
expect 0 "gate status" in_dir "$W" sh "$S/gate.sh" status
has out 'VERDICT: APPROVED' "status에 verdict"
expect 0 "context: 상태 요약" hook context.sh "$W"
has out '이슈 7 · phase=GATE1' "context 요약"

echo "# guard (GREEN — 동결)"
expect 0 "GATE1→GREEN" in_dir "$W" sh "$S/phase.sh" set GREEN
expect 2 "GREEN: *.test.ts 차단" hook guard.sh "$W" "$W/src/a.test.ts"
has err 'RED-REOPEN' "차단 메시지에 RED-REOPEN 안내"
expect 2 "GREEN: 상대 경로도 차단" hook guard.sh "$W" "src/a.test.ts"
expect 2 "GREEN: 루트 test-setup.ts 차단" hook guard.sh "$W" "$W/test-setup.ts"
expect 2 "GREEN: test/fixtures 차단" hook guard.sh "$W" "$W/test/fixtures/h.ts"
expect 0 "GREEN: 구현 파일 허용" hook guard.sh "$W" "$W/src/app.ts"
expect 2 "타 워크트리 편집 차단(검토 세션)" hook guard.sh "$R" "$W/src/app.ts"
expect 2 "./ 상대 경로(루트 기준 글롭)도 차단" hook guard.sh "$W" "./test/fixtures/h.ts"
expect 2 ".. 표기도 차단" hook guard.sh "$W" "$W/src/../test/fixtures/h.ts"
expect 2 "정규화된 경로로도 차단" hook guard.sh "$W" "$(cd "$W" && pwd -P)/test/fixtures/h.ts"
expect 2 "가운데 ** 0단계(src/spec) 차단" hook guard.sh "$W" "$W/src/spec/b.ts"
expect 2 "NotebookEdit(notebook_path) 차단" hooknb "$W" "$W/nb/a.ipynb"
mkdir -p "$T/notes"
expect 0 "작업 트리 밖 파일은 동결 대상 아님" hook guard.sh "$W" "$T/notes/idea.test.ts"
mkdir -p "$T/nojq"; for t in cat dirname basename git sed date mkdir; do ln -s "$(command -v $t)" "$T/nojq/$t"; done
expect 2 "jq 없으면 동결 단계에서 차단" sh -c 'cd "$1" && echo "{}" | PATH="$2" /bin/sh "$3/guard.sh"' _ "$W" "$T/nojq" "$S"
expect 0 "stop: 서브에이전트 백그라운드면 통과" stopbg "$W"
hasnt out block "서브에이전트 진행 중 통과"
expect 0 "stop: 셸 작업만 있으면 막음" sh -c 'jq -n --arg c "$1" "{cwd:\$c, stop_hook_active:false, background_tasks:[{id:\"s\",type:\"shell\",status:\"running\"}]}" | sh "$2/stop-guard.sh"' _ "$W" "$S"
has out block "셸 작업은 허용 사유 아님"
expect 2 "대소문자만 바꾼 이름도 차단" hook guard.sh "$W" "$W/src/A.TEST.TS"
mv "$R/.claude/multisession-tdd.json" "$T/cfg.bak"
expect 2 "설정 없으면 판정 불가로 차단" hook guard.sh "$W" "$W/src/app.ts"
mv "$T/cfg.bak" "$R/.claude/multisession-tdd.json"

echo "# testdiff.sh"
expect 0 "UNCHANGED" in_dir "$W" sh "$S/testdiff.sh"
echo '// x' >> "$W/src/a.test.ts"
expect 1 "워킹트리 변경 → CHANGED" in_dir "$W" sh "$S/testdiff.sh"
git -C "$W" commit -qam "sneak"
expect 1 "커밋된 변경 → CHANGED" sh "$S/testdiff.sh" -C "$W"
has out '커밋된 변경' "CHANGED 사유"
git -C "$W" reset -q --hard HEAD~1
expect 0 "되돌리면 UNCHANGED" sh "$S/testdiff.sh" -C "$W"
expect 2 "없는 sha는 검사 불가(2)" sh "$S/testdiff.sh" -C "$W" deadbeef
expect 2 "HEAD~99도 검사 불가(2)" sh "$S/testdiff.sh" -C "$W" 'HEAD~99'
expect 1 "머지가 아닌 커밋으로 redsha 거부" in_dir "$W" sh "$S/phase.sh" redsha HEAD --note "merge origin/main"
echo 'export const b = 2' > "$R/src/b.ts"; git -C "$R" add src/b.ts; git -C "$R" commit -qm "base 진행"; git -C "$R" push -q origin main
git -C "$W" fetch -q origin && git -C "$W" merge -q --no-edit origin/main
expect 0 "머지 커밋으로 redsha 갱신" in_dir "$W" sh "$S/phase.sh" redsha HEAD --note "merge origin/main"
has out 'MERGE: old redSha=' "redsha 기록 형식"
expect 0 "redsha --force(기록 남김)" in_dir "$W" sh "$S/phase.sh" redsha HEAD --note "rebase" --force
expect 0 "패킷에 RED sha 이력" in_dir "$W" sh "$S/gate.sh" prepare GATE2 --resend
grep -q 'RED sha 이력' "$(cat "$T/out")" && grep -q 'FORCED' "$(cat "$T/out")" && ok "이력·FORCED 표기" || ng "이력 누락"
expect 1 "모르는 단계 거부(--force여도)" in_dir "$W" sh "$S/phase.sh" set green --force
expect 0 "GREEN→RED_REOPEN" in_dir "$W" sh "$S/phase.sh" set RED_REOPEN
expect 0 "RED_REOPEN→GREEN(기각)" in_dir "$W" sh "$S/phase.sh" set GREEN

echo "# 스택 PR"
git -C "$W" push -q origin feature/7-login 2>/dev/null
expect 0 "선행 브랜치 위에 wt" in_dir "$R" sh "$S/wt.sh" 8 next feature/7-login
has out '스택 PR' "스택 안내"
W8="$T/repo-wt/8-next"
expect 0 "init(스택)" in_dir "$W8" sh "$S/phase.sh" init 8 --branch feature/8-next --plan p.md --review review --master 8-next
expect 0 "show" in_dir "$W8" sh "$S/phase.sh" show
has out 'origin/feature/7-login' "base = 선행 브랜치(원격 보정)"
expect 0 "base 전환" in_dir "$W8" sh "$S/phase.sh" base main
has out 'origin/feature/7-login → origin/main' "base 전환 기록"

echo "# 악성 설정"
cp "$R/.claude/multisession-tdd.json" "$T/cfg.good"
jq '.base="--upload-pack=touch PWNED;false #/main"' "$T/cfg.good" > "$R/.claude/multisession-tdd.json"
expect 1 "옵션 주입 base는 check 실패" in_dir "$R" sh "$S/config.sh" check
expect 1 "옵션 주입 base로 wt 거부" in_dir "$R" sh "$S/wt.sh" 11 evil
[ ! -e "$R/PWNED" ] && ok "주입 명령 미실행" || ng "주입 명령 실행됨"
mkdir -p "$T/outside"; echo secret > "$T/outside/id"
jq '.copyOnWorktree=["../outside/id"] | .planGlob=["/'"${T#/}"'/outside/*"]' "$T/cfg.good" > "$R/.claude/multisession-tdd.json"
expect 1 "저장소 밖 경로는 check 실패" in_dir "$R" sh "$S/config.sh" check
expect 0 "wt는 밖 경로를 건너뛴다" in_dir "$R" sh "$S/wt.sh" 12 safe
if [ -e "$T/repo-wt/outside/id" ]; then ng "워크트리 루트 밖으로 씀"; else ok "밖으로 쓰지 않음"; fi
[ -z "$(git -C "$T/repo-wt/12-safe" status --porcelain)" ] && ok "밖 파일을 들여오지 않음" || ng "밖 파일 유입: $(git -C "$T/repo-wt/12-safe" status --porcelain)"
jq '.worktreeRoot="../$(touch PWNED2)-wt"' "$T/cfg.good" > "$R/.claude/multisession-tdd.json"
expect 1 "worktreeRoot 메타문자는 check 실패" in_dir "$R" sh "$S/config.sh" check
expect 1 "worktreeRoot 메타문자로 wt 거부" in_dir "$R" sh "$S/wt.sh" 13 meta
cp "$T/cfg.good" "$R/.claude/multisession-tdd.json"
expect 0 "링크된 워크트리에서도 wt.sh 동작" in_dir "$T/repo-wt/12-safe" sh "$S/wt.sh" 14 from-linked
mkdir -p "$T/repo-wt/7/login" && git init -q "$T/repo-wt/7/login"
expect 0 "키 충돌 없음(7/login ≠ 7-login)" stop "$T/repo-wt/7/login" false
hasnt out block "다른 저장소는 막지 않음"

echo "# wt rm"
expect 1 "진행 중이면 rm 거부" in_dir "$R" sh "$S/wt.sh" rm 7-login
expect 0 "--force rm" in_dir "$R" sh "$S/wt.sh" rm 7-login --force
[ ! -d "$W" ] && ok "워크트리 제거" || ng "워크트리 제거"
git -C "$R" rev-parse -q --verify feature/7-login >/dev/null && ok "브랜치는 남김" || ng "브랜치 보존"
expect 0 "기존 브랜치에 다시 붙이기" in_dir "$R" sh "$S/wt.sh" 7 login
has out '다시 붙였다' "재부착 안내"
expect 0 "rm 뒤 낡은 상태 없음(stop)" stop "$W" false
hasnt out block "재생성 워크트리는 막지 않음"
expect 0 "rm 뒤 context 배너 없음" hook context.sh "$W"
hasnt out 상태 "배너 없음"
echo new > "$W/untracked.txt"
expect 1 "추적 안 된 파일이 있으면 rm 거부" in_dir "$R" sh "$S/wt.sh" rm 7-login
git -C "$W" checkout -q --detach
expect 0 "detached HEAD도 --force --delete-branch로 정리" in_dir "$R" sh "$S/wt.sh" rm 7-login --force --delete-branch
[ ! -d "$W" ] && ok "detached 워크트리 제거" || ng "detached 워크트리 제거"
echo "# 같은 이슈 재시작"
expect 0 "rm 뒤 재부착한 워크트리 없음 → 다시 만들기" in_dir "$R" sh "$S/wt.sh" 7 login
expect 0 "재init" in_dir "$W" sh "$S/phase.sh" init 7 --branch feature/7-login --plan p.md --review review --master 7-login
expect 0 "재시작 뒤 RED" in_dir "$W" sh "$S/phase.sh" set RED
in_dir "$W" sh "$S/phase.sh" set GATE1 >/dev/null
expect 0 "새 패킷" in_dir "$W" sh "$S/gate.sh" prepare GATE1
hasnt out '/01-GATE1.md' "이전 판정과 번호가 겹치지 않음"
echo "# 추가 경계"
git init -q --bare -b main "$T/origin2.git"; git clone -q "$T/origin2.git" "$T/repo2" 2>/dev/null
mkdir -p "$T/repo2/.claude"; cp "$T/cfg.good" "$T/repo2/.claude/multisession-tdd.json"
[ "$(in_dir "$R" sh "$S/config.sh" gates)" != "$(in_dir "$T/repo2" sh "$S/config.sh" gates)" ] && ok "저장소마다 게이트 폴더 분리" || ng "게이트 폴더 공유"
touch "$G7/09-GATE2.md"
expect 0 "폴더에 있는 번호는 건너뜀" in_dir "$W" sh "$S/gate.sh" prepare GATE1
has out '/10-GATE1.md' "seq = 폴더 최대 + 1"
in_dir "$W" sh "$S/phase.sh" set GREEN >/dev/null
echo 'x' > "$W/side.txt"; git -C "$W" add side.txt; git -C "$W" commit -qm side
git -C "$W" checkout -q -b side-branch HEAD~1; echo y > "$W/other.txt"; git -C "$W" add other.txt; git -C "$W" commit -qm other
git -C "$W" checkout -q feature/7-login; git -C "$W" merge -q --no-edit side-branch
expect 1 "base가 아닌 브랜치를 합친 머지로 redsha 거부" in_dir "$W" sh "$S/phase.sh" redsha HEAD --note "merge side"
expect 0 "GATE1 강제 재설정" in_dir "$W" sh "$S/phase.sh" set GATE1 --force
expect 0 "재설정 뒤 패킷" in_dir "$W" sh "$S/gate.sh" prepare GATE1
grep -q 'GATE1 재설정' "$(cat "$T/out")" && ok "GATE1 재설정이 RED sha 이력에" || ng "재설정 이력 누락"
in_dir "$W" sh "$S/phase.sh" set GREEN --force >/dev/null
expect 0 "stop: 셸+서브에이전트 섞이면 통과(GREEN)" sh -c 'jq -n --arg c "$1" "{cwd:\$c, stop_hook_active:false, background_tasks:[{id:\"s\",type:\"shell\"},{id:\"a\",type:\"subagent\"}]}" | sh "$2/stop-guard.sh"' _ "$W" "$S"
hasnt out block "섞인 경우 허용"
[ "$(env -u MSTDD_HOME XDG_STATE_HOME=rel sh "$S/config.sh" root)" = "$HOME/.local/state/multisession-tdd" ] && ok "상대 XDG_STATE_HOME 무시" || ng "상대 XDG 처리"
[ "$(env -u MSTDD_HOME XDG_STATE_HOME=/x/y sh "$S/config.sh" root)" = "/x/y/multisession-tdd" ] && ok "절대 XDG_STATE_HOME 사용" || ng "절대 XDG 처리"
mkdir -p "$T/repo-wt/12-safe/sub/dir"
expect 0 "링크된 워크트리 하위 폴더에서 wt.sh" in_dir "$T/repo-wt/12-safe/sub/dir" sh "$S/wt.sh" 15 from-sub
if command -v dash >/dev/null 2>&1; then
  expect 1 "dash: 인수 없는 config.sh는 사용법(1)" in_dir "$R" dash "$S/config.sh"
fi

echo
echo "결과: 통과 $pass · 실패 $fail"
[ "$fail" -eq 0 ]
