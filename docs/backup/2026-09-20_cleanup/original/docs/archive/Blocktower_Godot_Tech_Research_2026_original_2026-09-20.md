# Blocktower Godot 기술 리서치 2026

- 기준일: 2026-09-20
- 대상 프로젝트: Blocktower
- 확정 엔진: Godot 4.7.x + GDScript
- 그래픽: 2D Puzzle + 2.5D Pre-rendered Tower
- 조사 범위: 2026년 이후 영어권 Reddit Godot 개발자 커뮤니티 + 최신 GitHub 공개 프로젝트
- 목적: 개발 착수 전 필요한 코드 구조, 효과음, 애니메이션, VFX, 데이터 구조, 테스트 도구 및 참고 프로젝트 선정

---

## 1. 핵심 결론

Blocktower는 **핵심 퍼즐 로직은 직접 GDScript로 구현하고, 오디오·테스트·일부 Game Feel만 검증된 도구를 사용하는 방식**이 가장 적합하다.

권장 조합:

| 영역 | 권장안 |
|---|---|
| 퍼즐 핵심 로직 | 직접 GDScript 구현 |
| 보드/조각 데이터 | Custom Resource (`.tres`) |
| 이벤트 연결 | Godot Signal 중심 |
| 짧은 UI/블록 애니메이션 | Tween |
| 복합 연출 | AnimationPlayer |
| 효과음 재생 | Godot Sound Manager |
| 효과음 제작/프로토타입 | WAV 중심 + GodotSfxr 참고 |
| 반복 SFX 변화 | 여러 샘플 + Pitch/Volume Variation |
| VFX | GPUParticles2D + 간단한 Shader/Tween |
| Game Feel 참고 | Saltmire Juice / Spark |
| 테스트 | GUT 9.7.1 (Godot 4.7.x) |
| 저장 | 자체 SaveManager |
| 공식 참고 코드 | Godot Demo Projects |
| 퍼즐 참고 코드 | Kenney Starter Kit Match-3 |

핵심 원칙:

> **많은 플러그인으로 퍼즐 자체를 구성하지 않고, 규칙 로직은 직접 소유한다. 외부 도구는 오디오·테스트·Game Feel처럼 교체 가능한 영역에만 사용한다.**

---

## 2. 권장 프로젝트 구조

```text
res://
├── scripts/
│   ├── core/
│   │   ├── board_data.gd
│   │   ├── piece_data.gd
│   │   ├── placement_validator.gd
│   │   ├── line_detector.gd
│   │   ├── clear_resolver.gd
│   │   ├── score_calculator.gd
│   │   └── game_over_checker.gd
│   ├── game/
│   │   ├── puzzle_board.gd
│   │   ├── piece_controller.gd
│   │   ├── input_controller.gd
│   │   ├── clear_controller.gd
│   │   └── game_state.gd
│   ├── presentation/
│   │   ├── animation_controller.gd
│   │   ├── vfx_controller.gd
│   │   └── audio_controller.gd
│   ├── growth/
│   │   ├── tower_progress.gd
│   │   ├── material_progress.gd
│   │   └── segment_progress.gd
│   └── autoload/
│       ├── event_bus.gd
│       ├── save_manager.gd
│       └── settings_manager.gd
├── resources/
│   ├── pieces/
│   ├── skins/
│   ├── audio/
│   ├── vfx/
│   ├── animation/
│   └── balance/
├── scenes/
├── audio/
├── vfx/
└── tests/
```

---

## 3. 핵심 퍼즐 코드

### 3.1 BoardData
8×8 보드의 논리 상태만 관리한다.

```text
0 = 빈칸
1 = 블록 있음
```

Sprite, Tween, Particle 정보는 섞지 않는다.

### 3.2 PieceData
각 블록 모양을 Resource 데이터로 관리한다.

### 3.3 PlacementValidator
보드 상태와 조각을 기준으로 배치 가능 여부를 계산한다.

### 3.4 LineDetector
배치 후 완성된 가로줄, 세로줄, 교차줄을 탐지한다.

### 3.5 ClearResolver
Blocktower 핵심 차별 로직.

```text
AUTO OFF
→ 완성 줄 저장
→ 보드에 유지
→ 수동 클리어 대기

AUTO ON
→ 완성 즉시 제거
```

### 3.6 ScoreCalculator
점수 계산을 화면 연출과 분리한다.

### 3.7 GameOverChecker
중요 예외:

> 배치 가능한 조각 없음 + 완성된 대기 줄 있음 = 아직 Game Over 아님

---

## 4. 입력 처리

8×8 고정 보드에서는 셀마다 `CollisionShape2D`를 두기보다 터치 좌표를 보드 좌표로 변환하는 방식을 권장한다.

