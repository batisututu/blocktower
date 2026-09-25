# Blocktower 조작감·클리어 연출·UI/UX 개선 리서치 v0.1

> **2026-09-21 적용 결과:** [보드 중심 UI·조작감 구현 및 검증](implementation/GameFeel_Improvement_Report_2026-09-21.md). 아래 연구 제안과 실제 채택값을 구분한다. 원문 커뮤니티 인용·수치는 보존하며, 전부 재현/검증됐다는 의미가 아니다.

- 기준일: 2026-09-21
- 대상: Blocktower 모바일 퍼즐
- 엔진: Godot 4.7.x + GDScript
- 조사 범위: 2026년 이후 영어권 Reddit Godot/게임개발 커뮤니티 + GitHub 오픈소스
- 목적: 현재 개발 중 확인된 3개 문제의 해결 레퍼런스를 개발팀에 제공

## 1. 현재 문제

1. 블록을 정확한 칸에 맞춰야 해서 Drag/Drop 피로감이 큼
2. Line Clear의 손맛/VFX/SFX가 약함
3. Block Blast급 UI/UX 편의성을 구현하고 싶으나 방법이 불명확함

---

## 2. 핵심 결론

### 조작감
정확한 셀 직접 배치에서 다음 구조로 변경한다.

**Finger Offset + Nearest Valid Anchor + Ghost Preview + Magnetic Snap + Snap Hysteresis**

### 클리어 손맛
단순 삭제를 다음 시퀀스로 변경한다.

**Anticipation → Architectural Sweep → Shrink/Fade → Particle → Layered SFX → Haptic → Score/Tower Feedback**

### UI/UX
Block Blast 화면을 그대로 복제하지 않는다.

대신 다음 UX 원칙을 분석해 Blocktower Visual Bible로 다시 표현한다.

- Board 중심 정보 위계
- Tray와 Board 간 짧은 손가락 이동 거리
- Drag 중 Preview
- 배치 보정
- 빠른 피드백
- 단순한 설정 접근

---

# 3. 자료 신뢰도 구분

| 등급 | 의미 |
|---|---|
| A | 공식 프로젝트 또는 널리 사용되는 공개 자료 |
| B | 커뮤니티 반응과 GitHub 평가가 비교적 좋고 적용 가능성이 높음 |
| C | 규모는 작지만 특정 문제 해결 방식이 명확함 |
| R | 연구/분석용. 직접 사용보다 구조 참고 권장 |

---

# 4. 문제 1 — Drag/Drop 조작 피로

## 4.1 Reddit: Drag & Drop UI / Grid Snap

2026-03-07 / r/godot / 약 389 upvotes

https://www.reddit.com/r/godot/comments/1rn6o24/wip_making_some_kind_of_dragdrop_ui/

핵심 시사점:

- Grid에 자연스럽게 붙는 Snap이 만족스럽다는 평가
- Drag 오브젝트가 포인터보다 늦게 따라오는 문제 지적
- Drag 중 input accumulation을 줄이는 방법에 대한 논의
- Tween smoothing과 VSync가 체감 Delay를 만들 수 있다는 경험 공유

### Blocktower 적용

Magnetic Snap만 넣지 말고 아래를 함께 본다.

- Snap
- Drag Latency
- Ghost Preview 안정화
- Finger Offset

---

## 4.2 Reddit: Magnetic Snap / Lock Satisfaction

2026-07-22 / r/godot

https://www.reddit.com/r/godot/comments/1v3gddz/

시사점:

- Piece가 정확히 정착하지 않으면 시각적 만족감이 떨어질 수 있음
- Magnetic Snap과 Lock Feedback이 만족감을 높일 수 있다는 피드백
- Shine/Lock 연출 같은 짧은 피드백 제안

### Blocktower 적용

Release 시 자유 위치가 아니라 유효 Grid Anchor에 확실히 정착시키고,
짧은 Snap Animation을 적용한다.

---

## 4.3 Reddit: iOS Drag/Input Accumulation

2026-09-08 / r/godot

https://www.reddit.com/r/godot/comments/1wb5a5v/has_anyone_pushed_ios_coalesced_touches_through/

핵심:

- 빠른 손가락 이동에서 ScreenDrag Event 간 간격이 커질 수 있음
- 기본 input accumulation이 Drag 이벤트를 프레임 단위로 합칠 수 있다는 분석

