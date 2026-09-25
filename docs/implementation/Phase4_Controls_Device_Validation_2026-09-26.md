# Phase 4 요청 제어와 트레이 version 15 확인

기준일: 2026-09-26. [구현 기록](Phase4_Request_Controls_2026-09-26.md)의 현재 소스를 로컬 임시 서버와 Samsung SM-N981N(Android 13)에서 확인했다.

## 서버 동작

- 고정 Godot 4.7.2/GUT 9.7.1 회귀 검사: **147개 검사, 3,777개 단언**, 실패·오류·보류 0. 테스트 러너는 기존 객체 잔여 경고 70개를 출력했다.
- 별도 임시 SQLite DB의 기본 서버에서 [기존 HTTP 검사](../../tools/verify_phase4_service.py) **17항목**이 통과했다. 계정 발급·토큰 검증/회전·도전 발급·재생 제출·중복·분기 거절·순위·복구 코드 경로를 포함한다.
- [요청 제어 검사](../../tools/verify_phase4_controls.py)의 **8묶음, HTTP 응답 42개**가 통과했다. liveness/readiness, 누락·형식 오류 프록시 IP 거절, 계정 발급 12회/분과 13번째 429, 별도 IP의 독립 한도, 복구 8회/분, 제출 12회/분, `Retry-After`, 요청 ID 대응과 로그의 토큰/IP/쿼리 미포함을 확인했다. 재생기 슬롯 2개를 점유한 뒤 세 번째 요청의 `VERIFIER_BUSY`를 확인했다. [민감정보가 없는 결과 JSON](version15_evidence_2026-09-26/request_controls.json)을 보존했다.

## 실기기

- QA 패키지 `com.blocktower.game.qa`를 versionCode 14에서 **15**로 데이터 보존 업데이트했다. 본 앱 `com.blocktower.game`은 versionCode 8 그대로다.
- [초기 퍼즐 화면](version15_evidence_2026-09-26/tray.png)에서 세 조각 뒤의 어두운 판과 두 칸 구분선을 확인했다. 조각을 끌어 놓은 [결과](version15_evidence_2026-09-26/after_drag.png)는 4점·보드 4칸이다. 강제 종료 후 [재시작 화면](version15_evidence_2026-09-26/restarted.png)이 결과 화면과 바이트 단위 SHA-256까지 일치해 배치와 점수가 복원됐다.
- 기존 QA 온라인 계정·도전 폴더는 앱의 비공개 폴더 안에서 다른 이름으로 보관하고, `adb reverse`를 통해 새 임시 서버에 별도 임시 계정을 만들었다. [도전 화면](version15_evidence_2026-09-26/challenge.png)에서도 판이 보였고, [조각 배치](version15_evidence_2026-09-26/challenge_move.png) 후 3점을 확인했다. [서버 제출 화면](version15_evidence_2026-09-26/submit_result.png)에 `제출 완료`와 검증된 순위 2명이 표시됐다. 완성된 줄이 없어 검증 층수는 0층이다.
- 검증 후 기존 QA 계정·도전 파일을 원래 이름으로 복원했다. 시험 계정·도전 파일은 별도 이름으로 비공개 폴더에 보관돼 앱에서 사용하지 않는다. 재실행한 개인 화면은 앞선 4점 화면과 SHA-256이 같았다. 임시 서버를 중지하고 `adb reverse`를 해제했다.

## 남은 범위

이번 실기기 확인은 한 기기, USB 경유 loopback 서버, 한 번의 개인·주간 배치와 제출이다. TLS 공개 호스팅, 실제 여러 기기, 주차 경계, 장시간 부하와 사람의 가독성 평가를 확인한 결과로 확대하지 않는다. 429와 503의 서버 응답은 확인했지만 앱 화면에서 해당 오류 안내를 실제로 띄우지는 않았다.
