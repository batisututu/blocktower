# W3 실제 파일 저장·앱 재실행·손상 복구

2026-09-21. **Windows W3 구현·검증 완료. 전체 58개 테스트·2,495개 단언, 별도 프로세스 검사 26개 통과.** W2 GameSession 전체 상태를 실제 파일로 저장하고 앱 시작 시 복원한다. 현재 화면은 기존 합성 시안이며 실제 조작·표시 연결은 W4다.

## 구현 결과

| 구성 | 역할 |
|---|---|
| [SaveCodec](../../game/scripts/persistence/save_codec.gd) | UTF-8·2 MiB 상한·정확한 필드·버전·SHA-256·상태 불변식 검사. 누적 정수와 RNG는 10진 문자열, 셀은 hex로 저장 |
| [FileSaveRepository](../../game/scripts/persistence/file_save_repository.gd) | 두 세대 교대 저장, 임시 파일 검증, 이전 상태 복구, 손상 원본 보존, revision 충돌·동시 프로세스 차단 |
| [SavedGame](../../game/scripts/application/saved_game.gd) | 기존 기록이면 공급 재추첨 없이 resume. 기록이 없을 때만 최초 상태를 커밋하고 시작 |
| [앱 시작 씬](../../game/scenes/app.tscn)·[AppRoot](../../game/scripts/application/app_root.gd) | 프로젝트 시작점에서 실제 세션 복원. 손상 복구 안내와 오류 시 다시 시도 제공 |
| [저장 계약](../../game/scripts/core/contracts/file_save_contract.md)·[ADR-0004](../adr/0004-two-generation-file-persistence.md) | 파일 형식·오류·확정 경계·플랫폼 제한의 기준 |

기본 위치는 `user://save_v1`이며 이 Windows 작업 환경에서는 `C:/Users/batis/AppData/Roaming/Godot/app_userdata/Blocktower/save_v1`이다. `slot_a.json`·`slot_b.json`을 교대로 확정하고 `pending.json`은 미확정으로 취급한다. 테스트는 별도 고유 경로를 사용한다.

쓰기 → flush/닫기 → 다시 읽어 검증 → 손상 원본 보존 → 비활성 슬롯 제거 → 같은 폴더 rename → 확정 파일 재검증 순서다. 성공 확인 전에는 점수·성장 이벤트를 발행하지 않는다. 확정 후 응답이 불명확하면 `COMMIT_UNCERTAIN`으로 세션 입력을 중지하고 다시 읽어야 한다. 전체 상태에는 보드·슬롯·점수·층수·구간 선택·공급 체크포인트·사건 ID가 함께 들어간다.

최신 파일이 손상되면 정상 세대를 선택하고 최근 진행 일부가 되돌아갈 수 있음을 안내한다. 손상 파일은 다음 커밋이 해당 슬롯을 교체하기 전에 `preserved/<파일명>.<원본 SHA-256>.bad`로 복사·검증한다. 그 전에는 원래 위치에 그대로 남는다. 원본 보존 실패 시 커밋을 중단한다. 두 세대 모두 손상되거나 미지원 버전·읽기 실패·서로 다른 세션이 발견되면 초기화하지 않고 오류를 반환한다.

## 실행 증거

- [전체 GUT 결과](w3_evidence_2026-09-21/last_test_run.json): 7개 스위트, 58개 테스트, 실패/오류/보류 0. 기존 45개와 W3 신규 13개를 함께 실행했다. [실행 로그](w3_evidence_2026-09-21/gut.stdout.log), [JUnit](w3_evidence_2026-09-21/gut_unit.xml).
- [프로세스 검사 결과](w3_evidence_2026-09-21/process/summary.json): 정상 탐침 프로세스 20개와 강제 종료한 쓰기 프로세스 6개, 총 26개 검사 통과. 정상 프로세스마다 별도 Godot를 실행했다.
- [고정 v1 저장 fixture](../../game/tests/fixtures/save_v1_pending_cross.json)와 [클리어 후 fixture](../../game/tests/fixtures/save_v1_cleared_cross.json): 수동 교차 줄, 9→11층, 240점 및 공급 체크포인트가 정확히 일치한다. 미래 마이그레이션 회귀 검사의 출발점이며 실서비스 구버전 이관을 수행했다는 뜻은 아니다.
- [소스 해시 목록](w3_evidence_2026-09-21/source_manifest.json): 검사 대상 구현·씬·설정·계약·테스트·검사 도구를 기록했다. 기존 생성기 구현/설정과 과거 30만 트레이 증거는 변경하지 않았다.

