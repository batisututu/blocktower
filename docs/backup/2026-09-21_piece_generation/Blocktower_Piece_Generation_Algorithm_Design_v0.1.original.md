# Blocktower 블록 생성 알고리즘 설계 문서 v0.1

- 문서 목적: 개발팀 구현 참고
- 기준일: 2026-09-21
- 대상 프로젝트: Blocktower
- 엔진/언어: Godot 4.7.x + GDScript
- 퍼즐 기본 구조: 8×8 보드 / 블록 3개 제공 / 수동 클리어 기본 / 자동 클리어 ON·OFF 가능
- 상태: 개발 전 상위 알고리즘 설계
- 주의: 본 문서의 수치(Weight, Easy Family 등)는 초기 밸런스 가안이며 실제 플레이테스트 후 조정한다.

---

## 1. 설계 목표

Blocktower의 블록 생성 알고리즘은 다음 목표를 만족해야 한다.

1. 랜덤성 유지
2. 큰/어려운 블록 3개 연속 같은 억울한 실패 감소
3. Family Weight 기반 난이도 튜닝
4. Rotation 수에 따른 확률 왜곡 방지
5. 수동 클리어 대기 줄까지 고려
6. 플레이어를 노골적으로 살려주는 RNG는 피함

---

## 2. 조사한 주요 GitHub 구현

### 2.1 Klooni1010
Repository: https://github.com/LonamiWebs/Klooni1010

- 1010! 계열 오픈소스
- 약 243 Stars / 76 Forks 조사 시점
- Java + libGDX
- GPL-3.0
- 2026년 2월 아카이브

핵심 방식:

```text
shape_type = random(0 ~ 8)
rotation   = random(0 ~ 3)
return piece(shape_type, rotation)
```

장점:
- 구현 매우 단순
- 성능 부담 거의 없음
- 테스트 쉬움

단점:
- 보드 상태 고려 없음
- 쉬운 블록 최소 보장 없음
- 난이도 조절이 거침
- 어려운 블록 3개가 연속 등장 가능

Blocktower 판단:
- 개념 참고만 권장
- GPL-3.0이므로 직접 코드 재사용은 비추천

---

### 2.2 blockerino
Repository: https://github.com/tokaa1/blockerino

- Block Blast clone
- 8×8 + 3 Piece
- 약 15 Stars / 10 Forks 조사 시점
- TypeScript / React Native
- MIT

각 Piece에 `distributionPoints`를 두는 Weighted Random 방식.

예:

```text
L       = 2
T       = 1.5
S/Z     = 1
3×3     = 3
2×2     = 6
3 Line  = 4
```

개념:

```text
total_weight = 모든 piece weight 합
r = random(0, total_weight)

for piece in pieces:
    r -= piece.weight
    if r < 0:
        return piece
```

장점:
- 출현 확률 조절 가능
- 쉬운 Shape 비율을 높일 수 있음
- Blocktower와 구조가 가까움
- MIT

단점:
- 회전 Variant마다 Weight를 주면 Variant가 많은 Family가 과다 출현 가능
- Board 상태 고려 없음
- Easy Piece 보장 없음

Blocktower 판단:
- Weighted Random 구조는 채택 가치 높음
- Piece 단위가 아닌 Family 단위로 개선 필요

---

## 3. 추가 조사: 10Block

Repository: https://github.com/viliceq/10block

- 2026년 제작
- TypeScript
- MIT
- 테스트 중심 개발
- Family-weighted sampling
- Anti-frustration guarantee 구현

핵심 개선:
- Piece Variant를 바로 추첨하지 않음
- Family 먼저 추첨
- Family 내부 Rotation은 균등 랜덤

예시 Family Weight:

```text
Line        12
2×2          6
Single       5
Small L      5

T            3
L            3
J            3

S            2
Z            2
2×3          2

3×3          1
Large L      1
```

장점:
- Rotation 수가 출현 확률에 영향 주지 않음
- Family 단위 튜닝 쉬움
- 신규 Rotation 추가 시 확률 구조 유지
- 테스트하기 좋음

