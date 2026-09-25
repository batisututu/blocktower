# W2 GameSession 구현·검증 보고서

2026-09-21. **W2의 화면 없는 규칙·최소 성장·커밋 연결 구현 완료. 총 45개 테스트 통과.** 실제 파일 저장과 앱 재실행은 W3 미완료다. 기존 기능 시안은 이번 모듈과 아직 연결하지 않았다.

## 구현 결과

| 산출물 | 역할 |
|---|---|
| [GameSession 계약](../../game/scripts/core/contracts/game_session_contract.md) | 상태 필드/소유권, 행동·오류·사건 순서, 초기 생성·새 판·재개·커밋 경계 |
| [GameSession](../../game/scripts/core/game_session.gd) | 배치·수동/자동·묶음 정산·v0.2 재공급·게임오버·편집·중복 방지 |
| [성장 규칙](../../game/scripts/core/growth_rules.gd) | 실제 제거 줄 누적, 네 재질과 정의된 벽돌 4파츠 해금, 구간/대표 선택 |
| [메모리 저장소](../../game/scripts/core/memory_save_repository.gd) | 전체 스냅샷 복사·revision 충돌 검사·실패/응답 유실 주입. 디스크에 쓰지 않음 |
| [사용자 결과 검사](../../game/tests/unit/test_game_session.gd) | 신규 20개 통합/경계 테스트 |

첫 공급부터 전체 상태 커밋에 성공해야 세션을 반환한다. 배치/클리어/새 공급/점수/성장을 한 후보로 계산하고 커밋 이후에만 `PLACED`, `CLEARED`, `BATCH_SETTLED`, `SUPPLIED` 등의 연출 사건을 반환한다. 취소·무효 배치·중복 입력·실패 커밋은 보상 사건을 반환하지 않는다.

남은 트레이가 비지 않으면 공급 RNG를 진행하지 않는다. 마지막 조각 사용 시 새 완성 여부를 먼저 기록하고, 자동이면 제거한 뒤 묶음을 한 번 정산하고 재공급한다. 수동 클리어는 큐/RNG/묶음 성공을 바꾸지 않는다. 트레이 도중 게임오버는 현재 스트릭을 종료하고 영구 층수·최고 기록을 보존한다.

새 판에서는 보드·점수·현재 스트릭·묶음 성공·공급 RNG를 초기화한다. 영구 성장·외형·최고점/최고 스트릭·마지막 자동 설정을 유지하며 run_id/batch_id를 증가시켜 이전 드롭을 거절한다. session_id는 지속 사건열의 ID로 유지한다.

완성 구간별 재질 변경/대표 선택을 제공한다. 미완성 구간 선택·잠긴 재질 적용은 거절한다. 기본 목재 구간은 별도 배열 없이 암묵적으로 표현하여 탑 층수에 비례한 불필요한 상태 복사를 피했다. 금속/크리스털 상세 파츠·지붕·일괄 편집은 아직 구현하지 않았다.

## 실제 검증

Godot `4.7.2.stable.official.ed1daf0bf`, 고정 엔진 바이너리 해시 및 GUT 9.7.1 소스 해시 확인. **6개 스크립트 / 45개 테스트 / 2,338개 assertion / 실패·오류·pending 0.**

- [실행 요약](w2_evidence_2026-09-21/last_test_run.json), [JUnit](w2_evidence_2026-09-21/gut_unit.xml), [전체 로그](w2_evidence_2026-09-21/gut.stdout.log), [소스 해시](w2_evidence_2026-09-21/source_manifest.json).
- 최초 `pwsh -NoProfile -File tools/test.ps1`로 import 및 초기 검사 통과. 행동 재생/게임오버/정수 경계 검사를 추가한 뒤 `pwsh -NoProfile -File tools/test.ps1 -SkipImport`로 전체 45개를 다시 실행했다.
- 기존 생성기·설정·이전 검사 소스는 변경하지 않았다. [30만 트레이 실행 증거](piece_generation/README.md)는 기존 결과로 보존하며 이번에 재실행한 것으로 기록하지 않는다.

