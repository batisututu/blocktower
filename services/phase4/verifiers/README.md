# Phase 4 고정 재생기

`bt_rules_v1/`은 2026-09-26의 v1 검증 규칙·조각 카탈로그·두 공급 설정을 복사한 작은 Godot 프로젝트다. 파일 목록과 SHA-256은 `manifest.json`에 고정했다. 서버 기본 실행은 이 프로젝트를 사용한다. 진행 중인 도전이 있는 동안 수정하거나 삭제하지 않는다.

새 규칙을 배포할 때는 **규칙 변경 전에** `tools/freeze_phase4_verifier.py`로 새로운 버전 디렉터리를 만들고, 서버의 `CURRENT_RULE_VERSION`을 새 버전으로 바꾼다. 기존 버전 디렉터리는 그대로 둔다. 새 버전의 GameSession을 실행하는 앱이 배포될 때까지 새 규칙 도전을 발급하지 않는다.

기본 버전 외의 재생기는 서버 실행 시 `--verifier-registry` JSON에 등록한다. 예를 들어 새 v2 서버가 이전 v1 도전을 계속 받는 경우:

```json
{
  "bt_rules_v1": {
    "engine": "C:/private/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe",
    "project": "C:/private/verifiers/bt_rules_v1"
  }
}
```

실행 파일과 프로젝트 경로는 절대 경로나 JSON 파일 위치 기준 상대 경로다. 서버는 등록된 프로젝트의 파일 해시와 DB 도전의 모든 규칙 버전을 기동 시 확인한다. 기존 버전이 누락되면 기동하지 않는다. 검증기는 파일이 바뀐 경우 제출을 거절한다. 엔진 실행 파일도 배포 환경에서 해당 버전과 함께 보존해야 한다.
