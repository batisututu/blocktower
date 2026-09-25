# W5 Android 실기기 중간 검증

2026-09-21, 연결된 **삼성 SM-N981N / Android 13(API 33) / ARM64 / 1080×2400 / 450dpi**에 설치하고 검사했다. 에뮬레이터는 대상에서 제외했다. **기본 플레이·복원·탐색 중간 검증은 통과했고, W5 전체 완료는 아니다.**

최종 설치: `com.blocktower.game`, `0.1.0-w5-device2` / versionCode 2, 디버그 서명. [빌드·기기 정보와 APK 해시](w5_device_evidence_2026-09-21/device_build.json), [검사 요약](w5_device_evidence_2026-09-21/summary.json).

## 설치와 수정

고정 엔진과 같은 공식 Godot 4.7.2 export templates를 내려받아 공식 SHA512-SUMS와 대조했다. Android debug/release APK 템플릿만 로컬 엔진 자료실에 설치했다. [템플릿 출처](w5_device_evidence_2026-09-21/template_provenance.json).

`game/export_presets.cfg`에 ARM64 디버그 APK를 등록하고, `project.godot`의 ETC2/ASTC 가져오기를 활성화했다. 실제 사용 도구는 SDK build-tools 36.0.0, 기존 Zulu JDK 25다. 서명 검증과 실기기 설치가 성공했다. JDK 25에서는 apksigner의 native-access 경고가 있었으나 빌드는 성공했다. [Godot 공식 Android 안내](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)는 JDK 17을 권장하며 상위 버전도 지원한다. 재현 환경을 새로 구성할 때에는 이 권장 버전을 우선한다.

첫 설치는 incremental 방식이 기기에서 거절된 뒤 streamed 방식으로 성공했다. 이후 명령은 `--no-incremental -r`로 고정했다. 내부 GodotApp 직접 실행은 exported 제한으로 거절되어 공개 MAIN/LAUNCHER 경로로 변경했다. 앱 삭제·데이터 초기화는 하지 않았다.

내보내기 로그에는 `No project icon specified` 오류 수준 메시지 1건이 남아 있다. 엔진 기본 아이콘으로 서명/설치/실행은 성공했으나 브랜드 런처 아이콘 지정은 후속 납품 항목이다. 따라서 export 로그 전체를 무오류로 판정하지 않는다. 실행 중 Godot 오류 검사는 별도로 수행했다.

실기기에서 **설정창의 Android 뒤로가기가 앱 전체를 종료하는 문제**를 재현했다. AppRoot가 `quit_on_go_back=false`로 시스템 뒤로가기를 받아 모달 닫기→드래그 취소→탑에서 퍼즐 복귀를 우선 처리하고 루트에서만 종료하도록 수정했다. 데스크톱 Escape도 같은 화면 탐색 함수를 사용한다. 저장 오류 모달의 잠금은 유지한다. [공식 SceneTree 계약](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-quit-on-go-back)을 따랐다.

## 실행 결과

실기기에 전달한 조작은 ADB `input swipe/tap/keyevent`를 통한 Android 입력이다. Windows의 `Input.parse_input_event` 검증과 구분한다. 기기에 설치 직후 사용자 조작으로 진행된 상태를 읽어 기준으로 삼았고, 테스트용 보드나 세이브를 주입하지 않았다.

| 검사 | 관찰 및 판정 |
|---|---|
| 시작·리소스 | ARM64 APK 설치/실행 성공. GLES 3.2 / Adreno 650. 구조 타일·한글·아치 배경·입체 탑 정상 표시 |
| 보드 밖 드롭 | revision 10 상태 전체 불변, 조각 회수·오류 안내 확인 |
| 실제 배치·자동 클리어 | 하단 네 빈칸에 line4 배치. revision 10→11, 점수 227→331(+4 배치/+100 제거), 층수 2→3, 새 조각 3개 공급. 중복 커밋 없음 |
| 탑 연결 | 실제 누적 3층과 3개의 층 모듈·지붕 표시 |
| 백그라운드 | Home→앱 복귀 전후 전체 상태 동일 |
| 강제 종료·복원 | `am force-stop` 후 재실행. 보드·점수·성장·조각·RNG checkpoint·revision 전체 동일 |
| 덮어쓰기 설치 | versionCode 1→2를 `install -r`로 갱신. 게임 상태와 움직임 줄이기 설정 유지 |
| 뒤로가기 수정 | 설정→탑→퍼즐에서 같은 PID 유지. 루트 뒤로가기는 종료, 재실행 후 전체 상태 복원 |
| 새 게임 취소 | 확인창에서 시스템 뒤로가기로 취소. 전체 상태 불변 |
| 설정 파일 | 움직임 줄이기 켜기→업데이트 후 복원 확인→원래 꺼짐으로 복원. 소리·진동·음량은 유지 |
| 화면 | 퍼즐·탑·설정·확인창 캡처에서 필수 글자/버튼의 잘림이나 중첩 없음. 이 기기 기본 설정의 세로 화면 범위 |
| 로그·회귀 | 최종 앱 PID 로그에서 Godot SCRIPT ERROR/ERROR 및 FATAL EXCEPTION 없음. Windows 전체 75개 테스트·2,602개 단언 통과 |