| 수용 기준 | 실행 범위 / 결과 |
|---|---|
| R01 | 경계 밖·겹침·잘못된 슬롯·실수 좌표·int64 최대 좌표 거절, 큐/보드/점수/RNG/사건 ID 무변화 |
| R02 | 교차 15셀→2줄/240점/2층, 전체 64셀→16줄/2,560점/16층, 0줄 무보상 |
| R03 | 수동 대기 줄을 게임오버로 오인하지 않음, 소진 후 공급, 묶음 중 게임오버 시 미완료 묶음 미정산 |
| R04 | 자동 전환 확인 미충족 무변화, 확정 시 클리어/보상/모드 한 커밋. 실제 확인창은 W4 |
| R05 | 기존 대기 줄은 새 성공으로 세지 않음, 자동 제거 전 성공 감지, 소진 시 스트릭 한 번 정산 |
| R06 | 동시 4줄의 하위 재질 집계, 같은 사건 파츠 해금, 네 재질/정의된 벽돌 4파츠의 누적 경로, 새 판/게임오버 성장 유지 |
| R07 | 9→25 다중 경계, 19→21, 정확히 30/40층, 기존 재질/대표 유지, 미완성 구간/잠긴 재질 거절 |
| R08 | 두 세션에서 같은 200개 행동 재생. 한쪽은 5행동마다 총 40번 재개해 전체 상태·결과/사건이 동일 |
| R09/R10의 core 범위 | 같은/오래된 사건·다른 세션·오래된 묶음·소비된 슬롯 거절, 커밋 재진입 BUSY, 잘못된 스냅샷/숫자 타입/스타일·카운터 경계 거절 |
| S02/S05/S06의 메모리 경계 | 초기 커밋 실패 시 노출 없음, 재공급 도중 실패 후 동일 RNG 재시도, 커밋 응답 유실 후 복원/재시도 무보상, competing writer 충돌 차단 |

테스트 중 소비된 슬롯을 압축하여 생성기에 전달한 뒤 받은 witness의 슬롯 번호가 원래 트레이와 다를 수 있음을 확인했다. GameSession의 `view()`는 원래 0~2 슬롯으로 다시 매핑하며, 앞 두 슬롯이 비어 있는 경우를 회귀 검사에 넣었다.

## 사용 예시와 W3 연결점

```gdscript
const Session = preload("res://scripts/core/game_session.gd")
const MemoryStore = preload("res://scripts/core/memory_save_repository.gd")
var repository = MemoryStore.new() # W2 전용: 프로세스 종료 후 보존 안 됨
var created = Session.start(repository, "profile-session", "20260921")
if not created.ok:
    return created
var game_session = created.session
var result = game_session.dispatch({
    "type": "SET_AUTO", "session_id": "profile-session", "event_id": 1,
    "enabled": true, "confirmed": false
})
# result.ok 이후에만 result.events로 HUD/음향/연출을 갱신한다.
```

Repository의 `commit(candidate, expected_revision)`는 전체 스냅샷 커밋 또는 명확한 실패를 반환해야 한다. 이미 저장됐을 수도 있는 경우 `COMMIT_UNCERTAIN`을 반환하고, GameSession은 `RECOVERY_REQUIRED`로 다음 행동을 차단한다. 저장소에서 다시 읽은 사건 ID로 중복 보상을 막는다. 단순 실패 `SAVE_FAILED`는 원래 상태에서 같은 사건을 재시도할 수 있다.

W2 스냅샷은 `PackedByteArray`와 엄격한 int를 포함한다. 그대로 JSON으로 저장했다 복원하면 타입 계약이 깨질 수 있다. W3는 배열/카운터/RNG의 명시적 인코더·디코더, 파일 세대와 checksum, 손상/미래 버전 보존, 교체 전후 중단 검사를 구현해야 한다. 메모리 저장소는 저장 공간 부족·파일 권한·프로세스 종료·전원 손실을 검증하지 않는다.

## 다음 우선 작업

**W3 실제 파일 SaveRepository**와 버전 v1 저장 fixture를 구현한다. 이 작업 후 실제 앱 재실행, 중단 지점별 이전/새 전체 세대 선택, 초기 저장/새 판/응답 유실 복원을 검사한다. 이후 W4에서 실제 퍼즐 입력과 시안 기준 아트를 연결한다. 현재 W0 외형 재현 및 모바일/사람 플레이 검증은 계속 미완료다.
