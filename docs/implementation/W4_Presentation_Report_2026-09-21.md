# W4 실제 입력·화면 연결 구현 보고서

- 기준일: 2026-09-21. 사용자 선택 **B안 / B×2 구조 타일·웜 아키텍처** 적용.
- 판정: **Windows 실제 플레이·파일 저장 연결 구현 및 자동 검증 완료.** W4-A/B와 C의 기본 사건 연출을 구현했다. W4-D의 시안 정밀 재현·전체 PF 체험 검수, W5 실기기 검증은 남아 있다. G1a 전체 통과로 확대하지 않는다.
- 기준: [개발 계획](../Blocktower_Development_Plan.md), [ADR-0005](../adr/0005-committed-session-presentation.md), [presentation 계약](../../game/scripts/core/contracts/presentation_contract.md).

## 구현된 동작

실행 장면 `app.tscn`은 AppRoot의 파일 GameSession을 PuzzleScreen에 연결한다. 보드·3슬롯·점수·최고점·수동/자동·클리어 예상 점수·누적 층수는 실제 snapshot/view를 읽는다. 기존 합성 `main.tscn`/design_preview는 별도 대조 장면으로 보존했다.

- 마우스/단일 터치 드래그, 손가락 가림 보정, 유효 프리뷰·겹침 ×, 취소·포커스 상실 처리. 시작 revision/batch와 포인터 소유권으로 오래된 입력·이중 배치를 거부한다.
- 배치와 프리뷰가 core의 동일 판정을 사용한다. 자동 제거 직전의 행·열·중복 제거 셀·스타일을 사건으로 전달해 새로 놓인 셀도 연출에 포함한다.
- 수동 클리어, AUTO 확인/취소, 공급·스트릭·구간/해금·첫 최고 기록 알림, 게임오버·새 게임, 누적 탑 보기·대표 구간 선택을 연결했다. v1에 없는 ‘이번 판 층수’를 임의 계산하지 않는다.
- 저장 성공 후에만 Snap/제거/성장 반응을 시작한다. 저장 불확실·충돌은 재조회 안내로 잠근다. 손상 복원은 조용히 표시하며 이전 보상을 재생하지 않는다.
- 버튼 상태/포커스, 제거 잔상·구조선, 보상 요약, 6종 실제 WAV와 6개 재생 풀, 무음·음량·감소 모션·진동 OFF 기본 설정. 설정 파일은 게임 저장과 별개다.
- 탑은 실제 누적 층수의 선택 구간만 최대 10개 층으로 그린다. 13층의 1구간은 10층+경계 코니스, 2구간은 3층+지붕이다. 10→11 경계도 검사했다.

## 실제 적용한 연출 값과 계획 차이

정본은 [feedback_tokens.gd](../../game/scripts/presentation/feedback_tokens.gd)다. 버튼 100ms, Snap 120ms, 제거/입력 해제 180ms, 토스트 1.8초+150ms fade를 첫 구현값으로 사용한다. 감소 모션은 잔상·입력 잠금을 생략하고 같은 확정 수치를 표시한다. 터치 뒤 합성 마우스를 250ms 억제한다.

§4.4의 250~400ms 클리어 시퀀스와 숫자 count-up은 최초 비교 가안이다. 현재는 짧은 구조선/Fade와 정확한 정수·증감 텍스트로 구현했다. 1/2/3/4+ 음향은 최대 4단계 pitch 설정을 사용하며 별도 레이어/상세 조립/파티클·카메라는 미구현이다. 최고 기록은 한 실행 화면의 판별 상태로 첫 갱신을 알리고, 재개 시 과거 기록 축하는 생략한다. 영속적인 ‘축하 여부’ 필드는 없다.

## 실행 검증

| 검사 | 실제 결과 | 범위·증거 |
|---|---|---|
| 고정 Godot 4.7.2 / GUT 9.7.1 | **74/74 테스트, 2,592 단언 통과**, 실패·오류·pending 0 | [GUT 기록](w4_evidence_2026-09-21/tests/last_test_run.json), [JUnit](w4_evidence_2026-09-21/tests/gut_unit.xml). W3까지의 58개+W4 16개 |
| 별도 프로세스 저장/재실행 | **26개 검사 통과**, 강제 종료 6회 | [재실행 기록](w4_evidence_2026-09-21/restart/summary.json). W4 실제 AppRoot 정상/복구/차단 진입 포함 |
| Windows 네이티브 화면·입력 | **12개 상태 캡처/검사 통과** | [화면 기록](w4_evidence_2026-09-21/native/summary.json). 320×568, 360×800, 412×915의 지정 상태 조합; 모든 상태×모든 크기 전수는 아님 |
| 최대 제거 | 교차 2줄=15셀/240점, 전체 16줄=64셀/2,560점 | core payload + 실제 화면/정착 검사. 자동 배치로 추가된 제거 셀 포함 |
| 연속 실행 | 30행동 모두 idle 복귀 | [측정](w4_evidence_2026-09-21/stress/stress_360x800.metrics.json): dispatch p95 42.810ms/최대 46.836ms; 다음 프레임 대기 p95 15.947ms/최대 24.587ms |

