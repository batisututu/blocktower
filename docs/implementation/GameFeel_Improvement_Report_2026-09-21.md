# 보드 중심 UI·조작감 개선 기록

> 후속: 기기 재연결 후 version3 설치·단일 기기26개 검증이 통과했다. 최신 [실기기 보고서](GameFeel_Device_Verification_2026-09-21.md)를 참고한다. 아래 미연결/에뮬레이터 실패는 당시 작업 기록이다.

2026-09-21. 사용자가 실기기 화면의 좁은 보드, 좌우 메뉴와 배치·클리어·버튼 품질을 지적한 후 적용한 변경이다. B안 구조 타일·따뜻한 건축 배경을 유지하면서 사용자 지시로 화면 구성을 교체했다. 이전 외형 검토 통과는 이번 품질 승인으로 사용하지 않는다.

## 적용 내용

| 영역 | 실제 구현 |
|---|---|
| 보드 | 8×8 유지. 논리 너비 360에서 248→336(+35.5%), 화면의 93.3%. 좌우 12px. 320/412에서는 296/388px |
| 메뉴·위계 | 내 탑·설정을 최상단으로 이동. 점수/최고/모드는 그 아래, 보드 좌우에는 버튼 없음. 메뉴/모드/클리어 터치 영역 높이 48px 이상 |
| 대기 조각 | 보드 바로 아래 같은 단위 크기로 표시. 현재 세 조각의 최대 가로·세로에 맞춰 크기 산정. 일반 트레이 104px, 작은 화면은 안전 영역에 맞춰 48~64px |
| 배치 | 손가락 위 1.4칸 위치로 즉시 추적. 3×3 인근 후보에서 합법 위치를 0.70칸 이내 획득, 기존 후보는 0.90칸까지 유지. 원래 검증기로 재검증 후 같은 위치 저장 |
| 미리보기 | 실제 소재의 반투명 조각, 겹침 X, 완성 예정 가로·세로 줄 윤곽. 보드 밖 중심에서는 보정하지 않음 |
| 배치 확정 | 140ms 축소→확대→정착과 짧은 소리. 배치 보상은 보드 밖 힌트 줄에 표시. 새 조각을 잡으면 이전 보상 문구를 지우고 유효/무효 안내를 즉시 복원 |
| 클리어 | 총 420ms: 80ms 이내 예고, 45~230ms 축 방향 빛 이동, 120ms 이후 순차 축소·소멸, 130ms 이후 최대 36개 파편. 입력은 280ms에 해제 |
| 보상 | 정수 점수·층수는 저장 성공 직후 정확하게 갱신. 연출 꼬리가 저장/보상을 재실행하지 않음. 새 최고는 한 런에서 첫 갱신 한 번만 표시, 구간/해금/연속 완성은 하단 요약 |
| 버튼 | 활성 버튼 누름 65ms/배율0.955, 놓기 120ms 복원. 레이아웃/터치 사각형은 고정. 움직임 줄이기에서는 색 변화만 적용 |
| 음향·접근성 | 자체 합성한 button/snap/clear/air/chime 5종. clear에 공기층, 2줄 이상에 지연 화음 추가. 기존 음소거·음량·진동 선택 유지. 감소 모드에서도 같은 규칙·점수·저장 결과 |

`game/scripts/presentation/feedback_tokens.gd`가 실행 시간·보정 반경을 소유한다. 입력 보정은 보드나 조각 공급 RNG를 바꾸지 않는다. 자동 회전/이동, 구제 조각이나 무한 생존 보장을 추가하지 않았다.

## 조사 자료의 적용 판단

사용자 [UX/GameFeel 조사 문서](../Blocktower_UX_GameFeel_Improvement_Research_v0.1.md)를 구현 출발점으로 사용했다. 커뮤니티의 임계값·시간은 실험 제안이며 Block Blast 내부 구현의 확인된 사실로 간주하지 않는다.

