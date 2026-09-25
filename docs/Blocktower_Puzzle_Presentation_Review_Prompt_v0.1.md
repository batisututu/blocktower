# Blocktower 블록 퍼즐 시각·청각 연출 검토 프롬프트 v0.1

- 문서 목적: Blocktower의 퍼즐 플레이 연출 완성도 점검 및 개선 레퍼런스
- 대상: Godot 4.7.x + GDScript 기반 모바일 블록 퍼즐
- 핵심 플레이: 8×8 보드 / 블록 3개 제공 / 수동 클리어 기본 / 자동 클리어 ON·OFF / 다중 라인 클리어 / 탑 성장
- 기본 원칙: 새로운 콘텐츠를 추가하기보다, **이미 구현된 게임플레이의 의도와 결과가 충분히 전달되는지 먼저 검토한다.**

---

## 1. 검토 목표

현재 게임을 **상용 모바일 퍼즐게임의 완성도 기준**으로 검토하라.

새로운 기능이나 시스템을 추가하기보다,

> **이미 존재하는 퍼즐 로직이 시각·청각·햅틱 측면에서 충분히 전달되지 않거나, 플레이 감각과 완성도를 떨어뜨리는 요소를 먼저 찾아라.**

특히 Blocktower는 다음 행동의 원인과 결과가 즉시 이해되어야 한다.

- 어떤 블록을 집었는가
- 어디에 놓을 수 있는가
- 왜 그 위치에는 놓을 수 없는가
- 어떤 줄이 완성되었는가
- 어떤 줄이 아직 클리어 대기 중인가
- 수동 클리어를 누르면 무엇이 사라지는가
- 자동 클리어 상태에서는 무엇이 즉시 처리되는가
- 몇 줄을 동시에 지웠는가
- 점수가 얼마나 올랐는가
- 탑이 몇 층 성장했는가
- 왜 게임이 계속되거나 종료되었는가

목표는 더 화려하게 만드는 것이 아니라,

> **의도가 명확하고, 일관되고, 플레이어가 자신의 행동과 결과를 즉시 이해할 수 있는 상태**

를 만드는 것이다.

---

## 2. 사건 분석 프레임

먼저 현재 게임에서 중요한 사건과 상호작용을 파악하고, 각 사건을 다음 흐름으로 분석하라.

> **입력 → Anticipation(준비) → 행동 → 변화/클리어 → 결과 → Recovery(정착)**

Blocktower 예시:

```text
블록 터치
→ 블록이 살짝 떠오르고 Drag 가능 상태 인지
→ 보드 위로 이동
→ 배치 Preview 표시
→ 손을 놓아 실제 배치
→ 줄 완성 여부 표시
→ 클리어/점수/탑 성장
→ 다음 블록 선택 상태로 복귀
```

수동 클리어 예시:

```text
줄 완성
→ 줄이 즉시 사라지지 않고 대기 상태로 Highlight
→ 사용자가 [N줄 클리어] 버튼 인지
→ 버튼 입력
→ 완성 줄 일괄 제거
→ 점수/층수 증가
→ 보드 정착 및 다음 판단
```

---

## 3. 우선 검토해야 할 핵심 사건

### 3.1 블록 선택 / Pickup

확인:

- 터치 직후 블록이 선택되었다는 반응이 있는가
- 손가락에 가려지지 않게 위치가 보정되는가
- 블록 크기/Scale 변화가 과하지 않은가
- 선택 사운드가 너무 강하거나 반복적으로 피로하지 않은가
- 모바일 Haptic이 필요한가

권장 분석 흐름:

```text
Touch
→ 80~120ms Lift
→ Shadow 증가
→ Scale 1.00 → 약 1.04~1.06
→ 약한 Pick SFX / 필요 시 Light Haptic
```

### 3.2 Drag / 이동

확인:

- 이동 중 블록이 손가락을 자연스럽게 따라오는가
- Tween/Lerp가 과도하게 느리거나 미끄럽지 않은가
- 보드 셀 단위 Snap Preview가 명확한가
- 유효/무효 위치가 즉시 구분되는가
- Preview와 실제 배치 위치가 다르게 느껴지지 않는가

