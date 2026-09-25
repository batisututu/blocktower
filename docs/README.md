# Blocktower 현재 문서 안내

기준일: 2026-09-26. 아래 문서들이 현재 기획·정책·가이드·검증의 기준이다. 파일명은 고정하고 문서 안의 개정 번호를 갱신한다. 과거 버전과 검토 원문은 backup에서만 보관한다.

**코드 리뷰·최적화:** [변경·성능·핸드오프 기록](implementation/Code_Review_Optimization_2026-09-26.md). 확정 상태 분석과 트레이 정보를 재사용하고 중복 복사·미사용 선언을 정리했다. GUT 150개/3,812개 단언, 고정 v1과 12개 시나리오/450개 행동의 전체 이력 일치, Windows 8화면/95개 점검을 확인했다. 반복 view 2,000회의 중앙값은 81.147ms→11.512ms였으며 Android 성능 수치는 아니다.

| 문서 | 단일 관리 범위 |
|---|---|
| [게임 기획](Blocktower_Game_Design.md) | 콘셉트, 퍼즐 규칙·점수, Phase, 온라인 제품 정책, 공통 용어 |
| [성장 기획](Blocktower_Growth_Design.md) | 층수·재질/파츠 해금·스트릭·구간·대표 선택·편집/감상 |
| [디자인·에셋 가이드](Blocktower_Design_Asset_Guide.md) | B/C 정책, 시안 수정, 첫 에셋 A01~A09, 상태판, 제작·납품·권리 규격 |
| [조각 공급 명세·조사](Blocktower_Piece_Supply_Spec.md) | 공급 v0.1, GitHub/Reddit 근거, 자체 예제 API, 공급 실험 조건 |
| [조각 생성 알고리즘](Blocktower_Piece_Generation_Algorithm_Design_v0.1.md) | **알고리즘 v0.2 / 문서 v0.3**: 29종/13계열, 보드 보정, 한 수 보장 범위, 설정/RNG 계약과 통합 순서 |
| [Godot 기술 리서치 2026](Blocktower_Godot_Tech_Research_2026.md) | 버전·기술스택, 상태/저장/입력 계약, R/S/D 수용 검사, 가져오기·배포 |
| [개발 계획](Blocktower_Development_Plan.md) | W0~W6, W4 입력·연출 작업 순서/우선순위/시간표, 관찰 계획·미결정 D01~D14 |
| [사용자 연출 검토 레퍼런스](Blocktower_Puzzle_Presentation_Review_Prompt_v0.1.md) | 원문 보존: 34개 연출 검토 절. 프로젝트 적용 결정은 개발 계획 §4.1~4.5, 납품은 디자인 가이드 §12, 검사는 기술 리서치 PF01~PF10 |
| [사전 테스트 보고서](Blocktower_Preflight_Test_Report_2026-09-20.md) | 실제 실행 결과·범위·재실행 방법과 증거 링크 |

**Phase 3 건축 MVP:** [구현 범위](implementation/Phase3_MVP_Tower_Overview_Copy_2026-09-25.md), [데스크톱 검증](implementation/Phase3_Desktop_Validation_2026-09-25.md), [Android 실기기 검증](implementation/Phase3_Android_Device_Validation_2026-09-25.md). 전체 탑·구간 확대·단일 대상 외형 복사를 SM-N981N에서 30/300/3,000층으로 확인했다. 고정 GUT 138개/3,709개 단언이 통과했고 저장 재시작·짧은 프레임/메모리 작업 예산도 통과했다. 최소 지원 기기와 처음 플레이하는 사람의 관찰은 남아 있다.

**Phase 4 온라인 로컬 MVP:** [구현 범위와 실행 방법](implementation/Phase4_Online_MVP_2026-09-25.md), [서버·Android 실기기 검증](implementation/Phase4_Local_E2E_Validation_2026-09-25.md). 임시 계정·서버 발급 시드·행동 재생 검증·주간 순위·다른 대표 탑 보기와 별도 도전 저장을 연결했다. HTTP 검사 12개, GUT 141개/3,733개 단언, QA 실기기 도전·재시작 복원·제출·대표 10층 보기가 통과했다. 공개 서비스 운영 정책과 배포 검증은 남아 있다.

