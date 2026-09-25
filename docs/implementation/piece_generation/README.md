# 조각 생성기 v0.2 실행 검증

검증일: 2026-09-21. **독립 모듈 구현·검사·Codex 자체 기술검토 완료. 전체 게임 통합은 미완료.** 최신 [자체 검토](Codex_Review_2026-09-21.md)는 25개 테스트 통과이며 아래 21개 테스트/30만 트레이 표는 초기 실행 증거로 보존한다. 현재 사양은 [생성 알고리즘](../../Blocktower_Piece_Generation_Algorithm_Design_v0.1.md)이 소유한다.

## 구현과 검토

- [생성기](../../../game/scripts/core/generation/piece_generator.gd), [설정](../../../game/data/piece_generator_default.tres), [계약](../../../game/scripts/core/contracts/piece_generation_contract.md).
- 29방향/13계열, 활성 가중치 준수, Easy 한 개, 최대 후보 4회와 유한 fallback, 현재/클리어 후 증명 좌표, 정확한 checkpoint 검증.
- [기존 공급 v0.1](../../../game/scripts/core/piece_supply.gd)과 `docs/examples/`, `pretests/`의 기존 증거를 유지한다. 이번 출력은 별도 경로에 보존했다.
- 자체 레드팀 검토로 Easy 후보가 하나도 맞지 않지만 다른 계열은 맞는 상황, 활성 조각이 전부 안 맞는 상황, `MUST_CLEAR`와 배치 보장의 차이, 잘못된 int64 파싱, 호출자 데이터 변경, 보정에 따른 분포 변화를 검사했다.

Claude Code 요청은 기존 터미널 `term_fc16c4ac-9748-4625-91ad-1ad1d2bc8b44`가 수락했지만 **“You've reached your Fable limit”**를 반환했다. 리뷰 결과 파일은 생성되지 않았다. 이후 사용자가 Claude 답변을 생략하고 Codex가 직접 검토하도록 요청하여 대기를 종료했다. [자체 기술검토](Codex_Review_2026-09-21.md)를 완료했으며 제3자 공동 검토로 기록하지 않는다.

## 실행 환경과 증거

| 항목 | 실제 실행 |
|---|---|
| 엔진 | Godot `4.7.2.stable.official.ed1daf0bf` |
| 경로 | `C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe` |
| 엔진 SHA-256 | `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643` |
| GUT | 9.7.1, 고정 커밋과 소스 해시 검사 통과 |
| CPU | Intel Core i9-11900H 2.50GHz, Windows headless |
| 보드 RNG 시드 | `821913`, 공급 RNG와 분리 |
| 공급 초기 시드 | `20260921`, 각 정책 별도 checkpoint |

[실행 요약](last_test_run.json), [JUnit](gut_unit.xml), [GUT 로그](gut.stdout.log), [import 로그](import.stdout.log), [시뮬레이션 로그](piece_simulation.stdout.log), [실제 소스 해시](source_manifest.json), [외부 자료 조회 해시](source_provenance.json).

## 단위 테스트

**4개 스크립트, 21개 테스트, 1,491개 assertion, 실패/오류/pending 0.** 기존 9개와 [새 생성기 12개](../../../game/tests/unit/test_piece_generator.gd)를 함께 실행했다. assertion 한 개가 아래처럼 여러 조합의 루프 결과를 검사할 수 있으므로 assertion 수와 조합 수를 혼동하지 않는다.

- 29방향의 고유성·정규화·연결성 및 기존 19ID/좌표 보존.
- 정수 티켓 45개 경계 전수 검사, 비활성/음수/초과/전체 0 가중치 및 설정 오류.
- int64 양 끝값, 잘못된 문자열, 누락/불일치 checkpoint, 비어 있지 않은 트레이의 재추첨 거절.
- 교차 줄 동시 제거, 가득 찬 보드, 클리어 후에도 조각이 못 들어가는 사용자 설정.
- 체커 보드 우하단 3×3 창의 512패턴 × 29방향 = **14,848조합**을 독립 좌표 판정과 비교. 64비트 전체 보드 전수 검사는 아니다.
- 고정 200개 밀집 보드에서 JSON checkpoint 복원 후 전체 결과 동일성, 입력 소유권, 증명 좌표 검사.
- Easy/전체 계열 fallback, 최대 4회 종료, 후보 없음, 모든 교체 슬롯 도달, 설정 순서 정규화와 변경 탐지.
- 각 조각이 현재 개별적으로 놓이더라도 세 조각 모두 소진할 수 없는 반례.

