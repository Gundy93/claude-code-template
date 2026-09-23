#!/bin/sh
# SessionStart 훅: 이 cwd에 활성 상태가 있으면 요약을 컨텍스트로 준다.
set -u
. "$(dirname "$0")/lib.sh"
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat 2>/dev/null) || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
[ -n "$cwd" ] || cwd="$PWD"
sd=$(state_dir "$cwd"); sj="$sd/session.json"
[ -f "$sd/phase" ] && [ -f "$sj" ] || exit 0
issue=$(json_get "$sj" issue); phase=$(json_get "$sj" phase); branch=$(json_get "$sj" branch); base=$(json_get "$sj" base)
red=$(json_get "$sj" redSha); seq=$(json_get "$sj" gateSeq); master=$(json_get "$sj" masterSession); review=$(json_get "$sj" reviewSession)
last=$(cd "$cwd" 2>/dev/null && sh "$(dirname "$0")/gate.sh" last "$issue" 2>/dev/null)
verdict="없음"; if [ -n "$last" ]; then nn=$(basename "$last" | cut -d- -f1); [ -f "$(dirname "$last")/$nn-verdict.md" ] && verdict=$(grep -m1 '^VERDICT:' "$(dirname "$last")/$nn-verdict.md"); fi
cat <<MSG
[multisession-tdd 상태] 이슈 $issue · phase=$phase · 브랜치 $branch · base $base · redSha=${red:-없음} · gateSeq=$seq · master=$master · review=$review
마지막 패킷: ${last:-없음} · verdict: $verdict
이 상태는 /multisession-tdd:tdd(마스터)와 /multisession-tdd:gate-review(검토) 스킬이 관리한다. 자동으로 이어가지 말고, 사용자가 /multisession-tdd:tdd $issue --resume 또는 /multisession-tdd:gate-review $issue --latest 를 부를 때 계속한다. 단계 변경은 phase.sh set 로만 한다.
MSG