**퍼즐 조정:** [1칸 조각 빈도와 이전 배경 결정](implementation/Piece_Tray_Refinement_2026-09-25.md). 새 개인 저장의 1칸 조각 가중치를 낮췄다. 기존 저장·이번 주 도전은 종전 설정을 유지하며 다음 UTC 주차의 새 도전은 낮춘 설정을 받는다. 최신 [조각 트레이 복구와 Phase 4 요청 제한](implementation/Phase4_Request_Controls_2026-09-26.md)에서 사용자 가독성 피드백에 따라 어두운 판을 다시 그린다.

**Version 10~14 후속 확인:** [공급·서버 운영 준비 기록](implementation/Version10_Supply_And_Operations_2026-09-25.md)과 [계정 복구·충돌 실기기 기록](implementation/Phase4_Recovery_Conflict_2026-09-25.md). 10종 합성 보드에서 1칸 조각 16.70%→8.73%, QA 실기기에서 대기 조각 배경 제거·주간 제출·복구 코드·무효화된 토큰 재인증·서버 기록 복원·갈라진 기록의 보관과 선택을 확인했다. 최신 고정 GUT 147개/3,777개 단언과 HTTP 17항목이 통과했다. 공개 서버 운영과 다기기 장시간 검증은 남아 있다.

**Version 15 현재 확인:** [요청 제한·트레이 복구의 실기기/HTTP 결과](implementation/Phase4_Controls_Device_Validation_2026-09-26.md). SM-N981N QA 앱에서 어두운 판 복구, 개인 배치·재시작 복원, 임시 주간 도전 배치·제출을 확인했다. 요청 제어 8묶음/42응답, 기존 HTTP 17항목, GUT 147개/3,777단언이 통과했다. 공개 TLS와 여러 기기 검증은 남아 있다.

**Version 16 개발:** [클리어 피드백·Phase 4 DB 복원 경로](implementation/Clear_Feedback_And_Phase4_Restore_2026-09-26.md). Mobbin 화면 구성을 참고하고 Kenney CC0 타격음·별빛을 클리어에 연결했다. 백업 검증 후 새 경로로 복원하는 도구를 추가했다. 실기기 음향과 복원 훈련은 후속이다.

**Phase 4 다음 개발:** [규칙 버전별 검증기 보존](implementation/Phase4_Versioned_Verifier_2026-09-26.md). v1 재생 프로젝트를 고정하고 도전의 규칙 버전으로 제출 검증기를 선택한다. 버전이 누락된 서버는 DB의 기존 도전을 조용히 새 규칙으로 재생하지 않는다.

**Version 16 실기기 확인:** [QA 기기 기록](implementation/Version16_Device_Validation_2026-09-26.md). SM-N981N에서 데이터 보존 업데이트, 실제 2줄 클리어의 빛·별빛·파편과 241점·2층 저장, 고정 v1 재생기의 주간 제출을 확인했다. 기존 QA 저장·계정·도전은 복원했다. 효과음은 녹화에 소리가 없어 실제 청각 평가는 남아 있다.

**Phase 2-G 벽돌 랜드마크 파츠:** [구현 범위와 실행 기록](implementation/Phase2G_Brick_Landmark_Part_Plan_2026-09-25.md). 벽돌 진행도 100줄 또는 누적 300층에서 해금되는 네 번째 파츠를 추가했다. 일반·아치 외벽의 중간 층에 시계 랜드마크를 표시하며 네 파츠가 한 구간에 공존한다. 기록된 고정 검사 133개/3,600개 단언, 저장 재시작 42개, Windows 화면 15종·186개 점검, 큰 글씨 스크롤 3종·231개 점검, 층 접합 8종이 통과했다. 사람 관찰과 최신 Android 검증은 후속이다.

**Phase 2-H 높은 탑 구간 이동:** [구현 범위와 확인](implementation/Phase2H_Tower_Segment_Jump_2026-09-25.md). 탑 화면의 구간 번호 입력으로 원하는 완성·미완성 구간에 바로 이동한다. 저장과 대표 구간은 바뀌지 않는다. 고정 Godot 가져오기에서 파서 오류는 없었고, 입력 체험·GUT·Android 검증은 아직 수행하지 않았다.

**이전 Phase 2-F 벽돌 상단 장식 파츠:** [구현 범위와 Sol 독립 검증](implementation/Phase2F_Brick_Cornice_Part_Plan_2026-09-24.md). 수평 마감·깃발을 유지한 장식 지붕을 추가하고 아치 창문·테라스와 세 파츠 동시 장착을 지원한다. 고정 테스트 130개/3,510개 단언, 저장 재시작 37개, Windows 화면 11종·203개 점검, 새 6방향과 기존 16방향의 층 접합이 통과했다. 사람 관찰과 최신 Android 실기기 검증은 이후에 진행한다.

