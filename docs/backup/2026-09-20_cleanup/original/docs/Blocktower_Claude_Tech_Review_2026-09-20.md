# Blocktower Godot 기술 리서치 독립 검토 (Claude)

- 작성일: 2026-09-20 / 작성: Claude / 수신: Codex (최종 편집)
- 검토 대상: `Blocktower_Godot_Tech_Research_2026.md` (이하 **기술조사**). 대조 기준: 상위 v0.4 §29·§35~§38, 성장 v0.3, 스킨 v0.3 §10, 준비도 v0.1.
- 범위 외: 설치·구현·배포·플러그인 실행 검증. 공식 repo/release 최신성 확인은 Codex 담당. GUT 9.7.1의 Godot 4.7.x 표기는 Codex 확인 사항으로 수용하며 실행은 미검증.
- 유지 전제: 모든 파츠 이중 경로, 1줄=1층, B 무료/C 유료, 세부 수치는 실측 전 가안, Godot 4.7.2 + GDScript + 2D 퍼즐 + 2.5D 프리렌더.

## 1. 총평

기술조사의 방향(규칙 로직 직접 소유, 플러그인 최소화, 오디오·테스트만 외부 도구)은 타당하다. 그러나 **상위 v0.4 §35의 저장 계약과 아키텍처 경계가 기술조사에 반영되지 않았다.** 기술조사 §2 구조와 §5 Signal 전략은 "연출 완료 후 보상" 사고를 막는 장치가 없고, Resource·RNG·보드 표현이 규칙과 연출 사이에서 섞일 여지가 있다. 아래 15건 중 T01~T05가 코드 첫 줄 전에 문서에 고정되어야 한다.

## 2. 지적 사항과 판정

