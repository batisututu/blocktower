# W5 저장 복구 실행 증거

- 최종 결과: `emulator-5760/run.json`, `checks.json` (44개), `verified_run_logcat.txt`.
- 해당 `run_id`가 포함된 report/marker JSON만 최종 실행 증거다. 이전 ID의 JSON과 원본 logcat은 브리지 overload/errno 접근을 수정한 과정의 기록이며 통과 증거에 섞지 않는다.
- `windows_unit.log/xml`: 84개 / 2,867 assertions. `windows_restart.json/log`: 26개 별도 프로세스 검사.
- `production_source_hashes.json`: QA에 복사한 production 소스 해시. `production_apk.json`: ARM64 version4 APK 해시, 테스트 hooks 제외 및 두 APK의 핵심 컴파일 리소스 일치 확인.
- Android16 x86_64 에뮬레이터의 기존 SceneShaderGLES3 uniform 오류는 저장 검사와 구분한다. 최종 실행 SCRIPT/Parse 오류는 0개다. 화면·성능 또는 SM-N981N 복구 통과 증거가 아니다.
- 실기기는 초기 QA 설치 후 USB가 끊겨 검증하지 못했다. 사용자 본 앱 데이터는 건드리지 않았다. 실기기의 초기 QA 앱은 재연결 후 정리한다.
