# 코드 리뷰와 반복 계산 최적화

기준일: 2026-09-26. 기준 커밋 `7450a32`. 사용자 요청에 따라 퍼즐 입력·표현, 상태 분석, 온라인 행동 저장 및 Phase 4 서버의 반복 처리 경로를 읽고, 클라이언트에서 확인된 중복 계산과 미사용 선언을 정리했다.

## 적용 내용

| 확인한 문제 | 변경과 무효화 조건 |
|---|---|
| `GameSession.view()`가 같은 확정 상태의 보드·성장을 매번 다시 분석 | 세션별 결과를 보관하고 성공한 커밋 직후 비운다. 반환 시 깊은 복사로 호출자의 수정과 분리한다. 실패한 커밋은 기존 결과를 유지한다. |
| 화면 재생성 때 같은 세 조각의 배치 가능 위치를 다시 탐색 | 세션 객체와 revision이 같으면 조각·배치 가능 결과를 재사용한다. 다른 세션으로 교체되면 revision이 같아도 다시 계산한다. |
| 보드 재그리기·트레이 안내·크기 계산마다 조각 Dictionary 복사 | 확정 상태에서 얻은 세 조각을 화면에서 재사용한다. 사용한 슬롯과 새 공급은 커밋 후 갱신한다. |
| 제거할 줄이 없어도 생성기가 64칸을 다시 순회 | 대기 줄이 있을 때만 제거 후 보드를 계산한다. 원본 보드와 반환 버퍼의 분리는 유지한다. |
| 온라인 행동 추가 때 기존 전체 기록을 두 번 깊은 복사 | 추가용 목록만 얕게 복사하고, 저장소가 기록을 소유하는 지점에서 깊은 복사한다. 호출자가 수정한 배열·행동은 저장 기록에 영향을 주지 않는다. |
| 고정 음량 표를 효과음마다 생성 | 상수로 옮겼다. 사용되지 않는 `trim_db` 인수를 제거했다. |
| 중복·미사용 선언 | 동일한 v1/v2 최상위 상태 키 목록을 합치고, `COLORS`, `PANEL`, 퍼즐 화면의 `capture_path`, 생성기의 미사용 `MAX_WEIGHT`를 제거했다. 성장 설명도 검증당 한 번만 계산한다. |

이번 리뷰의 서버 경로에서는 별도 수정하지 않았다. 고정 v1 재생기 묶음은 과거 규칙 재현을 위해 보존한다. 캐시는 저장 파일에 쓰지 않으며 저장 스키마·조각 가중치·규칙 버전은 그대로다.

## 확인 결과

- 고정 Godot 4.7.2/GUT 9.7.1 전체 **150개 테스트, 3,812개 단언** 통과. 실패·오류·pending 0. 가져오기도 통과했다. [결과 요약](code_review_evidence_2026-09-26/last_test_run.json), [JUnit](code_review_evidence_2026-09-26/gut_unit.xml), [전체 로그](code_review_evidence_2026-09-26/gut.stdout.log).
- 신규 회귀 검사는 view 반환값의 중첩 수정 격리, 저장 실패·성공·새 게임 후 갱신, 같은 revision의 다른 세션으로 트레이 교체, 반복 레이아웃의 추가 탐색 0회, 온라인 기록의 호출자 수정 격리와 재시작 복원을 확인한다.
- [동일 스크립트](../../game/tests/integration/optimization_probe.gd)를 변경 전·후 본 프로젝트와 고정 v1 프로젝트에서 각각 실행했다. 두 공급 설정 × 세 시드 × 수동/자동 **12개 시나리오, 450개 행동**의 전체 상태·공급 체크포인트·view·이벤트 이력 SHA-256이 모두 일치했다. [변경 전](code_review_evidence_2026-09-26/before.json), [변경 후](code_review_evidence_2026-09-26/after.json), [고정 v1](code_review_evidence_2026-09-26/frozen_v1.json).
- Windows 실제 렌더링 **8개 시나리오, 95개 점검** 통과: 기본·대기 줄·유효/무효 드래그·2줄 클리어·감소 모션 복합 보상·30회 연속 입력·3,000층 전체 탑. [화면 검사 요약](code_review_evidence_2026-09-26/native_summary.json). [기본 화면](code_review_evidence_2026-09-26/basic_360x800.png)과 [드래그 화면](code_review_evidence_2026-09-26/valid_360x800.png)의 조각·받침판을 직접 확인했다.