## 대량 검사

[전체 JSON](piece_generation_simulation.json): 정책별 100,000트레이, 합계 **300,000**, 계약 위반 0. 빈 보드/가득 찬 보드/체커/점유 확률 25·50·70·85·95%의 다섯 조건/70% 보드에 교차 완성 줄 추가/대각선 구멍 등 10가지 합성 조건을 같은 순서와 보드 시드로 제공했다. 자연스러운 플레이에서 얻은 보드가 아니다. 정확한 입력 생성은 [시뮬레이션 코드](../../../game/tests/simulation/piece_generator_simulation.gd)의 `make_board()`가 기준이다.

각 결과의 3ID, 활성 가중치, Easy 조건, 후보 상한, 입력 불변을 검사했다. 있는 witness는 모두 독립 좌표 충돌 검사로 검증했다. 기본 SOFT는 100,000건 모두 witness가 있었다. 매 1,000번째 입력은 JSON 복원 후 결과 전체를 대조했다(정책당 100건). RAW/EASY의 witness 없는 결과가 실제로 전부 불가능한지 대량 검사에서 역방향 전수 검색하지는 않았다. 해당 판정은 별도의 14,848조합 oracle 검사가 담당한다.

| 지표 | RAW | EASY | SOFT |
|---|---:|---:|---:|
| 실제 배치 증명 있음 | 85,088 | 85,868 | 100,000 |
| 증명 중 먼저 클리어 필요 | 24,470 | 23,278 | 23,245 |
| 후보 트레이 총수 | 100,000 | 100,000 | 129,456 |
| Easy 교체 수 | 0 | 10,198 | 13,179 |
| 최종 fallback 트레이 수 | 0 | 0 | 4,250 |
| 함수 시간 p50 (µs) | 194 | 209 | 224 |
| 함수 시간 p95 (µs) | 360 | 386 | 632 |
| 함수 시간 p99 (µs) | 461 | 506 | 1,048 |
| 관측 최대 (µs) | 2,545 | 1,650 | 13,236 |

시간은 `generate()` 호출의 벽시계 시간이며 개발 PC의 다른 프로세스/스케줄링 영향을 포함한다. 워밍업을 별도 제외하지 않았고 모바일·렌더 프레임 SLA도 아니다. 기본 정책에서 평균 트레이 칸 수는 9.548, 최종 single 비율은 16.752%였다. 해당 값은 합성 입력 분포에 의존한다.

[분포 진단](raw_distribution_analysis.json)은 **고정 300,000회 RAW 추첨**의 13계열+29방향 주변 빈도를 기대값과 비교했다. 최대 절대 표준화 편차 약 1.643, 전 항목 6σ 이내였다. 독립성/PRNG 품질의 증명 또는 최종 보정 분포의 기대값 검사가 아니다. SOFT 후보 수는 보드 적합 여부로 중단되므로 동일한 고정 표본 검정으로 오해하지 않는다.

## 재실행

프로젝트 루트에서 실행한다. 산출물은 `tools/out/`에 기록되어 보존한 이 보고서 증거를 덮어쓰지 않는다.

```powershell
pwsh -NoProfile -File tools/test.ps1
pwsh -NoProfile -File tools/simulate_piece_generator.ps1 -SampleCount 100000
```

첫 명령은 고정 엔진/GUT 해시 확인 → import → GUT/JUnit 검증을 수행한다. 두 번째 명령은 고정 엔진 해시와 세 정책의 결과 수/성공 플래그를 확인한다. Godot 종료 코드가 0이어도 파서/스크립트 오류 로그가 있으면 실패 처리한다. 깨끗한 체크아웃에서는 위 순서로 import부터 수행한다.

## 아직 검증하지 않은 경계

1. GameSession: 남은 슬롯·배치·수동/자동·클리어·새 공급 순서, 중복 액션, queue와 batch_id 일치.
2. SaveRepository: 전체 상태 원자 커밋·실패 후 재시도·구 버전·손상 복구·중단/백그라운드.
3. Android ARM64 재현/성능 및 실제 UI/입력과의 통합.
4. 사람 플레이의 난이도·공정성·반복 체감·수동 클리어 이해. 이번 모듈은 전체 플레이 에피소드를 시뮬레이션하지 않았다.

이 항목을 통과하기 전에는 독립 생성기의 성공을 완성 게임 전체의 성공으로 확대하지 않는다.
