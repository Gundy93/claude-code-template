# 게이트 패킷과 판정 형식

`gate.sh prepare <GATE>`가 헤더·numstat을 채운 뼈대를 만든다. 마스터는 나머지 절을 채운다. **파일이 정본이고 메시지는 같은 본문을 보내는 깨우기 신호다** — 판정도 검토 세션이 `<NN>-verdict.md`에 먼저 쓰고 같은 본문을 보낸다.

## 패킷

```
MSTDD <GATE1|GATE2|GATE3|RED_REOPEN> <이슈> seq=<NN> master=<마스터 세션> resend=<0|1>
# 이슈 <이슈> · <FROM→TO> · 브랜치 <branch>
- 워크트리: <path> · HEAD: <sha> · RED sha: <sha|없음> · 계획: <planPath>
- base: <base> @ <tip sha> (merge-base <sha>)          ← session.json의 base. 스택 PR이면 선행 브랜치
- RED sha 이력(이번 시작 이후):                          ← redsha·GATE1 재설정이 있었을 때만 gate.sh가 넣는다
  - <시각>  redSha <old> → <new> note=…
- 패킷 파일: <config.sh gates>/<이슈>/<NN>-<GATE>.md

## 무엇을 검토하나
<이 게이트에서 승인받으려는 것 한 문단>

## 테스트 목록 (계획 줄 매핑)
| 테스트 | 파일 | 계획 줄 | 수용 기준 | 상태 |   ← RED: 실패 유형(assertion/behavior/compile) · GREEN 이후: pass

## 실행한 명령과 결과
- `<명령>` → 실패 7 / 통과 0

## 변경 파일 (git diff --numstat <merge-base>..HEAD)   ← base 기준이라 스택 PR에서도 선행 변경이 섞이지 않는다. GATE2/3은 「RED 이후」 블록도 자동
## 열린 질문·가정
- A-…: … / 없음
- (base를 합쳤으면) MERGE: old redSha=…, new redSha=…   ← phase.sh redsha 출력 그대로

## (GATE3만) 사전 리뷰 결과와 해결
| R-# | 등급 | 내용 | 해결(커밋 sha / 사유) |
- PR 본문 드라이런: <경로>
- 크기: 파일 N개(참고 F) · 최대 파일 <path> M줄(참고 L) · 제외: …

## (RED_REOPEN만) 재개정 요청
- 대상 테스트 / 왜 틀렸나(스펙 인용) / 제안 수정 / 영향 수용 기준 / 대안
```

## 판정 (검토 세션 → 마스터)

```
MSTDD VERDICT <이슈> seq=<NN> gate=<GATE>
VERDICT: APPROVED | CHANGES_REQUESTED | RED_REOPEN_APPROVED | REJECTED
승인 범위: <외부 반영 명령 원문 — GATE3 등에서 사용자가 승인한 것만. 없으면 「없음」>
1. <피드백 — 파일:줄, 무엇을 어떻게>
2. …
```

`CHANGES_REQUESTED`의 피드백 번호는 재작업 위임 프롬프트에 그대로 들어간다.
