#!/usr/bin/env bash
#
# sync.sh — shared/ 디렉토리의 공통 자산을 두 프로필로 복사한다.
#
# 사용 시점:
#   - shared/agents/*.md, shared/.gitignore, shared/adr-template.md를 수정한 뒤
#     두 프로필에 변경을 반영할 때.
#
# 비대상 (의도적으로 동기화하지 않음):
#   - profiles/*/CLAUDE.md  — lite와 standard가 의도된 차이를 가짐
#   - profiles/*/.claude/skills/sub-agent-routing/SKILL.md — 에이전트 매핑 표가 다름
#   - shared/claude-md-common.md — 사람 참조용 문서
#
# 사용 사용법:
#   ./scripts/sync.sh           # dry-run 미지원, 즉시 복사
#   ./scripts/sync.sh --check   # 차이만 검사하고 종료 (CI용)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED="${ROOT}/shared"
LITE="${ROOT}/profiles/lite"
STANDARD="${ROOT}/profiles/standard"

CHECK_MODE=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_MODE=1
fi

# (source, destination) 쌍을 정의
declare -a SYNC_PAIRS=(
  "${SHARED}/agents/explorer.md|${LITE}/.claude/agents/explorer.md"
  "${SHARED}/agents/implementer.md|${LITE}/.claude/agents/implementer.md"
  "${SHARED}/agents/test-writer.md|${LITE}/.claude/agents/test-writer.md"
  "${SHARED}/.gitignore|${LITE}/.gitignore"
  "${SHARED}/adr-template.md|${LITE}/docs/adr/0000-template.md"
  "${SHARED}/agents/explorer.md|${STANDARD}/.claude/agents/explorer.md"
  "${SHARED}/agents/implementer.md|${STANDARD}/.claude/agents/implementer.md"
  "${SHARED}/agents/test-writer.md|${STANDARD}/.claude/agents/test-writer.md"
  "${SHARED}/.gitignore|${STANDARD}/.gitignore"
  "${SHARED}/adr-template.md|${STANDARD}/docs/adr/0000-template.md"
)

drift_count=0
sync_count=0

for pair in "${SYNC_PAIRS[@]}"; do
  src="${pair%%|*}"
  dst="${pair##*|}"

  if [[ ! -f "${src}" ]]; then
    echo "ERROR: source missing: ${src}" >&2
    exit 1
  fi

  if [[ ! -f "${dst}" ]] || ! cmp -s "${src}" "${dst}"; then
    if [[ ${CHECK_MODE} -eq 1 ]]; then
      echo "DRIFT: ${dst#${ROOT}/}"
      drift_count=$((drift_count + 1))
    else
      mkdir -p "$(dirname "${dst}")"
      cp "${src}" "${dst}"
      echo "synced: ${dst#${ROOT}/}"
      sync_count=$((sync_count + 1))
    fi
  fi
done

if [[ ${CHECK_MODE} -eq 1 ]]; then
  if [[ ${drift_count} -gt 0 ]]; then
    echo "" >&2
    echo "${drift_count} file(s) drifted from shared/. Run scripts/sync.sh to fix." >&2
    exit 2
  fi
  echo "OK: all profile files match shared/ originals."
else
  echo ""
  echo "Done. ${sync_count} file(s) updated."
fi