```text
Touch Position
↓
Board Local Position
↓
row / column 계산
↓
PlacementValidator 호출
↓
Preview 표시
```

드래그 중 블록은 손가락보다 약간 위에 표시해 가림을 줄인다.

---

## 5. Signal 사용 전략

2026년 Reddit의 상용 Godot 프로젝트 회고에서는 Editor 연결 Signal이 리팩터링 중 끊어진 경험 때문에 Signal을 포기한 뒤 직접 참조·Polling 구조로 바꿨다가 오히려 결합도와 순환 의존성이 커졌다는 사례가 공유됐다.

권장 이벤트:

```text
piece_placed
line_completed
lines_cleared
auto_mode_changed
game_over
tower_floor_added
tower_segment_completed
skin_changed
```

권장 구조:

```text
Core Logic
    ↓ Signal
Presentation
    ↓
UI / Audio / VFX
```

중요한 Signal 연결은 가능하면 GDScript에서 명시적으로 연결한다.

---

## 6. Custom Resource 활용

Blocktower 권장 Resource:

```text
resources/
├── pieces/
├── skins/
├── audio/
├── vfx/
└── balance/
```

장점:
- 코드 수정 없이 밸런스 변경
- AI 개발 시 데이터와 코드 분리
- 스킨/VFX/SFX 추가 용이

주의:
리소스가 수백 개 이상 늘어나면 Inspector 수작업 편집이 느려질 수 있다. 2026년 Reddit에서는 대량 Resource의 경우 CSV/스프레드시트를 Source of Truth로 두고 Resource를 생성하는 방식이 추천됐다.

초기 Blocktower 규모에서는 `.tres`만으로 충분하다.

---

## 7. Tween vs AnimationPlayer

### Tween 추천
- 블록 집기
- 블록 Snap
- 점수 숫자 증가
- 클리어 버튼
- AUTO Toggle
- UI Fade
- `+3F` 표시

권장 시간:
- Block Snap: 100~160ms
- UI 반응: 약 100~200ms

### AnimationPlayer 추천
- 10층 구간 완성
- 재질 Unlock
- 탑 구간 생성
- 스킨 장착
- Game Over
- 복합 Timeline 연출

실무 기준:

> **런타임 값에 따라 달라지는 짧은 반응 = Tween**  
> **고정 순서와 타이밍이 중요한 복합 연출 = AnimationPlayer**

---

## 8. Blocktower SFX 설계

MVP는 약 **20~30개**의 짧은 SFX면 충분하다.

### Puzzle
- piece_pick_01.wav
- piece_pick_02.wav
- piece_snap_01~04.wav
- piece_invalid_01~02.wav
- line_ready_01~02.wav
- clear_base.wav
- clear_sweetener_01~03.wav
- multi_clear_impact_01~02.wav

### UI
- button.wav
- toggle.wav
- popup_open.wav
- popup_close.wav

### Growth
- floor_add.wav
- floor_multi.wav
- segment_complete.wav
- material_unlock.wav
- skin_equip.wav
- tower_segment_lock.wav

### Game
- game_start.wav
- game_over.wav
- new_best.wav

---

## 9. SFX Layering

```text
1줄
clear_base

2줄
clear_base
+ clear_sweetener_1

3줄
clear_base
+ clear_sweetener_2
+ low_impact

4줄 이상
clear_base
+ structure_impact
+ high_shimmer
```

---

## 10. SFX Variation

반복되는 Snap 사운드는 최소 3~4개 변형을 권장한다.

```text
PieceSnap

Samples:
snap_01
snap_02
snap_03
snap_04

Pitch:
0.96 ~ 1.04

Volume:
-1 dB ~ +1 dB
```

---

## 11. 추천 오디오 플러그인

### Godot Sound Manager
GitHub: https://github.com/nathanhoad/godot_sound_manager

특징:
- Godot 4.6+
- Pooled audio players
- Music crossfade
- UI/local sound 구분
- GDScript/C# 지원
- MIT

Blocktower 권장 Audio Bus:

```text
Master
├── Music
├── UI
├── Puzzle
└── Tower
```

---

## 12. Procedural Audio는 기본안에서 제외

2026년 Reddit 사례에서 `AudioStreamGenerator`를 GDScript로 사용해 여러 악기를 44.1kHz로 실시간 처리하자 모바일 성능이 크게 떨어졌다는 경험이 공유됐다.

Blocktower는 실시간 합성이 필요하지 않으므로:

> **사전 제작 SFX + Pitch/Volume Variation**

을 기본안으로 한다.

---

## 13. GodotSfxr

GitHub: https://github.com/tomeyro/godot-sfxr

추천 용도:
- 프로토타입
- 임시 효과음
- 빠른 플레이 감각 검증

