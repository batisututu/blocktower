# W6-A 데스크톱 첫 플레이 준비

기준일: 2026-09-23. 이 문서는 W4-E 이후의 개발 범위와 검증 기준이다. 실제 사람 관찰 결과는 별도로 기록한다. Android 최신 빌드 설치와 실기기 검증은 사용자 지시에 따라 이후에 진행한다.

## 이번 개발

Windows에서 실제 퍼즐 화면을 독립된 저장 폴더와 지정 시드로 시작하는 관찰용 실행 경로를 만든다. 수동/AUTO 조건은 같은 UI를 사용하며, AUTO 조건은 기존 자동 클리어 설정을 켠 상태에서 시작한다. 실행 경로는 기존 `SavedGame`/`GameSession`의 저장과 규칙을 사용하고, 기본 `user://save_v1`을 건드리지 않는다. 기존 폴더의 덮어쓰기와 재개는 모두 거부한다. 매 관찰 조건에 새 폴더를 지정한다.

실행 시 시드, 규칙/공급 버전, 빌드 식별자, 저장 위치만 로컬에 남긴다. 참가자의 이름, 발화, 입력 내역, 개인 식별 정보는 자동 수집하지 않는다. 관찰자는 [첫 플레이 관찰 초안](W6_Desktop_First_Play_Observation_Draft_2026-09-23.md)의 행동·혼동·피로 양식에 직접 기록한다.

## 비교 해석

같은 시드와 공급 정책으로 새 판을 시작하면 **첫 조각 묶음**을 재현할 수 있다. 이후 공급은 보드 상태를 참조하므로 수동/AUTO의 행동·제거 시점이 달라지면 같은 시드여도 조각열이 달라질 수 있다. 따라서 이 도구의 두 세션은 동일한 시작 조건 비교이며, 전 과정의 동일 조각열 실험이라고 표시하지 않는다. 같은 조각열이 필요한 별도 수치 실험은 고정 공급열과 유효 상태 전이 검사를 갖춘 별도 설계가 필요하다.

## 실행 방법

PowerShell에서 저장 폴더를 조건마다 새 이름으로 지정한다. 경로는 `tools/out/desktop_playtests` 아래의 절대 경로여야 한다. 이미 있는 폴더는 거부되며 자동 삭제나 재개 기능은 없다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start_desktop_playtest.ps1 -Seed 20260923 -SaveDirectory C:\DEV\Games\Blocktower\tools\out\desktop_playtests\manual_20260923
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start_desktop_playtest.ps1 -Seed 20260923 -Condition Auto -SaveDirectory C:\DEV\Games\Blocktower\tools\out\desktop_playtests\auto_20260923
```

관찰 전 상태 비교는 새 폴더에 `-Probe`를 붙여 실행한다. 실행 도구는 Godot 실행 파일의 고정 버전과 해시를 확인한다. `build_id`는 나열된 주요 실행 소스 파일의 로컬 SHA-256 목록 해시이며, 전체 게임 에셋이나 배포 빌드의 해시는 아니다.

## 검증 기준

1. 두 독립 폴더에 같은 시드로 새 세션을 만들면 초기 `queue`와 RNG checkpoint가 같다. 다른 폴더의 저장 진행은 서로 영향을 주지 않는다.
2. 기존 저장 폴더를 실수로 새 세션에 재사용하면 안전하게 거부하고, 기존 파일은 바뀌지 않는다.
3. Windows 실제 `AppRoot` 화면으로 진입하고 수동 클리어/AUTO/탑 흐름이 기존 입력 경로를 따른다. 고정 Godot 4.7.2/GUT 9.7.1 전체 검사에서 파서 오류, 실패, 미완료가 없다.
4. 기록물은 로컬에만 남고 개인 정보나 게임 내 자동 계측을 새로 넣지 않는다. 이번 검증으로 사람의 규칙 이해, 반복 피로, 재미, 모바일 체감을 통과 판정하지 않는다.

## 구현·검증 결과

Luna가 [Windows 실행 도구](../../tools/start_desktop_playtest.ps1)와 [Godot 실행기](../../game/tests/integration/desktop_playtest_launcher.gd)를 구현했다. 기존 `SavedGame.boot`로 새 폴더를 먼저 만들고 실제 `AppRoot`를 그 폴더에 연결한다. GUI 경로는 고정 콘솔 엔진으로 버전을 검증하고, 창 실행 파일도 고정 해시와 대조한다. 저장 폴더는 `tools/out/desktop_playtests` 아래로 제한하고 기존 경로와 Windows 연결 폴더를 거부한다. 별도 사용자 계측이나 게임 규칙 변경은 없다.

Luna의 [로컬 검사 기록](../../tools/out/w6a_desktop_playtest/report.json)과 [GUI 수정 기록](../../tools/out/w6a_desktop_playtest/gui_fix_report.json)에 따르면 수동/AUTO 각각의 시작 화면 연결, 같은 시드의 첫 조각·체크포인트 일치, 서로 분리된 저장 상태, 기존 폴더 재사용 거부, 공백 경로와 최소 int64 시드, GUI의 `UI_READY` 기록이 통과했다. 처음 GUI 실행에서 창 실행 파일의 비동기 `--version` 때문에 `$LASTEXITCODE`가 없어 중단되는 결함을 Sol 검토에서 발견해 수정했다. 새 작업 공간에 허용 폴더가 아직 없는 경우와 연결 폴더 우회도 후속으로 보완했다.

Sol은 수정 뒤 별도 시드 `20260925`와 새 폴더에서 `-Probe`를 다시 실행해 첫 조각·체크포인트 일치, 수동/AUTO 저장 분리, 실제 `AppRoot` 연결을 확인했다. 실제 Windows 창에서도 수동 화면이 나타나고 버튼 입력 뒤 `자동 ON`으로 바뀌는 것을 확인했다. AUTO 조건으로 별도 시작한 창도 `자동 ON`으로 열리고 20초 이상 유지됐다. 화면은 [수동 시작](../../tools/out/w6a_desktop_playtest/sol_gui_manual.png), [전환 뒤](../../tools/out/w6a_desktop_playtest/sol_gui_auto.png), [AUTO 시작](../../tools/out/w6a_desktop_playtest/sol_gui_auto_initial.png)에 보관했다. 공백이 있는 저장 경로로 GUI를 다시 열었을 때도 `UI_READY`와 메타데이터 파일이 생성됐다. 독립 재실행한 고정 Godot 4.7.2/GUT 9.7.1 전체 검사는 102개 테스트·3,124개 단언, 실패·오류·미완료 0개였다. 최종 PowerShell 경로 수정은 Godot 파일을 변경하지 않았고, 마지막 `-Probe`도 통과했다.

이번 결과는 관찰 **준비**의 완료다. 실제 사람의 첫 플레이 이해·피로·재방문 판단과 Android 최신 빌드 설치·실기기 평가는 수행하지 않았다.

## 다음 관찰의 선행 결정

첫 사람 관찰 전에 D01 참가자 조건과 짧은 세션 길이, D04 10/30층 도달 측정 및 중단 정의, D12 기록 동의·보관 기간·전송 여부를 정한다. 모드 순서는 참가자 사이에서 교차하고, 동일한 공급 정책과 시작 시드를 기록한다. 30층은 여러 판에 걸친 누적 목표로 다룬다. 관찰 뒤 반복되는 혼동과 피로 근거를 모아 HUD·효과·밸런스 수정 순서를 정한다.