| 확인한 원문 | 적용 판단 |
|---|---|
| [Kenney Starter Kit Match 3](https://github.com/KenneyNL/Starter-Kit-Match-3) | 리포지터리의 Godot 4.6 기준, 애니메이션/음향/파티클 구조 및 코드 MIT·에셋 CC0 구분 확인. 이 프로젝트 4.7.2에 예제를 그대로 가져오지 않고 피드백 계층만 참조 |
| [Juicee](https://github.com/Kelpekk/Juicee) | 효과 묶음을 조합하는 접근을 참조. 새 애드온 의존성 없이 Godot Tween·CanvasItem·AudioStreamPlayer로 구현 |
| [Block Blast clone](https://github.com/MrCerise/block-blast) | 배치/보드 상호작용 비교용. 경쟁 앱 코드·이미지·음향을 복제하거나 반입하지 않음 |
| [Godot Input](https://docs.godotengine.org/en/stable/classes/class_input.html) | 터치/마우스 입력 구분 및 진동 API 참고. 실제 기기 체감은 문서만으로 판정하지 않음 |

Reddit 경험담의 투표 수·날짜·효과 크기를 별도 재현한 것은 아니다. 외부 코드/패키지 반입이 없으므로 라이선스 호환성을 추정해 채택하지 않았다. 소리 원본·생성 파라미터·해시는 `art_source/gamefeel/build_audio.py`와 `game/assets/audio/gamefeel/manifest.json`에 보존했다.

## 검증과 범위

Windows 네이티브 **82개 테스트·2,843개 단언**, **20개 화면/입력 시나리오**가 통과했다. [테스트 원본](gamefeel_evidence_2026-09-21/tests_final.log), [구조화 결과](gamefeel_evidence_2026-09-21/last_test_run.json), [화면 검사 요약](gamefeel_evidence_2026-09-21/summary.json), [최신 화면](gamefeel_evidence_2026-09-21/basic_360x800.png)을 보존했다. Android 실제 기기 결과와 구분한다.

- 기본 320×568 / 360×800 / 412×915, 유효/무효 드롭, 실제 입력 확정, 교차·최대16줄, 설정/확인창, 큰 점수, 버튼 눌림, 예고/빛 이동/소멸, 13층 탑을 검사한다.
- 모션 시퀀스는 실제 Tween을 실행하고 0/60/140/220/300/460ms 목표에 프레임을 읽는다. PNG 압축은 연출 종료 후 수행한다. 실제 수집 시각은 timeline JSON에 기록하며 실기기 FPS/지연 증거가 아니다.
- 동기 저장 완료 후에만 피드백을 시작한다. 카탈로그 29종의 경계 보정 프리뷰/저장 위치 일치, 프리뷰 무변경, 조기 입력 해제와 중단 시 보상 불변을 검사한다.

## Android 전달 상태와 미검증

ARM64 설치용 APK: `game/export/blocktower-device-debug.apk`, 패키지 `com.blocktower.game`, versionCode3 / `0.1.0-gamefeel3`. 삼성 SM-N981N이 현재 ADB에 없어 이번 변경을 실기기에 설치·검증하지 못했다. 이전 W5 보고서의 version2 검증을 version3 결과로 확장하지 않는다.

추가로 독립 검토 수정 전의 중간 빌드를 1080×2400 x86_64 에뮬레이터에 별도 `com.blocktower.game.qa` APK를 설치·실행했다. 설치는 성공했으나 현재 SwiftShader GLES3 환경에서 SceneShader/CanvasShader 링크가 `Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`로 실패하여 회색 화면만 나온다. 이 결과는 **검증 실패/환경 진단**이며 UI 통과가 아니다. 물리 기기용 렌더러 설정을 에뮬레이터에 맞춰 임의 변경하지 않았다.

다음 확인은 삼성 실기기에서 version3 덮어쓰기 설치 후 연속 배치/교차 클리어/모든 버튼/뒤로가기/재실행, 소리·진동·손가락 가림·프레임 지연을 확인하는 것이다. 원래 세이브를 지우거나 테스트 보드를 주입하지 않는다. Android 잔여 writer lock 복구와 큰 글꼴·접근성·장시간 부하 등 기존 W5 미완료 항목도 남아 있다. 이번 변경이 Block Blast 수준의 체감 품질을 달성했다는 판정은 사용자 실기기 확인 전까지 보류한다.

## 전달 파일·재현

[APK 해시·범위](gamefeel_evidence_2026-09-21/apk.json), [최종 내보내기 로그](gamefeel_evidence_2026-09-21/export.log), [소스 해시](gamefeel_evidence_2026-09-21/source_manifest.json)를 보존했다. 최종 export에서 SCRIPT ERROR/ERROR가 없고 APK v2/v3 서명이 검증됐다. 로컬 JDK25 apksigner의 native-access 경고는 남으며, 공개 배포용 서명은 아니다.

```powershell
pwsh -NoProfile -File tools/test.ps1
python tools/verify_presentation.py --cases "basic:320x568,basic:360x800,reference:412x915,inset:320x568,clear_pick:360x800,motion:360x800" --output tools/out/gamefeel_recheck
& C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path game --export-debug "Android Device Debug" export/blocktower-device-debug.apk
```

프리뷰 도구는 별도 테스트 저장 폴더를 만든다. 실제 앱 저장 파일과 분리한다. 실기기 재연결 시 기존 W5와 같은 `adb -s <serial> install --no-incremental -r` 방식으로 갱신한다.

## 독립 검토 결과

새 독립 검토에서 일반 배치 보상이 보드 첫 줄을 가리고 다음 드래그 안내를 숨기는 문제(GF-01), 작은 화면에 상하 안전 여백이 있을 때 하단 클리어가 잘리는 문제(GF-02)를 찾았다. 두 항목을 한 번에 수정한 뒤 같은 화면 행렬을 재검사했다. 일반 보상은 힌트 줄로 옮겼고 새 pickup 시 이전 토스트를 지우며 안내를 복원한다. 320×568에 상하24px 안전 영역을 모사했을 때296px보드와48px클리어 버튼이544px유효 하단 안에 들어간다.

[후속 판정](gamefeel_evidence_2026-09-21/verdict-pass.md)은 **두 지적 모두 resolved, 이 수정 범위에 한해 ship**이다. Android 전체 화면 검증은 **recapture**로 남는다. [첫 검토](gamefeel_evidence_2026-09-21/finish-review.md)의 범위와 함께 읽어야 하며, 전체 체감 품질 승인으로 확대하지 않는다. 네이티브 Godot이므로 HTML/CSS 탐지기는 적용하지 않았다.
