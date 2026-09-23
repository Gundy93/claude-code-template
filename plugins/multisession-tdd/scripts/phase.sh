#!/bin/sh
# 상태 변경의 유일한 경로. cwd(=$PWD) 기준 상태 디렉토리를 쓴다.
#   phase.sh init <issue> --branch B --plan P --review R --master M [--worktree W] [--base <원격>/<브랜치>]
#     --base 생략 시 wt.sh가 남긴 state/<key>/base, 그것도 없으면 설정 base
#   phase.sh set <PHASE> [--force] [--note "..."]
#   phase.sh wait "<사유>"            대기 선언 — Stop 훅이 한 번 통과시키고 지운다
#   phase.sh base <원격>/<브랜치>      스택 PR의 선행이 머지된 뒤 base 전환
#   phase.sh redsha <sha> --note "..." [--force]  base를 merge한 뒤 새 RED 기준(동결 기준점)
#     <sha>는 이전 redSha를 조상으로 둔 머지 커밋이어야 한다. rebase 등은 --force(로그·패킷에 남는다)
#   phase.sh get | show | status | clear
set -u
. "$(dirname "$0")/lib.sh"
sd=$(state_dir "$PWD"); sj="$sd/session.json"
usage() { sed -n '2,10p' "$0" | grep '^#'; exit 1; }
need() { [ -f "$sj" ] && [ -f "$sd/phase" ] || die "활성 상태 없음: $sd (phase.sh init 먼저)"; }
log() { printf '%s  %s\n' "$(now_iso)" "$1" >> "$sd/log"; }
head_sha() { git -C "$PWD" rev-parse HEAD 2>/dev/null || echo ""; }
val() { [ $# -ge 2 ] || die "$1 뒤에 값이 필요하다"; }
PHASES="INIT RED GATE1 GREEN GATE2 REFACTOR REVIEW GATE3 PR DONE RED_REOPEN HALT"
known() { for p in $PHASES; do [ "$p" = "$1" ] && return 0; done; return 1; }

allowed() {
  case "$1:$2" in
    INIT:RED|RED:GATE1|GATE1:GREEN|GATE1:RED|GREEN:GATE2|GATE2:REFACTOR|GATE2:GREEN|REFACTOR:REVIEW|REVIEW:GATE3|GATE3:PR|GATE3:REVIEW|PR:DONE) return 0 ;;
    GREEN:RED_REOPEN|REFACTOR:RED_REOPEN|REVIEW:RED_REOPEN|RED_REOPEN:RED|RED_REOPEN:GREEN|RED_REOPEN:REFACTOR|RED_REOPEN:REVIEW) return 0 ;;
    PR:REVIEW|DONE:REVIEW) return 0 ;;   # 발행 뒤 리뷰 반영 — 수정은 REVIEW(동결)에서 하고 GATE-3을 다시 받는다
    *:HALT) return 0 ;;
  esac
  return 1
}

