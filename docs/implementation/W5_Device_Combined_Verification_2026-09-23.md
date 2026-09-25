# W5 Android 실기기 저장 복구·중단/복귀 통합 검증

기준일: 2026-09-23. 사용자의 “실기기 검증 해줘” 요청으로 9월 21일 설치/검증 보류를 해제했다. Samsung SM-N981N(Android 13, ARM64, 1080×2400)에서 수행했다. 사용자 앱은 유지하고 파괴적 검사는 별도 QA 패키지에서만 실행했다.

## 발견한 결함과 수정

version5에서 손상 복구 안내를 띄운 채 Home/복귀하면 회색 화면이 지속됐다. 실제 Android 알림 전파 중 AppRoot가 직접 자식 CanvasLayer를 제거/추가하여 Godot의 자식 목록 잠금과 충돌했다. 로그에 `Parent node is busy adding/removing children`가 기록됐다. 기존 단위 검사는 `_notification()`을 직접 호출했으므로 실제 `propagate_notification()`의 잠금 조건을 재현하지 못했다.

- 활성 상태 변경 시 안내 버튼 세대를 즉시 무효화하고, 안내 교체는 알림 전파가 끝난 뒤 deferred callback으로 수행한다.
- 이전 버튼의 지연 입력, 다시 중단된 상태, 새 boot로 교체된 안내에는 callback이 실행되지 않는다.
- 실제 알림 전파를 사용하는 복구/실패 안내 검사와 deferred callback의 재중단/재부팅 경합 검사를 추가했다.
- 수정본은 `0.1.0-w5-lifecycle6` / versionCode6이다. 저장 schema·규칙·성장·RNG·저장소 구현은 변경하지 않았다.

수정 전 [오류 로그](w5_device_evidence_2026-09-23/qa_blank_screen_logcat.txt), 수정 후 [복구 안내](w5_device_evidence_2026-09-23/v6_corrupt_notice_resumed.png), [두 슬롯 손상 안내](w5_device_evidence_2026-09-23/v6_both_corrupt_resumed.png)를 보존했다.

## 실행 결과

| 범위 | 결과 | 증거 |
|---|---|---|
| 고정 Godot 4.7.2 / GUT 9.7.1 | 수정 후 95개 / 3,027 assertions, 실패·오류·pending 0 | [로그](w5_device_evidence_2026-09-23/unit.log), [JUnit](w5_device_evidence_2026-09-23/unit.xml) |
| Windows lifecycle 실제 입력 회귀 | 수정 후 360×800 / 320×568, 22개 확인 통과 | [summary](w5_device_evidence_2026-09-23/native_fix/summary.json) |
| Android 실기기 저장 복구 | 44개 확인 통과 | [체크](w5_device_evidence_2026-09-23/recovery/checks.json), [실행 식별](w5_device_evidence_2026-09-23/recovery/run.json) |
| 사용자 본 앱 업데이트 | version3→5→6, 전체 저장 snapshot 및 설정 동일 | [검사 전](w5_device_evidence_2026-09-23/main_before_install_state.json), [version6 설치 후](w5_device_evidence_2026-09-23/main_v6_installed_state.json) |
| Android UI / 복귀 및 설치·정리 | 62개 확인 통과; 잠금 해제 전 시도2개 제외·해제 후 재실행 통과 | [체크](w5_device_evidence_2026-09-23/checks.json) |

저장 복구 44개는 이번 SM-N981N 실행 결과다. 6개 commit 지점 강제 종료, 공개 전/후 세대 선택, 공개 전 재시도의 정확히 한 번 보상, 중복 이벤트 거부, 실제 Java 별도 프로세스 잠금 경합·프로세스 사망 후 해제, legacy claim 보호/정리, 최신 손상 fallback·원본 보존·양쪽 손상 차단, 미래 포맷 차단, pending-only 초기화를 포함한다. 단순 저장 완료 후 재실행으로 대체하지 않았다.

본 앱과 UI QA는 assets 182개가 같고, 저장 전용 QA와 본 앱의 core/persistence/SavedGame 컴파일 리소스·remap 20개가 같다. 저장 QA의 과거 version label을 최신 UI 검증으로 사용하지 않으며, 동일한 저장 코드 범위만 연결한다. [빌드 해시와 리소스 목록](w5_device_evidence_2026-09-23/v6_builds.json).

### 실제 UI 확인

- version5: 드래그 중 Home/복귀 뒤 남은 UP 입력이 배치하지 않음; 같은 프로세스 유지; AUTO 버튼을 누른 채 Home/복귀 후 UP으로 모드가 바뀌지 않음.
- version5: 실제 Android 2-pointer 이벤트로 조각을 끄는 동안 다른 손가락이 설정을 눌러도 소유 포인터만 한 번 배치함.
- version5: 미확인 AUTO 전환 폐기; 수동 교차 클리어 뒤 80ms 지연 Home 전환에서 240점/2층(9→11층)이 한 번만 저장되고 복귀 후 동일함.
- version6: 손상 복구 안내의 실제 Home/복귀 및 Back 종료/재실행 후 표시 확인. 안내 뒤 클리어 입력 차단, 새 확인 후 클리어 정상 실행, 손상 원본 바이트 별도 보존.
- version6: 두 슬롯 모두 손상된 경우 Home/복귀와 재시도 후에도 안내를 유지하며 두 원본 바이트를 변경하지 않음.