| ID | 우선 | 주제 | 판정 | 결론과 근거 |
|---|---|---|---|---|
| T01 | P0 | Resource 정적/가변 분리 | 채택 | `.tres`는 **출시 시 고정되는 정의**(조각 카탈로그, 스킨, 밸런스, VFX/SFX 프리셋)만. 보드·큐·점수·성장 등 **가변 런타임 상태는 `RefCounted` + 자체 직렬화(JSON 또는 바이너리, `schema_version` 포함)**. 근거: `ResourceLoader`로 `user://`의 `.tres`를 읽으면 스크립트가 실행될 수 있어 세이브 변조가 코드 실행 경로가 되고, Resource는 참조 공유라 런타임 변경이 다른 씬으로 번진다. 규칙: 정적 Resource는 런타임 읽기 전용, `ResourceSaver`로 이용자 상태를 저장하지 않음. 조각 카탈로그는 파일 다수가 아니라 `PieceCatalog.tres` 1개 + `catalog_version` 필드(T04 재현용). |
| T02 | P0 | core 순수 함수 + 단일 트랜잭션 소유자 + 저장 후 Signal | 채택 | `scripts/core/*`는 Node·Signal·Autoload 접근 없는 정적/`RefCounted` 함수 `apply(state, action) → (state', events[])`. 소유자 1개(`GameSession`)만 core를 호출하고 저장한 뒤 `events[]`를 Signal로 방출. 상위 §35.2 6단계와 일치. 기술조사 §5 "Core → Signal → Presentation"은 방향은 맞지만 **"저장 후"가 빠져 있고** §2의 `event_bus` Autoload가 core에서 직접 emit하는 구조를 허용한다. 수정: `event_bus`는 presentation 팬아웃 전용, core는 emit 금지, `save_manager`는 `GameSession`만 호출(전역 접근 금지). |
| T03 | P0 | 보드 0/1과 외형 ID 분리 | 채택 | 기술조사 §3.1의 0/1은 규칙에 충분하나 렌더·스킨·복원에 셀별 외형이 필요. `occupancy: PackedByteArray(64)`(규칙 입력)와 `cell_style: PackedByteArray(64)`(팔레트 슬롯 또는 조각 ID, 규칙은 읽지 않음)를 **같은 트랜잭션 상태 안에서 분리**. 둘 다 저장. 스킨 변경은 `cell_style`의 해석(스킨 Resource의 슬롯→텍스처 매핑)만 바꾸고 배열은 불변. 규칙 테스트가 색에 의존하지 않게 됨. |
| T04 | P0 | gameplay RNG / presentation RNG 분리, 버전 재현 | 채택 | 조각 공급 전용 `RandomNumberGenerator` 인스턴스(시드+`state` 저장)와 연출용(피치 변화·파티클 흔들림·트윈 랜덤) 인스턴스를 분리. 전역 `randi()`는 core에서 금지. 공유하면 효과음 하나 추가가 공급 순서를 바꿔 재생·진단이 깨진다. 재현 키 = `(catalog_version, supply_policy_version, seed, actions[])`. 상위 §36.1 "시드 재현"의 구현 조건. 검증: 앱 재시작 후 같은 키로 같은 공급 순서. |
| T05 | P0 | 연출 완료 비의존 저장·입력 상태 | 채택 | 입력 잠금은 논리 상태의 시간값(`input_locked_until`)이며 `animation_finished`로 풀지 않음. 클리어·구간 완성 연출은 **저장된 상태 차이**로 재구성(예: `last_acknowledged_segment` 저장, 복귀 시 차이만 요약 표시). 강제 종료 후 복귀는 최종 상태를 즉시 표시하고 연출은 생략. 기술조사 §7 AnimationPlayer 사용 자체는 문제없으나 "연출 안에서 상태를 바꾸지 않는다"를 명문화. 탭으로 연출 건너뛰기 지원. |
| T06 | P1 | Sound Manager 플러그인 필요 여부 | **기각(MVP)** | 기술조사 §10~§11의 요구(다중 샘플 + 피치/볼륨 변화, 버스 4개, 풀링)는 내장 `AudioStreamRandomizer` + `AudioStreamPlayer` 풀 8개 + Audio Bus로 충족. 플러그인의 고유 가치는 음악 크로스페이드인데 MVP에 음악이 없다(준비도 §8). 4.7.2 호환 위험 하나를 줄인다. 음악 도입 시 재검토(내장 `AudioStreamInteractive`/`Playlist`도 후보). |
| T07 | P1 | GPUParticles2D와 Compatibility 실기기 조건 | 수정 | 준비도 §4가 Compatibility를 첫 기준으로 권함. GPUParticles2D는 4.3부터 Compatibility에서 동작하나 구형 Android GLES3 드라이버 편차가 있다. 기술조사 §15 수량(8~40개)은 `CPUParticles2D`로 충분하므로 **MVP 기본은 CPUParticles2D**, GPU 전환은 최소 기기 프레임 시간 실측이 근거일 때만. 서브이미터·트레일 등 GPU 전용 기능은 사용 금지 목록에. |
| T08 | P1 | hitstop / shake | **기각** | 히트스톱은 실시간 시뮬레이션을 멈추는 장치인데 이 게임은 턴 기반이라 효과가 없다. 흔들림은 대기 줄 판독(스킨 §10 "정적 표시 기본")과 모션 감소 설정에 반한다. `shake_strength`는 프리셋 필드로만 남기고 0 고정, Saltmire Juice는 목록에서 제외(Spark는 구현 참고로 유지). 전체 화면 플래시는 광과민 위험이 있어 약하게 제한하고 모션 감소 시 비활성. |
| T09 | P1 | SFX 20~30종 vs 6종 시작 | 채택(+1) | 준비도 A09의 6종과 정렬. 단 **`line_ready`(대기 줄 발생)를 7번째로 추가** 권고. 수동 클리어가 핵심 기제이므로 무음이 아닌 청각 채널이 접근성상 필요하다. 변형은 샘플 4개 대신 `AudioStreamRandomizer` 피치 ±4%로 시작. §9 레이어링은 클리어 손맛 검증 후. |
| T10 | P1 | GUT 9.7.1 / 4.7.x | 채택(조건부) | README 표기는 Codex 확인, 실행은 미검증. 채택 조건: `addons/gut/plugin.cfg` 버전 고정 + 저장소에 벤더링. core가 Node 없는 순수 함수(T02)이므로 헤드리스 실행이 가능하고 빠르다. 기술조사 §20 필수 테스트 11개에 상위 §35.4 표의 10개와 재현 테스트(T04)를 합쳐 하나의 목록으로 통합 권고. |
| T11 | P0 | 로컬 Godot 4.6.1 불일치 | 채택 | 준비도 §2 확인 사실. 4.7.2가 승인 확정이므로 **4.7.2를 별도 폴더에 두고 절대 경로로 호출**, PATH 변경 금지. 저장소에 `engine_version.txt`(에디터·템플릿 동일 버전)와 검사 스크립트를 두어 버전이 다르면 테스트·내보내기를 중단. 다른 마이너 버전으로 프로젝트를 열면 `.godot` 캐시와 `project.godot` `config/features`가 바뀌므로 4.6.1로 임시 착수하지 않는다. 설치는 본 검토 범위 밖. |
| T12 | P1 | tests / CI / headless / export 경계 | 채택 | 3층 분리. (1) core 단위 테스트: 헤드리스, 매 커밋. (2) 통합 테스트: 입력→트랜잭션→저장, 헤드리스 가능 범위까지, 파티클·셰이더 제외. (3) 기기 테스트: APK 설치 후 강제 종료·복귀·성능 실측, 수동. 헤드리스 첫 실행 전 `--import` 단계 필요. 내보내기는 테스트 잡에 포함하지 않음. 저장소가 아직 없으므로(준비도 §2) 우선 로컬 스크립트 1개로 시작하고 원격 CI는 저장소 생성 후. |
| T13 | P1 | 우선순위 순서 충돌 | 수정 | 기술조사 §25는 P3에 성장을 두지만 결정 기록은 "MVP = Phase 1 + 최소 탑"이다. 층·구간·진행도는 정수 카운터라 규칙과 같은 P0 트랜잭션에 속한다. 순서 수정: P0 규칙+저장 계약+성장 카운터 → P1 테스트 → P2 최소 손맛(트윈 + SFX 7종 + CPU 파티클) → P3 탑 표현 → P4 실기기 최적화. |
| T14 | P1 | 2.5D 에셋 파이프라인 부재 | 채택 | 기술조사에 탑 파이프라인이 없다. 최소 기재: Blender 실행 경로 확인(준비도 미확인), 카메라·조명·해상도를 고정한 **재생성 가능한 렌더 스크립트**(`bpy`) 1개, Godot 가져오기 프리셋 분리(탑 스프라이트는 mipmap ON + VRAM 압축, UI는 무손실), 텍스처 메모리 실측 항목. 카메라 투영·층 픽셀은 결정 기록대로 후보 비교 후 확정. |
| T15 | P2 | 라이선스·결제 복원·온라인 경계 | 채택 | (a) 애드온(GUT·Saltmire 등 MIT)과 참고 코드(Kenney Starter Kit MIT)도 에셋 등록부에 기록, 코드 스니펫 복사 시 표기 의무. Reddit 게시물은 결정 근거가 아닌 참고(기술조사 §28 유지). (b) 세이브에 `entitlements`를 두되 "스토어 확인 전 미보유" 의미로, IAP 플러그인 4.7.2 호환은 D11에서 확인. (c) `Uploader` 경계 인터페이스만 정의하고 Phase 4까지 구현하지 않음. 진단 로그는 보관 한도를 두고 서버 검증 증거와 구분(결정 기록과 일치). |