| 기술 리서치 항목 | 확인한 내용과 한계 |
|---|---|
| S01 중단 | before_write / after_write / after_verify / after_preserve / after_remove_target / after_publish에서 실제 쓰기 프로세스를 강제 종료. 확정 전에는 이전 상태, 확정 후에는 새 상태 전체로 복원 |
| S02 실패 | 실제 읽기 전용 pending 파일, 쓰기 경로가 디렉터리인 경우, 원본 보존 경로가 파일인 경우. 성공 이벤트·메모리 선반영 없음. 실제 디스크를 가득 채우는 검사는 하지 않음 |
| S03 손상/버전 | 최신 손상 복구·원본 바이트 보존, 두 파일 손상 차단, 잘못된 UTF-8/JSON/hash/타입 및 미래 schema/정책 불일치 차단. 신규 v1 fixture 고정; 아직 이관 대상 구버전 없음 |
| S04 정밀도 | 누적 정수 9,000,000,000,000,000과 int64 경계 RNG 문자열을 인코딩·실제 파일 읽기·세션 복원 후 비교 |
| S05 초기/새 판 | 초기 커밋·기존 ID/시드 재사용·실제 시작 씬 재개. 새 판 성장 유지·행동 재생은 기존 W2 테스트도 함께 통과. 행동 로그 절단 기능은 구현 범위에 없음 |
| S06 응답 유실 | 확정 직후 종료→재시작→같은 사건 재전송 시 ALREADY_APPLIED. 보상·공급 재추첨 중복 없음 |

정상·복구·오류의 실제 앱 시작 씬도 별도 프로세스에서 headless 실행했다. GUI 외형·모바일 터치 검증으로 확대하지 않는다.

## 검토에서 바로잡은 문제

고정 엔진의 Windows `is_process_running`은 엔진이 생성한 자식만 추적하므로 다른 앱 인스턴스의 잠금 소유자 검사에 사용할 수 없다. Windows 기본 `tasklist /FO CSV /NH`를 숨김 실행해 확인하며, 불명확하면 잠금을 회수하지 않는다. 살아 있는 별도 쓰기 프로세스가 있을 때 SAVE_BUSY로 차단되는 것도 실제 검사했다. [Godot OS 문서](https://docs.godotengine.org/en/stable/classes/class_os.html), [고정 커밋의 Windows 구현](https://github.com/godotengine/godot/blob/ed1daf0bf/platform/windows/os_windows.cpp)

잠금 디렉터리 조회는 숨김 항목까지 포함한다. 파일 쓰기 반환·flush 후 오류를 확인하고 닫은 뒤 다시 읽는다. API 호출 성공만으로 저장 완료를 판단하지 않는다. [DirAccess 문서](https://docs.godotengine.org/en/stable/classes/class_diraccess.html), [FileAccess 문서](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)

Windows 콘솔 실행 파일은 별도 엔진 프로세스를 띄우는 래퍼라 PID가 다르다. 강제 종료 도구는 실제 엔진 실행 파일로 정규화하고 그 SHA-256과 버전을 확인한다. 기존 시안의 루트 타입은 유지하고 별도 앱 시작 씬으로 감싸 기존 시안 회귀 검사도 보존했다.

## 재실행과 다음 단계

저장소 루트에서 실행한다. 강제 종료 검사는 고유 테스트 폴더를 만들며 기본 사용자 기록을 변경하지 않는다.

```powershell
pwsh -NoProfile -File tools/test.ps1
python tools/verify_save_restart.py --godot C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64.exe
pwsh -NoProfile -File tools/run.ps1
```

다음은 W4: 실제 보드·트레이·점수·성장 표시를 `game_session.snapshot()/view()`에 연결하고, 입력을 `dispatch()`로 직렬화한다. 기존 합성 시안 버튼을 누른 결과는 아직 저장된 실제 게임 진행이 아니다. 시안 기준 W0 에셋 제작·외형 대조도 계속 필요하다.

Windows 로컬 파일과 프로세스 종료를 검증했다. 하드웨어 전원 손실·디렉터리 fsync·네트워크 드라이브·Android/iOS 동작을 보장하지 않는다. 모바일은 비정상 종료 후 다른 PID의 잠금을 안전하게 회수하는 플랫폼 어댑터와 실기기 검사가 필요하다. 저장은 매 수락 행동마다 동기 처리하므로 W5에서 지연을 측정한다. 손상 원본은 자동 삭제하지 않는다.
