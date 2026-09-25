# Blocktower 기획 문서 안내

기준일: 2026-09-20. 아래 개정본을 현재 작업 기준으로 사용한다.
기존 방향을 유지하면서 레드팀 검토로 모호한 규칙과 누락을 보완했다. 밸런스 수치·실기기 성능·상품 출시는 검증 전이다.

| 문서 | 역할 |
|---|---|
| [개발 착수 준비도·첫 구현 계획 v0.2](Blocktower_Predevelopment_Readiness_v0.2.md) | 현재 착수 판단, 코드/사람 플레이 관문 분리, 첫 작업 W1~W6, 저장·입력 수용 기준과 최소 에셋 |
| [개발 전 사전 테스트 결과](Blocktower_Preflight_Test_Report_2026-09-20.md) | Godot 4.7.2/GUT 9.7.1 실행, 배치 정답 대조·분포·별도 프로세스 복원 결과와 미검증 범위 |
| [조각 공급 조사·적용 코드 v0.1](Blocktower_Piece_Supply_Research_v0.1.md) | GitHub/Reddit 비교, 19종·계열 가중 실험안, 자체 GDScript 예제와 검사 결과. 제품 밸런스·4.7.2 통합은 미확정 |
| [Godot 기술 리서치 2026 — 개정 v0.2](Blocktower_Godot_Tech_Research_2026.md) | 공식 자료 최신성, 엔진·애드온 버전, 상태/저장 계약, 최소 스택·에셋, 테스트·배포와 A–Z 적용 순서 |
| [Claude Code 기술 검토 원문](Blocktower_Claude_Tech_Review_2026-09-20.md) | 기술조사에 대한 독립 검토. 최종 조정 사항은 기술 리서치 v0.2 §21을 따름 |
| [최초 준비도 조사 v0.1](Blocktower_Predevelopment_Readiness_v0.1.md) | 조사 당시 환경과 상세 에셋 납품 규격. 현재 착수 순서·완료 여부는 v0.2를 따름 |
| [상위기획 v0.4](Blocktower_Upper_Game_Design_v0.4.md) | 공통 규칙, 점수/성장 저장, 개발 단계, 첫 30층 검증, 온라인 선행 결정 |
| [성장기획 v0.3](Blocktower_Growth_System_Plan_v0.3.md) | 재질/파츠 이중 해금, 누적 집계, 10층 구간 경계 사례 |
| [스킨 결정문 v0.3](Blocktower_Visual_Bible_BlockSkin_Decision_v0.3.md) | B 무료/C 유료 방향, 시안 결함, 상태별 시각 규칙, 후속 시안·구매 검증 |
| [레드팀 검토·결정 기록](Blocktower_Redteam_Review_2026-09-20.md) | 지적 근거, 반영 위치, Claude Code 협의 결과, 미결정 과제 |
| [Claude Code 검토 원문](Blocktower_Claude_Review_2026-09-20.md) | 별도 세션의 독립 검토 의견. 최종 결정은 위 개정본/결정 기록을 따름 |

공통 규칙과 Phase 번호는 상위기획을 따른다. 성장 상세와 시각 상세는 각각의 최신 문서를 따른다.
기술 적용은 Godot 기술 리서치 개정본을 따른다. [사용자 기술조사 원안](archive/Blocktower_Godot_Tech_Research_2026_original_2026-09-20.md)은 변경 이력으로 보존했다.
다음 구현은 준비도 v0.2의 W1(저장소·엔진 경로·최소 프로젝트·테스트 명령)부터 시작한다. 사전 테스트 통과는 실제 게임 통합이나 모바일 플레이 검증 완료를 뜻하지 않는다.
검토 의견은 검증 증거와 구분한다. 제안이나 수치 가안은 사용자 승인·사용성 검증 완료를 뜻하지 않는다.

협업·구조 규칙은 [CLAUDE.md](../CLAUDE.md), 설계 진입점은 [GAME-DESIGN.md](../GAME-DESIGN.md), 엔진과 GDScript 계약 매핑 결정은 [ADR-0001](adr/0001-godot-baseline-and-contracts.md)에 정리했다. 이번 착수 협의는 준비도 v0.2 §8을 참조한다.

이전 상위기획 v0.3, 성장기획 v0.2, 스킨 결정문 v0.2와 [원본 B/C 비교 이미지](Blocktower_BlockSkin_B_vs_C_v0.2.png)는 변경 이력으로 보존한다.
이미지는 콘셉트 비교 자료다. 보드 하단의 문구 겹침과 실제 모바일 HUD 부재는 스킨 v0.3에 수정 요구사항으로 기록했다.
기존 문서에서 언급한 상위기획 v0.1/v0.2 및 전체 Visual Bible v0.1은 현재 폴더에서 확인되지 않았다.