GUT 로그에는 테스트 중 `queue_free`된 UI 노드의 orphan 경고를 포함한 경고 70개가 남아 있다. 이 결과를 경고 0건 또는 장시간 메모리 누수 검사 통과로 해석하지 않는다. 이번 변경은 Android APK로 내보내거나 실기기에 설치하지 않았다.

## 성능 측정 범위

Windows 헤드리스 동일 엔진에서 100회 준비 호출 후 7개 표본의 중앙값을 비교했다.

| 측정 | 변경 전 | 변경 후 | 해석 |
|---|---:|---:|---|
| 같은 상태 `view()` 2,000회 | 81.147ms | 11.512ms | 약 85.8% 감소 |
| 자동 제거 설정 전환 커밋 200회 | 55.107ms | 54.946ms | 0.3% 차이로 유의한 개선을 주장하지 않음 |

첫 view는 여전히 실제 분석을 수행한다. 수치는 반복 조회의 제한된 측정이며 Android FPS·배터리·전체 게임 속도 개선율이 아니다.

## 재현 명령

```powershell
& ./tools/test.ps1 -GodotExe 'C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& 'C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/integration/optimization_probe.gd -- C:/DEV/Games/Blocktower/tools/out/optimization_current.json
& 'C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path services/phase4/verifiers/bt_rules_v1 --script C:/DEV/Games/Blocktower/game/tests/integration/optimization_probe.gd -- C:/DEV/Games/Blocktower/tools/out/optimization_frozen.json
python tools/verify_presentation.py --output tools/out/optimization_native --cases 'basic:360x800,pending:320x568,valid:360x800,invalid:360x800,clear:320x568,reduced_event_multi16:360x800,stress:320x568,phase3_overview_3000:360x800'
```

호환성은 두 JSON의 `cases` 배열을 비교한다. 측정 시간은 실행마다 달라진다. 원시 임시 산출물은 `tools/out/code_review_2026-09-26/`에 있고, 저장소에는 위 증거만 보존한다.

## 컨텍스트 축소 후 핸드오프

- 이번 최적화 구현·단위/규칙 호환/Windows 화면 확인은 완료했다. 새로운 변경이나 실패가 없다면 같은 검사를 반복할 필요가 없다.
- 새 캐시를 건드릴 때는 성공 커밋 후 view 무효화와 세션 객체/revision에 따른 트레이 무효화 조건을 함께 유지한다. 미확정 후보 분석은 캐시하지 않는다.
- 사용자 저장·서버 DB는 수정하지 않았다. 연결 기기에는 이전 QA v16, 본 앱 v8이 설치된 상태이며 이번 소스 최적화는 아직 미설치다.
- 다음 개발의 기존 우선순위는 DB 복원 훈련, 구·신 규칙 동시 운영/UTC 주차 경계 확인, 공개 TLS 환경 준비다. 최신 효과음의 실제 청감 평가도 남아 있다.
- 이후 코드 분리 후보는 큰 `puzzle_screen.gd`의 탑 화면·모달 생성 책임이다. 이번 측정만으로 전체 파일 재설계나 추가 캐시가 필요하다고 판정하지 않는다.
- 작업 공간은 `C:/DEV/Games/Blocktower`, 원격은 `https://github.com/batisututu/blocktower.git`, 브랜치는 `main`이다. 사용자에게 받은 커밋·푸시 권한을 유지한다.
