# W5 백그라운드·복귀와 연속 입력 안정화

기준일: 2026-09-21. 사용자 요청에 따라 **최신 APK 설치와 실기기 복구 검증을 보류**하고, 다음 구현인 앱 중단/복귀 입력 경계를 완료했다. W5 전체 완료나 Android 실기기 통과를 뜻하지 않는다.

## 구현 결과

- AppRoot가 포커스 상실과 앱 일시정지를 각각 추적한다. 두 조건이 모두 해제돼야 입력이 열린다. 알림 순서와 중복에 영향을 받지 않으며 중단 중 새로 만든 화면도 차단 상태를 이어받는다.
- PresentationController는 비활성 상태에서 드래그·게임 명령·확인 명령을 막는다. 저장 복구가 필요한 상태는 유지한다.
- 중단 시 드래그, 버튼 Tween, 블록/클리어 잔상, 효과음, 예정된 축하를 정리한다. 복귀 때 현재 확정 snapshot으로 버튼을 다시 만들며 보상·RNG·세이브 revision을 변경하지 않는다.
- 이전 버튼, AUTO/새 게임 확인, 설정 체크·음량 슬라이더의 지연 callback은 실행되지 않는다. 모달 뒤 버튼도 실행되지 않는다. 시작 시 손상 복구 안내/읽기 실패 안내는 새 확인/재시도가 필요하다.
- 드래그 중 다른 손가락이 설정 버튼을 누르더라도 GUI에 전달하지 않는다. 복귀 후 남아 있던 release는 블록을 놓지 않으며 새 press부터 시작한다.
- 탑/퍼즐 위치는 유지하고 과거 효과음·클리어 축하를 재생하지 않는다. 저장이 불확실한 경우의 명시적인 재조회 절차는 그대로 유지한다.

계약: [presentation_contract](../../game/scripts/core/contracts/presentation_contract.md). 결정: [ADR-0007](../adr/0007-application-lifecycle-input-boundary.md). 직전 Android 잠금·손상 복구 구현: [저장 복구 보고서](W5_Android_Save_Recovery_2026-09-21.md).

## 실행한 검증

| 범위 | 결과 | 근거 |
|---|---|---|
| 고정 Godot/GUT 회귀 | 93개 / 3,005 assertions, 실패·오류·pending 0 | [로그](w5_lifecycle_evidence_2026-09-21/unit.log), [XML](w5_lifecycle_evidence_2026-09-21/unit.xml) |
| 새 lifecycle 검사 | 위 93개 중 9개. 알림 교차/중복, 지연 callback, clear 중단, 복구/재시도, 20회 반복 복귀의 전체 상태 불변 | `test_application_lifecycle.gd` |
| Windows 실제 입력/렌더링 | 5개 시나리오, 37개 확인 통과 | [summary](w5_lifecycle_evidence_2026-09-21/native/summary.json) |
| Windows 별도 프로세스 저장 회귀 | 26개 통과, 6개 커밋 지점 강제 종료 포함 | [summary](w5_lifecycle_evidence_2026-09-21/restart.json) |
| Android 실기기 설치·복구·lifecycle | **보류, 미실행** | 사용자 요청. 다음 통합 검사에서 수행 |

Windows lifecycle 시나리오는 실제 AppRoot와 파일 세션을 열고 Godot의 mouse/touch 입력 경로를 사용했다. 앱 알림은 테스트가 주입한다. 360×800 및 320×568에서 버튼 press→중단→복귀→release, 두 번째 터치의 메뉴 침범, orphan release, 클리어 뒤 확정 상태/HUD/파일 일치와 축하 미재생을 검사했다. 추가로 일반 배치·AUTO 확인·설정 화면을 점검했다. [작은 화면 복귀 캡처](w5_lifecycle_evidence_2026-09-21/native/lifecycle_320x568.png)도 확인했다.

Android 저장 검사 44개는 직전 version4의 에뮬레이터 증거다. 이번 실행으로 다시 센 결과가 아니며, 이번 lifecycle의 Android 통과 근거로 사용하지 않는다. 저장 schema/core/persistence 변경은 없다.

## 통합 빌드

`0.1.0-w5-lifecycle5` / versionCode5, ARM64 디버그 APK:

- 본 앱: `game/export/blocktower-device-debug.apk`, `com.blocktower.game`.
- 분리 QA: `game/export/blocktower-device-qa.apk`, `com.blocktower.game.qa`.
- 저장 중 강제 종료 전용 QA는 기존 `tools/build_android_recovery_probe.py`로 만든다. 전체 UI QA와 목적이 다르며 본 앱에는 중단 hook을 넣지 않는다.

최종 APK 해시·동일 리소스·테스트 코드 제외 결과는 [빌드 manifest](w5_lifecycle_evidence_2026-09-21/builds.json)를 따른다. APK를 기기에 설치하거나 사용자 본 앱 저장을 변경하지 않았다.

본 앱/전체 UI QA의 리소스 182개가 모두 일치한다. 이전 저장 중단 검사에 사용한 QA와 core/persistence/SavedGame 컴파일 리소스·remap 20개도 일치한다. 본 앱 SHA-256: `726ad2ef0321b50b7b20c3ac07d15b6a38bdbddca560b0d9368a94eb243fcf5e`.

## 다음 실기기 통합 검증 순서

사용자가 보류를 해제한 뒤 진행한다. 이미 연결됐다는 사실만으로 보류를 해제하지 않는다.

| 순서 | 대상·상황 | 통과 조건 |
|---|---|---|
| 1 | 본 앱 업데이트 전/후 | 사용자 저장 세대·전체 상태·설정 보존. 삭제/초기화 없이 version5 설치 |
| 2 | 저장 전용 QA: 6개 commit 지점 종료 | 공개 전 이전 세대, 공개 후 새 세대; 이벤트 재전송에 중복 보상 없음 |
| 3 | 저장 전용 QA: 잠금·손상 | 살아 있는 writer 보호, 죽은 legacy claim 정리, 최신 손상 fallback/원본 보존, 양쪽 손상·미지원 버전 차단 |
| 4 | 전체 UI QA: 드래그 중 Home/화면 잠금·복귀 | 프리뷰/소리 정리, 남은 손가락 release가 배치하지 않음, 새 터치 정상 |
| 5 | 전체 UI QA: 클리어 직후 및 꼬리 중 Home/복귀 | 확정 점수·층수 유지, 중복 보상/효과음/축하 없음, 입력 복원 |
| 6 | 전체 UI QA: 버튼 누른 채 전환·두 손가락 | 늦은 release 실행 없음, 드래그 중 다른 손가락이 메뉴를 열지 않음 |
| 7 | 전체 UI QA: AUTO/새 게임 확인·설정 중 전환 | 이전 확인·설정 입력 폐기, 미확인 destructive action 실행 없음 |
| 8 | 전체 UI QA: 손상 복구/저장 재조회 안내 중 전환 | 필수 안내 유지, 새 확인/재조회만 실행. 닫기/뒤로가기로 우회 불가 |
| 9 | 연속 배치·클리어·모션 감소·탑에서 20회 전환 | 저장 상태 및 설정 일치, 오디오/햅틱 잔류 없음, 포인터/입력 잠금 고착 없음 |
| 10 | 마무리 | 로그·상태·기기별 프레임/지연 기록, QA 정리, 사용자 본 앱으로 복귀 |

소리/진동 체감, Android OS의 실제 알림 순서, 지원 기기별 성능과 전원 차단 내구성은 이번 Windows 결과로 확정하지 않는다. W6 사람 관찰은 기존 G1b 조건 충족 후 진행한다.

## 재현 명령

```powershell
pwsh -NoProfile -File tools/test.ps1
python tools/verify_presentation.py --cases lifecycle:360x800,lifecycle:320x568,input:360x800,modal:320x568,settings:320x568
python tools/verify_save_restart.py --godot C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64.exe
```


## 2026-09-23 후속 검증

사용자가 실기기 검증을 요청하여 설치/검증 보류를 해제했다. SM-N981N(Android13)에서 저장 복구44개를 실행했고, 복구 안내 Home/복귀 시 회색 화면 결함을 발견하여 version6에서 수정했다. 수정 후95개 회귀·Windows lifecycle22개가 통과했다. 현재 설치/상세 결과/잔여 항목은 [통합 실기기 보고서](W5_Device_Combined_Verification_2026-09-23.md)를 따른다. 위의 미실행·보류·구버전 해시는 당시 기록으로 보존한다.