최종 사운드 전체를 8-bit 스타일로 구성하는 것은 권장하지 않는다.

---

## 14. VFX 구성

Visual Bible 원칙:

> Candy Explosion ❌  
> Architectural Sweep ✅

MVP 핵심 VFX:
1. piece_snap
2. line_ready
3. line_clear
4. multi_clear
5. floor_gain
6. segment_complete

---

## 15. GPUParticles2D

초기 기준:

```text
1줄 Clear:
8~16 particles

4줄 이상:
20~40 particles
```

Blocktower에는 수백 개의 파티클이 필요하지 않다.

핵심 표현:
- 구조선
- 짧은 Light Sweep
- 작은 Geometry Fragment
- 빠른 Fade

---

## 16. 모바일 성능 원칙

2026년 Reddit에는 2D 게임에서도 Fullscreen Shader, PointLight2D, AnimatedSprite, Particles가 겹치며 GPU/RAM 사용이 커진 사례가 있다.

반면 Godot 4.6 Mobile Renderer에서 큰 성능 개선을 체감했다는 사용자 사례도 있다.

결론:

> **엔진 성능이 좋아졌다고 VFX를 무제한 추가하지 않는다.**

실기기에서 Profiler와 Monitors로 확인한다.

---

## 17. Saltmire Spark

GitHub: https://github.com/saltmire/saltmire-spark

특징:
- Godot 4
- 2D particle burst
- One-call API
- Procedural
- Texture 불필요
- MIT
- 의존성 없음

Blocktower에서는 구현 방식 참고 및 프로토타입용으로 적합하다.

---

## 18. Saltmire Juice

GitHub: https://github.com/saltmire/saltmire-juice

특징:
- Godot 4.6+
- Screen shake
- Hit stop
- Flash
- Scale punch
- Pooled numbers
- MIT

Blocktower 권장:
- 1~3줄: Shake 없음
- 4줄 이상: 50~80ms 수준의 극약한 Micro Shake
- 접근성 옵션으로 화면 흔들림 OFF 검토

---

## 19. VFX 데이터화

예:

```text
ClearVFXPreset.tres

duration = 0.32
particle_count = 14
line_width = 2
sweep_speed = 0.25
flash_strength = 0.15
shake_strength = 0
```

4줄:

```text
ClearVFX_4.tres

duration = 0.48
particle_count = 36
line_width = 3
sweep_speed = 0.32
flash_strength = 0.25
shake_strength = 0.05
```

---

## 20. GUT 테스트

GitHub: https://github.com/bitwes/Gut

현재 README 기준:
- GUT 9.7.1 → Godot 4.7.x 지원
- GUT 9.x → Godot 4.x
- GDScript로 GDScript 테스트 가능
- MIT

필수 테스트:
1. 가로 한 줄 완성
2. 세로 한 줄 완성
3. 교차 가로+세로
4. 수동 모드에서 즉시 제거되지 않음
5. AUTO ON에서 즉시 제거
6. 대기 줄이 있으면 Game Over 아님
7. 3줄 Clear = 420점
8. 3줄 Clear = Tower +3층
9. 4줄 Clear → Material progression +4
10. 수동→자동 전환 시 대기 줄 1회만 제거
11. 저장/복귀 후 중복 보상 없음

---

## 21. Kenney Starter Kit Match-3

GitHub: https://github.com/KenneyNL/Starter-Kit-Match-3

2026년 공개된 Godot 4.6 기반 Starter Kit.

포함:
- 이해하기 쉬운 코드
- Animation
- Sound
- Particle
- Board 크기 조절
- CC0 2D Sprite
- MIT 코드

Blocktower에서는 Grid, Drag, Tween, Sound Trigger, Particle Trigger 구조를 참고한다.

---

## 22. Godot 공식 Demo Projects

GitHub: https://github.com/godotengine/godot-demo-projects

2026년 7월 Godot 4.7용 Demo release가 공개됨.

특히 참고:
- 2D
- GUI
- Audio
- Mobile
- Glow
- Isometric
- Finite State Machine
- Custom Drawing

---

## 23. 추천 플러그인 최소 구성

### 채택 권장
- GUT
- Godot Sound Manager

### 참고/선택
- GodotSfxr
- Saltmire Spark
- Saltmire Juice

### 기본안에서 제외
- FMOD
- Wwise
- 대형 VFX Framework
- 복잡한 Procedural Audio
- 외부 Puzzle Framework
- 대형 State Machine Plugin
- Physics Framework

---

## 24. 최종 권장 기술 세트

