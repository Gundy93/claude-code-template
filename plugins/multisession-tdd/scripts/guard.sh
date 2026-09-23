#!/bin/sh
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit) 훅.
# 1) 파일이 다른 git toplevel(예: 검토 세션이 본 워크트리)에 있고 그쪽에 상태가 있으면 막는다 — 검토 세션은 읽기 전용.
# 2) 이 cwd에 상태가 있고 단계가 GREEN 이후면 테스트 경로(설정 testGlobs) 편집을 막는다(exit 2).
# 그 외(상태 없음·다른 트리의 상태 없는 파일)는 전부 exit 0 — 이 플러그인을 쓰지 않는 세션에 영향 없음.
set -u
. "$(dirname "$0")/lib.sh"
frozen() { case "$1" in GREEN|GATE2|REFACTOR|REVIEW|GATE3|PR|RED_REOPEN) return 0 ;; esac; return 1; }
input=$(cat 2>/dev/null) || exit 0
if ! command -v jq >/dev/null 2>&1; then
  # jq 없이는 입력을 읽을 수 없다. 동결 단계면 막는다(fail-closed), 아니면 통과.
  sd=$(state_dir "$PWD")
  if [ -f "$sd/phase" ] && frozen "$(cat "$sd/phase")"; then
    echo "[multisession-tdd] jq가 없어 편집 대상을 판정할 수 없다. jq를 설치하라." >&2; exit 2
  fi
  exit 0
fi
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null) || exit 0
[ -n "$cwd" ] && [ -n "$fp" ] || exit 0
case "$fp" in /*) ;; *) fp="$cwd/$fp" ;; esac

cwd_top=$(top_of "$cwd")
file_top=$(top_of "$(dirname "$fp")")

if [ "$file_top" != "$cwd_top" ]; then
  if active_state "$file_top"; then
    printf '[multisession-tdd] 이 세션(cwd %s)은 다른 작업 트리 %s 를 수정할 수 없다(검토 세션은 읽기 전용): %s\n' "$cwd_top" "$file_top" "$fp" >&2
    exit 2
  fi
  exit 0   # 이 작업 트리 밖의 파일(패킷·메모 등)은 동결 대상이 아니다
fi

sd=$(state_dir "$cwd_top")
[ -f "$sd/phase" ] || exit 0
phase=$(cat "$sd/phase")
frozen "$phase" || exit 0
is_test_path "$fp" "$cwd_top"; rc=$?
case $rc in
  1) exit 0 ;;
  2) printf '[multisession-tdd] 단계 %s 인데 설정(%s)이 없거나 testGlobs가 비어 테스트 경로를 판정할 수 없다. config.sh check 로 고친 뒤 다시 시도하라: %s\n' "$phase" "$CONFIG_REL" "$fp" >&2
     exit 2 ;;
esac
printf '[multisession-tdd] 단계 %s 에서는 테스트 경로를 수정할 수 없다(RED에서 동결된 스펙): %s\n테스트가 잘못됐다면 작업을 멈추고 출력에 "RED-REOPEN 요청" 블록(대상 테스트 / 근거 / 제안 수정 / 영향 수용 기준 / 대안)을 남겨 마스터에 보고하라.\n' "$phase" "$fp" >&2
exit 2