과도한 관성, 탄성, Bounce는 제외하라.

Blocktower의 Motion Language는:

> **Elastic Toy가 아니라 Mechanical Satisfaction**

을 기준으로 한다.

### 3.3 배치 가능 Preview

확인:

- 놓을 수 있는 위치가 충분히 명확한가
- Preview Alpha가 너무 약하거나 강하지 않은가
- 색상만으로 Valid/Invalid를 구분하지 않는가
- 셀 Outline / 명도 / 패턴 등 보조 표현이 있는가
- 이미 채워진 블록과 겹치는 이유가 이해되는가

추천:

```text
Valid:
반투명 35~45%
정상 Outline

Invalid:
색상만 변경하지 말고
Outline / Cross / Fade / Shake 등 최소 2개 신호 사용
```

### 3.4 정상 배치

확인:

- 손을 놓은 순간 정확히 고정되었다는 느낌이 있는가
- Snap의 속도가 충분히 빠른가
- 배치 SFX와 애니메이션이 같은 순간에 발생하는가
- 블록이 튀거나 늘어나 퍼즐 판독성을 해치지 않는가

추천:

```text
Release
→ 100~160ms Snap
→ Scale 1.04 → 0.98 → 1.00
→ Piece Snap SFX
→ 아주 약한 Haptic
```

### 3.5 배치 실패 / Invalid Drop

확인:

- 실패 이유가 즉시 이해되는가
- 단순히 아무 일도 일어나지 않는 상태가 아닌가
- 실패 효과가 성공보다 강하지 않은가
- 반복 실패 시 짜증나는 사운드가 되지 않는가

추천:

```text
Invalid Release
→ 80~120ms 미세한 좌우 또는 원위치 복귀
→ 약한 Error SFX
→ Haptic은 매우 짧게 또는 생략
```

강한 Screen Shake, Flash, Red Fullscreen Overlay는 사용하지 않는다.

---

## 4. 줄 완성 / 클리어 대기 상태

Blocktower는 **수동 클리어가 기본**이므로 매우 중요하다.

검토:

- 줄이 완성되었지만 아직 지워지지 않았음을 즉시 이해할 수 있는가
- 일반 블록과 완성 대기 줄이 명확히 구분되는가
- 너무 강한 Blink 때문에 장시간 시선이 뺏기지 않는가
- 한 줄 / 여러 줄 대기 상태가 직관적인가
- 사용자가 클리어 버튼을 언제 눌러야 하는지 이해할 수 있는가

추천 표현:

```text
완성 대기 줄
→ 얇은 Outline
→ 밝기 소폭 증가
→ 매우 느린 Light Sweep
→ 깜빡임 금지
```

사운드 `line_ready`는 실제 Clear SFX보다 훨씬 약해야 한다.

---

## 5. 수동 클리어 버튼

Blocktower의 핵심 인터랙션이므로 일반 UI 버튼보다 중요하게 검토한다.

확인:

- 활성/비활성 상태가 명확한가
- 현재 몇 줄이 지워질지 보이는가
- 예상 점수와 실제 결과가 일치하는가
- 버튼을 눌렀다는 Press Feedback이 충분한가
- 클리어 시작 타이밍과 버튼 Release 타이밍이 자연스러운가

예:

```text
[3줄 클리어 · +420]
```

버튼 상태:

- Normal
- Pressed
- Disabled
- Active Multi-Clear

모바일에서는 Hover 검토 제외.

---

## 6. 자동 클리어 ON/OFF

검토:

- 현재 수동/자동 상태를 플레이 중 항상 이해할 수 있는가
- ON/OFF 상태를 색상만으로 전달하지 않는가
- 전환 시 짧은 UI Feedback이 있는가
- 대기 중인 줄이 있을 때 자동으로 바꾸면 무엇이 일어나는지 명확한가
- 토글 연출이 클리어보다 더 시끄럽지 않은가

추천:

```text
OFF = 수동
ON  = 자동

Text + Icon 병행
```

전환 애니메이션:
- 120~180ms
- 과도한 Bounce 금지

