# Phase 3 건축 MVP 데스크톱 보완·검증

기준일: 2026-09-25. [초기 구현 기록](Phase3_MVP_Tower_Overview_Copy_2026-09-25.md)의 전체 탑 보기와 단일 구간 복사를 고정 Godot 4.7.2의 Windows 실행 경로에서 확인했다. 기록된 결과는 이번 소스의 데스크톱 범위에 한정한다.

## 보완한 기능

- 전체 탑 화면의 밝은 배경을 낮추고 재질 비중을 소수 첫째 자리로 표시한다. 실제 비중이 0보다 작게 반올림되던 3,000층의 10층 재질도 `0.3%`로 읽힌다. 0보다 크고 0.1% 미만인 경우 `0.1% 미만`으로 표시한다. 정확한 층수 계산은 기존 희소 구간 상태를 따른다.
- 320×568에서 10층 외형이 작게 보이는 문제를 줄이기 위해 구간 화면에 `확대` 동작을 추가했다. 확대 화면은 동일한 프리렌더·저장 외형을 다시 그리며 이전/다음 구간과 닫기·뒤로가기를 제공한다. 이동·확대는 저장, 대표 구간과 공급 상태를 변경하지 않는다. 큰 화면에서는 하단 설명과 탑 받침 사이에 간격을 남겼다.
- 화면 버튼의 글꼴 크기 타입 추론 오류를 명시적 `int`로 고쳤다. 초기 간이 가져오기에서는 드러나지 않았고, 고정 테스트 도구의 콘솔 엔진 가져오기에서 발견됐다.

## 실행 결과

| 범위 | 결과 |
|---|---|
| 고정 엔진/GUT | 138개 테스트, 3,705개 단언, 실패·오류·보류 0. [요약](phase3_desktop_evidence_2026-09-25/gut_summary.json) |
| Windows 파일 저장 | 별도 Godot 프로세스 35회, 46개 점검 통과. 외형 복사의 대상 재질·4개 파츠가 한 revision에서 함께 저장되고 새 프로세스에 복원됐다. 읽기 전용 재개는 저장 바이트를 바꾸지 않았다. [요약](phase3_desktop_evidence_2026-09-25/save_restart_summary.json) |
| Windows 실제 화면 | 전체 탑·확대·복사 시트 11종/110개 점검, 일반 구간 화면 2종/10개 점검 통과. 320×568, 360×800, 412×915과 24px 안전 여백·큰 글씨 화면을 포함한다. [화면 요약](phase3_desktop_evidence_2026-09-25/native_summary.json), [일반 화면 요약](phase3_desktop_evidence_2026-09-25/detail_summary.json) |

30/300/3,000층의 [전체 탑 화면](phase3_desktop_evidence_2026-09-25/phase3_overview_30_320x568.png), [300층 화면](phase3_desktop_evidence_2026-09-25/phase3_overview_300_360x800.png), [3,000층 화면](phase3_desktop_evidence_2026-09-25/phase3_overview_3000_412x915.png)과 [30층 확대](phase3_desktop_evidence_2026-09-25/phase3_focus_30_320x568.png), [3,000층 확대](phase3_desktop_evidence_2026-09-25/phase3_focus_3000_412x915.png)를 육안으로 확인했다. 선택한 10층 구간의 층/지붕 접합에 눈에 띄는 빈틈은 없었다. [복사 시트](phase3_desktop_evidence_2026-09-25/phase3_copy_sheet_320x568.png)의 대상·결과 설명과 [성공 후 대상 화면](phase3_desktop_evidence_2026-09-25/phase3_copy_commit_360x800.png)도 보존했다. 재질 간 소스 모듈 경계의 이전 8방향 검사는 [Phase 2-G 기록](Phase2G_Brick_Landmark_Part_Plan_2026-09-25.md)에 남아 있으며 이번 작업에서 에셋은 수정하지 않았다.

전체 탑 화면에서 각 높이별 24회 다시 그리기를 측정한 Windows 호스트 값은 다음과 같다. 다른 해상도를 함께 사용한 관찰값이며 기기 예산 판정값이 아니다.

| 층수 / 화면 | 다음 화면까지 95백분위 | 최대 | 노드 수 전후 | 엔진 정적 메모리 차이 |
|---|---:|---:|---:|---:|
| 30층 / 320×568 | 6.52ms | 6.62ms | 25→25 | +1,164바이트 |
| 300층 / 360×800 | 6.42ms | 6.89ms | 25→25 | +1,164바이트 |
| 3,000층 / 412×915 | 6.82ms | 6.83ms | 25→25 | +1,164바이트 |

개별 [측정 JSON](phase3_desktop_evidence_2026-09-25/phase3_overview_3000_412x915.metrics.json)과 모든 [증거 해시](phase3_desktop_evidence_2026-09-25/evidence_sha256.json)를 보존했다. 이 시간은 Windows 호스트의 화면 갱신을 포함하지만 GPU 전용 시간, Android 기기 메모리·발열·장시간 프레임 안정성을 의미하지 않는다.

## 남은 수용 조건

이 기록 시점에는 게임 기획 §36의 Phase 3 관문 전체를 통과했다고 판정하지 않았다. 후속 [Android 실기기 검증](Phase3_Android_Device_Validation_2026-09-25.md)에서 연결 기기의 기능·짧은 성능을 측정했다. 최소 지원 기기와 사람의 첫 30층 이해·가독성 관찰은 남아 있다. 전체 적용/대량 복사·일괄 되돌리기는 단일 대상 MVP 범위 밖이다.

## 재실행

저장·단위 검사: `pwsh -NoProfile -File tools/test.ps1`, `python tools/verify_save_restart.py --godot C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64.exe`.

Windows 화면 검사: `python tools/verify_presentation.py --cases phase3_overview_30:320x568,phase3_overview_300:360x800,phase3_overview_3000:412x915,inset_text_phase3_overview_30:320x568,phase3_focus_30:320x568,phase3_focus_300:360x800,phase3_focus_3000:412x915,inset_text_phase3_focus_30:320x568,phase3_copy_sheet:320x568,inset_text_phase3_copy_sheet:320x568,phase3_copy_commit:360x800`.
