# 게임필 개선 version3 실기기 검증

2026-09-21. 삼성 **SM-N981N / Android13 / 1080×2400 / 450dpi**에 `0.1.0-gamefeel3`(versionCode3)을 덮어쓰기 설치했다. **단일 기기 설치·기본 UI·배치/클리어·저장 검증은 통과했다.** 전체 W5/출시 승인과 사람의 체감 품질 평가는 미완료다.

## 설치와 기록 보존

실제 설치 패키지는 `com.blocktower.game`, ARM64 APK SHA-256 `9e088503c6b30b0205462889c4229859b9f033f3b5706a92b1e8fc5a21986be1`이다. `adb -s R3CN80ZJ8SV install --no-incremental -r`로 설치했고 기존 앱 삭제나 데이터 초기화를 하지 않았다. 설치 직전/직후 전체 저장 상태가 **453점·4층·revision16**으로 동일하고, 음량/음소거/감소 모션/진동 설정도 유지됐다. [설치 정보](gamefeel_device_evidence_2026-09-21/installed_build.json).

설치 후 사용자의 직접 플레이로 관찰 기록이780점, 이어서 **1,047점·9층·revision36 / 게임 종료 상태**까지 바뀌었다. 이 진행량은 자동 검증의 성공으로 계산하지 않았다. 이후 이 상태를 사용자 기록 보존 기준으로 삼았고 QA 검사 종료 후에도 보드·조각·RNG·점수·성장·revision 전체가 동일함을 확인했다. 최종 실제 앱은 이 기록의 퍼즐 화면에 열어두었다.

## 본 앱과 별도 QA 검증 구분

종료된 사용자 보드를 초기화하지 않기 위해 `Android Device QA` export preset과 별도 `com.blocktower.game.qa`를 사용했다. 설치 전에 기기에 이 패키지가 없음을 확인했다. **본 앱과 QA APK의 assets180개가 바이트 단위로 모두 동일**하며 패키지명/앱 표시명만 다르다. [리소스 대조](gamefeel_device_evidence_2026-09-21/runtime_asset_comparison.json).

QA 앱에만 교차 줄의 중앙 한 칸이 빈 보드와 단일 셀 세 조각의 통제 세이브를 준비했다. 본 앱의 세이브에 테스트 보드를 주입하지 않았다. 이후 모든 배치/모드 전환/클리어는 Android `adb input swipe/tap`으로 실행했다. Godot 내부 입력 이벤트나 직접 GameSession.dispatch 호출은 쓰지 않았다. 완료 후 임시 QA 앱을 제거하고 원래 앱을 다시 열었다.

## 결과

[구조화 요약](gamefeel_device_evidence_2026-09-21/summary.json): **본 앱13개 + QA13개 = 총26개 확인 통과**. 이는82개 Windows 단위 테스트와 별도의 실제 기기 검사다. 이번에는 게임 런타임 코드를 변경하지 않았으며 QA export preset만 추가했다.