**이전 Phase 2-E 벽돌 테라스 파츠:** [구현 범위와 Sol 독립 검증](implementation/Phase2E_Brick_Terrace_Part_Plan_2026-09-24.md). 아치 창문과 독립 장착·동시 표시, 기존 v2 저장 복원, 재질 변경 중 숨김/복원을 구현했다. 당시 고정 테스트 127개/3,453개 단언, 저장 재시작 33개, Windows 화면 7종·137개 점검, 새 테라스 4방향과 기존 12방향 층 경계가 통과했다.

**이전 Phase 2-D 첫 벽돌 아치 창문 파츠:** [구현 범위와 Sol 독립 검증](implementation/Phase2D_Brick_Arch_Part_Plan_2026-09-24.md). 구간별 장착·휴면/복원과 v1 저장의 읽기 전용 v2 전환을 구현했다. 당시 고정 테스트 125개/3,419개 단언, 저장 재시작 29개, Windows 화면 8종·147개 점검, 아치↔기본 벽돌 2방향 층 경계가 통과했다.

**이전 Phase 2-C 크리스털 기본 외벽:** [구현 범위와 Sol 검증](implementation/Phase2C_Crystal_Facade_Plan_2026-09-24.md). 기존 해금·저장 계약으로 네 번째 외벽과 이전 크리스털 저장값의 그림 복원을 연결했다. 당시 고정 테스트 119개/3,342 assertions, Sol 별도 Windows 화면 11종·157개 점검, 크리스털↔세 재질 6방향 경계가 통과했다. [Phase 2-B 금속·유리](implementation/Phase2B_Metal_Glass_Facade_Plan_2026-09-24.md)와 [Phase 2-A 목재·벽돌](implementation/Phase2A_Brick_Facade_Plan_2026-09-24.md) 기록도 이전 범위의 증거로 보존한다.

**최신 W6-A 데스크톱 관찰 준비:** [실행·검증 기록](implementation/W6A_Desktop_Playtest_Readiness_2026-09-23.md). 고정 시드와 조건별 독립 저장 폴더로 실제 Windows 게임 화면을 시작하는 도구를 추가했다. Sol 별도 검증에서 같은 시드의 첫 조각·체크포인트와 저장 분리, GUI 수동→AUTO 전환을 확인했고 전체 102개/3,124 assertions가 통과했다. [사람 관찰 기록 카드](implementation/W6_Desktop_First_Play_Observation_Draft_2026-09-23.md)는 준비됐지만 참가자 관찰과 Android 최신 소스 실기기 평가는 아직 진행하지 않았다.

**최신 게임필 개선:** [Block Blast 참고 version7 보고서](implementation/BlockBlast_Feel_Refinement_2026-09-23.md). 손가락 가림·효과음/진동 단계·반복 입력 리듬·클리어 표시 위치를 조정했다. Godot 테스트97개/3,042 assertions와 Windows 실제 렌더 확인을 통과하고 본 앱/QA ARM64 APK를 빌드했다. 실기기가 연결되지 않아 version7 체감·설치는 미검증이다. 아래 version6 실기기 기록은 이전 빌드의 증거다.

**화면 가독성 이력:** [W4-D 검증](implementation/W4D_Readability_Plan_2026-09-23.md)에서 큰 글씨·회색조 정보·안전 영역을 적용하고 고정 테스트99개/3,070 assertions와 Windows 캡처18종을 확인했다. 이 변경은 아직 Android 최신 소스 빌드·실기기 설치 전이다. 후속 [W4-E 복합 보상 안내](implementation/W4E_Event_Clarity_Plan_2026-09-23.md)가 적용됐다.

**최신 W4-E 복합 보상 안내:** [구현·Sol 검증](implementation/W4E_Event_Clarity_Plan_2026-09-23.md)에서 알림을 최대 3개로 묶고 탑의 해금 상세 경로를 추가했다. 전체 테스트102개/3,124 assertions, 최종 Windows 복합 화면8종과 Sol 별도 화면3종·30회 입력 검사가 통과했다. 데스크톱 사람 관찰은 [초안](implementation/W6_Desktop_First_Play_Observation_Draft_2026-09-23.md)만 준비했으며 Android 최신 소스 설치·실기기 검증은 이후 작업이다.

