# Version 16 실기기 확인

기준일: 2026-09-26. Samsung SM-N981N(Android 13, 1080×2400)에 QA 앱 `com.blocktower.game.qa`를 versionCode 15에서 **16**으로 데이터 보존 업데이트했다. 본 앱 `com.blocktower.game`은 versionCode 8 그대로다. QA APK SHA-256은 `3394478fe9cdac684a05066667d2a2103cf4ad61f02cb2eb2ee50c4d4a326716`이다.

## 개인 퍼즐·클리어 연출

- 설치 전후 QA 저장 두 슬롯의 SHA-256이 각각 같았다. [설치 직후 화면](version16_evidence_2026-09-26/qa_after_install.png)에서 기존 4점·조각 받침판을 확인했다.
- 기존 QA 저장을 별도 이름으로 보관한 뒤 [교차 줄 통제 저장](gamefeel_device_evidence_2026-09-21/qa/controlled_fixture.json)을 QA 앱에만 넣었다. 실제 Android 터치 `swipe 180 1833 729 1191 900`으로 중앙 한 칸을 채워 [2줄 대기 화면](version16_evidence_2026-09-26/pending_clear.png)을 얻었다.
- `tap 360 2200`으로 제거했다. 저장된 최신 상태는 revision 2, **241점·2층**이다. 배치 +1점과 2줄 제거 +240점이 한 번만 기록됐다.
- [기기 녹화](version16_evidence_2026-09-26/clear_motion.mp4)의 [밝은 줄 스윕](version16_evidence_2026-09-26/clear_flash.png)과 [별빛·파편](version16_evidence_2026-09-26/clear_shards.png)을 직접 확인했다. 보드 밖 전체 화면 섬광은 없고, 정리 후 다음 입력이 가능한 화면으로 돌아왔다.
- APK에는 `impactWood_heavy_000.ogg`와 `star_02.png`의 가져온 리소스가 포함돼 있다. Android `screenrecord`는 오디오를 담지 않으며 이번 연결 환경에는 재생음 캡처 수단이 없어 **실제 음량·강렬함을 청각적으로 확인하지 못했다**. 기기 미디어 볼륨은 7이었고 [Godot 로그](version16_evidence_2026-09-26/godot_logcat.txt) 49줄에서 `SCRIPT ERROR`/`ERROR:`/`FATAL`은 없었다. 이는 효과음 청취 통과 판정이 아니다.

## 주간 도전·고정 재생기

QA 기존 계정·도전 파일을 별도 이름으로 보관하고, 임시 로컬 서버에 `adb reverse tcp:8765 tcp:8765`로 접속했다. 새 임시 계정에서 실제 화면으로 도전을 시작해 조각 한 개를 놓고 [제출 완료 화면](version16_evidence_2026-09-26/weekly_submitted.png)을 확인했다. 서버는 `bt_rules_v1` 고정 프로젝트로 행동 1개를 재생해 HTTP 200으로 받았고, DB에는 `rule_version=bt_rules_v1`, `supply_profile=classic`, 검증 층수 0이 남았다. 이번 도전은 줄을 제거하지 않아 0층이 정상이다.

## 종료 상태와 한계

시험 후 QA 개인 저장·기존 계정·기존 도전의 **9개 파일이 시험 전 백업과 모두 일치**했다. QA 재실행 화면의 SHA-256도 설치 직후 화면과 같은 `5d69b06cdd86ca873371774184a1d642413bf11eca545bcf3dd7bb1dec117a36`이다. 시험 계정·도전은 QA 비공개 폴더의 `_v16_verify` 이름으로 분리했다. 임시 서버는 중지하고 `adb reverse`, 기기의 임시 fixture·녹화 파일을 제거했다. 토큰·원시 DB·QA 백업은 저장소에 올리지 않는다.

이번 결과는 **한 기기의 QA 앱과 USB 경유 로컬 서버** 범위다. 사람이 기기에서 효과음을 듣고 음량 균형을 평가하는 작업, 공개 TLS, 여러 기기, 주차 경계, 오래된/새 규칙 동시 운영의 정상·예외 경로는 남아 있다.