---

## 4. 10Block Anti-Frustration

Easy Family 예:

```text
Single
2×2
Small L
```

3개 Tray 생성 후 Easy Piece가 하나도 없으면 첫 Slot을 Easy Pool에서 교체.

즉:

> 3개 중 최소 1개는 비교적 다루기 쉬운 조각

프로젝트 문서 기준 현재 Weight에서는 약 27%의 Hand에서 해당 보정이 작동하도록 설계됨.

Blocktower 판단:
- 개념 채택 권장
- Easy Family 정의는 8×8 플레이테스트 후 조정

---

## 5. 세 방식 비교

| 항목 | Klooni | blockerino | 10Block |
|---|---|---|---|
| 기본 방식 | 균등 랜덤 | Piece Weighted | Family Weighted |
| Rotation 확률 왜곡 | 낮음/단순 | 발생 가능 | 방지 |
| 난이도 튜닝 | 낮음 | 높음 | 매우 높음 |
| Easy Piece 보장 | 없음 | 없음 | 있음 |
| Board 상태 확인 | 없음 | 없음 | 없음 |
| 3개 Hand | 있음 | 있음 | 있음 |
| Blocktower 적합성 | 낮음 | 높음 | 매우 높음 |

---

## 6. Blocktower 최종 추천

> Family Weighted Random  
> + Rotation 분리  
> + 최소 1개 Easy Piece  
> + Board-aware Soft Solvability

---

## 7. 생성 Flow

```text
[새 Tray 생성 요청]

1. Family Weight 기반 Piece 3개 추첨
2. 각 Family 내부 Rotation/Variant 선택
3. Easy Piece 포함 여부 검사
4. Easy Piece가 없으면 Slot 하나를 Easy Piece로 교체
5. Current Board에서 배치 가능 여부 검사
6. Pending Clear가 있으면 Post-Clear Board에서도 검사
7. 최소 1개 합리적 선택지가 있으면 확정
8. 모두 불가능하면 최대 3회 재생성
9. 그래도 불가능하면 Easy Pool 중 실제 배치 가능한 Piece 선택

[Tray 반환]
```

---

## 8. Piece Family 초안

```text
single
line_2
line_3
line_4
line_5
square_2
square_3
small_l
t
s
z
large_l
rect_2x3
```

향후 필요 시:
- j
- plus
- corner
- custom

---

## 9. 초기 Family Weight 가안

| Family | Weight |
|---|---:|
| Single | 5 |
| 2 Line | 6 |
| 3 Line | 8 |
| 4 Line | 4 |
| 5 Line | 1 |
| 2×2 | 6 |
| Small L | 5 |
| T | 3 |
| S/Z | 2 |
| Large L | 2 |
| 2×3 | 2 |
| 3×3 | 1 |

※ 밸런스 가안이며 확정값 아님.

---

## 10. Easy Family 초기안

```text
1×1
2 Line
3 Line
Small L
```

주의:
- 2×2는 8×8 후반 보드에서 생각보다 배치가 어려울 수 있어 초기 Easy Pool에서 제외 권장
- 실제 플레이테스트 후 재평가

---

## 11. Family Weighted 선택 Pseudo

```gdscript
func sample_family(rng_value: float) -> String:
    var total_weight := 0.0

    for weight in family_weights.values():
        total_weight += weight

    var target := rng_value * total_weight

    for family in family_weights:
        target -= family_weights[family]

        if target < 0:
            return family

    return DEFAULT_FAMILY
```

---

## 12. Rotation 선택

```gdscript
func sample_variant(family: StringName):
    var variants = family_variants[family]
    return variants[randi_range(0, variants.size() - 1)]
```

원칙:

> Variant 수가 Family Weight에 영향을 주면 안 된다.

---

## 13. Tray 생성 Pseudo

```gdscript
func generate_tray(size := 3) -> Array[PieceData]:
    var tray: Array[PieceData] = []

    for i in size:
        tray.append(sample_weighted_piece())

    if not has_easy_piece(tray):
        tray[0] = sample_easy_piece()

    return apply_soft_solvability(tray)
```

