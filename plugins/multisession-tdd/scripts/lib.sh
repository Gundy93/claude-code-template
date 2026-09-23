#!/bin/sh
# multisession-tdd 공통 함수. 다른 스크립트가 `. "$(dirname "$0")/lib.sh"`로 읽는다.
# 상태·패킷 루트. 플러그인 데이터 디렉토리나 ~/.claude 아래가 아닌 이유는 README "상태와 기록" 참조.
case "${XDG_STATE_HOME:-}" in /*) _xdg=$XDG_STATE_HOME ;; *) _xdg=$HOME/.local/state ;; esac   # 상대 경로는 무시(명세)
ROOT="${MSTDD_HOME:-$_xdg/multisession-tdd}"
CONFIG_REL=".claude/multisession-tdd.json"
unset CDPATH

die() { printf '%s\n' "$*" >&2; exit 1; }

# 존재하는 가장 가까운 상위 디렉토리
existing_dir() {
  d="$1"
  while [ ! -d "$d" ] && [ "$d" != "/" ]; do d=$(dirname "$d"); done
  printf '%s' "$d"
}

# 디렉토리 → git toplevel(없으면 그 경로)
top_of() {
  d=$(existing_dir "$1")
  git -C "$d" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$d"
}
# 경로 → 상태 키. 서로 다른 경로가 같은 키가 되지 않게 %와 -를 먼저 이스케이프한다.
key_of() { printf '%s' "$1" | sed -e 's#%#%25#g' -e 's#-#%2D#g' -e 's#/#-#g'; }
cwd_key() { key_of "$(top_of "$1")"; }
state_dir() { printf '%s/state/%s' "$ROOT" "$(cwd_key "$1")"; }
# 활성 상태: phase 파일이 있을 때만(wt.sh rm·phase.sh clear가 지운다)
active_state() { [ -f "$(state_dir "$1")/phase" ]; }

# 디렉토리 → main 워크트리 루트. 링크된 워크트리에서도 main을 가리킨다. bare 저장소는 실패.
main_root_of() {
  d=$(existing_dir "$1")
  gd=$(git -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null) || return 1
  gcd=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  if [ "$gd" = "$gcd" ]; then git -C "$d" rev-parse --show-toplevel 2>/dev/null; return; fi
  w=$(git --git-dir="$gcd" config --get core.worktree 2>/dev/null || true)   # 서브모듈의 링크된 워크트리
  if [ -n "$w" ]; then (cd "$gcd" && cd "$w" && pwd -P); else dirname "$gcd"; fi
}

# 저장소 식별자(이름-경로 해시)와 그 저장소의 게이트 폴더. 저장소마다 패킷·판정을 분리한다
# — 두 저장소가 같은 이슈 번호를 써도 판정이 섞이지 않는다.
repo_id() { m=$(main_root_of "$1") || return 1; printf '%s-%s' "$(basename "$m" | tr -c 'A-Za-z0-9._-' '_')" "$(printf '%s' "$m" | cksum | cut -d' ' -f1)"; }
gates_dir() { r=$(repo_id "$1") || return 1; printf '%s/gates/%s' "$ROOT" "$r"; }
# 폴더 안에서 가장 큰 패킷 번호(NN-*.md), 없으면 0
max_seq() { n=$(ls -1 "$1" 2>/dev/null | sed -n 's/^\([0-9][0-9]*\)-.*/\1/p' | sed 's/^0*//' | sort -n | tail -n 1); printf '%s' "${n:-0}"; }

# 설정 파일 경로와 값. 설정은 main 워크트리의 한 파일이다(커밋하지 않아도 모든 워크트리가 같은 값을 본다).
config_file() { r=$(main_root_of "$1") || return 1; printf '%s/%s' "$r" "$CONFIG_REL"; }
has_config() { f=$(config_file "$1") && [ -f "$f" ]; }
# cfg <dir> <jq 필터> — 없으면 빈 출력. 배열은 '.key[]?'로 한 줄에 하나씩.
cfg() {
  f=$(config_file "$1") || return 0
  [ -f "$f" ] || return 0
  jq -r "($2) // empty" "$f" 2>/dev/null
}
need_config() { has_config "$1" || die "설정 없음: $(config_file "$1" 2>/dev/null || echo "$1 (git 저장소 아님)") — config.sh init 뒤 값을 채운다"; }

