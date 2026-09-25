# 퍼즐 HUD·흐름 UI/UX 개선 반영 — 2026-09-23

기준일: 2026-09-23. 사용자가 Mobbin 조사와 블록 퍼즐 UI/UX 원칙으로 만든 [개선안 캔버스](https://claude.ai/artifact/Kwsfu4XnUM4iYs87DTKXss)를 승인하고 "전체 다 Godot에 반영"을 요청했다. 퍼즐 규칙, 저장 schema, RNG, 커밋 순서, B안 재질과 탑 모듈은 바꾸지 않았다. **Android 실기기 설치와 체감 검증은 이번 범위에서 하지 않았다.**

## 참고 근거

- Block Blast는 Mobbin에 수록되어 있지 않다. 공개된 UX 원칙만 적용했고, 화면·코드·에셋은 가져오지 않았다.
- Mobbin 참고 화면: [Quizlet Blocks 플레이→종료 흐름](https://mobbin.com/flows/316bc602-ee9a-4c65-9e20-8e0b752ddd09), [Quizlet 블록 퍼즐](https://mobbin.com/screens/6e7e71b7-d02f-44d4-a980-ca44aca2b0d7), [Quizlet 결과](https://mobbin.com/screens/914f0481-4918-4b49-a99c-122998a9774d), [Nike Run Club 다음 단계 진행](https://mobbin.com/screens/2ae2fa41-fa1a-42c3-9329-27e3bf4f1eb7), [LinkedIn 연속 기록](https://mobbin.com/screens/9a775693-d284-4ca6-a590-8fa36db0d8da), [FocusFlight 소리·진동 시트](https://mobbin.com/screens/d9b7865e-8c3c-4333-ac5b-022425c9e9e3), [Brink 설정 시트](https://mobbin.com/screens/ff703c2d-dee4-42d1-9629-f733d4fbdd3a). 링크는 관찰 자료이며 게임 에셋에는 넣지 않았다.

## 적용 내용

| 영역 | 변경 |
|---|---|
| 상단 | 퍼즐 화면의 워드마크와 점수 패널을 없앴다. 상단은 `내 탑 N층` 칩(탑 선 아이콘, 구간 진행 막대, `N층 남음`)과 설정 아이콘 버튼 한 줄이다. |
| 점수 | 쉼표로 묶은 정확한 정수를 가운데에 크게 표시한다. 최고 기록은 기본 배치에서 점수 위, 작은 화면에서 점수 왼쪽에 둔다. 저장된 `streak`가 2 이상이면 최고 기록 줄 오른쪽에 `N묶음 연속` 칩을 보인다(작은 화면 제외). |
| 보드 | 배경판을 38% 어둡게 해 보드와 HUD에 시선을 모은다. 대기 줄은 채운 띠, 실선, 양 끝 점으로 표시한다. |
| 드래그 | 끌고 있는 조각을 별도 레이어에 그려 안내 알약 위로 보이게 했다. 새로 완성될 줄만 띠로 표시하고 `[가능] +N점 · M줄 완성` 안내를 보인다. 원래 칸에는 20% 잔상을 남긴다. |
| 트레이 | 세 칸 패널을 선반 하나로 합쳤고, 레인 전체가 잡기 영역이다. 현재 보드에 놓을 곳이 없는 조각은 흐리게 하고 `×`와 `놓을 곳 없음`을 붙인다. 잡기는 여전히 가능하다. |
| 클리어 | 클리어 버튼과 `자동 클리어` 스위치(끔/켬/대기)를 한 줄에 둔다. 상태별 문구는 대기 줄 `N줄 클리어 / +P점 · 탑 +N층`, 줄 없음 `대기 · 줄을 완성하세요`, 드래그 중 `놓는 동안 잠겨요`, 자동 `자동 · 줄이 바로 지워져요`, 게임 종료 `결과 보기`다. `MUST_CLEAR` 상태에서는 금색 테두리와 `[완성] N줄 · 지워야 계속할 수 있어요`로 강조한다. |
| 성장 피드백 | 커밋된 클리어가 층을 주면 칩에 `+N층` 배지와 금색 테두리를 1.4초 보인다. 움직임 줄이기에서는 같은 배지를 정지 상태로 보인다. 중단하면 숨긴다. |
| 확인창 | 모든 확인창은 안전 영역 안에서 내용 높이에 맞춘 하단 시트다. 두 선택지는 보조 동작을 왼쪽, 주 동작을 오른쪽에 둔다(주 동작은 첫 자식). 자동 전환 문구는 기획 §4.4의 `수동 유지`/`지우고 자동 전환`과 이번 보상 알약을 따른다. |
| 설정 | 닫기 버튼이 있는 시트에 효과음, 음량, 진동, 움직임 줄이기, 큰 글씨 순으로 원본 스위치 재질을 쓴다. `효과음`은 저장값 `muted`의 반대이고, 꺼지면 음량 슬라이더가 비활성된다. `새 게임 시작`은 동작 영역으로 옮겼다. |
| 결과 | `더 놓을 곳이 없어요`, 이번 점수와 최고 기록 카드, 누적 탑 카드(실제 최상단 구간 스프라이트, 누적 층, 진행 막대, 다음 구간까지 남은 층), 이번 결과 안내를 보인다. 동작은 `다시 하기`(판이 끝났으므로 확정된 NEW_RUN), `내 탑 보기`, `보드 보기`다. 계약에 따라 판별 층 카운터는 만들지 않았다. |

## 계약과 에셋

- [presentation_contract.md](../../game/scripts/core/contracts/presentation_contract.md)에 `2026-09-23 HUD and flow refinement` 절을 추가했다. 이 절이 이전의 워드마크·점수 패널·하단 성장 문구 배치를 대체한다.
- [visual_assets_contract.md](../../game/scripts/core/contracts/visual_assets_contract.md)에 새 아이콘·스위치를 기록했다. HUD 칩은 층수를 암시하지 않도록 선 아이콘을 쓴다.
- [build_surfaces.py](../../art_source/visual_bible/build_surfaces.py)가 `icon_close`, `icon_best`, `icon_streak`, `switch_off`, `switch_on`을 새로 생성한다. 기존 런타임 SVG 15개는 재생성 후에도 바이트가 같다(SHA-256 비교).
- **주의:** `export_surfaces.gd`를 다시 실행하면서 `art_source/visual_bible/surface_exports/`의 기존 PNG 15개가 새로 인코딩되었다. 원본 SVG는 같지만 이전 파일은 약 200바이트 더 컸고, README가 말하는 출처 메타데이터가 들어 있었을 수 있다. 이전 사본은 찾지 못해 복원하지 못했다. `manifest.json`은 현재 파일 해시로 갱신했다. 이전 해시는 [fidelity 증거의 source_manifest](fidelity_evidence_2026-09-21/source_manifest.json)에 남아 있다.

## 검증

- 고정 Godot 4.7.2 / GUT 9.7.1: **112개 테스트, 3,233 assertions 통과**, 실패·오류·pending 0. [JUnit](hud_ux_evidence_2026-09-23/gut_unit.xml). 새 테스트 10개가 칩·점수·연속 칩, 클리어 상태와 자동 스위치, `MUST_CLEAR` 강조, 놓을 수 없는 조각 표시, 드래그 새 완성 줄 계산, 시트 크기·순서, 효과음 역전 저장, 결과 시트 재시작·탑 이동, 정수 포맷을 검증한다.
- 기존 테스트 2개는 의도한 구조 변경에 맞춰 조회 방식만 바꿨다. 결과 시트의 사실 확인은 시트 전체 Label을 모아 검사하고, 생명주기 테스트는 줄 컨테이너 안의 음량 슬라이더를 찾는다. 검증 대상은 그대로다.
- GUT가 보고하는 Orphans는 `_layout()`의 `queue_free` 대기 노드다. 별도 확인에서 20회 재배치 직후 996개였던 대기 노드가 5프레임 뒤 0개가 되었다. 누수는 없다.
- Windows 네이티브 프로브: **35개 케이스, 283개 검사 모두 통과**. [요약](hud_ux_evidence_2026-09-23/native/summary.json). 새 케이스는 `hud`(시안과 같은 보드, 320/360/412, 큰 글씨, 안전 영역, 흑백), `drag`, `blocked`(흑백 포함), `over`(320/360)다. 기존 `basic`, `pending`, `valid`, `invalid`, `clear`, `modal`, `settings`, `large`, `max`, `lifecycle`, `input`, `event`, `clear_pick`, `motion`, `tower`, `stress` 케이스도 다시 통과했다. `clear_pick` 기대 문구는 새 드래그 안내에 맞게 `[가능]` 접두사로 바꿨다.
- 대표 캡처: [기본](hud_ux_evidence_2026-09-23/native/hud_360x800.png), [작은 화면](hud_ux_evidence_2026-09-23/native/hud_320x568.png), [대기 줄](hud_ux_evidence_2026-09-23/native/pending_360x800.png), [클리어 보상](hud_ux_evidence_2026-09-23/native/clear_360x800.png), [놓을 곳 없음](hud_ux_evidence_2026-09-23/native/blocked_360x800.png), [흑백](hud_ux_evidence_2026-09-23/native/gray_blocked_360x800.png), [자동 전환 시트](hud_ux_evidence_2026-09-23/native/modal_360x800.png), [설정](hud_ux_evidence_2026-09-23/native/settings_360x800.png), [결과](hud_ux_evidence_2026-09-23/native/over_360x800.png), [결과 작은 화면](hud_ux_evidence_2026-09-23/native/over_320x568.png).

## 남은 한계

- APK를 빌드하거나 SM-N981N에 설치하지 않았다. 실제 터치, 안전 영역, 글꼴 배율, 성능은 확인하지 않았다.
- 9경 단위의 극단 점수는 작은 화면에서 7~8px까지 줄어든다. 기존에도 비슷한 대체 동작이 있었고, 실제 플레이 범위의 값에는 해당하지 않는다.
- DESIGN.md, CLAUDE.md, PRODUCT.md와 docs의 기존 문서는 수정하지 않았다. 스크림 불투명도(0.94→0.82), 하단 성장 문구 제거 같은 기록 반영은 문서 담당 검토 후 진행한다.