---

## 7. 1줄 클리어

흐름:

```text
Clear 입력/자동 판정
→ 짧은 Anticipation
→ Line Sweep
→ 블록 Fade/Dissolve
→ 점수 증가
→ 탑 +1층
→ 보드 정착
```

확인:

- 어느 줄이 지워졌는지 명확한가
- 너무 빨라서 결과를 못 보는가
- 반대로 반복 플레이를 끊을 정도로 느린가
- 점수와 층수 피드백이 같은 정보를 중복 전달하지 않는가

권장:

```text
전체 250~400ms
Particle 8~16개 수준
Screen Shake 없음
```

---

## 8. 2줄 / 3줄 / 4줄+ 동시 클리어

연출 강도는 플레이 중요도에 비례해야 한다.

### 2줄
- Dual Sweep
- 짧은 Light Pulse
- Clear Base + Sweetener

### 3줄
- 동시 Highlight
- Geometry Line
- 약한 Impact Sound
- 층수 +3 Feedback 강화

### 4줄 이상
- Landmark Clear 수준의 가장 강한 클리어 연출
- 구조적 Light
- 더 풍부한 Layered SFX
- 매우 약한 Micro Shake 검토
- Fullscreen Flash는 금지 또는 극도로 제한

권장:

```text
1줄 = 일반 행동
2~3줄 = 중요한 행동
4줄+ = 클라이맥스
```

모든 클리어에 동일한 Particle, Shake, Sound를 사용하지 않는다.

---

## 9. 클리어 시퀀스 전체 검토

중요한 다중 클리어는 개별 효과가 아니라 **연속된 경험**으로 분석한다.

예:

```text
사용자가 4줄 클리어 버튼 누름
→ 80~120ms 준비
→ 완성 줄 강조
→ Sweep
→ 블록 제거
→ Impact Sound
→ +640 Score
→ Tower +4F
→ 짧은 여운
→ 다음 조각 선택 상태
```

반복 플레이를 방해하지 않도록 전체 길이는 과도하게 늘리지 않는다.

---

## 10. 점수 변화 표현

전투게임의 Damage Number 대신 Blocktower에서는 **Score / Clear Bonus / Tower Floor**가 핵심 수치다.

검토:

- 점수가 즉시 바뀌어 결과를 체감하기 어려운가
- Count-up이 너무 느린가
- 점수 증가와 +N층 표시가 서로 시선을 빼앗는가
- 큰 클리어와 작은 클리어의 차이를 수치 표현에서도 느낄 수 있는가

추천:

```text
작은 변화:
즉시 또는 150~250ms Count-up

큰 변화:
250~400ms Count-up
```

숫자 Bounce는 최소화.

---

## 11. Tower Floor Gain Feedback

퍼즐 중 탑 화면으로 강제 이동하지 않는다.

추천:

```text
+3F
또는
Tower +3
```

검토:

- 퍼즐 흐름을 방해하지 않는가
- 점수보다 시각 우선순위가 높아지지 않는가
- 성장 보상이 존재한다는 사실은 충분히 느껴지는가

---

## 12. 10층 구간 완성

중요도:

> 일반 클리어보다 강하고, Game Over/Victory보다 짧아야 한다.

흐름:

```text
10층 달성
→ 짧은 알림
→ 구간 조립 Preview
→ 외벽/창문 Build
→ Lock
→ Light Sweep
→ 탑에 결합
→ 퍼즐 또는 결과 화면 복귀
```

검토:

- 10층 완성이 특별하게 느껴지는가
- 매 10층마다 너무 길어 반복 피로를 만드는가
- Skip/빠른 처리 필요 여부
- 퍼즐 도중 강제로 화면을 끊지는 않는가

실제 상세 연출은 퍼즐 종료 후 보여주는 방식도 비교 검토한다.

---

## 13. Game Over 연출

전투게임의 사망 연출에 대응.

검토:

- 왜 게임이 끝났는지 이해되는가
- 배치 가능한 블록이 없음을 충분히 보여주는가
- Pending Clear가 있는데 잘못 Game Over처럼 느껴지지 않는가
- 갑자기 팝업만 나타나 감정적 마침표가 없는가

