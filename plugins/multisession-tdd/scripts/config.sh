#!/bin/sh
# 저장소 설정(.claude/multisession-tdd.json, main 워크트리)을 만들고 읽는다. cwd 기준.
#   config.sh init                 예시 파일을 복사한다(이미 있으면 거부). 값은 그 뒤에 채운다.
#   config.sh check                필수 키·형식 검사
#   config.sh path | show | root | gates   (root = 상태 루트, gates = 이 저장소의 패킷 폴더)
#   config.sh get <key>            문자열은 그대로, 배열은 한 줄에 하나씩
#   config.sh pathspecs [--exclude] [-z]  testGlobs → git pathspec(:(glob)… / :(exclude,glob)…), -z는 NUL 구분(xargs -0용)
#   config.sh branch <issue> <slug>
set -u
. "$(dirname "$0")/lib.sh"
cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  root) printf '%s\n' "$ROOT" ;;
  gates) gates_dir "$PWD" || die "git 저장소 안에서 실행하라"; echo ;;
  path) config_file "$PWD" || die "git 저장소 안에서 실행하라"; echo ;;
  init)
    f=$(config_file "$PWD") || die "git 저장소 안에서 실행하라"
    [ -f "$f" ] && die "이미 있다: $f (config.sh show)"
    mkdir -p "$(dirname "$f")"
    cp "$(dirname "$0")/../config.example.json" "$f"
    echo "$f" ;;
  show) need_config "$PWD"; jq . "$(config_file "$PWD")" ;;
  get)
    need_config "$PWD"; k=${1:?키}
    jq -r --arg k "$k" '.[$k] | if type == "array" then .[] elif type == "object" then tojson else (. // empty) end' "$(config_file "$PWD")" ;;
  pathspecs)
    need_config "$PWD"; magic="glob"; sep='\n'
    for a in "$@"; do case "$a" in --exclude) magic="exclude,glob" ;; -z) sep='\0' ;; *) die "모르는 인수 $a" ;; esac; done
    cfg "$PWD" '.testGlobs[]?' | while IFS= read -r g; do if [ -n "$g" ]; then printf ":(%s)%s$sep" "$magic" "$g"; fi; done ;;
  branch) need_config "$PWD"; render_branch "$PWD" "${1:?issue}" "${2:?slug}"; echo ;;
  check)
    need_config "$PWD"; f=$(config_file "$PWD"); bad=0
    jq empty "$f" 2>/dev/null || die "JSON 파싱 실패: $f"
    for k in checks testGlobs; do
      n=$(jq --arg k "$k" '.[$k] | if type == "array" then map(select(type == "string" and . != "")) | length else 0 end' "$f")
      [ "$n" -gt 0 ] || { echo "필수: $k — 비어 있지 않은 문자열 배열" >&2; bad=1; }
    done
    for k in base branch worktreeRoot; do
      [ -n "$(cfg "$PWD" ".$k")" ] || { echo "필수: $k" >&2; bad=1; }
    done
    wr=$(cfg "$PWD" '.worktreeRoot'); plain_path "$wr" || { echo "worktreeRoot에 셸 메타문자를 쓸 수 없다: $wr" >&2; bad=1; }
    br=$(cfg "$PWD" '.branch')
    case "$br" in *'{issue}'*'{slug}'*|*'{slug}'*'{issue}'*) ;; *) echo "branch에 {issue}와 {slug}가 모두 있어야 한다: $br" >&2; bad=1 ;; esac
    b=$(cfg "$PWD" '.base')
    case "$b" in -*|/*|*/) echo "base가 잘못됐다: $b" >&2; bad=1 ;; */*) ;; *) echo "base는 <원격>/<브랜치> 형식: $b" >&2; bad=1 ;; esac
    r=${b%%/*}; case "$r" in ''|-*) ;; *) git remote get-url -- "$r" >/dev/null 2>&1 || { echo "원격 $r 이 없다" >&2; bad=1; } ;; esac
    for k in copyOnWorktree planGlob; do
      cfg "$PWD" ".$k[]?" > "${TMPDIR:-/tmp}/mstdd-check.$$"
      while IFS= read -r v; do [ -z "$v" ] || safe_rel "$v" || { echo "$k: 저장소 안의 상대 경로여야 한다(/, ~, .. 불가): $v" >&2; bad=1; }; done < "${TMPDIR:-/tmp}/mstdd-check.$$"
      rm -f "${TMPDIR:-/tmp}/mstdd-check.$$"
    done
    cfg "$PWD" '.testGlobs[]?' | while IFS= read -r g; do
      case "$g" in */*) ;; *) echo "경고: testGlobs \"$g\"에 /가 없다 — git은 루트에서만, 훅은 모든 깊이에서 맞춘다. \"**/$g\"로 쓴다." >&2 ;; esac
    done
    [ $bad -eq 0 ] || exit 1
    echo "OK: $f" ;;
  *) sed -n '2,12p' "$0" | grep '^#'; exit 1 ;;
esac