**최신 W5 실기기 통합 검증:** [2026-09-23 보고서](implementation/W5_Device_Combined_Verification_2026-09-23.md). SM-N981N(Android 13)에서 저장 복구44개 통과. 실기기에서 발견한 복구 안내 회색 화면 결함을 수정하고 version6을 설치했다. 수정 후 회귀95개/3,027 assertions·Windows lifecycle 입력22개 통과. 사용자 저장·설정은 유지했다. 기존 설치 보류는 사용자 요청으로 해제했다. 입력·설치·정리62개 확인과20회 전환도 통과했고 QA 앱을 정리한 뒤 본 앱으로 복귀했다. 잔여 성능·체감 범위는 보고서를 따른다.

**9월 21일 W5 입력 구현 기록:** [백그라운드·복귀/연속 입력 안정화](implementation/W5_Lifecycle_Input_2026-09-21.md) 구현. 93개 회귀·Windows 입력37개·프로세스 저장26개 통과. 저장 복구를 포함한 version5 본 앱/QA APK를 준비했다. **사용자 요청으로 설치·실기기 검증은 보류**하며, 보고서의 통합 검증표를 함께 수행한다.

**9월 21일 W5 저장 구현 기록:** [Android 저장 중 종료·복구](implementation/W5_Android_Save_Recovery_2026-09-21.md)를 구현했다. Windows84개·별도 프로세스26개·Android16 에뮬레이터44개 검사 통과. 실기기 USB 연결 중단으로 version4 설치와 동일 복구 매트릭스는 재연결 후 진행한다. 전체 W5는 미완료다.

**현재: 사용자 실기기 지적에 따른 보드 중심 UI·게임필 개선 적용.** 내 탑/설정 상단 이동, 보드 확대, 배치 보정·클리어 연출·버튼/음향을 연결했다. 최신 [개선 보고서](implementation/GameFeel_Improvement_Report_2026-09-21.md)와 [수정 화면](implementation/gamefeel_evidence_2026-09-21/basic_360x800.png)을 따른다. Windows82개 테스트·20상태 검증 통과. [version3 삼성 실기기 후속 검증](implementation/GameFeel_Device_Verification_2026-09-21.md)에서 설치·기본 UI·수동/자동 클리어·저장 복원26개 확인이 통과했다. 소리/진동/손가락 체감과 전체 W5는 미완료다. 에뮬레이터의 셰이더 오류는 실기기에서 재현되지 않았다. 과거 [B안 외형](implementation/Visual_Fidelity_Report_2026-09-21.md)과 [W5 version2 실기기 중간 검증](implementation/W5_Device_Interim_Report_2026-09-21.md)은 역사적 증거로 보존하며 최신 버전 통과로 확대하지 않는다.

선행 작업: v0.2 독립 구현과 [25개 단위 테스트·기존 30만 트레이 검사](implementation/piece_generation/README.md)를 완료했다. 사용자 요청에 따라 Claude 답변을 생략하고 [Codex 자체 기술검토](implementation/piece_generation/Codex_Review_2026-09-21.md)를 완료했다. 생성기는 W2/W3 전체 상태 커밋에 연결했다. B안 상세 외형은 후속 보고서를 따르며, Mobbin MCP·Godot 자료실 [조사 결과](design/Reference_Research_2026-09-21.md)와 디자인 가이드 §11을 따른다. [기존 실행 증거](implementation/W0_W1_Report_2026-09-21.md)는 보존한다.

역할별 상세 규칙은 소유 문서 한 곳에서 변경하고 다른 문서는 링크로 참조한다. 게임 방향 변경은 게임 기획, 기술 결정은 ADR, 구현/관찰 증거는 결과 보고서에 남긴다. 테스트 수용 기준과 실제 통과 기록을 구분한다. 밸런스·실기기·출시는 미검증 범위를 완료로 표시하지 않는다.

- [프로젝트 협업 규칙](../CLAUDE.md), [설계 진입점](../GAME-DESIGN.md), [ADR-0001](adr/0001-godot-baseline-and-contracts.md)
- [사용자 디자인 시안](디자인시안.png): 외형의 우선 기준. [B/C 비교 이미지](Blocktower_BlockSkin_B_vs_C_v0.2.png)는 스킨 비교 이력으로 보존하며 첨부 시안의 외형을 덮어쓰지 않는다.
- `examples/`, `pretests/`: 현재 참조 코드·검사·실행 증거. 문서 정리 과정에서 코드와 JSON을 변경하지 않았다.
- [백업 및 통합 이력](backup/2026-09-20_cleanup/README.md): 원본 29개, 이동 내역·SHA-256 manifest와 복원 위치.