### Blocktower 적용

Drag가 느리게 느껴질 때 확인 순서:

1. Tween smoothing 강도
2. VSync
3. Input accumulation
4. `_input()` / `_unhandled_input()` 처리 방식

무조건 accumulated input을 끄는 방식은 권장하지 않는다.

---

# 5. Blocktower Drag UX 권장안

## 5.1 Finger Offset

블록은 손가락보다 약 1~1.5 Cell 위에 표시한다.

```text
Finger
   ●

   ↑ 1~1.5 Cell

  ■■■
```

목적:
- 손가락에 Piece가 가려지는 문제 감소
- Preview 확인 용이

---

## 5.2 Nearest Valid Anchor

```text
Finger Position
→ Nearest Grid Anchor
→ 주변 Anchor 후보 검색
→ Valid Anchor 필터링
→ 가장 가까운 Valid Anchor 선택
→ Ghost Preview
```

초기 검색 범위:

```text
기준 Anchor ±1 Cell
= 최대 3×3 후보
```

8×8 Board에서는 계산 부담이 매우 낮다.

---

## 5.3 Snap Hysteresis

두 셀 경계에서 Preview가 계속 바뀌는 문제를 줄인다.

초기 가안:

```text
Snap Acquire Distance = 0.70 cell
Snap Release Distance = 0.90 cell
```

수치는 Playtest로 조정.

---

# 6. 조작 관련 오픈소스

## C급 — beothorn/slidePuzzle

https://github.com/beothorn/slidePuzzle

조사 시점:
- MIT
- 약 8 Stars
- 5 Forks
- Touch Screen 최적화 명시

주요 특징:
- Drag Piece를 정해진 Path에 유지
- 이동 Smooth 처리
- Touch Puzzle 구조

Blocktower에서 참고할 것:
- Drag Controller 분리
- Position Constraint
- Smooth Movement

직접 Drop-in보다는 구조 참고용.

---

## C급 — Xogot Tile-Based Movement

https://github.com/xogot-projects/Xogot-Tile-Based-Movement

특징:
- MIT
- Godot 4.x
- Grid Snap
- Smooth Tile Movement
- iPad/iPhone Godot 환경 예제

Blocktower에서 참고:
- Grid Position 계산
- Tile Size
- Snap
- `move_toward()` 기반 정착

---

# 7. 문제 2 — Line Clear 손맛 부족

## 7.1 Reddit: Puzzle Game Juice

2026-06-15 / r/godot / 약 527 upvotes

https://www.reddit.com/r/godot/comments/1u6268p/starting_to_add_some_juice/

퍼즐게임 개발자가 Tile/목표 달성 연출을 강화한 사례.

시사점:
- 퍼즐은 큰 폭발보다 작은 Timing/Feedback 변화가 효과적
- 목표 달성 직전 Anticipation이 만족감에 기여
- Secondary Motion과 짧은 효과가 유효

---

## 7.2 Reddit: Godot Tween

2026-01-20 / r/godot / 약 159 upvotes

https://www.reddit.com/r/godot/comments/1qhz66f/change_my_mind_tween_is_the_best_tool_in_godot/

시사점:
Godot Tween은 다음에 적합하다.

- Scale
- Position
- Alpha
- UI Motion
- Count-up

Blocktower 적용:
- Piece Pick
- Snap
- Clear Shrink
- Fade
- Score Count-up
- Tower +N
- Button Press

---

## 7.3 Reddit: Juicee

2026-06-13 / r/godot / 약 145 upvotes

https://www.reddit.com/r/godot/comments/1u4pczt/juicee_a_free_game_juice_addon_for_godot_4_90/

Godot 4용 Game Feel Addon.

커뮤니티 반응이 비교적 좋고,
빠른 프로토타입 테스트용으로 유용하다.

---

# 8. B급 오픈소스 — Juicee

https://github.com/Kelpekk/Juicee

조사 시점:
- 약 141 Stars
- 8 Forks
- MIT
- Godot 4
- 2026년 업데이트
- Godot Asset Library 등록

Asset Library:
https://godotengine.org/asset-library/asset/5218

기능 예:
- Screen Shake
- Hit Stop
- Spring
- Shader
- Number Effect
- Visual Effect Graph
- 약 90개 Game Feel Effect

Blocktower 적용 권장:
- Scale Pop
- Short Flash
- Micro Shake
- UI Pop
- Spring

