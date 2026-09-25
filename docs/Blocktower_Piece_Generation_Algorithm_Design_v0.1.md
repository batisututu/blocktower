# Blocktower 퍼즐 조각 생성 알고리즘

- 문서 개정: **v0.3 / 2026-09-21**, Codex 자체 기술검토 반영. 알고리즘/카탈로그/공급 정책은 **v0.2 유지**.
- 사용자가 지정한 파일 경로를 유지했다. 파일명의 v0.1은 최초 작성명이며 현재 문서 개정은 v0.3, 알고리즘은 v0.2다.
- 원문은 [백업](backup/2026-09-21_piece_generation/Blocktower_Piece_Generation_Algorithm_Design_v0.1.original.md)과 [SHA-256 manifest](backup/2026-09-21_piece_generation/manifest.json)에 보존했다.
- 소유 범위: **새 공급 알고리즘·카탈로그·설정·보장 조건**. 이전 v0.1 및 Reddit 조사 이력은 [공급 명세](Blocktower_Piece_Supply_Spec.md), 실행 결과는 [검증 보고서](implementation/piece_generation/README.md), 기술 결정은 [ADR-0002](adr/0002-versioned-board-aware-piece-generation.md).
- 상태: Godot 독립 구현·자동 검사 완료. **Codex 자체 기술검토·W2 GameSession 연결 완료. W3 Windows 디스크 저장·재실행 완료. UI·사람 플레이·모바일 검증은 미완료.** 사용자 요청으로 Claude 답변과 모델 전환 대기는 종료했다. 공동/제3자 승인으로 기록하지 않는다.

## 1. 기술검토 결론

계열 정수 가중 추첨 → 계열 내 고정 방향 균등 추첨 → 세 조각 구성 → 쉬운 계열 보정 → 현재/수동 클리어 후 보드의 실제 배치 검사 → 최대 세 번 추가 추첨 → 유한 후보 목록에서 대체한다. 별도의 외부 런타임 패키지는 추가하지 않는다.

원문의 좋은 구조를 유지하되 다음 모호함을 제거했다.

| 원문에서 부족했던 부분 | v0.2 결정 |
|---|---|
| 모든 상황에서 완벽하다는 목표 | 유효 입력·종료·상태 불변·재현·배치 증명을 계약으로 정의. 무한 생존이나 모든 조각 소진은 보장하지 않음 |
| Soft 보정이지만 강제 생존은 아니라는 표현 | 기본 설정은 **새 공급 시점 한 수 보장**. 트레이 진행 중 게임오버는 가능 |
| S/Z 묶음 가중치·방향 개수 미정 | S와 Z를 별도 계열로 나누고 각 가중치 1. 총 13계열·29방향, 합계 45 |
| Easy 조각의 뜻 | 계열 분류와 실제 배치 가능성을 구분. 쉬운 계열도 현재 보드에 못 놓을 수 있음 |
| 최대 3회 재추첨의 의미 | 최초 1회 + 추가 0~3회. 최대 후보 트레이 4개 |
| 대체할 Easy가 전혀 안 맞는 사용자 설정 | 양의 가중치를 가진 전체 계열로 확대. 기존 Easy 한 개를 보존할 다른 슬롯에 대체 |
| 아무 활성 조각도 안 맞는 상황 | 정상 3ID와 `guarantee_met=false` 반환. 대기 클리어가 있으면 `MUST_CLEAR` |
| RNG·Resource·저장 경계 | 지역 RNG, 설정 깊은 복사, 엄격한 int64 문자열, 정책/엔진/정의/설정 해시 검사 |
| 보정 후 분포 | 원래 후보와 최종 결과를 따로 측정. 슬롯 0 고정 교체 제거 |

## 2. 조사 자료 재확인

2026-09-21 GitHub 기본 브랜치의 커밋과 실제 파일을 조회했다. 조회 URL·파일 SHA-256은 [출처 기록](implementation/piece_generation/source_provenance.json)에 있다. 아래 자료는 비교 근거이며 외부 코드를 복사한 구현이 아니다.

