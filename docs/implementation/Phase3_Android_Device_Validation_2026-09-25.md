# Phase 3 건축 MVP Android 실기기 보완·검증

기준일: 2026-09-25. [데스크톱 보완·검증](Phase3_Desktop_Validation_2026-09-25.md) 이후의 소스를 Samsung SM-N981N(Android 13, ARM64, 1080×2400, 60Hz, 약 7.47GiB RAM)에서 확인했다. Godot 4.7.2 Compatibility 렌더러의 ARM64 디버그 APK `0.1.0-phase3-8` / versionCode 8을 사용했다. 이 기록의 기기 수치는 해당 한 기기의 짧은 실행 구간에 한정한다.

## 기기에서 발견하고 수정한 점

- 전체 탑 그림의 윗선이 `구간 축약 보기` 설명에 닿았다. 그림 시작 위치를 20 논리 px 내리고 30·300·3,000층 및 큰 글씨 화면에서 간격을 다시 확인했다.
- 구간 이동·외형 복사 번호 입력창의 미리 채운 숫자가 Android 키보드 입력 앞에 남았다. 창을 열거나 잘못된 번호를 다시 입력할 때 기존 텍스트 전체를 선택해 새 번호로 바로 교체할 수 있게 했다. 실제 키보드에서 `2`를 `3`으로, `1`을 `300`으로 교체해 확인했다.

## 실행 결과

| 범위 | 결과 |
|---|---|
| 고정 Godot/GUT | 138개 테스트, 3,709개 단언, 실패·오류·보류 0. [요약](phase3_device_evidence_2026-09-25/gut_summary.json) |
| Windows 작은 화면 회귀 | 최종 화면 간격 수정 뒤 320×568 기본·큰 글씨/안전 여백, 412×915의 3종·30개 점검 통과. [요약](phase3_device_evidence_2026-09-25/windows_regression_summary.json) |
| 빌드 일치 | 본 앱·QA 앱의 게임 리소스 251개가 바이트 단위로 동일. 두 APK 모두 ARM64 versionCode 8. [빌드 식별](phase3_device_evidence_2026-09-25/build_identity.json) |
| 30·300·3,000층 | 실제 터치 주입으로 상세 화면→확대→다음 구간→Back→전체 탑→Back을 수행했다. 각 높이에서 탐색 전후 저장 바이트가 동일했다. [30층](phase3_device_evidence_2026-09-25/result_30.json), [300층](phase3_device_evidence_2026-09-25/result_300.json), [3,000층](phase3_device_evidence_2026-09-25/result_3000.json) |
| 복사·재시작 | 300층의 벽돌 재질과 장식 4개가 대상 구간 3에 한 revision으로 저장됐다. 3,000층에서는 금속·유리를 구간 1에 복사하면서 기존 벽돌 장식 4개가 제거됐다. 둘 다 프로세스 재시작 후 상태·저장 바이트가 동일했다. [벽돌 결과](phase3_device_evidence_2026-09-25/copy_result_brick_parts.png), [비벽돌·고층 이동 결과](phase3_device_evidence_2026-09-25/result_3000_copy_jump.json) |
| 높은 구간 이동 | 3,000층 탑의 번호 입력창에서 300번 구간을 열고 크리스털 외벽·지붕을 확인했다. 저장 바이트는 변하지 않았다. [화면](phase3_device_evidence_2026-09-25/jump_result_300.png) |
| 큰 글씨·안전 영역 | Android 실제 안전 여백과 큰 글씨에서 30·3,000층 상세/확대/전체 탑을 열었다. [30층](phase3_device_evidence_2026-09-25/large_text_overview_30.png), [3,000층](phase3_device_evidence_2026-09-25/large_text_overview_3000.png) |
| 본 앱 설치 | 연결 당시 `com.blocktower.game`은 설치되어 있지 않았다. 새로 설치해 revision 0/0층의 첫 화면을 실행하고 강제 종료·재실행 후 저장 바이트 동일함을 확인했다. 검사 뒤 QA 앱만 제거하고 본 앱을 실행 상태로 두었다. [첫 화면](phase3_device_evidence_2026-09-25/main_first_run.png), [재시작](phase3_device_evidence_2026-09-25/main_restart.json), [최종 상태](phase3_device_evidence_2026-09-25/final_device_state.json) |