배치 자동화의 첫 유효 드롭 시도는 x좌표를 칸 경계에 두어 거절됐다. 상태가 바뀌지 않음을 확인한 뒤 칸 내부 좌표로 보정해 성공했다. 이를 제품의 드래그 성공으로 계산하지 않았다. 최종 좌표는 `(239,1674)→(400,1443)`, 1초 swipe다. 터치 시 조각을 손가락 위로 띄우는 오프셋을 포함하며 다른 기기/보드에서 그대로 재사용하면 안 된다.

설치 후 콜드 시작의 Android `am start -W` TotalTime은 1,391ms, 후속 재시작은 592ms였다. 이는 Activity 시작 측정이며 플레이 가능 시간이나 터치 지연 측정값이 아니다. 마지막 퍼즐 화면의 PSS는 288,499KB(약 282MiB), RSS는 385,288KB였다. 한 시점의 디버그 빌드 값이며 장시간 성능/누수 검증을 의미하지 않는다.

확인 종료 시 **331점·3층·revision 11**, 자동 클리어 켜짐, 남은 `line3_v1 / line5_v1 / rect2x3_v0`를 보존했다. 앱은 퍼즐 화면에 열어두었다. 이후 사용자 플레이로 값은 달라질 수 있다.

## 화면·원시 증거

- [최종 퍼즐](w5_device_evidence_2026-09-21/20_final_puzzle.png), [탑](w5_device_evidence_2026-09-21/16_back_to_tower.png), [설정](w5_device_evidence_2026-09-21/15_final_settings.png), [자동 클리어 보상](w5_device_evidence_2026-09-21/08b_auto_clear.png).
- [새 게임 확인](w5_device_evidence_2026-09-21/18_new_run_confirmation.png), [취소 후 상태](w5_device_evidence_2026-09-21/19_cancel_new_run.png).
- 같은 evidence 폴더의 전후 state/slot JSON은 실제 파일을 읽은 사본이다. payload SHA-256을 확인한 후 높은 revision의 유효 세대를 비교했다. 상태 파일에 쓰는 테스트는 하지 않았다.
- `export.log`, `final_runtime.log`, `memory.txt`, `last_test_run.json`, `gut_unit.xml`, `tests_final.log`, `source_manifest.json`을 함께 보존했다. 과거 W3/W4 및 B안 외형 증거는 변경하지 않는다.

## 재현

APK: `game/export/blocktower-device-debug.apk` (빌드 출력, git 제외). 서명 키와 엔진/SDK는 로컬 자료이며 저장소에 넣지 않는다.

```powershell
pwsh -NoProfile -File tools/test.ps1
& C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path game --export-debug 'Android Device Debug' export/blocktower-device-debug.apk
# adb devices -l에서 실기기 serial을 확인해 명시한다.
adb -s <DEVICE_SERIAL> install --no-incremental -r game/export/blocktower-device-debug.apk
adb -s <DEVICE_SERIAL> shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p com.blocktower.game
```

이 PC의 adb는 `C:/Users/batis/AppData/Local/Android/Sdk/platform-tools/adb.exe`다. 패키지 서명이 다른 기존 앱을 발견하면 삭제해 해결하지 않고 데이터 보존 방법부터 판단한다.

## 다음 검증과 알려진 한계

1. **저장 커밋 도중 프로세스 사망/잔여 잠금 복구:** 아직 Android `_owner_status` 어댑터가 없어 잔여 writer lock을 만나면 안전하게 오류로 멈춘다. 이번 종료는 완료된 커밋 이후이며 해당 결함 복구를 검증하지 않았다. W5 우선 구현 항목이다.
2. 수동 클리어·교차/최대 제거·10/11층 경계의 실기기 전체 조합, 드래그 중 Home/전화/멀티터치 및 화면 잠금 복귀가 남아 있다.
3. 다른 화면비/노치·내비게이션 방식·큰 글꼴·접근성, 실제 손가락 사용성, 음향 청취·햅틱 체감, 장시간 발열/FPS/배터리 측정이 남아 있다.
4. 브랜드 런처/adaptive 아이콘 지정 후 export의 기본 아이콘 진단을 제거한다.

G_DEVICE는 **단일 기기 중간 통과**, G1b 및 전체 PF01~PF10은 미완료로 유지한다. 디버그 APK 설치가 배포용 서명·스토어 출시 준비 완료를 의미하지 않는다.
