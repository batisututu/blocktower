# Blocktower Godot 기술 리서치 2026

- 개정: v0.10 (W4 연결 및 B안 상세 재질 적용 증거 반영) / 기술스택 조사일: 2026-09-20 / W1~W3 적용·W4 연출 후속 검토일: 2026-09-21
- 대상: Godot **4.7.2 stable + GDScript**, 2D 퍼즐 + 2.5D 프리렌더 탑
- 작성 방식: 사용자 원안 전체 검토 → Codex 레드팀·공식 출처 확인 → 열린 Claude Code 세션의 독립 검토·조정
- 상태: **개발 적용 명세. 목표 엔진의 공급 예제·GUT 기본 실행은 후속 검증 완료. W2 headless GameSession/메모리 커밋 연결은 검증됨. W3 Windows 파일 저장·재실행·손상 복구는 검증됨. W4 Windows 실제 입력/화면 연결은 검증됨. 전체 UI 체험·플랫폼 내보내기·실기기 성능은 미검증.**
- 후속 실행 증거: [개발 전 사전 테스트](Blocktower_Preflight_Test_Report_2026-09-20.md)에서 임시 Godot 4.7.2 + GUT 9.7.1 기본 실행과 공급 예제 검사를 통과했다. 아래 조사 당시의 미검증 표기 중 이 범위는 해당 보고서로 갱신하며, 현재 [W2 실행 결과](implementation/W2_GameSession_Report_2026-09-21.md)는 GameSession·메모리 커밋 45개 테스트를 통과했다. 후속 [W3 보고서](implementation/W3_File_Save_Report_2026-09-21.md)에서 총 58개 테스트와 별도 프로세스 26개 검사를 통과했다. [W4 보고서](implementation/W4_Presentation_Report_2026-09-21.md)에서 74개 테스트, 12개 실제 상태 캡처, 30행동 측정을 추가했다. 전체 PF 검수·모바일·전원 손실은 미검증이다.
- 기준 기획: [게임 기획](Blocktower_Game_Design.md), [성장 기획](Blocktower_Growth_Design.md), [디자인 에셋 가이드](Blocktower_Design_Asset_Guide.md), [개발 계획](Blocktower_Development_Plan.md)
- 디자인 후속: [Mobbin MCP·Godot 자료실 조사](design/Reference_Research_2026-09-21.md)에서 UI 흐름·에셋 후보와 `StyleBoxTexture`/`NinePatchRect`/`AtlasTexture` 적용을 정리했다. 사용자 첨부 시안의 외형을 제작 기준으로 삼으며 기존 W0 평면 시안은 재현 완료로 인정하지 않는다. 후보 애드온의 4.7.2 실행 호환성과 실제 에셋 도입은 아직 검증/수행하지 않았다.

## 1. 판정과 근거의 범위

**GDScript로 규칙을 직접 소유하고, Godot 내장 UI·오디오·애니메이션에 GUT만 추가하는 구성이 현재 규모에 적합하다.** 원안의 방향은 유지하되 플러그인 필수 지정, 가변 상태의 Resource 사용, 저장보다 늦은 성장 처리, 뒤로 밀린 기기 검증을 수정한다. 아래의 적합성 판단은 프로젝트 요구에서 도출한 설계 판단이며 벤치마크 결과가 아니다.

| 구분 | 이번 확인 범위 | 해석 |
|---|---|---|
| 확인 사실 | 공식 릴리스·README·태그·API 문서·스토어 제출 요구, 로컬 설치 현황 | 링크 확인과 실행 호환성은 별개 |
| 적용 기준 | 단일 상태 변경 주체, 저장 후 연출, 정적 정의/가변 상태 분리, 최소 에셋 | 새 코드의 리뷰 기준으로 사용 |
| 가안 | 공급 가중치, 카메라/픽셀 크기, 연출 시간, 오디오 풀 크기, 메모리 예산 | 실험 결과와 확정일을 후속 기록 |
| 미검증 | 전체 게임·저장 통합, Android/iOS 내보내기, 결제, 실제 GPU/메모리/입력 지연 | GUT 기본 실행은 사전 테스트에서 별도 통과. 나머지는 로그·기기·빌드 증거 필요 |

원안의 Reddit 11개 링크와 GitHub 7개 프로젝트를 확인했다. Reddit은 경험담·연출 탐색 자료로 보존하며 엔진 API나 성능의 근거로 삼지 않는다. 모든 글이 2026년에 작성되었다는 주장은 채택하지 않는다. `stable`, `main`, `latest`는 이동하는 이름이므로 확인일과 실제 태그를 함께 기록한다.

## 2. 최신성·호환성 감사

