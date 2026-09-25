# Version 10 공급·Phase 4 운영 준비 확인

기준일: 2026-09-25. [1칸 조각과 대기 조각 배경 변경](Piece_Tray_Refinement_2026-09-25.md)의 후속 확인이다.

## 공급 설정과 저장

고정 Godot 4.7.2에서 같은 시드로 프로필마다 조건별 10,000트레이(30,000조각)를 생성했다. `mixed`는 빈/가득 찬/체커/여러 점유 밀도/완성 줄/대각선 빈칸을 같은 순서로 반복하는 10종 합성 보드이며 실제 사람 플레이 분포는 아니다.

| 조건 | 기존 `classic` 1칸 | 새 `reduced_single` 1칸 |
|---|---:|---:|
| 빈 보드 | 3,487 / 30,000 = 11.62% | 744 / 30,000 = 2.48% |
| 10종 합성 보드 | 5,009 / 30,000 = 16.70% | 2,620 / 30,000 = 8.73% |

[재실행 스크립트](../../game/tests/integration/supply_profile_probe.gd)는 두 조건에서 새 비율이 낮은지, 모든 트레이에 한 수 증명이 있는지 확인한다. 별도 회귀 검사 3개를 추가해 새 개인 저장의 프로필과 재시작 복원, 기존 저장의 종전 설정 복원, 새 주간 도전 기록의 같은 프로필 복원을 확인했다. 전체 고정 GUT **144개 / 3,753개 단언**, 실패·오류·보류 0.

[Windows 실제 퍼즐 캡처](version10_evidence_2026-09-25/puzzle_without_tray.png)는 독립 저장 폴더에서 새 개인 게임을 열어 360×800 화면을 렌더한 결과다. 대기 조각 세 개 아래의 판·구분선이 보이지 않고 보드와 조작 버튼은 표시된다. 캡처 실행기는 새 저장의 `reduced_single` 프로필을 반환했다.

## 주간 도전과 서버

[주차·DB 이전 확인 도구](../../tools/verify_phase4_profiles.py)로 기존 `challenges` 표에 `supply_profile=classic` 열이 추가되는지 확인했다. 한 계정이 2026-09-21 UTC 주차에는 `classic`, 2026-09-28 주차에는 `reduced_single`을 발급받았고 각각 같은 도전 재요청과 무행동 재생 제출이 통과했다. 지난주 도전의 마감 뒤 재제출은 거절됐다. [HTTP 검사](../../tools/verify_phase4_service.py) 13개에서는 다른 계정·임의 점수·중복·연장·축소·분기 기록과 잘못된 이벤트 순서를 확인했다. 같은 길이의 다른 기기 분기는 `TRACE_NOT_EXTENSION`으로 거절됐다.

[서버 DB 백업 도구](../../tools/backup_phase4_db.py)는 실행 중인 SQLite DB를 일관된 스냅샷으로 복사하고 무결성·필수 표·외래키를 확인한 뒤 새 파일로 게시한다. 테스트 DB의 계정 2개·도전 1개·제출 1개를 백업했고, 이미 있는 백업 파일의 덮어쓰기는 거절하며 해시가 유지되는 것도 확인했다. 백업 파일은 토큰 해시와 행동 기록을 포함하는 비공개 자료다.

```powershell
python tools/backup_phase4_db.py --source C:/DEV/BlocktowerPrivate/phase4.sqlite3 --output C:/DEV/BlocktowerPrivate/backup-2026-09-25.sqlite3
```

## Android 상태

versionCode 10 QA APK 빌드·별도 패키지 설치는 성공했다. 처음에는 SM-N981N이 잠겨 확인이 보류됐으나, 잠금 해제 후 [실기기 화면](version13_evidence_2026-09-25/personal_tray.png)에서 대기 조각 배경이 보이지 않는 것을 확인했다. 새 개인 저장의 공급 해시가 `reduced_single`과 일치했고, 별도 주간 도전에서 조각 배치·서버 제출 1회를 확인했다. 개인 저장은 0회차로 유지됐다. 계정 복구와 충돌 선택의 후속 구현·실기기 확인은 [Phase 4 후속 기록](Phase4_Recovery_Conflict_2026-09-25.md)을 따른다. 본 앱 `com.blocktower.game` version 8과 개인 데이터는 변경하지 않았다.

재실행 시에는 고정 Godot 4.7.2에서 `game/tests/integration/supply_profile_probe.gd`와 `game/tests/integration/capture_puzzle_screen.gd`를 사용한다. 후자는 새 격리 저장 폴더와 PNG 출력 경로를 인수로 받는다. 실행 중 서버의 DB 백업은 저장소 밖의 비공개 경로에 둔다.
