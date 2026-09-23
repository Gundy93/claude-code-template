#!/bin/sh
# RED sha 이후 테스트 경로(설정 testGlobs)가 바뀌지 않았는지(커밋 + 워킹트리) 검사한다.
#   testdiff.sh [RED_SHA] [-C <dir>]
# 종료 코드: 0 무변경 / 1 변경 있음 / 2 검사 불가(sha·설정·git 오류) — 2를 무변경으로 읽지 않는다.
set -u
. "$(dirname "$0")/lib.sh"
err() { printf 'TESTDIFF ERROR: %s\n' "$*" >&2; exit 2; }
dir="$PWD"; sha=""
while [ $# -gt 0 ]; do
  case "$1" in -C) [ $# -ge 2 ] || err "-C 뒤에 디렉토리"; dir=$2; shift 2 ;; *) sha=$1; shift ;; esac
done
if [ -z "$sha" ]; then
  sj="$(state_dir "$dir")/session.json"; [ -f "$sj" ] && sha=$(json_get "$sj" redSha)
fi
[ -n "$sha" ] || err "redSha 없음 — 인수로 주거나 GATE1 이후여야 한다"
has_config "$dir" || err "설정 없음: $(config_file "$dir" 2>/dev/null)"
git -C "$dir" rev-parse --verify -q --end-of-options "$sha^{commit}" >/dev/null || err "커밋이 아니다: $sha"
set --
while IFS= read -r g; do if [ -n "$g" ]; then set -- "$@" ":(glob)$g"; fi; done <<LIST
$(cfg "$dir" '.testGlobs[]?')
LIST
[ $# -gt 0 ] || err "testGlobs가 비어 있다"
committed=$(git -C "$dir" diff --stat --end-of-options "$sha" HEAD -- "$@") || err "git diff 실패"
dirty=$(git -C "$dir" status --porcelain -- "$@") || err "git status 실패"
if [ -z "$committed" ] && [ -z "$dirty" ]; then
  echo "TEST PATHS UNCHANGED since $sha"; exit 0
fi
echo "TEST PATHS CHANGED since $sha"
[ -n "$committed" ] && { echo "[커밋된 변경]"; printf '%s\n' "$committed"; }
[ -n "$dirty" ] && { echo "[워킹트리 변경]"; printf '%s\n' "$dirty"; }
exit 1
