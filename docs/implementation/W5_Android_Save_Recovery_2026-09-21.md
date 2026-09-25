# W5 Android 저장 중 종료·복구

기준일: 2026-09-21. 범위는 Android 저장 잠금·중단 복구다. 전체 W5, 기기별 성능, 사용자 체감 승인을 의미하지 않는다.

## 변경

- `android_file_guard.gd`: Android Java 파일 잠금. 프로세스가 죽으면 OS가 해제한다. 동일 프로세스의 canonical 경로 예약으로 중복 채널 접근도 막는다.
- `file_save_repository.gd`: Android만 새 잠금을 사용한다. 구버전 PID 폴더는 ESRCH로 종료가 확인된 빈 폴더만 정리한다. 살아 있는 프로세스·불명확한 오류·잘못된 폴더는 차단한다.
- 두 세대 저장 형식, 점수/탑/RNG/이벤트 ID, 공개 지점, 복구 알림 UI는 유지한다. 잠금 파일은 삭제하지 않는다.
- [저장 계약](../../game/scripts/core/contracts/file_save_contract.md), [ADR-0006](../adr/0006-android-process-death-save-recovery.md)에 운영 조건과 근거를 기록했다.

## 검증

Windows GUT **84개 / 2,867 assertions** 통과. 기존 82개에 구버전 잠금의 생존/불명확/종료 분기와 잘못되거나 비어 있지 않은 폴더 보존 검사를 추가했다. 별도 Windows 프로세스의 저장·강제 종료·재개 **26개**도 통과했다.

Android는 본 앱과 분리된 `com.blocktower.recovery.qa`에서 production core/persistence/SavedGame을 그대로 복사해 실행한다. 테스트 전용 subclass가 커밋 지점에서 marker를 flush하고 정지하면 ADB가 해당 QA 앱만 force-stop한다. 새 PID로 전체 직렬화 상태를 비교하고, 같은 이벤트 재전송이 ALREADY_APPLIED인지 확인한다. 별도 Java VM도 같은 파일 잠금에 참여시켜 양방향 경합을 검사한다.

**Android 16/API36 x86_64 에뮬레이터에서 44개 검사 통과.** [검사 목록](w5_recovery_evidence_2026-09-21/emulator-5760/checks.json), [실행 manifest](w5_recovery_evidence_2026-09-21/emulator-5760/run.json), [해당 실행 로그](w5_recovery_evidence_2026-09-21/emulator-5760/verified_run_logcat.txt)를 보존했다. 43개 전체 검사 후 pending만 남은 최초 저장 경로를 추가 실행해 44개를 확인했다. 현재 재현 도구는 이 추가 검사도 포함한다. production 소스와 QA 복사본의 해시 일치를 확인했고 해당 실행의 SCRIPT/Parse 오류는 0개다. 기존 SwiftShader의 SceneShader uniform 오류는 남아 있어 이 결과는 저장 동작 검증에만 사용하며 화면/성능 통과로 간주하지 않는다.

SM-N981N 실기기는 초기 QA APK 설치 후 USB 연결이 끊겼다. 재연결을 요청했으나 검증 종료 시점까지 연결되지 않아 **실기기 강제 종료 매트릭스와 version4 본 앱 설치는 미실행**이다. 실기기에는 초기 `Blocktower Recovery QA`가 남아 있으며 재연결 후 검증·제거한다. 본 앱 데이터는 변경하지 않았다.

설치용 `game/export/blocktower-device-debug.apk`는 `com.blocktower.game`, versionCode4 / `0.1.0-w5-recovery4`, ARM64로 빌드했다. SHA-256은 `c47862134a929e13ddac44f379c720bd0933b027fb1b5bea2b9a85bc56b5f3ca`. [APK 검사 기록](w5_recovery_evidence_2026-09-21/production_apk.json)에서 테스트 APK와 production의 core/persistence/SavedGame 컴파일 리소스 및 remap 20개가 모두 일치하고 QA 중단 코드가 본 APK에 없음을 확인했다. 이것은 ARM64 실기기 실행 통과를 대신하지 않는다.