| 자료 / 확인 커밋 | 실제 동작과 적용 판단 |
|---|---|
| [Klooni Piece.java](https://github.com/LonamiWebs/Klooni1010/blob/db50b8537ccbcea54e6dd0e2bddab87445c642ae/core/src/dev/lonami/klooni/game/Piece.java) / `db50b853…` | 9종 계열 선택 및 방향 정규화. 가족·방향 분리 개념 참고. GPL-3.0-or-later 표기가 있는 소스는 직접 이식하지 않음 |
| [blockerino Piece.tsx](https://github.com/tokaa1/blockerino/blob/488544878d4f19e16fad043450c13e5070de4689/constants/Piece.tsx), [Hand.tsx](https://github.com/tokaa1/blockerino/blob/488544878d4f19e16fad043450c13e5070de4689/constants/Hand.tsx) / `48854487…` | 각 방향 항목에 `distributionPoints`를 두고 `Math.random()`으로 누적 가중 선택. 계열/방향이 독립된 공급기는 아님. MIT. 시각·전역 난수 결합은 가져오지 않음 |
| [10block pieces.ts](https://github.com/viliceq/10block/blob/93dfa7eaf785043d038a4e5f20ba358d90f6edd9/src/pieces.ts), [실험 기록](https://github.com/viliceq/10block/blob/93dfa7eaf785043d038a4e5f20ba358d90f6edd9/docs/iterations/0032-tray-weighting.md) / `93dfa7ea…` | 37방향. 계열/방향 분리 후 Easy가 없으면 슬롯 0을 쉬운 **방향 목록에서 균등** 교체. MIT. 계열 구조만 참고하고 교체는 계열 가중/무작위 슬롯으로 새로 정의 |
| [Godot RandomNumberGenerator](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html) | RNG 구현의 엔진 버전 간 동일 출력은 보장하지 않음. seed 설정 후 state 복원. 프로젝트 실행은 고정 4.7.2 바이너리 사용 |

10block의 약 27%는 그 코드의 Easy 가중치 16/45에 따른 `(29/45)^3 ≈ 26.765%`다. **Blocktower의 교체 예상치는 `(21/45)^3 ≈ 10.163%`**이며 서로 다른 카탈로그/분류에 숫자를 그대로 적용하면 안 된다. 상용 게임의 비공개 공급 알고리즘이나 재미가 입증됐다는 근거로 사용하지 않는다.

## 3. 카탈로그와 기본 수치

카탈로그 ID: `bt_catalog_29_v0_2`. 정확한 셀 좌표와 방향 순서는 [구현](../game/scripts/core/generation/piece_generator.gd)의 카탈로그가 소유한다. 기존 [v0.1 카탈로그](../game/scripts/core/piece_supply.gd)의 19방향 ID/좌표를 그대로 보존하고 신규 계열만 뒤에 붙였다. `elbow3`는 small_l, `elbow5`는 큰 ㄴ자에 대응한다.

| 계열 ID | 칸 수 | 방향 수 | 정수 가중치 | Easy |
|---|---:|---:|---:|---|
| single | 1 | 1 | 5 | 예 |
| line2 | 2 | 2 | 6 | 예 |
| line3 | 3 | 2 | 8 | 예 |
| line4 | 4 | 2 | 4 | 아니오 |
| line5 | 5 | 2 | 1 | 아니오 |
| square2 | 4 | 1 | 6 | 아니오 |
| square3 | 9 | 1 | 1 | 아니오 |
| elbow3 | 3 | 4 | 5 | 예 |
| elbow5 | 5 | 4 | 2 | 아니오 |
| t | 4 | 4 | 3 | 아니오 |
| s | 4 | 2 | 1 | 아니오 |
| z | 4 | 2 | 1 | 아니오 |
| rect2x3 | 6 | 2 | 2 | 아니오 |
| **합계** | | **29** | **45** | **Easy 가중치 24** |

`family_probability = weight / 45`, 보정 전 `variant_probability = family_probability / variant_count`. 예를 들어 T 계열 전체는 3/45이며 T 방향마다 3/180이다. 중복 ID를 허용하며 런타임 회전 입력은 없다. 면적, 점수, 층수, 스킨, 광고, 시간에 따른 동적 난이도는 넣지 않았다. 이 가중치는 초기 실험값이며 최종 밸런스가 아니다.

**2026-09-25 공급 조정:** 위 표와 기존 기본 Resource는 이전 저장·이번 주 도전 재생용으로 보존한다. 새 개인 저장은 [낮은 1칸 조각 설정](../game/data/piece_generator_low_single.tres)을 사용한다. `single` 가중치만 5→1로 바꾸어 전체 41, 보정 전 슬롯별 확률은 5/45(11.1%)→1/41(2.4%)다. Easy 교체와 한 수 보장 fallback 때문에 최종 트레이 확률은 이 값보다 높을 수 있다. 이미 시작한 개인 판은 체크포인트 해시가 가리키는 기존 설정으로 계속 진행하며 진행 중 설정을 바꾸지 않는다. Phase 4 도전은 서버가 발급한 설정을 고정한다. 2026-09-28 UTC 시작 주차부터 새 설정을 발급하고 앞서 발급된 도전은 기존 설정을 유지한다. 이 조정값의 대량 분포·사람 체감은 아직 측정하지 않았다.

설정은 [기본 Resource](../game/data/piece_generator_default.tres)와 [설정 클래스](../game/scripts/core/generation/piece_generator_config.gd)로 분리했다. 계열 순서에 맞춘 13개 정수, 각 가중치 ≥0, 합계 1~1,000,000, 알려진 Easy 계열의 중복 없는 목록, 재추첨 0~3을 검증한다. Easy/SOFT는 Easy 중 양의 가중치가 하나 이상 필요하다. 0은 추첨과 fallback 모두 비활성화한다. 실행 중 Resource 수정은 기존 생성기에 반영되지 않는다. 새 설정은 새 생성기와 새로운 checkpoint를 필요로 한다.

## 4. 세 정책과 순서

| 정책 ID | 목적 |
|---|---|
| `bt_family_weighted_v0_2` | 같은 29종의 무보정 비교군 |
| `bt_easy_family_v0_2` | Easy 최소 한 개만 보정하는 비교군 |
| **`bt_soft_one_move_v0_2`** | 새 모듈의 기본값. Easy 보정 + 현재/클리어 후 한 수 보장 |

1. 보드·트레이·checkpoint·설정 버전을 먼저 검증한다. 남은 조각이 있으면 `REFILL_NOT_ALLOWED`로 거절한다.
2. 요청의 checkpoint로 지역 RNG를 복원한다. 매 슬롯에서 계열 정수 티켓 한 번, 방향 균등 추첨 한 번. 방향이 하나여도 호출을 생략하지 않는다.
3. Easy/SOFT에서 Easy가 없으면 교체 슬롯을 0~2 균등 선택하고, 활성 Easy 계열을 기존 가중치에 비례해 선택한 뒤 방향을 균등 선택한다.
4. 현재 보드에서 실제 배치가 가능한지 확인한다. 없으면 현재 완성된 모든 행/열을 동시에 제거한 가상 보드도 검사한다. 점수/성장/실제 보드에는 변화가 없다.
5. SOFT에서 증명 좌표가 없을 때만 전체 트레이를 추가 추첨한다. 매 후보마다 Easy 보정을 동일하게 적용한다. 최대 총 4개 후보다.
6. 모두 실패하면 현재/가상 보드에 들어가는 활성 Easy 방향을 전수 열거한다. 해당 계열의 원래 가중치로 계열을, 그 계열의 **배치 가능한 방향 중에서** 방향을 균등 선택한다. 배치 위치 수로 가중하지 않는다.
7. Easy 후보가 없으면 전체 활성 계열로 확대한다. 교체 결과도 Easy 최소 한 개를 유지하도록 교체 가능한 슬롯들 중 균등 선택한다.
8. 활성 후보가 전혀 없으면 마지막 트레이와 `guarantee_met=false`, `fallback=no_enabled_fit`을 반환한다. 무한 재추첨이나 비활성 1칸 조각 삽입은 없다.
9. 반환된 트레이와 다음 checkpoint는 호출자가 새 상태로 함께 커밋해야 한다.

위의 RNG 호출 순서와 카탈로그 순서를 바꾸는 수정도 재현에 영향을 준다. 정책 버전을 갱신하고 회귀 증거를 새로 만든다. 내부 PRNG가 진행하는 횟수가 API 호출 수와 같다고 가정하지 않는다.

## 5. 보드·수동 클리어·게임오버

보드는 길이 64의 `PackedByteArray`, 값은 0/1, 좌표는 `Vector2i(x,y)`, 인덱스는 `y*8+x`다. 최적화 내부 표현은 8개의 8비트 행 마스크다. 64비트 정수 하나의 부호 비트에 의존하지 않는다. 각 방향의 경계 안 원점을 유한하게 순회해 충돌을 검사한다.

완성 행·열 목록을 **원래 보드에서 모두 계산한 뒤 합집합 셀을 한 번만 제거**한다. 교차 행/열을 순차 제거해 다른 완성 줄을 놓치는 오류를 막는다. 교차 1행+1열은 줄 수 2개, 제거 셀은 15개다. 공급기는 보상이나 줄 제거 액션을 실행하지 않는다.

| 상태 | 판정 |
|---|---|
| `REFILL_REQUIRED` | 트레이가 비었음. 공급 전 게임오버로 단정하지 않음 |
| `CAN_PLACE` | 남은 조각 중 현재 보드에 놓을 수 있는 것이 있음 |
| `MUST_CLEAR` | 현재 배치는 불가능하지만 기존 완성 줄을 지우는 액션이 있음. 클리어 후 배치 가능 여부는 witness로 별도 확인 |
| `GAME_OVER` | 남은 조각이 있고 현재 배치도 기존 클리어도 불가능 |

`witness={piece_id,slot,x,y,requires_clear}`가 실제 배치의 증거다. `MUST_CLEAR`만으로 클리어 후 조각이 들어간다고 해석하지 않는다. 수동 모드에서는 사용자가 먼저 클리어해야 하고, 자동 모드에서는 GameSession의 배치/클리어 원자 전이가 끝난 상태를 공급기에 전달한다. UI 모드나 애니메이션 완료 이벤트가 새 공급을 호출하지 않는다.

## 6. 보장과 증명 범위

**유효 요청의 종료:** 후보 생성 최대 4회, 최대 29방향과 각 방향 최대 64원점의 배치 검사, 고정 8×8 클리어 계산으로 끝난다. 무한 루프, 무제한 탐색, 과거 플레이 전체 검색은 없다.

**조건부 한 수 보장:** SOFT에서 활성 조각이 현재 또는 클리어 후 보드에 하나라도 들어가면, 후보 수락 또는 fallback의 완전한 활성 방향 열거가 그것을 찾는다. Easy 외 계열만 들어가더라도 전체 계열 fallback이 처리한다.

**기본 설정의 전 보드 조건:** 빈칸이 있으면 활성 single을 그곳에 놓을 수 있다. 빈칸이 없으면 모든 행/열이 완성되어 클리어 후 빈 보드가 된다. 따라서 64칸 이진 보드와 기본 설정에서 새 공급 시점의 한 수 조건은 항상 성립한다. 이는 논리적 조건 분석이며 `2^64`개 보드를 전수 실행했다는 뜻이 아니다.

**보장하지 않는 것:** 트레이 세 개를 모두 놓는 순서, 반드시 줄이 생기는 것, 모든 사용자 선택 후의 생존, 무한 플레이, 사람이 해를 알아볼 수 있음, 재미, 공정한 체감. 체커보드의 한 점유 칸만 비워 가로 3칸 공간을 만들면 가로 도미노 3개가 각각 현재 들어가지만 어느 하나를 놓은 뒤 다음 도미노는 들어가지 않는다. 이 반례도 단위 테스트로 고정했다.

장차 세 조각 전체의 풀이를 보장하려면 상태 `(board, remaining_slot_mask, manual_clear_availability)`의 정확한 탐색과 별도 정책이 필요하다. 탐색 시간 초과는 해 없음과 구별해야 한다. 이번 모듈의 한 수 검사로 해당 기능을 주장하거나 숨겨서 추가하지 않는다.

## 7. API·실패·소유권·저장

정확한 영어 계약: [piece_generation_contract.md](../game/scripts/core/contracts/piece_generation_contract.md).

```gdscript
const Generator = preload("res://scripts/core/generation/piece_generator.gd")
var created = Generator.create()
if not created.ok:
    return created
var generator = created.generator
var checkpoint = generator.initial_checkpoint("20260921").checkpoint
var occupancy = PackedByteArray()
occupancy.resize(64)
var result = generator.generate(occupancy, [], checkpoint)
# result.ok 확인 후 후보 상태에 queue와 checkpoint를 함께 반영한다.
# 저장 완료 이후에만 화면 이벤트를 발행한다.
```

- `create(config)`는 Resource 검증 및 깊은 복사. `catalog()/config_snapshot()`도 복사본을 반환한다.
- `generate(occupancy, remaining_ids, checkpoint)`는 `{ok,piece_ids,checkpoint,decision,guarantee_met,metrics}` 또는 `{ok:false,error}`를 반환한다.
- `analyze_tray()`는 공급 RNG를 소비하지 않으며 남은 조각 0~3개를 검사한다. 유효 조각 뒤에 숨은 미등록 ID도 거절한다.
- `rng_seed/rng_state`는 부호 있는 정규 10진 int64 문자열이다. 공백, `+1`, `01`, `-0`, 실수, 지수 표기, 범위 초과를 거절한다. JSON 숫자로 저장하지 않는다.
- checkpoint는 정확히 7개 문자열 필드: `rng_seed`, `rng_state`, `engine_version`, `catalog_version`, `supply_policy_version`, `definition_hash`, `config_hash`. 알 수 없는 필드·버전/해시 불일치는 거절한다.
- 잘못된 입력은 호출자 보드/checkpoint를 변경하지 않는다. 정상 반환도 새 상태일 뿐 원본을 변경하지 않는다.
- 같은 엔진·정의·설정·checkpoint·보드에서 결과가 재현된다. **시드만 같고 보드가 다르면 공급열은 달라질 수 있다.** 실제 배치/클리어 액션과 공급 ID도 기록해야 한다.
- 해시는 버전 혼동 탐지용이며 저장 위조 방지나 코드 서명의 대체물이 아니다. 임의 int64 state의 형식 검증이 진짜 이전 저장임을 인증하지는 않는다.

GameSession은 `occupancy/cell_style/queue/batch_id/점수/성장/공급 checkpoint` 전체 후보를 한 번에 커밋한다. W2 메모리 저장소와 W3 두 세대 디스크 저장소가 같은 커밋 계약을 구현한다. 실패하면 이전 checkpoint로 재시도해야 같은 트레이가 나온다. 화면 재열기·스킨 변경·모드 전환으로 generate를 호출하지 않는다. 호출자는 요청 직렬화와 batch_id 중복 방지를 책임진다. [W2 GameSession](implementation/W2_GameSession_Report_2026-09-21.md)은 메모리 저장소에서 이 커밋/동시성 경계를 구현했다. 실제 Windows 파일 저장·앱 재실행·손상 복구는 [W3 보고서](implementation/W3_File_Save_Report_2026-09-21.md)에서 검증했다.

이전 v0.1 저장을 v0.2로 조용히 재해석하지 않는다. 진행 중 구 버전 판은 그 규칙으로 마무리하거나 명시적인 새 판 전환을 적용하는 로더 정책이 필요하다. 변환/복구 및 모바일 ARM64 재현은 통합 단계의 미완료 항목이다.

## 8. 검증 방법과 밸런스 판정

[실행 보고서](implementation/piece_generation/README.md)에 테스트 수, 30만 트레이 JSON, 소스 해시, 엔진 정보, 재실행 명령을 보존한다. 자동 검사는 입력·경계·비활성 가중치·fallback 양 경로·재현·현재/클리어 후 독립 좌표 검증을 포함한다. 고정 3×3 국소 창의 512패턴 × 29방향 = 14,848개를 독립 좌표 검사와 비교했다.

대량 시뮬레이션은 같은 보드 생성 시드의 10가지 합성 보드 조건으로 각 정책을 100,000회 호출한다. 빈/가득 찬 보드, 체커, 여러 밀도, 교차 완성 줄, 대각선 한 칸 구멍을 포함한다. 이것은 사람 플레이 중 자연스러운 보드 분포나 게임오버율을 대표하지 않는다.

| 100,000 트레이씩 | 무보정 | Easy | SOFT 기본 |
|---|---:|---:|---:|
| 현재/클리어 후 배치 증명 있음 | 85,088 | 85,868 | 100,000 |
| 추가 후보 트레이 수 | 0 | 0 | 29,456 |
| Easy 교체 횟수 | 0 | 10,198 | 13,179 |
| 최종 fallback 트레이 | 0 | 0 | 4,250 |
| 최종 1칸 조각 비율 | 11.148% | 11.829% | 16.752% |
| 평균 트레이 칸 수 | 10.127 | 9.900 | 9.548 |

SOFT의 Easy 교체 횟수 분모는 최초 트레이 수가 아니라 전체 후보 129,456개다. 추가 후보 횟수는 재추첨이 발생한 트레이 수와 다르다. 보정은 의도적으로 최종 분포를 바꾼다. 전체 입력 분포와 사용자 행동도 바뀌므로 이 결과만으로 너무 쉽거나 어렵다고 결론 내리지 않는다.

실기기에서는 시간 p95/p99/최대값과 렌더 프레임 지연을 측정한다. 사람 관찰은 생존 길이·초반 실패·반복 체감·배치 인지·수동 클리어 이해·10/30층 경험을 기록하고, 같은 시작 스냅샷과 정책별 독립 RNG로 비교한다. 동적 난이도, pity, bag, 고정 실패, 사용량/광고에 따른 조작은 이 정책에 없다.

## 9. 다음 개발 순서와 검토 상태

1. **자체 기술검토 완료:** 사용자 요청에 따라 Claude 답변을 생략하고 [Codex가 직접 검토](implementation/piece_generation/Codex_Review_2026-09-21.md)했다. 활성 계열 8,191조합, 모든 유효 배치 원점 1,261개, 전체 보드·조각 6,380쌍 등을 추가해 총 25개 테스트가 통과했다. 검토 범위에서 개발 착수를 막는 결함을 찾지 못했다. 생성기 런타임/가중치는 변경하지 않았다.
2. **W2 통합 완료:** [GameSession 계약·구현](implementation/W2_GameSession_Report_2026-09-21.md)에 배치·수동/자동·트레이 소진과 공급 한 번, 점수/성장·메모리 커밋을 연결하고 총 45개 테스트를 통과했다.
3. **W3 Windows 저장 완료:** 전체 후보 커밋·동일 공급 복원·손상/미지원 버전·재실행·중복 사건을 검사했다. v1 fixture를 고정했다. 모바일 백그라운드/기기 재실행과 향후 버전 마이그레이션은 후속이다.
4. **W0/W4 디자인와 실제 입력:** 원본 시안 재현 작업을 이어가고 실제 조각 ID/보드 상태를 연결한다. 이번 알고리즘 검사 통과가 외형 완료를 뜻하지 않는다.
5. **W5/W6 모바일·사람 관찰:** 고정 fixture의 ARM64 동일 결과, 타깃 기기 성능, 재미와 난이도를 확인한 뒤 수치를 채택한다.

이번 완료 범위는 독립 생성기·Codex 자체 기술검토·재실행 가능한 검사다. W2/W3 이후 W4 Windows 실제 UI 입력·상태 연결도 구현했다. 실행 증거와 남은 외형/기기 범위는 [W4 보고서](implementation/W4_Presentation_Report_2026-09-21.md)를 따른다. 알고리즘 v0.2는 변경하지 않았다. 전체 게임의 모든 상황 검증을 완료했다는 뜻은 아니다.