주의:
전체 효과를 무분별하게 사용하지 않는다.

Prototype으로 적합한 효과를 찾은 뒤
필요하면 Blocktower 전용 코드로 단순화한다.

---

# 9. A급 오픈소스 — Kenney Starter Kit Match-3

https://github.com/KenneyNL/Starter-Kit-Match-3

조사 시점:
- 약 155 Stars
- 30 Forks
- 2026년 공개
- Godot 4.6
- MIT
- 포함 Asset은 CC0

포함:
- Drag
- Animation
- Sound
- Particle
- Board
- 간단한 Godot 퍼즐 구조

Blocktower에서 참고:
- Input → Animation Trigger
- Sound Trigger
- Particle Trigger
- Scene 구성
- 짧은 Tween

게임 규칙은 다르므로 Match-3 Logic 자체는 사용하지 않는다.

---

# 10. A급 오픈소스 — Godot Demo Projects

https://github.com/godotengine/godot-demo-projects

조사 시점:
- 약 9.5k Stars
- 약 2.2k Forks
- 공식 Godot 조직
- MIT

2026년 릴리스에도 포함된 예:
- 2D Glow
- 2D Isometric
- GUI
- Audio
- Mobile
- Custom Drawing
- State Machine

Blocktower 활용:
- AI/개발자가 만든 구현이 이상할 때 공식 기준으로 비교
- Particle/Shader/GUI/Mobile Input 구현 검증

---

# 11. C급 오픈소스 — Saltmire Spark

https://github.com/saltmire/saltmire-spark

특징:
- MIT
- Godot 4
- Dependency 없음
- Procedural 2D Particle Burst
- One-call API

예:

```gdscript
Spark.burst(global_position)
```

Blocktower 활용:
- Structure Fragment
- Line Dust
- Tiny Light Particle

Preset을 그대로 쓰기보다 Blocktower용으로 튜닝한다.

---

# 12. Blocktower Clear Sequence 권장안

현재:

```text
Line Complete
→ Delete
```

개선:

```text
Line Complete / Clear Input
↓
Lock
↓
Anticipation
↓
Architectural Sweep
↓
Shrink + Fade
↓
Geometry Particle
↓
Layered SFX
↓
Haptic
↓
Score / Tower Result
↓
Recovery
```

---

# 13. Clear Timing 가안

```text
Lock          40~70ms
Anticipation  60~90ms
Sweep         100~160ms
Break/Fade    140~200ms
Reward        180~300ms
```

전체 약 300~500ms 수준.

다음 입력을 불필요하게 막지 않는다.

---

# 14. Line 수별 연출 차등

## 1줄
- Light Sweep
- 8~12 Particles
- Clear Base SFX
- Light Haptic
- Shake 없음

## 2줄
- Dual Sweep
- 12~18 Particles
- Sweetener SFX

## 3줄
- Structure Light 강화
- 18~24 Particles
- Impact Layer

## 4줄+
- Landmark Clear
- 24~36 Particles
- Low Punch + High Shimmer
- 매우 약한 Micro Shake 가능

---

# 15. 접근성

2026-06-22 Godot 커뮤니티에서는 Screen Shake를 사용할 경우
사용자가 끌 수 있도록 하라는 피드백이 나왔다.

https://www.reddit.com/r/godot/comments/1ucuv7d/my_godot_games_visual_style_is_starting_to_look/

권장 설정:
- Haptic ON/OFF
- Screen Shake ON/OFF
- 또는 Reduced Motion

---

# 16. 문제 3 — Block Blast급 UI/UX 구현

## 핵심 원칙

Block Blast의 화면을 그대로 복제하지 않는다.

대신 다음 사용성 원칙을 참고한다.

- Board가 화면의 중심
- Tray가 Board 가까이 위치
- Drag Piece가 손가락에 가리지 않음
- Ghost Preview 제공
- Snap Assist
- Score는 플레이를 방해하지 않음
- Settings는 단순
- 결과가 빠르게 전달됨

복제하지 않을 것:
- 정확한 Color Palette
- Glossy Block
- Board Frame
- Crown UI
- Score Typography
- Gear 위치/형태
- Combo Text
- Particle
- Sound

---

# 17. R급 오픈소스 — MrCerise/block-blast

https://github.com/MrCerise/block-blast