# 식별자(이슈·slug)와 저장소 상대 경로 검사. 설정은 저장소가 주는 값이라 믿지 않는다.
# 셸 메타문자가 없는 경로(안내 출력에 그대로 붙여 넣어도 안전)
plain_path() { case "$1" in *[\$\`\;\|\&\<\>\'\"\\]*) return 1 ;; esac; }
valid_id() { case "$1" in ''|-*|*[!A-Za-z0-9._-]*) return 1 ;; esac; }
safe_rel() { case "$1" in ''|/*|'~'*|..|../*|*/..|*/../*) return 1 ;; esac; }

# 설정 base(예: origin/main). 원격 이름은 그 앞부분이며, 실제로 있는 원격이어야 한다.
cfg_base() { b=$(cfg "$1" '.base'); printf '%s' "${b:-origin/main}"; }
remote_of() { b=$(cfg_base "$1"); printf '%s' "${b%%/*}"; }
check_remote() {
  r=$(remote_of "$1")
  case "$r" in ''|-*) die "base의 원격 이름이 잘못됐다: $r" ;; esac
  git -C "$(existing_dir "$1")" remote get-url -- "$r" >/dev/null 2>&1 || die "원격 $r 이 없다(설정 base 확인)"
}
# 원격 브랜치 이름만 주면 원격을 붙인다(feature/x → origin/feature/x).
norm_base() {
  r=$(remote_of "$2")
  case "$1" in -*) die "base가 -로 시작한다: $1" ;; esac
  case "$1" in "$r"/*) printf '%s' "$1" ;; *) printf '%s/%s' "$r" "$1" ;; esac
}

# sed 치환 문자열 이스케이프
sed_repl() { printf '%s' "$1" | sed 's/[&#\\]/\\&/g'; }

# 브랜치 패턴 {issue}·{slug} 치환
render_branch() {
  valid_id "$2" && valid_id "$3" || die "이슈·slug는 영숫자와 . _ - 만(-로 시작 불가): $2 $3"
  p=$(cfg "$1" '.branch'); [ -n "$p" ] || p='feature/{issue}-{slug}'
  printf '%s' "$p" | sed -e "s#{issue}#$2#g" -e "s#{slug}#$3#g"
}

# 워크트리 루트 — {repo}는 main 루트 이름, 상대 경로는 main 루트 기준, ~/ 허용
wt_root() {
  main=$(main_root_of "$1") || return 1
  p=$(cfg "$1" '.worktreeRoot'); [ -n "$p" ] || p='../{repo}-wt'
  p=$(printf '%s' "$p" | sed "s#{repo}#$(sed_repl "$(basename "$main")")#g")
  case "$p" in "~/"*) p="$HOME/${p#\~/}" ;; /*) ;; *) p="$main/$p" ;; esac
  printf '%s' "$p"
}

# 글롭 하나를 저장소 상대 경로에 대조한다. git glob에 맞추려고 **는 *로 읽고,
# **/가 0단계 디렉토리도 뜻하는 경우(맨 앞 **/, 가운데 /**/)를 따로 한 번 더 본다.
# case 패턴의 *는 /도 넘으므로 git보다 넓게 잡는다(막는 쪽으로만 어긋난다).
match_glob() {
  for pat in "$(printf '%s' "$2" | sed 's#\*\*#*#g')" \
             "$(printf '%s' "$2" | sed -e 's#^\*\*/##' -e 's#/\*\*/#/#g' -e 's#\*\*#*#g')"; do
    # shellcheck disable=SC2254
    case "$1" in $pat) return 0 ;; esac
  done
  return 1
}

# 테스트 경로 판정(동결 대상) — is_test_path <절대 경로> <작업 트리 루트>
# 상대 경로는 git이 정한다(--show-prefix) — 심볼릭 링크·대소문자·./ 표기가 달라도 같은 경로가 된다.
# 반환: 0 테스트 경로(또는 판정 불가한 . / .. 표기) / 1 아님 / 2 설정 없음
is_test_path() {
  has_config "$2" || return 2
  globs=$(cfg "$2" '.testGlobs[]?')
  [ -n "$globs" ] || return 2
  d=$(existing_dir "$(dirname "$1")")
  prefix=$(git -C "$d" rev-parse --show-prefix 2>/dev/null) || return 1
  rest=${1#"$d"}; rest=${rest#/}
  case "/$rest/" in */./*|*/../*) return 0 ;; esac
  # 대소문자를 구분하지 않는 저장소(core.ignorecase)에서는 표기만 바꾼 우회를 막으려고 소문자로 비교한다.
  lc=cat; [ "$(git -C "$d" config --get core.ignorecase 2>/dev/null)" = true ] && lc=lower
  rel=$(printf '%s' "$prefix$rest" | $lc)
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    g=$(printf '%s' "$g" | $lc)
    match_glob "$rel" "$g" && return 0
  done <<EOF
$globs
EOF
  return 1
}

lower() { tr '[:upper:]' '[:lower:]'; }
json_get() { jq -r --arg k "$2" '.[$k] // empty' "$1" 2>/dev/null; }
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
# session.json을 같은 디렉토리의 임시 파일로 고쳐 쓴다(원자적 mv). 실패하면 원본을 남긴다.
json_update() {
  f=$1; shift
  tmp=$(mktemp "$(dirname "$f")/.sj.XXXXXX") || return 1
  if jq "$@" "$f" > "$tmp"; then mv "$tmp" "$f"; else rm -f "$tmp"; return 1; fi
}
# 디렉토리 잠금(동시에 두 세션이 seq를 올리는 것을 막는다)
lock() { n=0; until mkdir "$1" 2>/dev/null; do n=$((n+1)); [ $n -lt 50 ] || die "잠금 대기 초과: $1"; sleep 0.1; done; }
unlock() { rmdir "$1" 2>/dev/null || true; }