추천 흐름:

```text
모든 선택지 검사
→ 잠깐 보드 상태 강조
→ 남은 블록 Disabled
→ 짧은 정착
→ Game Over
→ Score / Best / Tower Growth Result
```

과도하게 우울하거나 긴 실패 연출은 피한다.

---

## 14. New Best / 기록 갱신

검토:

- 단순 숫자 변경으로 끝나는가
- 최고 기록이 갱신되었다는 작은 축하가 있는가
- 지나치게 큰 Victory 연출로 오해되지 않는가

추천:
- 짧은 Badge
- 한 번의 Accent SFX
- 500~800ms 이내

---

## 15. UI 버튼 상태

모바일 기준 검토 상태:

- Normal
- Press
- Release
- Disabled
- Selected / Active

Hover는 제외.

중요 대상:
- 수동 클리어 버튼
- AUTO Toggle
- Pause
- Retry
- Tower
- Skin
- Settings

버튼 작동은 하지만 눌렀다는 반응이 없는 상태를 우선 개선한다.

---

## 16. Tween / Lerp / Easing 점검

검토:

- 이동이 Linear라 기계적으로 느껴지는가
- 반대로 Elastic/Bounce가 과도한가
- 서로 다른 화면/버튼에서 Easing 스타일이 제각각인가

Blocktower 기본:

```text
배치 / UI = Ease Out 계열
복귀 = Ease In-Out
건축 조립 = Ease Out
Elastic/Bounce = 최소화
```

같은 유형 행동은 같은 Easing Family를 사용한다.

---

## 17. Anticipation / Squash & Stretch / Follow-through

전투게임의 과장된 캐릭터 Animation을 그대로 적용하지 않는다.

### Anticipation
사용:
- 블록 Pick
- 다중 Clear 직전
- 10층 완성

### Squash & Stretch
극도로 제한:
- Snap 순간 2~4% Scale 변화

### Follow-through
사용:
- 클리어 후 구조선/Particle 잔상
- 점수/층수 Feedback 정착

### Secondary Motion
사용:
- 작은 구조선
- 짧은 Glow
- Tower Floor Icon Stack

과도한 Bounce/Elastic은 피한다.

---

## 18. Particle / Trail / Impact / Afterimage

Blocktower에서는 Trail/Afterimage보다 **Grid / Line / Structure VFX**를 우선한다.

추천:
- Light Sweep
- Grid Fragment
- Geometry Line
- 작은 Dust
- 짧은 Glow

비추천:
- 별
- Confetti 남발
- Rainbow Burst
- 화려한 Flame
- 긴 Afterimage Trail

---

## 19. Camera 연출

퍼즐 화면은 고정 카메라를 기본으로 한다.

검토 가능:
- 4줄+ Micro Zoom
- 매우 약한 Camera Kick
- 10층 완성 시 짧은 Tower Focus

원칙:
- 1~3줄 일반 Clear에는 카메라 이동 없음
- Camera 효과가 Grid 판독성을 해치면 삭제
- Motion Sickness 가능성을 고려해 옵션 제공 검토

---

## 20. Haptic Feedback

모바일에서만 검토.

| 사건 | Haptic |
|---|---|
| 블록 Pick | 매우 약함 또는 없음 |
| 정상 배치 | Light |
| Invalid | 매우 짧게 또는 없음 |
| 1줄 Clear | Light |
| 2~3줄 | Light~Medium |
| 4줄+ | Medium 이하 |
| 10층 완성 | 짧은 Pattern 가능 |
| 버튼 일반 | 기본적으로 없음 |

원칙:
- 모든 Tap에 Haptic 금지
- 시각/SFX와 정확히 동기화
- 설정에서 Off 가능하도록 검토

---

## 21. 사운드와 화면 효과 동기화

반드시 확인:

```text
Piece Snap Animation
= Snap SFX
= Haptic
```

```text
Line 실제 제거 Frame
= Clear SFX Impact
```

```text
10F Lock Frame
= Tower Lock SFX
```