입력 검사는 `Input.parse_input_event`로 Godot의 네이티브 입력 분배를 거쳐 선택→프리뷰→드롭→커밋 1회→동일 저장 상태를 확인했다. OS 물리 마우스나 실제 터치 패널 시험은 아니다. 성능 수치는 Windows OpenGL/NVIDIA RTX 3070 Laptop 호스트의 동기 파일 커밋을 포함한 관찰값이다. 모바일 60fps·입력 지연·GPU 단독 시간·열 안정성의 통과 증거로 사용하지 않는다.

레드팀 검토에서 복구 안내의 resize 후 소실, 주요 버튼 대비, 재개한 판의 최초 최고 기록 알림, 중간 구간의 잘못된 지붕을 수정했다. 회귀 검사로 고정했으며 주요 버튼 글자 대비는 정상 약 5.16:1, hover 5.76:1, pressed 4.79:1이다. [검토 기록](w4_evidence_2026-09-21/finish-review.md)의 판정은 Windows 첫 플레이 범위다.

## 첫 에셋과 재현

- 건축 배경: `game/assets/presentation/architecture_b.png`. 사용자 시안을 참조해 이미지 생성 도구로 제작. [정확한 프롬프트](../../art_source/w4/background_prompt.txt) 보존, PNG 메타데이터 포함.
- 목재: `floor/roof/base/cornice.png`, 384×256 투명 배경. [Godot 3D 원본 생성기](../../art_source/w4/render_tower.gd), anchor (192,128), 층 간격 50.5614166px. 외부 모델/텍스처 없이 재현한다. 최종 Blender/세밀한 장식 납품은 아니다.
- 블록/HUD/효과: 코드 기반 재질형 베벨·상태 윤곽·구조선. 독립 텍스트/입력 UI이며 전체 시안 이미지를 배경 UI로 붙이지 않았다.
- 음향: [원본 합성 코드](../../art_source/w4/build_audio.py), 44.1kHz mono PCM16 WAV 6종. [음원 manifest](../../game/assets/audio/manifest.json)에 길이·피크·SHA를 기록했다. 외부 CC0 음원으로 표시하지 않는다.
- [아트 출처·해시](../../art_source/w4/manifest.json), [소스/증거 해시](w4_evidence_2026-09-21/source_manifest.json), [권리 기록](../../THIRD_PARTY_NOTICES.md).

```powershell
pwsh -NoProfile -File tools/test.ps1
pwsh -NoProfile -File tools/run.ps1
python tools/verify_presentation.py
python tools/verify_presentation.py --cases tower:360x800,tower_top:360x800
python tools/verify_presentation.py --cases stress:360x800
python tools/verify_save_restart.py --godot C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64.exe
```

검증 프로필은 실행별 새 출력 폴더에 격리한다. `--output` 폴더를 재사용하지 않는다. 평상시 앱은 기존 `user://save_v1`을 복원한다. 기존 기능 시안만 캡처하려면 `tools/capture_design.ps1`을 사용한다.

## 다음 검수와 개발

1. W0/W4-D: 사용자 시안 대비 블록 표면·HUD 디테일·목재 탑의 세밀한 외형을 보완하고 VR01~VR06 대조. B 방향 선택을 최종 외형 승인으로 해석하지 않는다.
2. PF06/08/09/10: 실제 연타 청취·음향 동기화, 최대 알림 줄바꿈, 큰 글꼴·회색조·모든 상태/크기·중단 시점, 노드/메모리/오버드로 및 지연 실측. 자동 검사로 사람 체험 평가를 대체하지 않는다. C는 미제작이다.
3. W5: 4.7.2 export templates/Android 설정, 모바일 프로세스 잠금 복구, 실제 터치·safe area·백그라운드·재실행·진동 권한/출력·프레임 측정. 데스크톱에서 첫 플레이가 가능한 상태로 이 작업을 진행한다.

W6 사람 관찰과 제품 밸런스, 4재질 전체/상점/계정/온라인은 이번 완료 범위에 포함하지 않는다.