---

## 14. Board-aware Soft Solvability

Blocktower는 수동 클리어 대기 줄이 존재할 수 있으므로 두 Board 상태를 본다.

### A. Current Board
현재 실제 보드

### B. Post-Clear Board
대기 중 완성 줄을 모두 제거했다고 가정한 보드

검사:

```text
Tray 중 하나라도 Current Board에 배치 가능
OR
Tray 중 하나라도 Post-Clear Board에 배치 가능
```

둘 다 불가능하면 재생성.

---

## 15. 재생성 횟수

초기 권장:

```text
MAX_REROLL = 3
```

3회 이후에도 모두 불가능하면:
- Easy Pool에서 실제 배치 가능한 Piece 탐색
- 찾으면 교체
- 없으면 자연스러운 Game Over 허용

---

## 16. 강제 생존 알고리즘 금지

하지 말아야 할 방식:

```text
게임오버 직전
→ 항상 현재 보드에 딱 맞는 Piece 제공
```

문제:
- RNG 조작감
- 실력 게임 느낌 약화
- 실패 책임감 감소
- 고수 플레이 긴장감 감소

---

## 17. Soft Guarantee 원칙

보장:
- 새 Tray 생성 시 최소 하나의 합리적인 선택 가능성

보장하지 않음:
- 3개 모두 반드시 사용 가능
- 반드시 줄 완성 가능
- 반드시 생존 가능
- 반드시 고득점 가능

목표:

> 플레이어를 살려주는 것이 아니라, 아무 선택지도 없는 불합리한 Hand를 줄이는 것

---

## 18. 수동 클리어와의 상호작용

예:

```text
Current Board에서는 3개 모두 배치 불가
하지만 Pending Clear 2줄 존재
```

이 경우:
- Game Over 아님
- Post-Clear Board 기준으로 다시 검사

Pseudo:

```gdscript
func can_use_tray(tray, board):
    if any_piece_fits(tray, board):
        return true

    if board.has_pending_lines():
        var post_clear = simulate_pending_clear(board)

        if any_piece_fits(tray, post_clear):
            return true

    return false
```

---

## 19. PieceGenerator 권장 구조

```text
PieceGenerator
├── PieceCatalog
├── FamilyWeights
├── FamilyVariants
├── EasyFamilies
├── sample_family()
├── sample_variant()
├── sample_weighted_piece()
├── generate_raw_tray()
├── guarantee_easy_piece()
├── validate_tray()
└── generate_tray()
```

---

## 20. Godot Resource 권장

### PieceDefinition.tres

```text
id
family
cells
bbox
difficulty_tag
```

### PieceGeneratorConfig.tres

```text
family_weights
easy_families
tray_size = 3
max_reroll = 3
soft_guarantee_enabled = true
```

Weight는 코드가 아닌 Resource 데이터로 관리한다.

---

## 21. Dynamic Difficulty는 후순위

MVP에서는 아래만 적용:

```text
고정 Family Weight
+ Easy Guarantee
+ Soft Solvability
```

향후 데이터가 쌓이면:
- score
- board occupancy
- 최근 clear 빈도
- 최근 game over 빈도

를 기반으로 완만한 Dynamic Weight를 검토할 수 있다.

---

## 22. 초기 버전에서 제외

```text
AI 기반 Piece Generation
Machine Learning RNG
Player-specific hidden difficulty
항상 정답 Piece 제공
광고 시청 여부에 따른 RNG
유료 스킨/결제에 따른 좋은 Piece 확률
```

결제와 RNG는 연결하지 않는다.

---

## 23. RNG 재현성

개발/테스트에서는 Seeded RNG 지원 권장.

Godot:

```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = debug_seed
```

장점:
- 버그 재현
- 자동 테스트
- Difficulty Simulation
- A/B 테스트

---

## 24. 필수 자동 테스트