```text
Godot 4.7.x
GDScript

Built-in:
- Signal
- Resource
- Tween
- AnimationPlayer
- GPUParticles2D
- ShaderMaterial
- Audio Bus
- FileAccess

Add-ons:
- GUT
- Godot Sound Manager

Reference:
- Kenney Starter Kit Match-3
- Godot Demo Projects
- GodotSfxr
- Saltmire Spark
- Saltmire Juice
```

---

## 25. 개발 준비 우선순위

### P0 — 규칙
1. BoardData
2. PieceData
3. PlacementValidator
4. LineDetector
5. ClearResolver
6. ScoreCalculator
7. GameOverChecker

### P1 — 자동 테스트
8. GUT 세팅
9. 퍼즐 규칙 테스트
10. 성장 규칙 테스트

### P2 — Game Feel
11. Tween
12. Snap SFX
13. Line Ready SFX
14. Clear SFX
15. 최소 VFX

### P3 — 성장
16. TowerProgress
17. MaterialProgress
18. SegmentProgress
19. 10층 AnimationPlayer 연출

### P4 — 최적화
20. Android 실기기 Profile
21. VFX 수량 튜닝
22. Audio Pool 튜닝
23. 메모리/발열 점검

---

## 26. 최종 권고

> **게임 규칙은 작고 명확한 GDScript로 직접 소유하고, 데이터는 Resource로 분리하며, Tween·SFX·VFX를 초기부터 함께 붙여 플레이 감각을 검증하고, GUT으로 규칙이 깨지지 않게 보호한다.**

특히 Blocktower에서는 **Place → Sound → Tween → Clear**의 1~2초 경험이 손맛을 결정하므로, 로직 완성 후 마지막에 효과음을 붙이는 방식보다 초기 프로토타입부터 최소 SFX와 애니메이션을 함께 넣는 편이 적합하다.

---

## 27. 조사 출처

### Reddit — 2026+
1. Two painful Godot lessons from a one year project  
   https://www.reddit.com/r/godot/comments/1qu06kl/two_painful_godot_lessons_from_a_one_year_project/

2. It's crazy how simple tweens can bring UI to life  
   https://www.reddit.com/r/godot/comments/1tev0q2/its_crazy_how_simple_tweens_can_bring_ui_to_life/

3. Animation player vs Tween  
   https://www.reddit.com/r/godot/comments/1tlr0jo/animation_player_vs_tween/

4. Change my mind: Tween is the best tool in Godot  
   https://www.reddit.com/r/godot/comments/1qhz66f/change_my_mind_tween_is_the_best_tool_in_godot/

5. Do yourself a favor and start using Godot Custom Resources for your weapons!  
   https://www.reddit.com/r/godot/comments/1sbb3wq/do_yourself_a_favor_and_start_using_godot_custom/

6. Custom Resources REDUX  
   https://www.reddit.com/r/godot/comments/1tjm9fj/custom_resources_redux_a_comprehensive_guide_to/

7. Best Ways of Mass-Authoring/Editing Custom Resources?  
   https://www.reddit.com/r/godot/comments/1uqudr5/best_ways_of_massauthoringediting_custom_resources/

8. Real-time Procedural Music in Godot 4: From GDScript to C++ GDExtension  
   https://www.reddit.com/r/godot/comments/1t3hhus/realtime_procedural_music_in_godot_4_from/

9. Procedural audio generation with Godot, is it possible?  
   https://www.reddit.com/r/godot/comments/1t1fqs0/procedural_audio_generation_with_godot_is_it/

10. Performance issues in a 2D game  
    https://www.reddit.com/r/godot/comments/1sj9p0w/performance_issues_in_a_2d_game/

11. Godot 4.6 has made the mobile renderer usable on mobile  
    https://www.reddit.com/r/godot/comments/1re3uas/godot_46_has_made_the_mobile_renderer_usable_on/

### GitHub
1. GUT — https://github.com/bitwes/Gut
2. Godot Sound Manager — https://github.com/nathanhoad/godot_sound_manager
3. Kenney Starter Kit Match-3 — https://github.com/KenneyNL/Starter-Kit-Match-3
4. Godot Demo Projects — https://github.com/godotengine/godot-demo-projects
5. GodotSfxr — https://github.com/tomeyro/godot-sfxr
6. Saltmire Spark — https://github.com/saltmire/saltmire-spark
7. Saltmire Juice — https://github.com/saltmire/saltmire-juice

---

## 28. 출처 해석 주의

- Reddit 게시물은 개발자의 실제 경험과 의견을 확인하는 데 유용하지만 공식 벤치마크는 아니다.
- 개별 성능 사례를 모든 Android/iOS 기기에 일반화하지 않는다.
- GitHub 프로젝트는 사용 전 최신 Release, Issue, License를 다시 확인한다.
- 개발 착수 시 Godot 4.7.x와 각 플러그인의 실제 호환성을 한 번 더 검증한다.
