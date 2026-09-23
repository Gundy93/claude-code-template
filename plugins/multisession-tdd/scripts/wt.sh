#!/bin/sh
# 이슈용 worktree 생성/제거. main 워크트리(또는 그 아래)에서 실행한다.
#   wt.sh <issue> <slug> [base]          → <worktreeRoot>/<issue>-<slug>, 브랜치는 설정 branch 패턴
#                                          base 생략 = 설정 base. 스택 PR이면 선행 PR 브랜치(원격 이름은 자동 보정)
#                                          브랜치가 이미 있으면 새로 만들지 않고 그 브랜치에 다시 붙인다
#   wt.sh rm <issue>-<slug> [--force] [--delete-branch]
set -eu
. "$(dirname "$0")/lib.sh"
REPO=$(main_root_of "$PWD") || die "git 저장소(bare 아님) 안에서 실행하라"
need_config "$REPO"
check_remote "$REPO"
WTROOT=$(wt_root "$REPO")
plain_path "$WTROOT" || die "worktreeRoot에 셸 메타문자를 쓸 수 없다: $WTROOT"
[ -d "$WTROOT" ] && WTROOT=$(cd "$WTROOT" && pwd -P)
plain_path "$WTROOT" || die "워크트리 루트 경로에 셸 메타문자가 있다: $WTROOT"

if [ "${1:-}" = rm ]; then
  name=${2:?이름}; shift 2; force=0; delbr=0
  for a in "$@"; do case "$a" in --force) force=1 ;; --delete-branch) delbr=1 ;; *) die "모르는 인수 $a" ;; esac; done
  wt="$WTROOT/$name"; [ -d "$wt" ] || die "워크트리 없음: $wt"
  sd=$(state_dir "$wt"); sj="$sd/session.json"
  if [ -f "$sd/phase" ] && [ $force -eq 0 ]; then
    p=$(cat "$sd/phase"); case "$p" in DONE|HALT) ;; *) die "phase=$p (진행 중). 정말 지우려면 --force" ;; esac
  fi
  if [ -n "$(git -C "$wt" status --porcelain --untracked-files=no)" ]; then
    git -C "$wt" status --short --untracked-files=no >&2
    die "추적 파일에 커밋되지 않은 변경이 있다. 커밋하거나 되돌린 뒤 다시 실행."
  fi
  untracked=$(git -C "$wt" status --porcelain --untracked-files=normal | sed -n 's/^?? //p')
  if [ -n "$untracked" ]; then
    printf '%s\n' "$untracked" | sed 's/^/  /' >&2
    [ $force -eq 1 ] || die "추적되지 않은 파일이 있다(위 목록). 옮기거나 지운 뒤 다시 실행하거나, 함께 지우려면 --force"
    echo "경고: 위 추적되지 않은 파일도 함께 지운다" >&2
  fi
  br=$(git -C "$wt" symbolic-ref -q --short HEAD || true)
  # 상태를 먼저 비활성화한다 — 같은 경로에 다시 만든 워크트리가 낡은 상태를 이어받지 않게
  if [ -f "$sj" ]; then json_update "$sj" --arg ts "$(now_iso)" '.phase="HALT" | .updatedAt=$ts' || true; fi
  rm -f "$sd/phase" "$sd/waiting" "$sd/stop-blocks"
  [ -d "$sd" ] && printf '%s  wt rm (force=%s)\n' "$(now_iso)" "$force" >> "$sd/log"
  git -C "$REPO" worktree remove --force "$wt"
  if [ $delbr -eq 1 ] && [ -n "$br" ]; then git -C "$REPO" branch -D -- "$br"
  elif [ $delbr -eq 1 ]; then echo "detached HEAD라 지울 브랜치가 없다"
  elif [ -n "$br" ]; then echo "브랜치 $br 는 남겼다(지우려면 --delete-branch)"; fi
  echo "제거: $wt"; exit 0
fi

