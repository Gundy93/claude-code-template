#!/bin/sh
# 게이트 패킷 파일을 만든다(헤더·numstat 자동, 나머지는 템플릿). cwd 기준 상태를 읽는다.
#   gate.sh prepare <GATE1|GATE2|GATE3|RED_REOPEN> [--resend]
#   gate.sh path <NN> <GATE|verdict|pr-body> [issue] | last [issue] | status   (cwd 저장소의 패킷 폴더 기준)
# 패킷 선택은 수정 시각이 아니라 seq(NN) 순서다.
set -u
. "$(dirname "$0")/lib.sh"
sd=$(state_dir "$PWD"); sj="$sd/session.json"
need() { [ -f "$sj" ] && [ -f "$sd/phase" ] || die "활성 상태 없음: $sd"; }
# 이슈의 패킷 목록(seq 오름차순) — 파일 이름이 NN-<GATE>.md
GD=$(gates_dir "$PWD" 2>/dev/null) || GD=""
packets() { d="$GD/$1"; [ -d "$d" ] || return 0; ls -1 "$d" | grep -E '^[0-9]+-(GATE[123]|RED_REOPEN)\.md$' | sort -n | sed "s#^#$d/#"; }
cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  prepare)
    need; gate=${1:-}; [ $# -gt 0 ] && shift
    case "$gate" in GATE1|GATE2|GATE3|RED_REOPEN) ;; *) die "GATE1|GATE2|GATE3|RED_REOPEN" ;; esac
    resend=0; [ "${1:-}" = "--resend" ] && resend=1
    issue=$(json_get "$sj" issue)
    lock "$sd/.lock"
    seq=$(json_get "$sj" gateSeq); case "$seq" in ''|*[!0-9]*) seq=0 ;; esac
    if [ $resend -eq 0 ]; then
      m=$(max_seq "$GD/$issue"); [ "$m" -gt "$seq" ] && seq=$m   # 폴더에 이미 있는 번호는 다시 쓰지 않는다
      seq=$((seq+1))
      json_update "$sj" --argjson s "$seq" '.gateSeq=$s' || { unlock "$sd/.lock"; die "session.json 갱신 실패"; }
    fi
    unlock "$sd/.lock"
    nn=$(printf '%02d' "$seq"); gd="$GD/$issue"; mkdir -p "$gd"; out="$gd/$nn-$gate.md"
    branch=$(json_get "$sj" branch); wt=$(json_get "$sj" worktree); red=$(json_get "$sj" redSha); plan=$(json_get "$sj" planPath); master=$(json_get "$sj" masterSession)
    head=$(git -C "$PWD" rev-parse HEAD 2>/dev/null || echo "")
    case "$gate" in GATE1) tr="RED→GREEN";; GATE2) tr="GREEN→REFACTOR";; GATE3) tr="REVIEW→PR 발행";; RED_REOPEN) tr="→RED 재개정";; esac
    cfgbase=$(cfg_base "$PWD")
    basebr=$(json_get "$sj" base); [ -n "$basebr" ] || basebr=$cfgbase
    base=$(git -C "$PWD" merge-base --end-of-options "$basebr" HEAD 2>/dev/null) || base=""
    basetip=$(git -C "$PWD" rev-parse --short "$basebr" 2>/dev/null || echo "?")
    hf=$(cfg "$PWD" '.sizeHint.files'); hl=$(cfg "$PWD" '.sizeHint.lines')
    {
      printf 'MSTDD %s %s seq=%s master=%s resend=%s\n' "$gate" "$issue" "$nn" "$master" "$resend"
      printf '# 이슈 %s · %s · 브랜치 %s\n' "$issue" "$tr" "$branch"
      printf -- '- 워크트리: %s · HEAD: %s · RED sha: %s · 계획: %s\n' "$wt" "$head" "${red:-없음}" "$plan"
      printf -- '- base: %s @ %s (merge-base %s)%s\n' "$basebr" "$basetip" "$(printf %.8s "${base:-?}")" "$([ "$basebr" = "$cfgbase" ] || printf ' · 스택 PR — 선행 브랜치 기준으로 센다')"
      hist=$(awk '/  init issue=/{b=""} /redSha .* → /{b=b $0 "\n"} END{printf "%s", b}' "$sd/log" 2>/dev/null)
      if [ -n "$hist" ]; then printf -- '- RED sha 이력(이번 시작 이후):\n'; printf '%s' "$hist" | sed 's/^/  - /'; fi
      printf -- '- 패킷 파일: %s\n\n' "$out"
      printf '## 무엇을 검토하나\n\n(한 문단)\n\n'
      printf '## 테스트 목록 (계획 줄 매핑)\n\n| 테스트 | 파일 | 계획 줄 | 수용 기준 | 상태 |\n| --- | --- | --- | --- | --- |\n\n'
      printf '## 실행한 명령과 결과\n\n- `…` → …\n\n'
      printf '## 변경 파일 (git diff --numstat %s..HEAD)\n\n```\n' "${base:-?}"
      if [ -n "$base" ]; then git -C "$PWD" diff --numstat "$base"..HEAD 2>/dev/null
      else printf '(base %s 해석 실패 — fetch 뒤 --resend로 다시 만든다)\n' "$basebr"; fi
      printf '```\n'
      if [ -n "$red" ] && [ "$gate" != GATE1 ]; then
        printf '\n### RED 이후 (git diff --numstat %s..HEAD)\n\n```\n' "$red"
        git -C "$PWD" diff --numstat "$red"..HEAD 2>/dev/null
        printf '```\n'
      fi
      printf '\n## 열린 질문·가정\n\n- (없으면 「없음」)\n\n'
      case "$gate" in
        GATE3) printf '## 사전 리뷰 결과와 해결\n\n| R-# | 등급 | 내용 | 해결(커밋 sha / 사유) |\n| --- | --- | --- | --- |\n\n- PR 본문 드라이런: %s/%s-pr-body.md\n- 크기: 파일 N개(참고 %s) · 최대 파일 <path> M줄(참고 %s) · 제외: …\n' "$gd" "$nn" "${hf:-없음}" "${hl:-없음}" ;;
        RED_REOPEN) printf '## 재개정 요청\n\n- 대상 테스트:\n- 왜 틀렸나(스펙 인용):\n- 제안 수정:\n- 영향 수용 기준:\n- 대안(테스트를 유지할 때 구현 방식):\n' ;;
      esac
    } > "$out"
    echo "$out"
    ;;
  path)
    nn=${1:?NN}; kind=${2:?GATE}; issue=${3:-}
    [ -n "$issue" ] || { need; issue=$(json_get "$sj" issue); }
    printf '%s/%s/%s-%s.md\n' "$GD" "$issue" "$nn" "$kind" ;;
  last)
    issue=${1:-}; [ -n "$issue" ] || { need; issue=$(json_get "$sj" issue); }
    packets "$issue" | tail -n 1 ;;
  status)
    need; issue=$(json_get "$sj" issue); gd="$GD/$issue"
    packets "$issue" | while IFS= read -r f; do
      nn=$(basename "$f" | cut -d- -f1)
      v="$gd/$nn-verdict.md"; if [ -f "$v" ]; then vv=$(grep -m1 '^VERDICT:' "$v"); else vv="(verdict 없음)"; fi
      printf '%s  %s\n' "$(basename "$f")" "$vv"
    done ;;
  *) sed -n '2,6p' "$0" | grep '^#'; exit 1 ;;
esac
