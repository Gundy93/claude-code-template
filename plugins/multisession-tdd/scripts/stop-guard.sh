#!/bin/sh
# Stop 훅 — 마스터가 할 일이 남은 단계에서 턴을 끝내려 하면 막는다.
# 멈춰도 되는 때: 활성 상태 없음(이 플러그인 세션 아님) · 게이트 대기 단계 · DONE/HALT/PR · 서브에이전트 백그라운드 진행 중 · 대기 표식(phase.sh wait)이 있을 때.
# 대기 표식은 한 번 쓰면 지운다 — 멈출 때마다 새로 선언해야 한다(낡은 표식으로 조용히 멈추는 것을 막는다).
set -u
. "$(dirname "$0")/lib.sh"
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat 2>/dev/null) || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
[ -n "$cwd" ] || cwd=$PWD
sd=$(state_dir "$cwd"); sj="$sd/session.json"
[ -f "$sd/phase" ] && [ -f "$sj" ] || exit 0
phase=$(json_get "$sj" phase)
case "$phase" in GATE1|GATE2|GATE3|RED_REOPEN|PR|DONE|HALT|"") exit 0 ;; esac
# 위임한 서브에이전트가 백그라운드로 돌고 있으면 끝날 때 세션이 다시 깨어난다 — 멈춤을 허용한다.
# 셸 작업(개발 서버·tail 등)은 세션을 깨우지 않으므로 허용 사유가 아니다.
bg=$(printf '%s' "$input" | jq -r '[.background_tasks // [] | .[] | select(.type == "subagent")] | length' 2>/dev/null)
case "$bg" in ''|0|*[!0-9]*) ;; *) printf '%s  stop 허용(서브에이전트 %s개 진행 중)\n' "$(now_iso)" "$bg" >> "$sd/log"; exit 0 ;; esac
if [ -f "$sd/waiting" ]; then
  printf '%s  stop 허용(대기 표식: %s)\n' "$(now_iso)" "$(cat "$sd/waiting")" >> "$sd/log"
  rm -f "$sd/waiting"; exit 0
fi
# 같은 멈춤에서 두 번 넘게 막지 않는다 — 무한 되돌림 방지.
n=0; [ -f "$sd/stop-blocks" ] && n=$(cat "$sd/stop-blocks")
case "$n" in ''|*[!0-9]*) n=0 ;; esac
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = true ] || n=0
if [ "$n" -ge 2 ]; then rm -f "$sd/stop-blocks"; printf '%s  stop 허용(막기 2회 초과)\n' "$(now_iso)" >> "$sd/log"; exit 0; fi
echo $((n + 1)) > "$sd/stop-blocks"
printf '%s  stop 막음(phase=%s)\n' "$(now_iso)" "$phase" >> "$sd/log"
jq -n --arg p "$phase" --arg w "$(dirname "$0")/phase.sh" '{decision:"block", reason:("multisession-tdd: 단계 " + $p + "에서 턴을 끝내려 한다. 이 단계의 남은 일(위임 결과 받기 → 검증 → 커밋 → 다음 phase.sh set / 게이트 패킷 발송)을 이어서 해라. 정말 기다려야 하면 먼저 `sh " + $w + " wait \"<사유>\"`를 실행한 뒤 멈춘다 — 허용 사유: 자원 승인 대기 · 검토 세션 회신 대기 · 사용자 결정 대기 · 사용자가 멈추라고 함.")}'