### Weight
1. 모든 Family가 생성 가능한가
2. 10,000회 샘플에서 기대 비율과 큰 차이가 없는가
3. Rotation이 Family 내부에서 균등한가

### Easy Guarantee
4. 생성되는 모든 Tray에 최소 1개 Easy Piece 존재

### Tray
5. 항상 3 Piece 반환
6. null 없음

### Board-aware
7. Current Board에서 1개 이상 배치 가능
8. Current Board는 불가하지만 Post-Clear Board는 가능한 경우 허용

### Game Over
9. Pending Clear가 있으면 즉시 Game Over 처리하지 않음

### Deterministic
10. 동일 Seed → 동일 Tray Sequence

---

## 25. Simulation 권장

UI 없이 Generator만 반복 실행:

```text
100,000 Tray 생성
```

측정:
- Family별 출현율
- Easy Guarantee 발동 비율
- Reroll 비율
- 강제 Easy Piece 교체 비율
- 평균 Piece Cell 수
- 3×3 출현율
- Line 계열 출현율

---

## 26. 플레이테스트 로그

권장 이벤트:

```text
tray_generated
piece_family
piece_variant
easy_replacement_triggered
reroll_count
board_occupancy
pending_clear_count
game_over
```

개인정보 없이 밸런스 분석 가능.

---

## 27. 튜닝 지표

### Frustration
3개 중 배치 가능한 Piece가 1개도 없는 Tray 비율

### Reroll
Reroll 발생 빈도

### Easy Replacement
너무 높으면 기본 Weight가 어려운 것

### Early Game
초반 Game Over가 빠르면 Small/Line Weight 증가 검토

---

## 28. 구현 순서

1. Piece Catalog
2. Family/Variant 분리
3. Weighted Family Sampler
4. Rotation Sampler
5. Tray 3개 생성
6. Easy Guarantee
7. PlacementValidator 연동
8. Post-Clear Board Simulation
9. Soft Solvability
10. GUT 테스트 + 대량 Simulation

---

## 29. 최종 채택 권고

Blocktower Piece Generator:

> **Family Weighted Random  
> + Family 내부 Rotation 균등 선택  
> + Tray당 최소 1개 Easy Piece  
> + Current/Post-Clear Board 기반 Soft Solvability  
> + 최대 3회 Reroll**

---

## 30. Blocktower의 차별점

기존 단순 Block Puzzle:

```text
Random Piece
```

blockerino:

```text
Weighted Piece
```

10Block:

```text
Weighted Family
+ Easy Guarantee
```

Blocktower:

```text
Weighted Family
+ Easy Guarantee
+ Pending Manual Clear를 고려한
Board-aware Soft Solvability
```

---

## 31. 라이선스

### Klooni1010
- GPL-3.0
- 로직 아이디어만 참고
- 직접 코드 복사 비추천

### blockerino
- MIT
- 구조 참고 가능
- Godot/GDScript로 독립 구현 권장

### 10Block
- MIT
- Family Weighted / Easy Guarantee / 테스트 구조 참고 가치 높음

---

## 32. 출처

### Klooni1010
Repository:
https://github.com/LonamiWebs/Klooni1010

Relevant:
```text
core/src/dev/lonami/klooni/game/Piece.java
core/src/dev/lonami/klooni/game/PieceHolder.java
```

### blockerino
Repository:
https://github.com/tokaa1/blockerino

Relevant:
```text
constants/Piece.tsx
constants/Hand.tsx
components/game/Game.tsx
```

### 10Block
Repository:
https://github.com/viliceq/10block

Relevant:
```text
src/pieces.ts
docs/iterations/0032-tray-weighting.md
tests/sample-piece.test.ts
```

---

## 33. 개발 전 미확정 사항

- 최종 Piece Family 목록
- 최종 Weight
- Easy Family 최종 정의
- Dynamic Difficulty 사용 여부
- Reroll 최대 횟수

현재는 **알고리즘 구조만 확정**하고,
수치는 Godot Resource로 분리해 플레이테스트 후 조정한다.