issue=${1:?이슈}; slug=${2:?slug}
valid_id "$issue" && valid_id "$slug" || die "이슈·slug는 영숫자와 . _ - 만(-로 시작 불가)"
cfgbase=$(norm_base "$(cfg_base "$REPO")" "$REPO")
remote=${cfgbase%%/*}
name="$issue-$slug"; wt="$WTROOT/$name"; br=$(render_branch "$REPO" "$issue" "$slug")
[ -e "$wt" ] && die "이미 있다: $wt"
git -C "$REPO" fetch --prune -- "$remote"
sd=$(state_dir "$wt")   # 워크트리가 아직 없으므로 경로 그대로의 키 — 생성 뒤 다시 구한다
if git -C "$REPO" show-ref --verify -q "refs/heads/$br"; then
  mkdir -p "$WTROOT"; WTROOT=$(cd "$WTROOT" && pwd -P); wt="$WTROOT/$name"; plain_path "$wt" || die "워크트리 경로에 셸 메타문자가 있다: $wt"
  git -C "$REPO" worktree add -- "$wt" "$br"
  sd=$(state_dir "$wt"); mkdir -p "$sd"
  if [ -n "${3:-}" ]; then base=$(norm_base "$3" "$REPO"); printf '%s\n' "$base" > "$sd/base"
  elif [ -f "$sd/base" ]; then base=$(cat "$sd/base")
  else base=$cfgbase; printf '%s\n' "$base" > "$sd/base"; fi
  echo "기존 브랜치 $br 에 다시 붙였다(base $base — 다르면 세 번째 인수로 준다)"
else
  base=$(norm_base "${3:-$cfgbase}" "$REPO")
  # 원격에 없는 base는 쓸 수 없다(발행되지 않은 선행 브랜치 위에서는 시작하지 않는다).
  git -C "$REPO" rev-parse --verify -q --end-of-options "$base" >/dev/null || die "base $base 가 원격에 없다. 선행 PR 브랜치가 push됐는지 확인."
  mkdir -p "$WTROOT"; WTROOT=$(cd "$WTROOT" && pwd -P); wt="$WTROOT/$name"; plain_path "$wt" || die "워크트리 경로에 셸 메타문자가 있다: $wt"
  git -C "$REPO" worktree add -b "$br" -- "$wt" "$base"
  sd=$(state_dir "$wt"); mkdir -p "$sd"; printf '%s\n' "$base" > "$sd/base"   # phase.sh init이 읽는다
fi

# 추적되지 않는 파일(로컬 환경 파일, gitignore된 계획 문서)을 옮긴다. 저장소 밖 경로·심볼릭 링크는 거부한다.
copy_in() {
  src=$1; rel=${src#"$REPO"/}
  case "$src" in "$REPO"/*) ;; *) echo "건너뜀(저장소 밖): $src" >&2; return 0 ;; esac
  [ -f "$src" ] && [ ! -L "$src" ] || return 0
  [ -e "$wt/$rel" ] && return 0
  mkdir -p "$(dirname "$wt/$rel")"; cp "$src" "$wt/$rel"; echo "복사: $rel"
}
cfg "$REPO" '.copyOnWorktree[]?' | while IFS= read -r f; do
  [ -n "$f" ] || continue
  if safe_rel "$f"; then copy_in "$REPO/$f"; else echo "건너뜀(안전하지 않은 경로): $f" >&2; fi
done
cfg "$REPO" '.planGlob[]?' | sed "s#{issue}#$issue#g" | while IFS= read -r g; do
  [ -n "$g" ] || continue
  safe_rel "$g" || { echo "건너뜀(안전하지 않은 경로): $g" >&2; continue; }
  old_ifs=$IFS; IFS=''   # 글롭은 펼치되 공백으로 쪼개지 않는다
  for p in "$REPO"/$g; do IFS=$old_ifs; copy_in "$p"; done
  IFS=$old_ifs
done

cat <<MSG

worktree: $wt  (브랜치 $br, base $base @ $(git -C "$REPO" rev-parse --short --end-of-options "$base" 2>/dev/null || echo '?'))
마스터 세션:  cd '$wt' && claude -n $name   → 안에서 /multisession-tdd:tdd $issue
검토 세션:    /multisession-tdd:coordinator 를 부른 세션이 패킷을 받는다. phase.sh init --review 에 그 세션 이름을 준다.
MSG
if [ "$base" != "$cfgbase" ]; then cat <<MSG
스택 PR:      PR 발행 때 --base ${base#"$remote"/}. 선행 브랜치가 바뀌면 git merge $base (발행 뒤 force push 금지).
              선행 PR이 머지되면 git fetch && git merge $cfgbase 뒤 PR base가 ${cfgbase#"$remote"/}로 바뀌었는지 확인.
MSG
fi