소리와 화면이 어긋나면 체감 품질이 크게 떨어질 수 있으므로 동일 이벤트에서 Trigger하는 구조를 우선 검토한다.

---

## 22. 정보 위계

퍼즐 화면 우선순위:

1. Board
2. 현재 Drag Piece / Preview
3. 완성 대기 Line
4. 수동 Clear Button
5. 다음 3 Piece
6. Score
7. Tower Growth
8. 기타 UI

성장 정보가 퍼즐보다 높은 시선을 가져가면 안 된다.

---

## 23. 반복 플레이 피로 검토

확인:

- 매 배치마다 긴 Bounce가 발생하는가
- 모든 클리어에 0.5초 이상의 연출이 들어가는가
- 10층 완성마다 플레이가 장시간 중단되는가
- Score Count-up 때문에 다음 입력이 막히는가
- Popup이 너무 자주 등장하는가

원칙:

> **연출 중에도 가능한 한 다음 플레이 준비가 진행되도록 한다.**

---

## 24. 중복 효과 점검

예:

```text
3줄 Clear
→ 블록 Flash
→ Board Flash
→ Screen Flash
→ Particle
→ Camera Shake
→ 숫자 Bounce
→ Haptic
→ 큰 Sound
```

같은 정보를 너무 많은 효과가 중복 전달하면 오히려 시선이 분산된다.

각 사건마다:

```text
Primary Feedback 1개
Secondary Feedback 1~2개
```

정도를 기본으로 검토한다.

---

## 25. 구현 여부 평가표

각 사건마다 아래 형식으로 평가하라.

| 사건 | 현재 구현 | 문제점 | 개선 효과 | 구현 난이도 | 우선순위 |
|---|---|---|---|---|---|
| 블록 Pick | O/X | 예: 선택감 약함 | 조작 인지 향상 | 낮음 | P0 |
| Valid Preview | O/X | 위치 인지 부족 | 오배치 감소 | 낮음 | P0 |
| Line Ready | O/X | 일반 블록과 구분 어려움 | 수동 규칙 이해 | 중간 | P0 |
| 1줄 Clear | O/X | Impact 약함 | 만족감 | 낮음 | P1 |
| 4줄 Clear | O/X | 1줄과 체감 차이 없음 | 클라이맥스 강화 | 중간 | P1 |
| Tower +F | O/X | 성장 인지 부족 | 장기 성장 연결 | 낮음 | P1 |
| Game Over | O/X | 갑작스러움 | 종료 이해 | 중간 | P1 |

실제 프로젝트를 분석하여 행을 추가한다.

---

## 26. 유지 / 통합 / 삭제 검토

### 유지
- 역할이 명확하고 스타일이 일관적인 연출

### 통합
- 같은 역할을 중복 수행하는 Tween
- 중복 Sound Trigger
- 같은 상태를 여러 UI가 표시
- 중복 VFX Manager
- 동일 Animation이 여러 곳에 복사되어 있음

### 삭제
- 사용되지 않는 Effect
- Debug Animation
- 과도한 Flash/Shake
- 현재 Visual Bible과 다른 스타일
- 플레이 정보를 전달하지 않는 장식성 Motion

---

## 27. 우선적으로 찾아야 할 문제

특히 **로직은 존재하지만 표현이 부족한 사건**을 먼저 찾아라.

Blocktower 예:

- 블록은 선택되지만 선택했다는 느낌이 없음
- 배치는 되지만 Snap 느낌이 약함
- 놓을 수 없는 위치지만 이유가 명확하지 않음
- 줄은 완성됐지만 수동 클리어 대기라는 사실이 안 보임
- 여러 줄을 모았지만 1줄과 체감 차이가 없음
- 수동 클리어 버튼은 작동하지만 Press Feedback이 없음
- Auto/Manual 전환은 되지만 현재 상태를 놓치기 쉬움
- 점수는 증가하지만 언제 왜 올랐는지 모름
- 탑은 성장하지만 퍼즐 플레이와 연결감이 약함
- 게임은 끝났지만 왜 끝났는지 설명이 약함
- 최고점은 갱신됐지만 숫자만 바뀜

