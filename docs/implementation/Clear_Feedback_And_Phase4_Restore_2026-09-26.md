# 클리어 피드백 강화와 Phase 4 DB 복원 경로

기준일: 2026-09-26. 이번 변경의 클리어 연출은 확정된 `CLEARED` 사건만 사용하며 점수·공급·저장 형식은 바꾸지 않는다. Android versionCode 16으로 내보낼 준비를 한다.

## 에셋 조사와 적용

Mobbin의 [Brilliant 완료 화면](https://mobbin.com/screens/3c3cb198-8f28-4ed3-84e0-d9607f4da700)은 큰 보상 수치 주위의 소수 별빛, [Quizlet 퍼즐 화면](https://mobbin.com/screens/ceac50c6-02e5-48f8-b57c-1bab0880746b)은 보드와 점수를 가리지 않는 구성을 참고했다. 두 화면은 블록 줄 제거 애니메이션의 직접 사례가 아니며 이미지·음향 파일을 복제하지 않았다.

실제 사용 파일은 Kenney의 [Impact Sounds](https://kenney.nl/assets/impact-sounds)와 [Particle Pack](https://kenney.nl/assets/particle-pack)에서 내려받았다. 두 팩의 동봉 `LICENSE.txt`는 CC0로 개인·상업 사용을 허용한다. 2026-09-26에 공식 배포 ZIP에서 아래 두 파일만 추출했다.

| 파일 | 원본 경로 | SHA-256 | 적용 |
|---|---|---|---|
| `game/assets/audio/kenney/impactWood_heavy_000.ogg` | `Audio/impactWood_heavy_000.ogg` | `15ff82332f342c30e469215539e1cc57e11b221aa2cf7e11e811d313a9927f3d` | 확정 클리어 타격음. 원본 최고 레벨 약 -0.9dBFS, 재생 레이어 -6dB + 사용자 볼륨 |
| `game/assets/effects/kenney/star_02.png` | `PNG (Transparent)/star_02.png` | `a0b7624a2e6f6825a3e93ddec685728c4d3de03b77bbf2a2e425b7a6d3d0215b` | 지워지는 셀 안에서만 최대 12개 금색 별빛 |

각 디렉터리에 동봉 `LICENSE.txt`를 보존한다. 기존 합성 클리어음·공기음·2줄 이상 차임을 함께 재생하되 기존 스냅 레이어는 빼고 최대 6개 재생기를 유지한다. 420ms 클리어 중 셀 윤곽과 줄 스윕의 밝기를 높인다. 파편은 최대 36개, 별빛은 최대 12개다. 입력은 기존 280ms에 열리며 감소 모션에서는 움직이는 효과를 생략한다. 전체 화면 섬광·카메라 흔들림은 없다.

## Phase 4 백업 복원

`tools/restore_phase4_db.py`는 기존 백업을 새 경로의 SQLite DB로 복원한다. 원본 백업과 현재 서버 DB를 덮어쓰지 않는다. 원본과 임시 복원본에 `integrity_check`, 필수 표·열, `foreign_key_check`를 적용하고 계정·도전·제출 행 수가 동일한지 확인한다. 검증 후 같은 디렉터리에서 새 파일 이름을 원자적으로 게시한다. 출력에는 행 수와 경로만 쓰며 토큰·행 내용은 쓰지 않는다.

운영 전 복원 절차:

1. `python tools/backup_phase4_db.py --source C:/private/phase4.sqlite3 --output C:/private/backups/phase4-YYYYMMDD.sqlite3`로 스냅샷을 만든다.
2. 서버를 중단한다. 새 경로를 정해 `python tools/restore_phase4_db.py --source C:/private/backups/phase4-YYYYMMDD.sqlite3 --output C:/private/phase4-restored.sqlite3`를 실행한다.
3. 종료된 서버의 `--db`를 새 파일로 지정해 기동하고 `/health/ready` 및 계정·도전·순위 읽기를 확인한다. 기존 DB와 백업은 원인을 파악할 때까지 보존한다.

새 경로 게시에는 같은 파일시스템 안의 하드 링크를 사용한다. 이를 지원하지 않는 저장소라면 작업이 실패하며 기존 파일은 그대로 남는다. 서버 실행 중 원본 DB 파일을 교체하지 않는다. 백업과 복원 파일은 토큰 해시와 게임 행동을 담으므로 저장소 밖의 접근 제한된 위치에 둔다.

## 확인 범위와 다음 순서

이번 작업에서는 코드·에셋·계약을 작성했다. 새 Android APK 설치, 실제 기기 음향 체감, DB 복원 훈련과 서버 기동은 아직 수행하지 않았다. 다음 순서는 별도 QA 앱의 versionCode 16 기기 체감, 비공개 DB 복원 훈련, 공개 TLS 환경 결정, 규칙 버전별 재생기 보존, 다기기·UTC 주차 경계 검증이다.