- MIT
- Android Kotlin
- Custom View + Canvas
- Block Blast Interaction을 매우 직접적으로 재현

README 명시 기능:
- 8×8 Board
- 3 Piece Tray
- Smooth Drag & Drop
- Ghost Preview
- Valid/Invalid Preview
- Placement Pop-in
- Flash-and-Shrink Clear
- Invalid Drop Shake
- Floating Combo Text
- Sound
- Haptics
- Auto Save

### 연구 가치

현재 Blocktower의 3개 문제와 거의 직접적으로 대응한다.

특히 분석 대상:

```text
Drag → Preview
Preview → Release
Place → Pop
Clear → Flash & Shrink
Clear → Sound/Haptic
```

### 제한

GitHub Stars는 거의 없어 커뮤니티 검증도는 낮다.

또한 저장소가 의도적으로 Block Blast reference build의 look & feel을 맞춘 clone이라고 설명한다.

따라서:

**Interaction Timing 연구용으로만 사용**

최종 UI/Art 복제 기준으로 사용하지 않는다.

---

# 18. UI/UX 벤치마킹 방법

## WHAT

Block Blast 화면에서 존재하는 요소를 분리한다.

```text
Score
Best
Board
Tray
Settings
Placement Preview
Clear Feedback
```

## WHY

각 요소가 왜 그 위치/방식인지 분석한다.

```text
왜 Board가 중앙인가?
왜 Tray가 Board 아래인가?
왜 Drag Piece가 Finger보다 위에 뜨는가?
왜 배치 전에 Preview가 보이는가?
```

## RE-APPLICATION

Blocktower의 고유 정보도 반영한다.

```text
Auto / Manual
Manual Clear Button
Tower Growth
```

---

# 19. Blocktower 화면 구조 초안

```text
┌────────────────────┐
│ BEST         TOWER │
│       SCORE        │
│ AUTO : 수동        │
│                    │
│ ┌────────────────┐ │
│ │                │ │
│ │    8 × 8       │ │
│ │    BOARD       │ │
│ │                │ │
│ └────────────────┘ │
│                    │
│ [3줄 클리어 +420] │
│                    │
│   ▦     ▦     ▦    │
└────────────────────┘
```

실제 위치는 Device Mockup 테스트 후 결정.

---

# 20. 개발 우선순위

## P0 — 조작
1. Finger Offset
2. Nearest Valid Anchor
3. Ghost Preview
4. Magnetic Snap
5. Snap Hysteresis
6. Drag Latency 점검

완료 기준:
정확한 셀 중앙에 맞추지 않아도
사용자가 의도한 Valid 위치에 자연스럽게 배치된다.

---

## P1 — Game Feel
1. Clear Lock
2. Anticipation
3. Architectural Sweep
4. Shrink/Fade
5. Geometry Particle
6. Layered SFX
7. Haptic
8. Score/Tower Feedback

---

## P2 — UI/UX
1. Board 중심 정보 위계
2. Tray 거리 최소화
3. Manual Clear Button 접근성
4. Auto/Manual 상태 인지성
5. Tower 정보는 보조 레이어 유지
6. Blocktower Visual Bible로 전체 스타일 재적용

---

# 21. 추천 Open Source 요약

| 자료 | 신뢰도 | 주요 용도 | 라이선스 |
|---|---|---|---|
| Godot Demo Projects | A | 공식 API/VFX/GUI/Mobile 구현 | MIT |
| Kenney Starter Kit Match-3 | A | 퍼즐 Animation/Sound/Particle | MIT + CC0 |
| Juicee | B | Game Feel 빠른 실험 | MIT |
| slidePuzzle | C | Touch Drag/Smooth Constraint | MIT |
| Xogot Tile Movement | C | Grid Snap/Smooth Move | MIT |
| Saltmire Spark | C | 2D Particle Prototype | MIT |
| MrCerise block-blast | R | Block Blast Interaction 분석 | MIT |

---

# 22. 개발팀이 먼저 볼 자료

## 조작
1. https://www.reddit.com/r/godot/comments/1rn6o24/wip_making_some_kind_of_dragdrop_ui/
2. https://github.com/beothorn/slidePuzzle
3. https://github.com/xogot-projects/Xogot-Tile-Based-Movement

## 퍼즐 연출
1. https://github.com/KenneyNL/Starter-Kit-Match-3
2. https://github.com/Kelpekk/Juicee
3. https://www.reddit.com/r/godot/comments/1u6268p/starting_to_add_some_juice/

