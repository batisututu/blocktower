# Block Blast 참고 게임필 개선 — version7

기준일: 2026-09-23. 사용자 요청으로 소리·진동·손가락 가림·반복 조작·이펙트를 개선했다. Blocktower의 퍼즐 규칙, 저장 schema, 목재 디자인과 원본 합성 음향은 유지한다. **Block Blast 실기기와 1:1 청각·촉각 일치 판정은 아직 없다.**

## 참고 근거와 적용 범위

- [HungryStudio의 공식 Google Play 설명](https://play.google.com/store/apps/details?id=com.block.juggle)은 드래그 배치, 줄 제거, 콤보, 단순 조작과 부드러운 효과를 제품 특성으로 소개한다. 효과음 파형·진동 길이·프레임별 시간 수치는 공개하지 않는다.
- [MrCerise의 독립 Android 구현](https://github.com/MrCerise/block-blast)은 ghost preview, 배치 pop, flash/shrink 제거, 보상 텍스트, 합성음과 햅틱을 함께 사용한다. 공식 앱의 소스나 정확한 동작 증거가 아니므로 코드·에셋을 반입하지 않았다.
- [2026년 4월 이용자 피드백](https://www.reddit.com/r/blockblast/comments/1snqajn/is_anyones_game_feel_weird_after_the_update/)은 진동 변화와 입력 지연이 만족도에 영향을 준다고 보고한다. [2026년 9월 피드백](https://www.reddit.com/r/blockblast/comments/1wgdtdw/why_is_block_blast_suddenly_so_overstimulating/)은 강한 콤보 전환·효과 반복에 대한 피로를 보고한다. 개별 이용자의 체감이므로 수치 사양으로 취급하지 않았다.
- [Godot Input 문서](https://docs.godotengine.org/en/stable/classes/class_input.html)는 `vibrate_handheld`의 길이·진폭과 Android `VIBRATE` 권한을 명시한다. 현재 export preset은 해당 권한을 포함한다. 기기 설정이 진동 출력을 막을 수 있다.

## 적용 내용

| 영역 | version7 동작 |
|---|---|
| 손가락 가림 | 조각 높이에 따라 터치 조각을 손가락 위로 1.4~3.15칸 띄운다. preview와 release가 같은 lift/anchor를 사용한다. |
| 햅틱 | 새 설치는 진동을 켠다. 기존 저장 설정은 보존한다. 선택 9ms/약, 배치 15ms/중, 줄 제거 26~44ms/줄 수별, 새 구간 30ms/강으로 나누고 45ms 간격을 둔다. 한 번의 배치+제거에는 제거 진동 하나만 요청한다. |
| 효과음 | 기존 원본 WAV를 유지한다. 클리어에 낮은 배치 transient를 깔고 제거·공기·2줄 이상 차임을 분리한다. 작은 효과음은 줄 제거를 방해할 때 생략하며 6개 재생 풀을 넘기지 않는다. 반복 배치의 pitch를 작게 순환한다. |
| 화면 효과 | 제거 줄 수에 따라 sweep 두께·밝기와 파편 크기를 조절한다. 보상 문구를 보드 아래로 옮겨 280ms 입력 해제 뒤 다음 배치를 가리지 않는다. 감소 모션은 기존 즉시 정착 동작을 유지한다. |

진동과 효과음은 성공한 커밋 이후에만 재생한다. 손상/저장 실패, 앱 중단 또는 과거 보상 재생은 기존 입력·저장 경계를 따른다. `haptics=false`를 저장한 사용자는 업데이트 뒤에도 꺼진 상태로 남는다.

## 검증

- 고정 Godot 4.7.2 / GUT 9.7.1: **97개 테스트, 3,042 assertions 통과**, 실패·오류·pending 0. [JUnit](blockblast_feel_evidence_2026-09-23/gut_unit.xml).
- Windows 네이티브 확인: 작은 화면 320×568과 360×800 기본 화면, 클리어 중 다음 선택, 0/60/140/220/300/460ms 연출을 캡처했다. 최종 재검사 `clear_pick`·`motion` 통과. [요약](blockblast_feel_evidence_2026-09-23/native_summary.json), [140ms 화면](blockblast_feel_evidence_2026-09-23/clear_t140.png), [300ms 화면](blockblast_feel_evidence_2026-09-23/clear_t300.png), [다음 선택](blockblast_feel_evidence_2026-09-23/clear_pick.png).
- ARM64 debug APK 둘을 빌드하고 package/version을 확인했다. 본 앱: `com.blocktower.game`, versionCode7, `0.1.0-gamefeel7`, SHA-256 `6e0936f71701469d43fe8fe5230fb895f1f85d7e61274c380d4180819865d5c3`. QA: `com.blocktower.game.qa`, SHA-256 `0bcb5cacd821227889d1029aafadc97483ee7d4b3ebaefbb9a35c041675be83`. 두 APK 모두 `game/export/`에 있다.

ADB 기기가 연결되어 있지 않아 version7을 실기기에 설치하거나 실제 스피커·진동 모터·손가락 입력 지연을 평가하지 못했다. version6이 설치된 기존 본 앱과 사용자 저장은 건드리지 않았다. 정확한 Block Blast 비교에는 동일 기기의 기준 앱 녹화와 청취·진동 관찰이 필요하다. QA 앱에서 먼저 반복 배치·다중 줄 제거·진동 ON/OFF·화면 잠금 복귀를 확인한 뒤 본 앱 데이터 보존 업데이트를 판단한다.