## 3. 빠진 실행 단계 (문서에 추가할 항목)

1. `scripts/core` 공개 시그니처 고정: `apply_action(state, action) -> Result{state, events}`, `evaluate_turn(state) -> CONTINUE|MUST_CLEAR|GAME_OVER`. 이 둘만 `GameSession`이 호출.
2. `SaveFile` 필드 확정: `schema_version, session_id, last_event_id, rng_seed, rng_state, catalog_version, supply_policy_version, batch_index, occupancy, cell_style, queue, score, best, auto_clear, batch_success, streak, growth, last_acknowledged_segment, entitlements, diagnostic_log(한도), checksum`.
3. 재현 테스트 1개를 P1 테스트 목록에 추가: 저장된 키로 공급 순서·점수·층수 재현.
4. `engine_version.txt` + 버전 검사 스크립트 + `--import` 선행을 포함한 로컬 테스트 스크립트 1개.
5. 파티클·연출 프리셋에 `reduce_motion` 분기와 `shake_strength = 0` 기본값 명시.
6. SFX 7종 목록과 `AudioStreamRandomizer` 설정표(피치 범위, 동시 재생 상한, 버스)로 기술조사 §8~§11 교체.
7. 탑 렌더 스크립트 계약(입력: 모듈 목록·재질, 출력: 파일명 규칙·크기·여백)과 가져오기 프리셋 2종.
8. 에셋 등록부에 코드 애드온 행 추가(이름·버전·커밋·라이선스 파일 경로).

## 4. 기각·유보 요약

- 기각: Godot Sound Manager(MVP), 히트스톱, 화면 흔들림, Saltmire Juice 채택, GPUParticles2D 기본 사용, 4.6.1 임시 착수.
- 유보(실측 후): GPU 파티클 전환 조건, 레이어링 SFX, 카메라 투영·층 픽셀 수치, 텍스처 예산.
- 유지: 규칙 직접 구현, Tween/AnimationPlayer 역할 구분(§7), 프로시저럴 오디오 제외(§12), Kenney/Demo 참고 사용, GUT 채택(조건부).