## Block Blast Interaction Study
1. https://github.com/MrCerise/block-blast

주의:
UI/Art 복제용이 아니라 Interaction Sequence 연구용.

---

# 23. Sprint 제안

## Sprint 1 — Magnetic Placement

구현:
- Finger Offset
- Ghost Preview
- Nearest Valid Anchor
- Snap Hysteresis

테스트:
- 1×1
- Long Line
- L Shape
- Board Edge
- 두 Valid 위치 경계

---

## Sprint 2 — Clear Prototype A/B/C

### A
```text
Fade Only
```

### B
```text
Sweep + Fade + SFX
```

### C
```text
Anticipation
+ Sweep
+ Shrink/Fade
+ Particle
+ Layered SFX
+ Haptic
```

같은 퍼즐 상황에서 비교한다.

---

## Sprint 3 — UI Restructure

Block Blast의 사용성 원칙만 참고하고
Blocktower Visual Bible 기준으로 다시 디자인한다.

---

# 24. 피해야 할 것

- Block Blast Screenshot을 그대로 UI Spec으로 사용
- 동일한 Color Palette
- 동일 Glossy Block
- 동일 Crown/Score UI
- 동일 Particle
- 동일 Combo Text
- 모든 Clear에 Screen Shake
- Juicee의 많은 효과를 무분별하게 적용
- Snap이 너무 강해 원치 않는 셀에 붙는 문제
- Drag Tween이 과해 Piece가 Finger보다 늦게 움직이는 문제

---

# 25. 최종 권고

현재 Blocktower의 완성도 차이를 줄이는 가장 효과적인 순서:

> **Drag Assist → Ghost Preview → Magnetic Snap → Clear Sequence → SFX/Haptic → UI Hierarchy**

먼저 블록을 **놓기 편하게** 만들고,
다음으로 클리어를 **느끼기 좋게** 만들며,
그 이후 화면 전체를 정리한다.

---

# 26. 주요 Reddit 출처

- Drag & Drop / Snap  
  https://www.reddit.com/r/godot/comments/1rn6o24/wip_making_some_kind_of_dragdrop_ui/

- Puzzle Juice  
  https://www.reddit.com/r/godot/comments/1u6268p/starting_to_add_some_juice/

- Tween  
  https://www.reddit.com/r/godot/comments/1qhz66f/change_my_mind_tween_is_the_best_tool_in_godot/

- Juicee  
  https://www.reddit.com/r/godot/comments/1u4pczt/juicee_a_free_game_juice_addon_for_godot_4_90/

- Visual Style / Shake Accessibility  
  https://www.reddit.com/r/godot/comments/1ucuv7d/my_godot_games_visual_style_is_starting_to_look/

- iOS Drag / Input Accumulation  
  https://www.reddit.com/r/godot/comments/1wb5a5v/has_anyone_pushed_ios_coalesced_touches_through/

---

# 27. 주요 GitHub 출처

- Godot Demo Projects  
  https://github.com/godotengine/godot-demo-projects

- Kenney Starter Kit Match-3  
  https://github.com/KenneyNL/Starter-Kit-Match-3

- Juicee  
  https://github.com/Kelpekk/Juicee

- slidePuzzle  
  https://github.com/beothorn/slidePuzzle

- Xogot Tile Based Movement  
  https://github.com/xogot-projects/Xogot-Tile-Based-Movement

- Saltmire Spark  
  https://github.com/saltmire/saltmire-spark

- MrCerise Block Blast Clone  
  https://github.com/MrCerise/block-blast

---

# 28. 출처 해석 주의

- Reddit Upvote는 기술 정확성을 보장하지 않는다. 실제 개발자 반응과 경험을 판단하는 참고 신호다.
- GitHub Stars도 품질 보증은 아니다.
- Godot Demo Projects와 Kenney Starter Kit은 비교적 신뢰도 높은 기준 자료로 사용한다.
- 작은 오픈소스는 코드 전체를 도입하기보다 구현 아이디어 검증 자료로 활용한다.
- Addon 도입 전 Godot 4.7.x 호환성과 Issue 상태를 다시 확인한다.
- Block Blast clone 저장소는 Interaction 연구용이며 최종 UI/Art 복제 기준으로 사용하지 않는다.