[30층 전체 탑](phase3_device_evidence_2026-09-25/overview_30.png), [300층 전체 탑](phase3_device_evidence_2026-09-25/overview_300.png), [3,000층 전체 탑](phase3_device_evidence_2026-09-25/overview_3000.png)과 [30층 확대](phase3_device_evidence_2026-09-25/focus_30.png), [300층 확대](phase3_device_evidence_2026-09-25/focus_300.png), [3,000층 확대](phase3_device_evidence_2026-09-25/focus_3000.png)를 시각 검사했다. 재질 구분, 지붕/층 접합, 누적 층수와 비중 표기가 보이며 눈에 띄는 외벽 빈틈은 없었다. 이는 개발자의 화면 검사이며 처음 플레이하는 사람의 이해도 관찰은 아니다. 검사 프로세스 로그에서 스크립트 오류, Java fatal, ANR 표식은 발견되지 않았다. [로그 검사](phase3_device_evidence_2026-09-25/log_audit.json), [증거 해시](phase3_device_evidence_2026-09-25/evidence_sha256.json).

## D08 단일 기기 작업 예산과 측정

현재 연결 기기에서 Phase 3 화면의 회귀를 판단하기 위한 **작업 예산**은 전체 PSS 384MiB 이하, Graphics PSS 96MiB 이하, APK 안의 가져온 `.ctex` 합계 8MiB 이하, 60Hz 화면 제출 간격 p95 20ms 이하 및 33.34ms 초과 간격 0개다. 이 수치는 이번 단일 기기에서 여유를 둔 회귀 한계이며 최소 지원 기기 정책이나 다른 기기의 합격 근거가 아니다. `.ctex` APK 크기는 실제 텍스처 VRAM을 뜻하지 않는다.

| QA 상태 | 전체 탑 PSS | Graphics PSS | SurfaceFlinger 제출 간격 p95 / 최대 | 33.34ms 초과 |
|---|---:|---:|---:|---:|
| 30층 | 319,935KiB | 62,232KiB | 16.71 / 16.78ms | 0/125 |
| 300층 | 322,193KiB | 62,232KiB | 16.70 / 16.74ms | 0/125 |
| 3,000층 | 293,875KiB | 51,956KiB | 16.72 / 16.78ms | 0/125 |

측정 실행 사이에 Android의 메모리 회수 상태가 달라졌으므로 높이별 PSS를 선형 비용으로 해석하지 않는다. 관찰된 상세 화면의 최대 PSS는 326,830KiB였다. 3,000층 상세↔전체 화면 10회 왕복에서 같은 프로세스·저장 바이트를 유지했고 PSS는 294,789→295,353KiB(+564KiB)였다. APK의 `.ctex`는 82개, 합계 3,386,398바이트였다. SurfaceFlinger 측정은 각 전체 탑 화면에서 약 4초 동안 수집한 최근 125개 제출 간격이며 엔진 CPU/GPU 처리 시간, 터치 반응 시간, 장시간 발열을 별도로 증명하지 않는다.

## 완료 범위와 남은 관문

Phase 3 MVP의 구현과 이 Samsung 기기에서의 기능·짧은 성능 검증은 완료했다. D08의 **최소 지원 기기 선정** 및 그 기기의 메모리·프레임·텍스처 실제 사용량 검증, 장시간 발열, 처음 플레이하는 사람의 10/30층 이해·꾸미기/대표 선택·가독성 관찰은 아직 수행하지 않았다. 따라서 게임 기획 §36의 Phase 3 전체 수용 관문 통과로 표기하지 않는다. 전체 적용/대량 복사와 일괄 되돌리기는 단일 대상 MVP 범위 밖이다.

## 재실행

`pwsh -NoProfile -File tools/test.ps1` 뒤 QA APK를 `Android Device QA` 프리셋으로 빌드·설치한다. 아래 도구는 **QA 패키지의 데이터만 초기화**하고 각 층수의 정합한 저장 fixture를 생성한다. 1080×2400 기기 좌표를 사용한다.

```powershell
python tools/verify_phase3_device.py --serial R3CN80ZJ8SV --floors 30 --exercise
python tools/verify_phase3_device.py --serial R3CN80ZJ8SV --floors 300 --exercise --copy-mode brick_parts
python tools/verify_phase3_device.py --serial R3CN80ZJ8SV --floors 3000 --exercise --soak-cycles 10
python tools/verify_phase3_device.py --serial R3CN80ZJ8SV --floors 3000 --exercise --copy-mode nonbrick --jump-segment 300
python tools/verify_phase3_device.py --serial R3CN80ZJ8SV --floors 30 --exercise --large-text
python tools/verify_phase3_device.py --serial R3CN80ZJ8SV --floors 3000 --exercise --large-text
```