| 대상 | 2026-09-20 확인 결과 | Blocktower 적용 |
|---|---|---|
| Godot | 최신 안정판 4.7.2, 2026-08-18. 4.8-dev6는 개발판 | 에디터·export templates를 4.7.2로 함께 고정. [공식 아카이브](https://godotengine.org/download/archive/) |
| GUT | README는 9.7.1 / `godot_4_7` → Godot 4.7.x. `main`은 4.6.x. v9.7.1은 2026-07-10 공개 | **v9.7.1 태그로만 도입**, 첫 실행 통과 후 채택 확정. [호환 표](https://github.com/bitwes/Gut), [릴리스](https://github.com/bitwes/Gut/releases/tag/v9.7.1) |
| SoundManager | 현재 main README는 Godot 4.6+. 최신 릴리스 v2.6.2는 2024-04-18이며 해당 태그 README는 Godot 4로 표기 | 최신 README를 오래된 태그의 검증 결과로 해석하지 않는다. MVP 선택 제외, 향후 음악 전환 요구가 생기면 재평가. [저장소](https://github.com/nathanhoad/godot_sound_manager), [릴리스](https://github.com/nathanhoad/godot_sound_manager/releases/tag/v2.6.2) |
| Kenney Match 3 | README Godot 4.6, 타일 교환 방식. 코드 MIT, 에셋 CC0. 확인 당시 공개 릴리스/태그 없음 | 드래그 피드백·UI 참고만. 교환·낙하·보드 규칙을 복사하지 않는다. [원본](https://github.com/KenneyNL/Starter-Kit-Match-3) |
| Godot 공식 데모 | 4.7용 `4.7-6ad6167`, 2026-07-07 공개 | 필요한 예제만 해당 릴리스 기준으로 확인. master 전체를 프로젝트 의존성으로 넣지 않는다. [릴리스](https://github.com/godotengine/godot-demo-projects/releases/tag/4.7-6ad6167) |
| GodotSfxr | 4.x 브랜치, 확인한 마지막 push 2023-09-18. 공개 릴리스/태그 없음 | 2026 신규 도구로 소개하지 않는다. 오프라인 소리 제작 참고, 런타임 합성은 도입하지 않는다. [원본](https://github.com/tomeyro/godot-sfxr) |
| Saltmire Spark | 2D 버스트 효과 참고 구현, 공개 릴리스/태그 없음 | 필수 애드온 아님. 필요한 구현을 검토할 때 커밋·라이선스 고정. [원본](https://github.com/saltmire/saltmire-spark) |
| Saltmire Juice | README Godot 4.6+, v1.0.0은 2026-07-03 | 팝 효과 참고만. hitstop·화면 흔들림 패키지를 MVP에 도입하지 않는다. [원본](https://github.com/saltmire/saltmire-juice) |

GUT의 `/releases/latest`는 확인 당시 v9.6.1을 반환했다. v9.7.1용 문서 URL도 본문 제목은 9.6.0으로 표시되어 있었다. 자동 설치에서 `latest`를 사용하지 말고 **태그 소스 → 해당 릴리스 → 문서 예제 실행 확인** 순서로 판단한다. `plugin.cfg`의 버전 문자열만으로 파일 동일성을 판정하지 않는다.

도입 시 버전 기록에 사용할 확인값:

| 구성 | 태그 / 커밋 | 관리 방법 |
|---|---|---|
| GUT | `v9.7.1` / `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605` | 필요한 `addons/gut` 벤더링, 출처·MIT 원문·배포본 해시 기록 |
| 공식 데모 참고 | `4.7-6ad6167` / `6ad6167e0577fe3622c18546138f456b107ce93c` | 참고 기록만, 코드 복사 시 해당 파일과 라이선스 기록 |
| SoundManager 후보 | `v2.6.2` / `fd96cad9d7939044fe59b00b8f8a1e7e758e7876` | 미도입. main을 선택하면 별도의 정확한 커밋과 검증 결과 필요 |

태그·라이선스 정보는 각 원본 저장소와 GitHub API의 release/tag 응답을 대조했다. 활동 날짜가 최근이라는 사실만으로 품질·모바일 성능·4.7.2 호환성을 보증하지 않는다. 애드온 업그레이드는 별도 변경으로 처리하고 저장 호환·회귀 테스트 후 기준 버전을 갱신한다.

## 3. 현재 환경과 착수 전 차이

| 항목 | 로컬 관찰 | 다음 조치 |
|---|---|---|
| 프로젝트 | W1에서 Git 초기화, `game/project.godot`, GUT 벤더링, `tools/run.ps1`·`test.ps1` 생성 | W2/W3 Windows 구현 완료. 다음 W4 실제 UI 연결 |
| Godot | PATH는 4.6.1 유지. `C:/DEV/tools/godot/4.7.2/`의 `4.7.2.stable.official.ed1daf0bf` 사용 | `engine_version.txt`와 엔진/GUT 해시 고정. 잘못된 버전·0개 검사 거부 확인 |
| Export templates | `4.6.1.stable` 확인 | 4.7.2와 정확히 맞추기 |
| Java | PATH는 Zulu 25.0.2 | Godot Android 문서 권장 JDK 17을 우선 후보로 프로젝트에 지정, 실제 빌드 조합 검증 |
| Android SDK | 플랫폼 34/35/36, build-tools 35.0.0/36.0.0/36.1.0, NDK 27.1.12297006/28.2.13676358 | 설치 목록과 최종 Gradle/SDK 조합을 구분. 엔진 템플릿과 맞춰 내보내기 확인 |
| ADB | SDK 안에 존재, PATH에서는 미확인 | SDK 내 절대 경로로 기기 확인 가능 |
| Blender | PATH와 기본 설치 후보 폴더에서 미확인 | 실제 설치 경로/버전 확인 또는 준비. 전 PC 검색으로 부재를 확정한 것은 아님 |
| 에셋 | 원본 B/C PNG 보존. W0에서 SVG 21개·한글 폰트·Godot 시안 추가 | [에셋 가이드](Blocktower_Design_Asset_Guide.md) §10 참조. 최종 2.5D 프리렌더와 음원은 미준비 |

글로벌 PATH나 기존 도구는 교체하지 않았다. `engine_version.txt`, [엔진/GUT 출처 기록](../tools/engine_provenance.json), 프로젝트별 경로와 반복 검사 명령을 추가했다. [W0/W1 실행 보고서](implementation/W0_W1_Report_2026-09-21.md)를 따른다. 재현 가능한 내보내기·Android 빌드 기록은 W5에서 추가한다. Godot의 JDK 권장과 내보내기 준비는 [Android 공식 문서](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)를 따른다.

## 4. 개발방법론과 최소 기술스택

**계약을 먼저 고정하고, 배치→저장→재개→최소 탑까지 이어지는 작은 플레이 흐름을 만든다.** 규칙·저장 경계에는 테스트를 먼저 작성하고, 외형 변경은 실제 화면에서 검증한다. 대규모 프레임워크·ECS·모든 기능의 FSM·상속 계층·전역 EventBus를 먼저 만들지 않는다.

| 영역 | 기준 선택 | 이유 / 변경 조건 |
|---|---|---|
| 규칙 | 타입을 명시한 GDScript, Node에 의존하지 않는 core | 8×8 규칙은 작은 데이터 연산으로 충분. 같은 입력 재현·헤드리스 테스트 용이 |
| 데이터 | 읽기 전용 Custom Resource 정의 + 소유권이 명확한 런타임 상태 | 에디터 편의와 저장 안정성을 분리 |
| 조정 | GameSession 1개가 action·저장·상태 전환 소유 | 중복 보상과 순서 역전 방지 |
| 화면 | Control 기반 HUD + 2D 보드/드래그 표현, 직접 Signal 연결 | 공통 상태가 늘어날 때만 presentation용 이벤트 중계 추가 |
| 렌더러 | Compatibility로 첫 기기 실험 | 2D 중심 요구에 대한 출발안. GPU 효과 요구·기기 결과에 따라 변경 |
| 짧은 움직임 | 내장 Tween | 배치·버튼·숫자 피드백 |
| 복합 연출 | 필요할 때 AnimationPlayer | 탑 구간 완성 등, 게임 상태 변경 금지 |
| 소리 | AudioStreamPlayer 풀 + AudioStreamRandomizer + Audio Bus | 샘플 변형·동시 재생에 충분한 내장 기능 |
| VFX | 선/스프라이트/Tween 우선, 파티클은 추가 실험 | CPU/GPU 파티클을 이름만 보고 성능 확정하지 않음 |
| 테스트 | GUT v9.7.1 + 저장 장애 주입 + 실기기 확인 | 규칙 정확성, 복원, 화면 품질을 서로 다른 증거로 검증 |
| 저장 | 자체 JSON 스키마와 검증·백업·마이그레이션 | 외부 객체 역직렬화 없이 상태를 통제 |
| 탑 제작 | Blender 고정 카메라 프리렌더 → 투명 PNG → Godot | 실시간 3D·물리 시뮬레이션은 현재 요구에 불필요 |
| 온라인/결제 | 경계와 요구만 문서화, 후속 단계에서 SDK 선정 | Phase 1~3을 계정·서버에 종속시키지 않음 |

렌더러의 실제 기능 차이는 [Godot 렌더러 문서](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)를 기준으로 확인한다. C#·GDExtension·FMOD/Wwise는 현재 요구만으로 추가하지 않는다. 특정 플랫폼 연동 또는 프로파일링으로 필요가 입증될 때 검토한다.

Claude Code는 구현 시 계약에 맞춘 코드·빌드 증거를 제시하고, Codex는 경계 사례·저장·입력·에셋 가독성을 레드팀 관점에서 검토한다. 한 파일의 편집 주체는 한 번에 한 세션으로 제한하고, 제안/채택/검증 완료를 구분해 남긴다. 현재 문서 편집자는 작업 시작 시 파일 소유권을 확인한다.

## 5. 제안 디렉터리와 책임

아래는 **후속 구현용 구조**이며 아직 생성된 파일 목록이 아니다. 처음에는 관련 기능을 같은 파일에 두고 책임이 실제로 커질 때 분리한다.

후속 착수 검토에서 루트 [CLAUDE.md](../CLAUDE.md), [GAME-DESIGN.md](../GAME-DESIGN.md), [ADR-0001](adr/0001-godot-baseline-and-contracts.md)을 추가했다. 공통 `src/types/` 역할은 `game/scripts/core/contracts/`로 매핑하며, TypeScript 계약을 중복 생성하지 않는다. 아래 구조 중 생성기·GameSession·성장·메모리/파일 저장소와 계약은 구현했으며 실제 플레이 UI 연결은 W4 후속이다.

```text
Blocktower/
  docs/                       # 기획, 결정, 조사, 검증 기록
  art_source/                 # .blend·원음·렌더 스크립트; 게임 export 밖
  game/                       # Godot 프로젝트 루트
    project.godot
    scenes/                   # game, board, HUD, tower
    scripts/core/             # 규칙·성장 계산·공급 정책; Node 접근 없음
    scripts/session/          # GameSession, 입력 action 변환
    scripts/infra/            # SaveRepository, AudioService, Settings
    scripts/presentation/     # 보드·탑·HUD·연출
    data/                     # 읽기 전용 조각/밸런스/스킨 정의 .tres
    assets/                   # 배포용 texture/font/audio
    addons/gut/               # 고정 태그의 테스트 도구
    tests/unit/               # 규칙·성장·재현
    tests/integration/        # 저장 장애·재개·입력 중복
    tests/fixtures/           # 과거 스키마·손상 저장 fixture
  tools/                      # 버전 검사·테스트·내보내기 스크립트
  engine_version.txt
  THIRD_PARTY_NOTICES.md
```

`.godot/` 캐시와 빌드 산출물·서명 비밀은 제외하고 원본 코드·에셋·필요한 UID/가져오기 설정은 추적한다. `.gitattributes`는 프로젝트에 두고 전역 Git 설정은 바꾸지 않는다. 큰 `.blend`/음원 등은 첫 커밋 전에 LFS 필요성을 결정한다. [Godot 버전 관리 안내](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html)

## 6. 상태 계약: 정의, 규칙, 연출 분리

`.tres`에는 조각의 고정 좌표, 카탈로그, 밸런스, 스킨, 음향·연출 프리셋을 둔다. 실행 중 보드·큐·성장 값을 공유 Resource에 쓰지 않는다. Resource는 경로로 로드할 때 공유될 수 있다. 런타임은 전용 `RefCounted`/데이터 객체로 관리하고 배열까지 소유권을 분리한다. 외부 저장 파일을 Resource로 로드하지 않는다. [Resource 문서](https://docs.godotengine.org/en/stable/classes/class_resource.html)

| 상태 | 계약 |
|---|---|
| occupancy | 길이 64, 0/1. 셀 인덱스 `y * 8 + x`. 빈칸·경계 검사만으로 합법 배치 판정 |
| cell_style | 길이 64, 색/팔레트 슬롯. 규칙은 읽지 않으며 occupancy와 같은 사건으로 저장·제거 |
| ID 범위 | PackedByteArray를 쓰면 슬롯은 0~255. 임의의 조각 ID를 바이트에 넣지 않음. 조각은 별도 안정적 ID 사용 |
| queue | 3개 슬롯의 조각 ID·소비 여부, batch_id. 무효 조각 ID는 저장 검증 실패 |
| pending lines | 현재 보드에서 계산한 행/열 집합. 저장된 별도 캐시를 진실로 삼지 않음 |
| batch/streak | 현재 묶음의 새 줄 완성 성공 여부, 연속 묶음 수. 묶음 전체 소진 때 1회 평가 |
| growth | 영구 총 층수, 재질별 실제 조건 충족 줄 수, 해금 상태, 구간/외형 선택 |
| versions | schema/rule/catalog/supply 정책·엔진 버전. 표시 이름 대신 안정적 ID |

권장 core 인터페이스는 `apply_action(state, action, definitions) -> Result(next_state, events, error)`이다. 실패하면 기존 상태와 RNG를 바꾸지 않는다. 초기에는 상태 복사 비용보다 정확성을 우선하되 실제 비용을 측정한다. 무한 탑의 전체 장식 배열을 매 입력마다 무조건 복사하는 방식은 피한다.

허용 action은 배치(묶음 ID·슬롯·좌표), 수동 클리어, 자동 전환 확정, 편집 확정, 새 게임 등이다. 자동 클리어는 배치 결과에서 파생시키므로 재생 로그에 별도 사용자 action으로 중복 기록하지 않는다.

## 7. 한 번의 입력에서 저장까지

```text
입력 → GameSession에서 사건 ID·현재 상태 검사
     → core가 배치/새 완성/클리어/점수/성장 계산
     → 묶음 평가·재공급 후 계속/클리어 유도/게임오버 판정
     → 전체 next_state 저장 커밋
     → 확정 상태 교체 → 결과 이벤트 전달 → HUD·SFX·Tween
```

1. 입력 처리는 직렬화한다. 같은 `session_id + event_id` 재시도는 다시 적용하지 않는다. 확정 결과를 보관한 사건은 그 결과를 반환하고, 보관 범위 밖의 지난 사건은 현재 상태와 이미 처리됨/오래된 요청 결과를 반환한다. 단조 사건 순서·세션 검증 계약을 구현 전에 명시하며, 마지막 ID 하나로 임의의 과거 결과까지 복원할 수 있다고 가정하지 않는다.
2. 배치 성공 시 조각 소비·배치 점수와 새로 완성된 줄을 기록한다. 자동이면 같은 사건에서 완성 줄 전체를 제거한다.
3. 점수·층수·진행도·해금·구간 완성을 함께 계산한다. 3개 소진 시 성공 여부를 한 번 평가하고 새 묶음을 공급한 뒤 종료 조건을 검사한다.
4. 저장 성공 전에 보상 연출을 보내지 않는다. 쓰기 실패 시 다음 입력을 받기 전에 상태를 정리하고 재시도/복구 경로를 표시한다.
5. 저장 교체 직후 프로세스가 죽어 호출자가 성공 여부를 모를 수 있다. 재개 시 유효한 커밋과 사건 ID를 확인해 보상을 다시 지급하지 않는다.
6. Signal·AnimationPlayer·Tween 콜백에서 점수/성장을 변경하지 않는다. 연출을 생략해도 결과가 같다.

짧은 입력 게이트가 필요하면 세션의 일시적 단조 시간/상태로 관리하고 일시정지·복귀·연출 취소 시 해제한다. `input_locked_until` 같은 벽시계 마감 값을 영구 게임 상태로 저장하지 않는다. `animation_finished` 누락 때문에 계속 잠기는 구조도 금지한다. 같은 보드 상태라면 B/C 스킨과 모션 감소 설정의 입력 해제 시점도 같아야 한다.

### 초기 생성·새 판·복귀 계약

W2 착수 때 새 판에서 초기화/유지할 필드 표와 action/result 오류 목록을 정의하고 W3 스키마에 연결한다. `session_id`, 단조 사건 순서, 중복/지난 사건 처리, 커밋 성공 여부가 불명확할 때의 재조회 경로를 명시한다. 마지막 사건 ID만으로 임의의 과거 요청에 원래 결과를 반환할 수 있다고 가정하지 않는다. 과거 결과를 보관하지 않는 경우 재적용하지 않고 현재 상태와 이미 처리됨/오래된 요청 결과를 반환하는 계약을 둔다.

새 저장 형식의 최초 구현에서는 가상의 구버전 마이그레이션을 완료했다고 표시하지 않는다. v1 fixture를 보존하고 이후 실제 스키마 변경 때 변환 검사를 추가한다. 파일 교체 실패 주입과 실제 전원 손실 내구성의 검증 범위도 구별한다.

최소 성장에 해금 카운터를 연결할 때는 해금 전 누적·해금 사건의 줄·조건을 만족하는 하위 재질 집계·모든 파츠의 누적 대체 경로를 §15의 성장 검사로 확인한다. 해금 미구현 상태에서는 층수 검사만으로 Phase 2 전체 통과를 주장하지 않는다.

Action은 배치, 수동 클리어, 자동 전환, 새 판, 편집 확정의 입력과 오류를 먼저 닫는다. 신규 판의 시드는 GameSession에서 한 번 정하고 후보 상태에 보존하며, 저장 재시도마다 새로 뽑지 않는다. 진행 중 새 판의 확인 UX와 설정 초기화 범위도 W2 필드 표에 포함한다. 구간 생성/보상은 클리어 사건에서 완료되므로 `ACK_SEGMENT`는 필수 게임 action이 아니다. 첫 구현의 복귀는 미완료 축하 연출을 생략한다. 나중에 미확인 안내를 재개할 경우에만 별도 표시 확인 상태를 설계하고, 확인 동작으로 보상을 지급하지 않는다.

## 8. 게임 규칙의 정본

배치·클리어·점수·종료·사건 순서는 [게임 기획](Blocktower_Game_Design.md), 층수·해금·스트릭·구간은 [성장 기획](Blocktower_Growth_Design.md)을 따른다. 규칙 표를 별도로 복제하지 않는다. 현재 점수 배율은 정수 백분율 100/120/140/160으로 구현하여 부동소수 반올림을 피한다. 정의 수치는 버전 관리한다.

## 9. 공급 적용과 재현성

2026-09-21 후속: [생성 알고리즘 v0.2](Blocktower_Piece_Generation_Algorithm_Design_v0.1.md)의 29종/13계열 및 현재/클리어 후 한 수 보장 모듈을 고정 Godot 4.7.2에서 구현했다. [25개 테스트·기존 30만 트레이 실행 증거](implementation/piece_generation/README.md)를 확보했으며 사용자 요청으로 Claude 답변을 생략하고 [Codex 자체 검토](implementation/piece_generation/Codex_Review_2026-09-21.md)를 완료했다. GameSession 연결은 [W2에서 완료](implementation/W2_GameSession_Report_2026-09-21.md)했으며 Windows 디스크 저장도 [W3 보고서](implementation/W3_File_Save_Report_2026-09-21.md)에서 완료했다. UI/제품 밸런스/모바일은 미완료다. 기존 [공급 v0.1](Blocktower_Piece_Supply_Spec.md)은 GitHub/Reddit 조사·19종 무보정 비교 이력을 소유한다.

현재 카탈로그·가중치·중복·보정·호출 순서·정의/설정 해시는 생성 알고리즘 v0.2와 [계약](../game/scripts/core/contracts/piece_generation_contract.md)이 소유한다. [ADR-0002](adr/0002-versioned-board-aware-piece-generation.md)에 정책 변경을 기록했다. 구 버전 저장을 새 정책으로 조용히 재해석하지 않는다. 같은 시드만으로 보드 보정 공급열이 같아지는 것은 아니며 동일 보드와 checkpoint가 함께 필요하다.

게임 공급 전용 RNG와 SFX/VFX RNG를 분리한다. core의 전역 `randi()` 사용을 금지한다. 안정적 순서의 카탈로그를 추첨하고 스킨·모드 변경으로 재추첨하지 않는다.

Godot RNG는 같은 시드로 재현할 수 있지만 내부 알고리즘은 구현 세부사항이다. **엔진 버전을 넘어 같은 시드만으로 동일 공급을 보장하지 않는다.** seed와 state를 함께 저장하고 복원 시 seed 설정 후 state를 복원한다. 엔진/규칙/카탈로그/공급 버전, 시작 스냅샷, action, 실제 공급 조각 ID를 재현 기록에 포함한다. [RNG 공식 문서](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)

## 10. 저장·복원·마이그레이션

2026-09-21 구현 기준: [파일 저장 계약](../game/scripts/core/contracts/file_save_contract.md)과 [ADR-0004](adr/0004-two-generation-file-persistence.md)가 정확한 wire 필드·세대 선택·복구 오류를 소유한다. 아래 표는 논리적 그룹이다. 실제 버전/공급 필드는 checkpoint 안에, generation은 revision으로, 해금/부분 구간은 저장 카운터에서 파생한다. Windows 앱 시작과 6개 커밋 지점 강제 종료를 검증했다. 구버전 실서비스 파일은 없으므로 가상 마이그레이션을 만들지 않고 v1 fixture를 고정했다.

JSON은 기본 자료형만 명시적으로 읽고 필드 타입·범위·배열 길이·ID 존재·상태 불변식을 검사한다. `allow_objects` 같은 임의 객체 복원 경로는 사용하지 않는다. JSON 숫자는 float로 해석될 수 있으므로 **64비트 RNG seed/state 및 커질 수 있는 누적 정수는 검증한 10진 문자열로 보존**한다. 작은 셀 좌표/슬롯도 정수 여부를 확인한다. [JSON 문서](https://docs.godotengine.org/en/stable/classes/class_json.html)

| 저장 그룹 | 최소 필드 |
|---|---|
| 식별/버전 | schema_version, rule_version, catalog_version, supply_policy_version, engine_version, session_id, last_event_id, generation |
| 퍼즐 | occupancy, cell_style, queue, batch_id, batch_success, streak, score, best, auto_clear |
| 공급 | rng_seed, rng_state, 필요한 공급 정책 상태 |
| 성장 | 총 층수, 재질별 진행도, 해금 ID, 구간/외형 선택, 부분 구간 |
| 무결성 | 검증 대상 payload와 checksum, 이전 유효 세대 |

같은 `user://` 저장 영역에 임시 파일 쓰기 → flush/닫기 → 다시 읽어 구조·체크섬 확인 → 검증된 이전 세대 보존 → 현재 파일 교체 순서를 설계한다. **파일 두 개를 순서대로 쓰는 것만으로 원자성이 생기지 않는다.** 각 중단 지점에서 이전 또는 새 전체 세대 하나만 선택되는지 테스트한다. Windows/Android/iOS의 교체 동작과 실패 반환을 확인하고, 앱 수준 커밋과 전원 손실 내구성을 구분한다. [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html), [DirAccess](https://docs.godotengine.org/en/stable/classes/class_diraccess.html)

손상 시 원본을 보존하고 백업 복구를 안내한다. 미지원 미래 스키마를 새 게임으로 조용히 덮어쓰지 않는다. 마이그레이션은 복사본에서 수행하고 구버전 fixture로 검증한다. 앱 백그라운드 알림에만 저장을 의존하지 않는다. 로컬 영구 성장은 앱 삭제·기기 분실 후 복구를 뜻하지 않는다.

설정은 별도 저장해도 되지만 보드·점수·성장 커밋과 섞이지 않게 한다. 결제 권한은 향후 스토어 검증 어댑터의 결과이며 로컬 `owned=true`를 권한 증거로 쓰지 않는다. 진단 로그는 별도 용량 제한·스냅샷 절단 정책을 두고 저장 핵심 데이터가 무한히 커지지 않게 한다. checksum은 손상 검출이며 부정행위 방지 장치가 아니다.

## 11. 입력·HUD·접근성 적용

64개의 물리 콜라이더 대신 보드 로컬 좌표로 셀을 계산하고 조각 원점을 고정한다. Canvas 변환·보드 스케일·safe area를 적용한 후 계산하며 가장자리 음수 좌표, UI 밖 드롭, 조각의 돌출 셀을 검증한다. 모바일은 포인터/터치 ID 하나를 드래그 소유자로 정한다. 다른 손가락·마우스 에뮬레이션 중복 이벤트가 두 번 배치하지 못하게 한다.

토글·팝업·포커스 상실·백그라운드 진입 시 드래그를 취소한다. 모달 뒤 보드로 입력이 통과하지 않게 한다. 취소와 배치 실패는 점수/RNG/조각 상태를 바꾸지 않는다. 드래그 오프셋은 손가락 가림을 줄이는 후보를 기기에서 비교한다.

B 무료/C 유료는 같은 배치 가능·불가·대기 줄·선택 표시를 사용한다. 색만으로 상태를 구별하지 않고 윤곽/패턴/문구를 함께 사용한다. 대기 줄은 정적 표시를 기본으로 한다. 큰 글자·긴 번역·작은 화면에서도 점수/클리어 버튼/3조각이 충돌하지 않게 확인한다. 시안 PNG 하단 문구 겹침은 실제 HUD 제작 전에 수정할 항목이다.

## 12. 오디오: 최소 6종으로 검증

효과음 구성과 디자인 수용 기준은 [디자인 에셋 가이드](Blocktower_Design_Asset_Guide.md) A09/§8에서 관리한다. 여기서는 재생 구현만 규정한다.

Master/UI/Puzzle/Tower 버스, 제한된 플레이어 풀, 우선순위·동시 재생 상한을 둔다. 풀 8개는 출발 가안이며 실제 중첩과 메모리를 보고 조정한다. 음악 도입 시 Music 버스를 추가한다. 음소거·볼륨·백그라운드/복귀를 검증하고 음향 설정이 게임 RNG에 영향을 주지 않게 한다.

짧은 효과음은 WAV 후보를 비교하고 불필요한 스테레오·무음 꼬리를 제거한다. 긴 음악은 별도 압축/스트리밍 후보를 검토한다. 샘플률·피크·루프 경계·파일 크기를 납품표에 남긴다. Sfxr는 제작 도구 후보일 뿐 실행 시 합성 의존성이 아니다.

내장 `AudioStreamRandomizer`의 `random_pitch=1.04`는 약 **0.9615~1.04배** 범위이며 정확한 대칭 ±4%가 아니다. `random_volume_offset_db=1`은 ±1dB 후보다. 원안의 수치는 청취 전 가안으로 유지하고 변형 없이도 읽히는 기준음을 먼저 만든다. [공식 API](https://docs.godotengine.org/en/stable/classes/class_audiostreamrandomizer.html)

## 13. 움직임·VFX·입력 시간

원문과 기존 가안을 검토한 첫 시간표·구현 순서는 [개발 계획 §4.2~4.4](Blocktower_Development_Plan.md)에 통합한다. 총 연출 길이와 입력 해제 시점은 별개다. 하나의 속성에 Tween이 겹치면 기존 것을 종료/교체하고 씬 해제·빠른 반복 입력도 처리한다. [Tween 문서](https://docs.godotengine.org/en/stable/classes/class_tween.html)

첫 W4는 실제 입력·Snap/프리뷰·대기 윤곽·차등 클리어·버튼·점수/+층·구간/해금 요약·게임오버를 연결한다. 상세 조립·카메라·파티클 장식은 후속이다. 화면 흔들림·hitstop·전체 화면 플래시는 기본 제외한다. 모션 감소에서는 스케일/이동을 정적 변경 또는 짧은 페이드로 바꿔도 규칙 정보가 남아야 한다.

파티클 없이 가독성과 반응을 먼저 통과시킨다. 이후 적은 수의 CPU 파티클과 GPU 파티클을 목표 기기에서 비교하고 필요할 때만 채택한다. 원안의 8~40개는 성능 보증이 아니다. 셰이더 오버드로·투명 면적·드로콜·첫 효과 로딩을 함께 측정한다. [GPUParticles2D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html)

### W4 사건·표현 기술 선택

아래는 2026-09-21 공식 API 재확인에 근거한 구현 계획이다. stable 문서 확인은 고정 Godot 4.7.2에서 새 코드가 실행됐다는 증거가 아니므로 W4에서 import/GUT/네이티브 실행을 별도로 확인한다.

| 대상 | 적용 결정과 경계 |
|---|---|
| 입력 | Control 입력과 보드 로컬 좌표, 단일 포인터 소유자. 장식 오버레이는 입력을 가로채지 않게 하고 모달은 마우스·터치·키보드 모두 차단. 드래그 위치를 Tween으로 지연시키지 않음 |
| 즉시 반응 | Pick/Snap/Button/숫자는 소유 노드의 `create_tween()`으로 생성, 동일 속성 Tween을 중단·교체. 종료 콜백을 기다리는 것만으로 입력 잠금을 관리하지 않고 취소 경로에서 명시적 정착 |
| 복합 시퀀스 | 단순 W4는 한 사건 타임라인으로 시작. 편집이 필요한 게임오버/구간 조립은 AnimationPlayer 후보. 같은 scale/alpha를 Tween과 동시에 소유하지 않음 |
| core→표현 | presentation 계약을 먼저 추가. CLEARED의 제거 직전 행/열/셀/스타일 데이터를 보강하고 commit 성공 후 전달. UI에는 보드·점수·성장을 수정할 권한이 없음 |
| 음향 동기화 | 성공 결과 안의 표시용 Snap/제거/Lock 시점에서 VFX·SFX·햅틱을 함께 요청. 논리적 제거는 이미 커밋된 상태이며 표시 시점에 CLEAR를 다시 보내지 않음. 실제 장치 출력 지연은 별도 측정 |
| 정밀한 HUD | 최종 점수/층수는 snapshot의 int를 그대로 표시. count-up에 큰 누적값 전체를 float로 바꿔 왕복시키지 않음. 큰 값은 즉시 표시+증분 표기로 대체해도 됨 |
| 설정 | SFX 음량/음소거·모션 감소·진동 OFF는 별도 버전 설정 저장 계약으로 분리. 설정 읽기 실패 시 안전 기본값·안내, 게임 저장을 초기화하지 않음. auto_clear는 기존 GameSession 저장 필드 유지 |
| 종료·복귀 | 최신 snapshot을 다시 그리며 과거 축하 재생 없이 입력 상태 복구. 중복/지난 사건은 성공 효과 없음. COMMIT_UNCERTAIN 등은 저장 재조회 우선 |

Tween은 같은 속성의 중복 애니메이션을 피하고 새 실행마다 새 인스턴스를 생성한다. [공식 Tween API](https://docs.godotengine.org/en/stable/classes/class_tween.html)

현재 렌더러는 Compatibility다. GPUParticles2D 전체를 불가로 단정하지 않되 `emit_particle()`은 Compatibility 미지원이므로 셀마다 직접 호출하는 설계는 채택하지 않는다. 먼저 도형/Sweep/Fade로 연결하고 one-shot·CPU/GPU 선택과 워밍업·재사용은 목표 렌더러에서 비교한다. [공식 GPUParticles2D API](https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html#class-gpuparticles2d-method-emit-particle)

진동은 내장 `Input.vibrate_handheld(duration_ms, amplitude)`를 첫 어댑터 후보로 사용한다. Android의 VIBRATE 내보내기 권한, OS 설정·장치 지원에 따른 무반응을 처리한다. 네이티브 플러그인은 기본 API로 충족하지 못하는 패턴이 확인될 때 검토한다. Light/Medium을 모든 기기의 동일 강도로 간주하지 않는다. 일반 버튼·실패에는 기본 무진동, 성공 배치/클리어 위주로 제한하며 OFF일 때 호출하지 않는다. [공식 Input API](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-vibrate-handheld)

## 14. 에셋 가져오기와 출처 후보

첫 에셋 목록·제작 순서·원본·카메라·납품/권리 규격은 [디자인 에셋 가이드](Blocktower_Design_Asset_Guide.md)가 소유한다. 최소 디자인 규격 후 첫 세트 제작과 코드 작업을 병행한다. `.blend` 원본은 Godot export 밖에 두고 검수된 모듈만 게임에 넣는다.

UI/작은 셀은 무손실을 출발점으로 한다. 탑의 mipmap과 VRAM 압축은 축소 품질·알파·메모리 A/B 후 에셋별 결정한다. **모든 탑 텍스처에 mipmap ON/VRAM 압축을 일괄 지정하지 않는다.** 파일 압축률과 GPU 메모리는 다른 값이며 SVG도 가져오기 결과를 확인한다. [이미지 가져오기 문서](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)

제작 재료 후보: [Kenney UI Pack](https://kenney.nl/assets/ui-pack), [UI Audio](https://kenney.nl/assets/ui-audio)는 각 페이지 CC0를 확인했다. [Poly Haven](https://polyhaven.com/license)은 에셋의 라이선스와 웹사이트 로고/미리보기 사용을 구분한다. [Noto CJK](https://github.com/notofonts/noto-cjk)는 실제 선택 파일의 라이선스를 동봉한다. 이 목록은 다운로드·사용 확정을 뜻하지 않는다. GUT 등 코드 의존성도 별도 출처/라이선스 등록 행을 둔다.

## 15. 테스트와 완료 기준

규칙 테스트는 메서드 존재 여부를 따라 쓰지 않고 아래 사용자 결과를 검증한다. 고정 시드 반복과 경계 보드를 함께 사용한다.

| ID | 검증 대상 | 통과 기준 |
|---|---|---|
| R01 | 경계·겹침·실패 배치 | 범위 밖/점유 셀 거부, 보드·점수·큐·RNG 무변화 |
| R02 | 교차 / 전체 보드 / 0줄 | 15셀·2줄·240점 / 64셀·16줄·2560점 / 0보상 |
| R03 | 게임오버와 재공급 | 하나라도 배치 가능하면 계속, 대기 줄 있으면 종료 금지, 소진 뒤 공급 후 검사 |
| R04 | 수동/자동 전환 | 확인 취소 무변화, 확정 클리어·보상·모드 저장 1회 |
| R05 | 묶음 스트릭 | 새 완성만 집계, 기존 대기 줄 제외, 소진당 1회 평가, 저장 복귀 일치 |
| R06 | 성장·해금 | 해금 전/당일 줄 포함, 하위 재질 집계, 모든 파츠 누적 경로, 게임오버 후 유지 |
| R07 | 구간 | 9→11, 19→21, 한 번에 여러 경계, 지붕/부분 층/기존 편집 유지 |
| R08 | 공급 재현 | 동일 버전·시작 상태·행동의 큐/점수/성장 일치, SFX 설정 바꿔도 동일 |
| R09 | 입력 중복 | 더블 탭·멀티터치·오래된 batch/slot·중복 사건으로 보상/조각 이중 처리 없음 |
| R10 | 상태 불변식 | 점유/스타일 길이·범위, 줄 계산의 안정성, 같은 사건 재처리 무보상 |
| S01 | 커밋 장애 주입 | 임시 쓰기/검증/백업/교체 전후 중단 시 이전 또는 새 전체 상태로만 복원 |
| S02 | 저장 실패 | 저장 공간/접근/파일 교체 실패 때 성공 연출·메모리만 선반영하지 않음 |
| S03 | 손상·마이그레이션 | 잘린 JSON·잘못된 타입·미래 스키마·구버전 fixture에서 원본 보존, 명시적 복구 |
| S05 | 초기 생성·새 판·로그 절단 | 최초 공급 커밋 전 제공 금지, 새 판 성장 유지, 재시도 seed 고정, 절단 후 스냅샷으로 전체 행동 재생 |
| S06 | 교체 직후 종료·중복 재시도 | 저장 응답을 못 받은 사건도 재조회 후 이전/새 전체 상태 선택, 보상/재추첨 중복 없음 |
| S04 | 숫자 정밀도 | 큰 RNG state/누적 정수를 round-trip해 완전 일치 |
| D01 | 종료·복귀 | 배치/클리어/해금/연출 도중 앱 종료 후 확정 상태와 입력 가능 상태 복구 |
| D02 | 화면·접근성 | 작은 화면/긴 문구/모션 감소/음소거/B·C에서 상태 정보와 입력 규칙 동일 |
| D04 | 모바일 RNG | Windows x64 체크포인트를 Android ARM64에서도 복원·ID/state 대조. 엔진 간 동일성 보증과 구분 |
| D03 | 성능 | 최소 기기에서 퍼즐과 30/300/3,000층 탐색 측정, 가시 범위 밖 렌더 제한 |

### W4 연출 수용 검사 — 계획, 아직 미실행

PF 항목은 R/S/D의 표현 계층 세부 검사다. 기존 W3의 58개 테스트 통과를 아래 검사 완료로 재사용하지 않는다. W4 검증 보고서에는 항목별 자동/Windows 실화면/Android 기기 결과와 미검증 범위를 남긴다.

| ID | 시나리오와 통과 기준 | 검증 방식 |
|---|---|---|
| PF01 | 가림 offset·확대/축소·음수/가장자리 좌표에서 Preview와 Drop 셀 일치, 겹침·범위 밖 이유 구분, 취소 시 상태/RNG 무변화 | 좌표·포인터 통합 검사 + 네이티브 조작 |
| PF02 | 멀티터치·에뮬레이션 중복·더블 탭·모달·포커스 상실·드롭 후 버튼 통과로 이중 dispatch 없음. 배경 키보드 포커스도 차단 | 합성 입력 검사 + 실제 터치 |
| PF03 | 수동 대기 1/2/3/4/16줄과 AUTO 확인/취소. 버튼 견적이 실제 points와 일치. 교차 2줄=15셀/240점, 전체 16줄=64셀/2560점. 자동 배치 후 사라진 신규 셀도 효과 위치에 포함 | core 사건 payload 검사 + 실제 화면 |
| PF04 | 확정 전 쓰기 실패 시 성공 Snap/제거음/성장 없음. 확정 직후 불확실 응답·재조회·동일 사건 재시도로 보상과 효과 중복 없음 | W3 장애 주입 + 표현 호출 기록 |
| PF05 | 세 조각 소진 후 새 batch 표시 1회, 오래된 슬롯 드래그 취소. 대기 줄이 있으면 종료 연출 금지. 실제 종료 이유와 재시작/탑 동작 일치 | 통합 검사 + 네이티브 조작 |
| PF06 | 1/2/3/4~16줄 강도 구분, 교차 셀 효과 중복 없음. Snap/제거/Lock의 VFX·SFX·햅틱 요청은 같은 표시 사건에서 1회. 배치·클리어·버튼 연타 시 음향 풀 상한 유지 | 사건 기록 + 네이티브 청취, 장치 출력 지연은 W5 |
| PF07 | 연출 각 단계에서 뒤로·앱 종료·백그라운드·씬 교체·모션 옵션 변경 후 최신 상태/입력 복구. Tween 취소 뒤 무한 잠금·과거 축하 재생 없음 | 통합 검사 + 별도 프로세스 재실행/기기 |
| PF08 | 9→11/19→21/다중 경계+해금+최고점+종료 조합에서 알림 요약, 탑 강제 이동 없음. 큰 정수 HUD 최종값 정확. 이번 판/누적 성장 문구 구분 | 고정 상태 사건 검사 + 화면 |
| PF09 | 무음·진동 OFF·감소 모션·B/C 공통 표시·회색조·큰 글꼴·320×568/360×800/412×915에서 같은 정보. 폰트/미지원 진동·누락 효과음에도 규칙 정상 | 자동 설정 분기 + 시각/장치 검수; C 미제작 범위 명시 |
| PF10 | 연속 배치·16줄 최대 제거·동시 알림으로 첫 효과/반복 프레임 시간·입력 잠금·음향 지연·노드/메모리/오버드로 기록. 잠금 목표는 개발 계획 §4.4, 최소 기기 성능 예산은 D08에서 측정 후 고정 | Windows 실제 렌더 + W5 장치/OS/렌더러별 p95·최대 지연 기록 |

GUT은 헤드리스 규칙·가능한 통합 테스트에 사용한다. 렌더링·오디오·모바일 입력은 기기 검증으로 남긴다. 단위/통합/내보내기는 별도 단계로 만들되 출시 후보는 모두 통과해야 한다.

아래는 **프로젝트와 GUT을 준비한 뒤 실행할 PowerShell 예시이며 이번에 실행한 명령이 아니다.** `$godotExe`는 실제 4.7.2 실행 파일 경로를 지정하고 현재 디렉터리는 `game/`로 맞춘다.

```powershell
& $godotExe --version
# 위 출력이 고정 버전과 다르면 중단한다.
& $godotExe --headless --path . --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $godotExe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
if ($LASTEXITCODE -ne 0) { throw 'Unit tests failed' }
& $godotExe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -ginclude_subdirs -gexit
if ($LASTEXITCODE -ne 0) { throw 'Integration tests failed' }
```

GUT CLI의 종료 코드만 보지 말고 **발견된 테스트 수 > 0, 필수 테스트의 pending/skip 없음**을 결과 검사에 포함한다. pending은 실패 종료를 보장하지 않는다. 첫 실행에서 태그 소스의 옵션과 예제를 대조하고 검사 스크립트로 고정한다. [GUT CLI 문서](https://gut.readthedocs.io/en/v9.7.1/Command-Line.html)

## 16. 성능·기기 검증을 앞당기기

첫 보드가 뜨는 시점에 Android 테스트 빌드를 만들어 좌표·safe area·터치·일시정지·오디오 복귀를 확인한다. 에셋 완료 후 처음 내보내면 입력/렌더러/SDK 문제가 늦게 드러난다.

최소 지원 기기·OS·화면 비율은 미확정이다. 최소/중간 기기 후보를 선정하고 기기 모델, OS, 렌더러, 빌드 해시, 화면 크기, 측정 장면을 결과에 남긴다. 60fps를 목표로 선택한다면 프레임 예산은 약 16.7ms이지만 이 값은 현재 달성 결과가 아니다. p95/p99 프레임 시간, 입력→시각 반응, 메모리 최고치, 앱 크기, 첫 로딩, 발열/유휴 전력을 기록한다.

탑은 전체 층마다 활성 Node/고해상도 텍스처를 무한 생성하지 않는다. 보이는 구간만 표시하고 동일 모듈을 재사용한다. 30/300/3,000층의 저장 크기·재개 시간·탐색을 함께 검사한다. 성능 수치는 Phase 3 전에 예산으로 고정하되 측정은 Phase 1부터 시작한다.

## 17. Android·iOS·배포 준비

| 항목 | 기준일의 확인 사실 | 프로젝트에 필요한 증거 |
|---|---|---|
| Android target SDK | 일반 휴대폰 신규 앱/업데이트는 2026-08-31부터 Android 16/API 36 이상 요구 | 최종 AAB/Manifest target 확인. min SDK와 구분. [Google Play 공식](https://developer.android.com/google/play/requirements/target-sdk) |
| Godot Android 빌드 | JDK 17 권장, SDK·템플릿·Gradle 준비 필요 | 에디터/템플릿/JDK/SDK/NDK/Gradle 조합과 실제 빌드 로그 기록. [Godot 공식](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) |
| Android 네이티브 라이브러리 | 16KB 페이지 대응에는 ELF·패키징 정렬과 포함 라이브러리 확인 필요 | 엔진 및 모든 플러그인 `.so`, AAB에서 생성한 APK와 16KB 환경에서 실행 검증. [Android 공식](https://developer.android.com/guide/practices/page-sizes) |
| iOS 제출 | 2026-04-28부터 Xcode 26 이상·iOS 26 SDK 이상 사용 요구 | macOS/Xcode 빌드 경로 확보, 실제 archive/기기 검증. 최소 지원 iOS 26을 뜻하지 않음. [Apple 공식](https://developer.apple.com/news/upcoming-requirements/) |
| Godot iOS | macOS/Xcode 환경에서 내보내기 준비 | 현재 Windows 검토만으로 iOS 빌드 성공 처리 금지. [Godot 공식](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html) |

Godot `stable` Android 문서의 SDK 패키지 예시가 API 35여도 Play 제출 기준 API 36을 대신하지 않는다. 엔진에 맞는 템플릿에서 target/compile/build tools를 검증하고 Gradle·AGP를 임의의 최신 버전으로 일괄 교체하지 않는다. 로컬 NDK를 설치했다고 이미 컴파일된 엔진/플러그인 라이브러리가 재빌드되는 것도 아니다.

앱 ID, 버전 코드, export preset, 디버그 APK/출시 AAB, 서명 키 보관·복구, 내부 테스트 배포 경로를 출시 전에 확정한다. 키·비밀번호는 저장소와 문서에 넣지 않는다. 스토어 개인정보/데이터 수집 표시·등급·스크린샷은 실제 포함 SDK와 동작을 기준으로 준비하고 제출 시 공식 요구를 다시 확인한다.

## 18. 결제·온라인의 후속 경계

C 스킨은 외형 상품이며 정보/입력 우위를 주지 않는다. 상품을 출시할 때 플랫폼별 비소모성 구매 SDK의 4.7.2 호환, 취소·대기·중복 콜백·재설치·복원·계정 전환·오프라인 권한 캐시 정책을 테스트한다. 복원 중/실패/확인된 미보유를 구분하고 로컬 저장 조작으로 권한을 부여하지 않는다. 실제 상품 출시는 별도 완료 기준이다.

Phase 4 전에는 서버 검증 기록과 개인 오프라인 성장의 구분, 서버 발급 시드/과제 유효기간, 지연 제출, 주차 시간대, 재시도 멱등성, 계정 귀속, 다중 기기 충돌을 확정한다. 단말 누적값이나 수신 주차만으로 공개 랭킹을 인정하지 않는다. 오프라인 기록을 모아 두었다 한 주에 제출하는 사례도 검증한다. 필요 경계만 정의하고 현재 단계에서 백엔드 제품·업로더를 구현하지 않는다.

## 19. 개발 순서와 변경 이력

개발 순서·디자인 선행 작업·담당 역할·미결정 D01~D14는 [개발 계획](Blocktower_Development_Plan.md)에 통합했다. A~Z 표를 별도로 유지하지 않는다. 수용 검사는 이 문서 §15, 과거 증거는 [사전 테스트 보고서](Blocktower_Preflight_Test_Report_2026-09-20.md), 규칙·메모리 커밋 이력은 [W2 보고서](implementation/W2_GameSession_Report_2026-09-21.md), 현재 Windows 파일 저장·재실행 증거는 [W3 보고서](implementation/W3_File_Save_Report_2026-09-21.md)가 소유한다.

원안 대비 처리표·Claude 기술 검토·협의 원문은 [백업 안내](backup/2026-09-20_cleanup/README.md)를 통해 조회한다. 채택한 기술 계약은 위 본문에 반영되어 있으며 백업 의견을 현재 명세보다 우선하지 않는다.

## 20. W4 적용 결과 (2026-09-21)

[W4 보고서](implementation/W4_Presentation_Report_2026-09-21.md)의 테스트/캡처/소스 해시가 실행 증거다. [ADR-0005](adr/0005-committed-session-presentation.md)에 실제 화면 계약을 기록했다. 추가 런타임 애드온 없이 내장 Control/그리기/Tween/AudioStreamPlayer로 구현했다. 저장 스키마 v1·공급 정책 v0.2는 유지한다.

PF01~PF05/07은 공유 배치 판정·포인터 소유권·revision·실패/복구·확인 취소와 Windows 실제 세션 분배를 자동 검사했다. 이는 모든 물리 터치/중단 타이밍의 전수 검사가 아니다. PF06은 6 WAV·재생 풀·요청 경로를 구현했고 청취/출력 지연은 남아 있다. PF08은 교차/최대 제거·누적 층수·최고점·탑 경계를 검사했으나 모든 알림 조합은 아니다. PF09는 설정 분기·세 해상도의 지정 상태를 확인했으며 C/큰 글꼴/회색조/장치는 미완료다. PF10은 30행동의 Windows dispatch/다음 프레임 관찰값을 남겼고 노드·메모리·오버드로/최소 기기 예산은 후속이다. PF 전체 PASS로 표시하지 않는다.

### 후속 B안 상세 외형 적용 (2026-09-21)

[외형 보고서](implementation/Visual_Fidelity_Report_2026-09-21.md)에 15개 SVG 표면, 생성 배경, 원본 3D 장면/프리렌더 9개, Godot 9-slice 연결과 19개 Windows 상태를 기록했다. 기술스택을 변경하거나 외부 애드온을 추가하지 않았다. 최종 지붕은 메시 UV 재질로 줄눈을 표현한다. 전체 74개 테스트 통과와 마지막 재질 수정 후 import/탑 6상태 재검증을 구분해 보존했다. 연구일·기존 W3/W4 측정값은 새 측정으로 바꾸지 않았다.
