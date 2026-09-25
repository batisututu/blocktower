# Phase 4 로컬 서버·Android 실기기 종단 간 검증

기준일: 2026-09-25. [온라인 MVP 구현](Phase4_Online_MVP_2026-09-25.md)의 로컬 개발 범위를 Windows 서버와 SM-N981N(Android 13) QA 앱에서 확인했다. 공개 서비스 수용 관문은 별개다.

## 실행 범위와 결과

| 흐름 | 결과 |
|---|---|
| Python HTTP/SQLite 서버, 고정 Godot 4.7.2 재생기 | 게스트 발급, 같은 주 도전 멱등성, 무행동 및 행동 연장 제출, 재전송, 검증 순위 확인. [12개 HTTP 검사](../../tools/verify_phase4_service.py) 통과. 다른 계정 제출·임의 층수·축소/분기·이벤트 순서 오류 거절 후 기존 기록 유지도 확인 |
| 실제 규칙 행동으로 대표 구간 만들기 | 서버 발급 시드에서 35개 합법 행동을 만들고 서버에 제출해 10층·대표 1번 구간을 확인. [재현 도구](../../tools/verify_phase4_tower.py)와 [Godot 행동 생성기](../../game/tests/integration/phase4_generate_trace.gd) 사용 |
| Android QA `com.blocktower.game.qa` | 새 QA 설치, `adb reverse` 로컬 서버 접속, 도전 시작, 조각 배치로 3점 획득, 강제 종료·재시작 후 기록 복원, 1개 행동 연장 제출과 순위 표시 확인 |
| 다른 검증 탑 보기 | QA 앱에서 서버가 검증한 10층 순위 항목을 눌러 읽기 전용 대표 탑 전체를 스크롤로 확인 |
| 개인 저장 격리 | QA 개인 저장 `slot_a.json` SHA-256이 도전 시작·배치·제출 전후 모두 `9fe85649e8d04f84bedfa63cd4dcc03b0edbf4e7eb03faade9441a3da13ea4e7`. 본 앱 `com.blocktower.game` version 8과 데이터는 건드리지 않음 |
| 고정 회귀 | GUT **141개 / 3,733개 단언**, 실패·오류·보류 0. 도전 행동 복원, `NEW_RUN` 차단, 손상된 최신 기록의 이전 세대 복원 3개를 추가 |

화면 증거: [실기기 조각 배치](phase4_evidence_2026-09-25/challenge_move.png), [제출 완료와 순위](phase4_evidence_2026-09-25/submission.png), [다른 대표 탑](phase4_evidence_2026-09-25/representative_tower.png). 서버 DB, 계정 토큰, 원시 행동 기록과 개인 저장 파일은 커밋하지 않았다.

## 수정 사항

- 손상된 도전 JSON을 읽을 때 엔진 오류를 출력하던 경로를 정상적인 `TRACE_CORRUPT` 결과로 바꿨다.
- 주간 화면에 기존 건축 배경과 버튼 스타일을 적용하고, 제출 후 새 순위를 읽어도 성공 안내가 유지되도록 했다.

## 재실행

저장소 루트에서 [구현 기록의 로컬 서버 실행법](Phase4_Online_MVP_2026-09-25.md#로컬-서버-실행)대로 서버를 띄운 뒤 다음 명령을 사용한다. 서버 DB는 저장소 밖 또는 무시되는 `tools/out`에 둔다.

```powershell
python tools/verify_phase4_service.py
python tools/verify_phase4_tower.py --godot C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe
pwsh -NoProfile -File tools/test.ps1
```

Android에는 별도 QA 패키지로 내보내고 `adb reverse tcp:8765 tcp:8765`를 설정한다. 이 검증은 한 대의 실기기와 로컬 loopback 서버에서 수행했다. 원격 TLS 배포, 계정 복구, 여러 기기의 실제 충돌 조정, 주차 경계의 실제 시각 전환, 운영 제한·백업·관측, 버전별 재생기 보존 및 사람 관찰은 아직 완료되지 않았다. 현재 결과를 공개 순위 서비스 준비 완료로 해석하지 않는다.
