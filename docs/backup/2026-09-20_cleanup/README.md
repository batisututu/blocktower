# 2026-09-20 문서 백업·통합 기록

사용자 요청에 따라 과거 버전·반영 완료 검토를 현재 docs에서 이동하고 중복 내용을 주제별 현재 문서로 통합했다. 이 폴더는 역사적 원본이며 현재 작업 기준은 [docs/README](../../README.md)다.

## 보존과 복원

- `original/docs/`: 정리 직전 파일 29개를 원래 상대 경로로 보존했다. 8개는 이동, 나머지는 통합 전 복사본이다.
- `original/CLAUDE.md`, `original/GAME-DESIGN.md`: 링크와 착수 순서를 갱신하기 전 루트 문서도 보존했다.
- [manifest.json](manifest.json): 원래 docs 상대 경로·SHA-256·이동/복사 구분. 모든 29개 원본의 해시를 대조했다.
- 원본 내용·내부 링크는 수정하지 않았다. `original/`을 프로젝트 루트로 보면 이전 상대 경로 구조를 유지한다.
- 복원할 때 `original/docs/<경로>`를 별도 작업 폴더에 복사해 비교한다. 현재 문서를 무조건 덮어쓰지 않는다.
- 현재 `examples/`, `pretests/`, 비교 PNG는 원본과 해시가 같고 위치도 유지했다. 사전 테스트 보고서는 결과를 보존하고 현행 문서 링크만 갱신했다.

## 현재 목록에서 이동한 문서

| 원본 | 이동 이유 |
|---|---|
| [Blocktower_Claude_Review_2026-09-20.md](original/docs/Blocktower_Claude_Review_2026-09-20.md) | 이전 버전 또는 본문에 반영된 검토 이력 |
| [Blocktower_Claude_Tech_Review_2026-09-20.md](original/docs/Blocktower_Claude_Tech_Review_2026-09-20.md) | 이전 버전 또는 본문에 반영된 검토 이력 |
| [Blocktower_Growth_System_Plan_v0.2.md](original/docs/Blocktower_Growth_System_Plan_v0.2.md) | 이전 버전 또는 본문에 반영된 검토 이력 |
| [Blocktower_Predevelopment_Readiness_v0.1.md](original/docs/Blocktower_Predevelopment_Readiness_v0.1.md) | 이전 버전 또는 본문에 반영된 검토 이력 |
| [Blocktower_Redteam_Review_2026-09-20.md](original/docs/Blocktower_Redteam_Review_2026-09-20.md) | 이전 버전 또는 본문에 반영된 검토 이력 |
| [Blocktower_Upper_Game_Design_v0.3.md](original/docs/Blocktower_Upper_Game_Design_v0.3.md) | 이전 버전 또는 본문에 반영된 검토 이력 |
| [Blocktower_Visual_Bible_BlockSkin_Decision_v0.2.md](original/docs/Blocktower_Visual_Bible_BlockSkin_Decision_v0.2.md) | 이전 버전 또는 본문에 반영된 검토 이력 |
| [archive/Blocktower_Godot_Tech_Research_2026_original_2026-09-20.md](original/docs/archive/Blocktower_Godot_Tech_Research_2026_original_2026-09-20.md) | 이전 버전 또는 본문에 반영된 검토 이력 |

## 통합 위치

| 원래 중복 영역 | 현재 단일 관리 위치 |
|---|---|
| 상위기획의 퍼즐·경쟁·Phase·용어 | [게임 기획](../../Blocktower_Game_Design.md) |
| 상위/성장기획의 높이·재질·파츠·스트릭·구간·편집 | [성장 기획](../../Blocktower_Growth_Design.md) |
| 스킨 결정 + 준비도 A01~A09/납품 규격 + 상위 시각 방향 | [디자인 에셋 가이드](../../Blocktower_Design_Asset_Guide.md) |
| 준비도 v0.1/v0.2 + D01~D14 + 기술 A~Z의 작업 순서 | [개발 계획](../../Blocktower_Development_Plan.md) W0~W6/후속 단계 |
| 준비도 P01~P10 + 기술 R/S/D + 초기 생성/새 판 계약 | [기술 리서치](../../Blocktower_Godot_Tech_Research_2026.md) §7/§15 |
| 공급 조사·현재 알고리즘·API·비교 조건 | [조각 공급 명세](../../Blocktower_Piece_Supply_Spec.md) |
| 여러 문서에서 반복한 통과 수치·명령·증거 | [사전 테스트 보고서](../../Blocktower_Preflight_Test_Report_2026-09-20.md) |

기술 A~Z의 후속 아트·온라인·출시·운영 범위는 개발 계획의 최소 루프 이후 표와 각 소유 문서에 유지했다. 과거 제안/기각의 상세 원문은 이 백업에만 둔다. 에셋을 개발 뒤로 미루는 이전 표현은 사용자의 후속 설명에 맞춰 디자인 규격 선행·첫 세트 제작과 코드 병행으로 갱신했다.