| 중단/오류 | 기대 동작 |
|---|---|
| before_write / after_write / after_verify / after_preserve / after_remove_target | 이전 확정 상태로 재개. 미완료 clear 재시도는 보상을 한 번만 반영 |
| after_publish | 새 확정 상태로 재개. 동일 event 재전송 거부 |
| 최신 슬롯 손상 | 이전 정상 세대로 재개하고 복구 메타데이터 제공. 다음 커밋 전에 손상 원본 보존 |
| 두 슬롯 손상 / 미지원 형식 | 새 게임으로 초기화하지 않고 오류 반환 |
| 다른 프로세스의 유효 잠금 | SAVE_BUSY, 세이브를 건드리지 않음 |
| 구버전 잔여 잠금 | 종료가 확인된 빈 디렉터리만 제거 |

## 재현

고정 Godot 4.7.2, JDK, Android SDK platform36/build-tools36.0.0을 사용한다. QA 패키지 설치/테스트만 아래 명령에서 수행한다. `--serial`은 대상 기기의 ADB serial로 바꾼다. 빌드가 끝난 뒤 ADB 기기 연결이 돌아온 것을 확인한다(Godot 에디터 종료가 ADB 서버를 정리할 수 있음).

```powershell
python tools/build_android_recovery_probe.py --godot C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe
adb -s SERIAL install --no-incremental -r tools/out/android_recovery_probe/probe.apk
python tools/verify_android_recovery.py --adb C:/Users/batis/AppData/Local/Android/Sdk/platform-tools/adb.exe --serial SERIAL
pwsh -NoProfile -File tools/test.ps1
python tools/verify_save_restart.py --godot C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64.exe
```

재현용 QA 빌드 도구도 오류 검사까지 통과했다. 검사 완료 후 에뮬레이터의 QA 앱과 임시 전송 파일을 제거했다. 실제 검사한 QA APK는 `tools/out/w5-tested-recovery-qa.apk`에 보관했으며 실행 manifest의 SHA와 일치한다.

QA Java helper `RecoveryLockProbe.java`는 빌더가 dex로 만들고 검사 도구가 QA 데이터 폴더에만 전달한다. 본 APK는 `tests/*`를 제외하며 probe/Java helper/QA 명령 파서를 포함하지 않는다. 검사 완료 후 QA 앱은 제거할 수 있다. 본 앱 삭제·데이터 초기화는 하지 않는다.

## 한계와 다음 검증

프로세스 강제 종료는 전원 차단·플래시 저장 장치 장애·디렉터리 fsync 보장을 대신하지 않는다. 두 세대가 모두 손상되면 복원이 불가능하며 최신 세대 손상 시 마지막 행동이 되돌아갈 수 있다. 구버전 PID 재사용은 보수적으로 차단될 수 있다. 구버전/신버전의 동시 writer는 지원하지 않고 종료 후 업데이트를 전제한다.

사용자 본 앱 저장에는 손상/종료 주입을 하지 않았다. 설치 가능한 ARM64 version4 APK를 준비했다. 이후 W5는 실기기 동일 매트릭스·실제 앱 복구 안내·빠른 입력 중 백그라운드 복귀·지원 기기별 성능 검증으로 이어진다.


## 2026-09-23 후속 검증

사용자가 실기기 검증을 요청하여 설치/검증 보류를 해제했다. SM-N981N(Android13)에서 저장 복구44개를 실행했고, 복구 안내 Home/복귀 시 회색 화면 결함을 발견하여 version6에서 수정했다. 수정 후95개 회귀·Windows lifecycle22개가 통과했다. 현재 설치/상세 결과/잔여 항목은 [통합 실기기 보고서](W5_Device_Combined_Verification_2026-09-23.md)를 따른다. 위의 미실행·보류·구버전 해시는 당시 기록으로 보존한다.