---

## 28. 중요도별 연출 강도

### Level 1 — 일반 행동
예:
- Block Pick
- Drag
- 기본 배치
- UI Toggle

연출:
- Tween
- 작은 SFX
- 최소 Haptic

### Level 2 — 중요한 행동
예:
- Line Ready
- 2~3줄 Clear
- 재질 해금
- New Best

연출:
- 강화된 SFX
- 구조선 VFX
- 짧은 Count-up
- 필요 시 Haptic

### Level 3 — 클라이맥스
예:
- 4줄+ Clear
- 10층 구간 완성
- 큰 최고점 갱신

연출:
- 복합 Layered SFX
- Light Sweep
- Geometry VFX
- 짧은 Micro Shake 가능
- 짧은 여운

모든 사건에 Level 3 효과를 사용하지 않는다.

---

## 29. Blocktower Visual Bible 준수

기존 원칙 유지:

> Candy Explosion ❌  
> Architectural Sweep ✅

> Elastic Toy ❌  
> Mechanical Satisfaction ✅

> Glossy Candy Block ❌  
> Matte Structural Block ✅

새로운 연출 제안이 기존 Visual Bible과 충돌하면 Visual Bible 기준을 우선한다.

---

## 30. 개발 구현 시 권장 기술

Godot 기준:

### Tween
- Pick
- Snap
- Button
- Score
- Floor Gain

### AnimationPlayer
- 10층 완성
- Material Unlock
- Game Over
- 복합 Sequence

### GPUParticles2D
- Line Clear
- Multi Clear
- Structure Fragment

### Audio
- Sound Manager
- Layered SFX
- Pitch Variation

### Haptic
- 모바일 Native Plugin/API 또는 플랫폼 지원 방식 검토

---

## 31. 성능 기준

시각 효과를 추가할 때 반드시 모바일 실기기에서 확인한다.

검토:
- Frame Time
- GPU 사용
- Particle Overdraw
- Fullscreen Shader
- Memory
- 발열
- 배터리

원칙:

> **효과 하나를 추가할 때, 그 효과가 실제 체감 가치를 제공하는지 먼저 확인한다.**

---

## 32. 최종 리포트 작성 형식

검토 후 결과는 반드시 아래 3단계로 정리하라.

### 1. 즉시 수정하면 효과가 큰 것
조건:
- 핵심 행동 이해에 직접 영향
- 플레이 손맛에 큰 영향
- 현재 로직은 이미 존재
- 수정 비용 대비 효과 큼

예:
- Drag Preview
- Line Ready
- Snap Feedback
- Multi-Clear 차등 연출
- Game Over 원인 전달

### 2. 적은 비용으로 개선 가능한 것
예:
- Button Press Tween
- SFX Variation
- Score Count-up
- Light Haptic
- 짧은 UI Fade
- Easing 통일

### 3. 나중에 다듬을 디테일
예:
- Particle Shape 세부 조정
- 4줄 Clear Micro Zoom
- Tower Window Light Timing
- Skin별 전용 Minor VFX
- Secondary Motion

---

## 33. 최종 판단 원칙

효과를 많이 넣는 것이 목표가 아니다.

다음 질문으로 모든 제안을 판단하라.

1. 이 효과가 사용자의 행동을 더 명확하게 이해시키는가?
2. 이 효과가 결과를 더 만족스럽게 느끼게 하는가?
3. 이 효과가 퍼즐 판독성을 방해하지 않는가?
4. 반복해도 지루하거나 피곤하지 않은가?
5. 이미 다른 효과가 같은 정보를 전달하고 있지 않은가?
6. 중요도에 맞는 강도인가?
7. 모바일 성능 비용 대비 가치가 있는가?

하나라도 명확한 이유가 없다면 추가하지 않는다.

---

## 34. 한 줄 목표

> **Blocktower의 연출 목표는 화려함이 아니라, 블록을 놓고 줄을 완성하고 직접 클리어하며 탑을 성장시키는 모든 과정이 짧고 명확하며 만족스럽게 이어지는 것이다.**