- version6: 드래그 중 화면 잠금 후 사용자가 잠금을 해제했다. 남은 UP 입력은 상태를 바꾸지 않았고, 새 2-pointer 드래그는 소유 조각을 정확히 한 번 배치했다.
- version6: 설정의 효과음 토글을 누른 채 Home/복귀 후 놓아도 기존 설정/세션이 유지됐다. 새 게임 확인을 열고 Home/복귀하면 미확인 새 게임이 실행되지 않았다.
- version6: UI에서 모션 감소를 켠 뒤 탑10회+퍼즐10회, 총20회 Home/복귀를 반복했다. 매회 전체 snapshot/RNG/revision 및 설정이 일치했고 같은 프로세스를 유지했다. 이후 새 조각도 정확히 한 번 배치됐다.
- version6: UI에서 일반 모션을 복원한 뒤 AUTO 확인 취소와 수동 클리어 뒤80ms/300ms Home 전환을 검사했다. 두 경우 모두240점/누적11층/revision1을 한 번만 저장했고 복귀 후 값이 일치했다. [300ms 복귀 화면](w5_device_evidence_2026-09-23/v6_clear_300_resumed.png)에 과거 클리어 잔상/축하가 남지 않았다.

보안 잠금의 `Bouncer`가 포커스를 가진 첫 입력 복원 시도는 앱에 전달되지 않았다. 원시 체크에는 실패 시도를 삭제하지 않고 `blocked_by_secure_keyguard`, 잠금 중 파일 불변만 확인한 항목에는 `partial`로 기록했다. 두 항목은 합격 수에서 제외했고, 사용자 잠금 해제 후 별도 재실행이 통과하여 해소됐다.

## 기기 반환 및 로그

본 앱 version6을 실행한 상태로 반환했다. [마지막 화면](w5_device_evidence_2026-09-23/main_v6_final.png), [최종 snapshot](w5_device_evidence_2026-09-23/main_v6_final_state.json)은 검사 전 사용자 기록(점수10, 최고1047, revision41, 누적9층) 및 전체 RNG/보드/트레이와 동일하다. 설정 파일도 바이트 단위로 일치했다. QA 두 패키지와 테스트용 기기 임시 파일을 제거했고 [본 앱만 설치되어 있음](w5_device_evidence_2026-09-23/final_packages.txt)을 확인했다.

version6의 실패 안내·설정/20회복귀·80ms/300ms클리어·본 앱 실행 프로세스 로그에서 Godot 오류, Java fatal, ANR 표식이 발견되지 않았다. [PID별 수집 로그 검사](w5_device_evidence_2026-09-23/v6_log_audit.json). 이는 수집 범위에 대한 판정이며 시스템 전체/장기 무오류 주장이 아니다. version5에서 발견한 오류는 앞 절에 별도 보존한다. [최종 요약](w5_device_evidence_2026-09-23/summary.json).

## 검증 방법과 범위

본 앱 패키지 `com.blocktower.game`에는 파일 손상, 초기화, 삭제를 하지 않았다. 저장 중단/잠금은 `com.blocktower.recovery.qa`, UI fixture/손상은 `com.blocktower.game.qa`에서만 주입했다. 검사 전 본 앱의 점수10·최고1047·revision41·누적9층과 조각 공급/RNG까지 포함한 전체 상태를 보관했다.

[DeviceInputProbe.java](../../tools/DeviceInputProbe.java)는 ADB shell UID에서 Android OS의 held touch / 2-pointer MotionEvent를 주입하는 검사 도구이며 APK에는 포함되지 않는다. Android13의 [AOSP InputManager](https://raw.githubusercontent.com/aosp-mirror/platform_frameworks_base/android13-release/core/java/android/hardware/input/InputManager.java) API를 참고했다. 사람 손가락으로 플레이한 사용성 승인과 구분한다. 잠금 화면의 인증을 우회하지 않는다.

이번 결과는 해당 Android13 한 기기의 프로세스 종료 및 OS 중단/복귀 범위다. 물리적 전원 차단, 다른 기기/Android 버전, 장시간 발열·프레임/입력 지연 계측, 사람의 소리·진동·게임필 판단은 완료 판정에 포함하지 않는다. W5 전체 성능·체감 승인과 W6 사람 관찰 관문은 별도로 남는다.

## 재현

```powershell
pwsh -NoProfile -File tools/test.ps1
python tools/verify_presentation.py --cases lifecycle:360x800,lifecycle:320x568 --output tools/out/w5_lifecycle_rerun
python tools/verify_android_recovery.py --adb C:/Users/batis/AppData/Local/Android/Sdk/platform-tools/adb.exe --serial R3CN80ZJ8SV --output tools/out/w5_device_recovery_rerun
```

저장 QA가 먼저 빌드/설치되어 있어야 한다. 이번 종료 시 QA를 삭제했으므로 재실행 때 `tools/build_android_recovery_probe.py` 빌드와 `adb -s R3CN80ZJ8SV install --no-incremental -r tools/out/android_recovery_probe/probe.apk` 설치가 필요하다. 기존 보고서는 당시 검사 범위로 보존한다. [W5 저장 구현](W5_Android_Save_Recovery_2026-09-21.md), [W5 lifecycle 구현](W5_Lifecycle_Input_2026-09-21.md).