cmd=${1:-}; [ -n "$cmd" ] || usage; shift
case "$cmd" in
  init)
    issue=${1:-}; [ -n "$issue" ] || usage; shift
    valid_id "$issue" || die "이슈는 영숫자와 . _ - 만(-로 시작 불가): $issue"
    need_config "$PWD"
    branch=""; plan=""; review=""; master=""; wt=$(top_of "$PWD"); base=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --branch) val "$@"; branch=$2; shift 2 ;; --plan) val "$@"; plan=$2; shift 2 ;; --review) val "$@"; review=$2; shift 2 ;;
        --master) val "$@"; master=$2; shift 2 ;; --worktree) val "$@"; wt=$2; shift 2 ;; --base) val "$@"; base=$2; shift 2 ;;
        *) die "모르는 인수 $1" ;;
      esac
    done
    [ -n "$branch" ] && [ -n "$plan" ] && [ -n "$review" ] && [ -n "$master" ] || die "--branch --plan --review --master 필수"
    if [ -f "$sj" ] && [ -f "$sd/phase" ]; then
      cur=$(json_get "$sj" phase)
      case "$cur" in DONE|HALT|"") ;; *) die "이미 진행 중(phase=$cur). phase.sh status 로 확인하거나 set HALT 뒤에 init." ;; esac
    fi
    mkdir -p "$sd"
    # 같은 이슈를 다시 시작해도 이전 패킷·판정과 번호가 겹치지 않게 seq를 이어 간다
    seq0=$(max_seq "$(gates_dir "$PWD")/$issue")
    [ -z "$base" ] && [ -f "$sd/base" ] && base=$(cat "$sd/base")
    [ -z "$base" ] && base=$(cfg_base "$PWD")
    base=$(norm_base "$base" "$PWD") || exit 1
    jq -n --arg issue "$issue" --arg branch "$branch" --arg plan "$plan" --arg review "$review" \
          --arg master "$master" --arg wt "$wt" --arg base "$base" --arg ts "$(now_iso)" \
          --argjson seq "$seq0" \
          '{issue:$issue, branch:$branch, base:$base, phase:"INIT", redSha:"", greenSha:"", gateSeq:$seq, planPath:$plan, reviewSession:$review, masterSession:$master, worktree:$wt, updatedAt:$ts}' > "$sj"
    printf 'INIT\n' > "$sd/phase"
    rm -f "$sd/waiting" "$sd/stop-blocks"
    log "init issue=$issue branch=$branch base=$base master=$master review=$review gateSeq=$seq0"
    echo "초기화: $sd (issue $issue, INIT, base $base)"
    ;;
  set)
    need; new=${1:-}; [ -n "$new" ] || usage; shift
    known "$new" || die "모르는 단계: $new ($PHASES)"
    force=0; note=""
    while [ $# -gt 0 ]; do case "$1" in --force) force=1; shift ;; --note) val "$@"; note=$2; shift 2 ;; *) die "모르는 인수 $1" ;; esac; done
    cur=$(json_get "$sj" phase)
    if [ $force -eq 0 ]; then
      if [ "$cur" = HALT ] || ! allowed "$cur" "$new"; then
        die "전이 거부: $cur → $new (허용 전이가 아니다. 의도한 것이면 --force)"
      fi
    fi
    sha=$(head_sha)
    ored=$(json_get "$sj" redSha)
    if [ "$new" = GATE1 ] && [ -n "$ored" ] && [ "$ored" != "$sha" ]; then
      log "redSha $ored → $sha note=GATE1 재설정${note:+ $note}$([ $force -eq 1 ] && printf ' FORCED')"
    fi
    json_update "$sj" --arg p "$new" --arg ts "$(now_iso)" --arg sha "$sha" '
      .phase=$p | .updatedAt=$ts
      | (if $p=="GATE1" then .redSha=$sha else . end)
      | (if $p=="GATE2" then .greenSha=$sha else . end)' || die "session.json 갱신 실패"
    printf '%s\n' "$new" > "$sd/phase"
    log "${cur}→${new} head=${sha} ${note:+note=$note}$([ $force -eq 1 ] && printf ' FORCED')"
    rm -f "$sd/waiting" "$sd/stop-blocks"
    echo "$cur → $new (HEAD $sha)"
    ;;
  wait)
    need; reason=${1:-}; [ -n "$reason" ] || die "사유 필수: phase.sh wait \"자원 승인 대기\""
    printf '%s\n' "$reason" > "$sd/waiting"; log "wait: $reason"; echo "대기 선언: $reason"
    ;;
  base)
    need; nb=$(norm_base "${1:?새 base}" "$PWD") || exit 1; ob=$(json_get "$sj" base)
    git -C "$PWD" rev-parse --verify -q --end-of-options "$nb" >/dev/null || die "$nb 가 없다(fetch 먼저)"
    json_update "$sj" --arg b "$nb" --arg ts "$(now_iso)" '.base=$b | .updatedAt=$ts' || die "session.json 갱신 실패"
    log "base $ob → $nb"; echo "base: $ob → $nb"
    ;;
  redsha)
    need; ns=${1:-}; [ -n "$ns" ] || usage; shift
    note=""; force=0
    while [ $# -gt 0 ]; do case "$1" in --note) val "$@"; note=$2; shift 2 ;; --force) force=1; shift ;; *) die "모르는 인수 $1" ;; esac; done
    [ -n "$note" ] || die "--note 필수(예: \"merge origin/main\")"
    full=$(git -C "$PWD" rev-parse --verify -q --end-of-options "$ns^{commit}") || die "커밋이 아니다: $ns"
    os=$(json_get "$sj" redSha); [ -n "$os" ] || die "redSha가 아직 없다(GATE1 이전)"
    if [ $force -eq 0 ]; then
      np=$(git -C "$PWD" rev-list --parents -n 1 "$full" | wc -w)
      [ "$np" -ge 3 ] || die "머지 커밋이 아니다: $full (rebase였다면 --force — 패킷에 기록된다)"
      git -C "$PWD" merge-base --is-ancestor "$os" "$full" || die "이전 redSha $os 가 $full 의 조상이 아니다"
      # 합친 쪽(두 번째 이후 부모)은 base 브랜치의 커밋이어야 한다 — 다른 브랜치를 합쳐 기준점을 옮기지 못하게
      b=$(json_get "$sj" base)
      for p in $(git -C "$PWD" rev-list --parents -n 1 "$full" | cut -d' ' -f3-); do
        git -C "$PWD" merge-base --is-ancestor "$p" "$b" 2>/dev/null || die "합친 커밋 $p 가 base $b 에 없다(base를 fetch했는지 확인)"
      done
    else note="FORCED $note"; fi
    json_update "$sj" --arg s "$full" --arg ts "$(now_iso)" '.redSha=$s | .updatedAt=$ts' || die "session.json 갱신 실패"
    log "redSha $os → $full note=$note"; echo "MERGE: old redSha=$os, new redSha=$full$([ $force -eq 1 ] && printf ' (FORCED)')"
    ;;
  get) need; cat "$sd/phase" ;;
  show) need; jq . "$sj" ;;
  status)
    need; jq . "$sj"
    issue=$(json_get "$sj" issue); gd="$(gates_dir "$PWD")/$issue"
    echo "--- gates/$issue"; ls -1 "$gd" 2>/dev/null || echo "(없음)"
    echo "--- log 마지막 5줄"; tail -n 5 "$sd/log" 2>/dev/null
    ;;
  clear)
    need; cur=$(json_get "$sj" phase)
    case "$cur" in DONE|HALT) rm -f "$sd/phase" "$sd/waiting" "$sd/stop-blocks"; log "clear"; echo "phase 파일 삭제(session.json·log 보존)";;
      *) die "DONE/HALT에서만 clear 가능(현재 $cur)" ;; esac
    ;;
  *) usage ;;
esac