| 확인 | 관찰 |
|---|---|
| 업데이트 | 저장 상태와 모든 로컬 표시 설정 보존 |
| 실제 화면 | 좌우 메뉴 제거, 내 탑/설정 상단 배치, 가로1008px(논리336px) 보드 확인. 해당 기기의 기본 세로 설정에서 버튼/글자 잘림 없음 |
| 보드 밖 드롭 | 상태 불변, 조각 회수 |
| 화면 탐색 | 설정·내 탑·결과·새 게임 확인창 정상 진입. Android Back으로 복귀/취소, 앱의 진행 상태 불변 |
| 단일 셀 배치 | 지정한 교차 중심으로 정확히 배치, revision1회 증가, 점수+1 |
| 수동 교차 클리어 | 행/열의15개 고유 셀 제거, +240점·2층 한 번만 반영. QA 누적241점 |
| 자동 모드/클리어 | 모드 버튼으로 전환 후 두 칸을 각각 실제 드래그. 두 번째에서 +1배치/+100클리어·1층. QA최종343점·3층 |
| 세 조각 소진 | 세 번째 배치 이후 새 조각3개 공급, 중복 보상 없음 |
| 연출 | 실제 기기22초 녹화에서 손가락 위 조각/유효·무효 미리보기, 배치 반응, 클리어의 빛·축소·파편, 버튼 상태와 보상 문구 변화를 관찰 |
| 표시 설정 | QA에서 움직임 줄이기 켜기/끄기가 파일에 저장됨. 기본값으로 복원. 본 앱 사용자 설정은 그대로 유지 |
| 재실행 | QA Home 복귀·커밋 완료 후 force-stop 재실행, 본 앱 재실행 모두 전체 상태 동일 |
| 실행 로그 | 이번 기기 Godot 태그 로그에서 SCRIPT ERROR/ERROR/FATAL 없음. 에뮬레이터의 기존 SwiftShader 실패는 이 실기기에서 재현되지 않음 |

[본 앱 검사](gamefeel_device_evidence_2026-09-21/checks.json), [QA 검사](gamefeel_device_evidence_2026-09-21/qa/checks.json), [Godot 로그](gamefeel_device_evidence_2026-09-21/godot_runtime.log), [QA 입력 좌표·순서](gamefeel_device_evidence_2026-09-21/qa/input_sequence.json)를 보존했다. 세이브 사본은 envelope payload SHA-256을 확인하고 가장 높은 유효 revision을 비교했다. 저장 도중 강제 종료/손상 복구 테스트는 수행하지 않았다.

## 화면과 녹화

- [설치 직후 실제 퍼즐](gamefeel_device_evidence_2026-09-21/01_updated_puzzle.png), [사용자 기록 보존 후 최종 화면](gamefeel_device_evidence_2026-09-21/09_final_puzzle.png).
- [설정](gamefeel_device_evidence_2026-09-21/03_settings.png), [내 탑](gamefeel_device_evidence_2026-09-21/04_tower.png), [결과](gamefeel_device_evidence_2026-09-21/07_results.png), [새 게임 취소 전](gamefeel_device_evidence_2026-09-21/08_new_game_confirmation.png).
- [QA 수동 교차 대기](gamefeel_device_evidence_2026-09-21/qa/02_pending_cross.png), [수동 제거](gamefeel_device_evidence_2026-09-21/qa/03_manual_clear_result.png), [자동 제거](gamefeel_device_evidence_2026-09-21/qa/04_auto_clear_result.png).
- [실제 기기 연출 녹화](gamefeel_device_evidence_2026-09-21/qa/motion.mp4): 540×1200,22.08초. 진단용 축소 화면 녹화이며 오디오는 포함하지 않는다. [0~5초 프레임](gamefeel_device_evidence_2026-09-21/qa/motion_first5s.png), [5~10초 프레임](gamefeel_device_evidence_2026-09-21/qa/motion_next5s.png)은 시간 순서대로6fps 추출한 진단 자료다. 녹화 파일의 프레임률을 게임 렌더링 FPS나 터치 지연 측정값으로 해석하지 않는다.

콜드 Activity 시작의 am start TotalTime은1,346ms다. 플레이 가능 시간이나 입력 반응 지연을 측정한 값은 아니다.

## 남은 범위

사람이 실제 손가락으로 느끼는 배치 보정/연출 만족도, 효과음 청취·레이어 균형·햅틱 체감은 별도다. 다른 기기/화면비·큰 글꼴·접근성, 멀티터치/빠른 연속 동작의 전체 조합, 장시간 발열·배터리·정밀 프레임 지연, Android 잔여 writer lock 복구는 미검증이다. Windows 독립 검토의 scoped ship을 전체 Android 품질 승인으로 바꾸지 않는다. 현재 판정은 **이 기기의 version3 smoke 및 통제된 핵심 플레이 흐름 통과**다.
