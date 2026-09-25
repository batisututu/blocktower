# 첨부 시안 재현을 위한 Mobbin·Godot 에셋 조사

조사일: 2026-09-21. 디자인 정책과 제작·검수 기준은 [디자인·에셋 가이드](../Blocktower_Design_Asset_Guide.md) §11에서 관리한다. 이 문서는 검색 결과, 적용 판단, 출처를 보관하는 조사 증거다.

## 1. 조사 결론과 시각 기준

시각 기준은 [사용자 디자인 시안](../디자인시안.png)이다. 1222×1287 원본의 파일 해시는 `f3a00233f60098fa27cc270bc6add4a67be5b5c7884620b209fa89981d395330`. 첨부 파일과 저장된 PNG는 파일 해시가 다르지만 RGBA 픽셀은 동일함을 확인했다. [기준 manifest](../../art_source/visual_target.json)에 기록했다.

기존 W0의 평면 SVG와 단색 HUD는 원본의 재질·건축 배경·입체 탑을 재현하지 못했다. 당시 레이아웃 검토 통과를 원본 외형 검수 통과로 사용하지 않는다. 현재 `DESIGN.md`는 기존 구현의 기록이며 목표 디자인을 결정하는 근거가 아니다.

이번에 검토한 후보 중 첨부 시안의 블록·배경·탑을 그대로 제공하는 완제품은 확인하지 못했다. **Mobbin은 정보 배치와 상태 전환의 참고 자료, Godot 자료실은 구현 보조 자료로 활용하고, 고유 외형은 원본에 맞춰 제작**한다. 후보의 페이지 확인과 실제 4.7.2 import/시각 검증은 구분한다. 이번 조사에서 외부 패키지를 설치하거나 출시 에셋으로 채택하지 않았다.

## 2. Mobbin MCP — 실제 이미지 확인

`search_screens` 2회와 `search_flows` 1회를 실행했다. 화면 6개와 흐름 2개(각 3화면)의 반환 미리보기를 직접 확인했다. [검색어·결과 ID·정식 링크](mobbin_research_2026-09-21.json)를 보존했다. 플랫폼 검색은 MCP가 지원하는 iOS를 사용했으며, 이것이 Blocktower의 출시 플랫폼이나 Android 위젯 규격을 결정하지 않는다.

| 자료 | 이미지에서 확인한 것 | Blocktower 적용 판단 |
|---|---|---|
| [Quizlet 퍼즐 화면](https://mobbin.com/screens/6e7e71b7-d02f-44d4-a980-ca44aca2b0d7) | 상단 점수·최고 기록, 중앙 격자, 하단의 세 조각 | 보드와 공급 영역의 정보 분리 참고. 흰색·평면 외형은 가져오지 않고, Blocktower의 수동 클리어 버튼과 건축 배경 유지 |
| [Google Arts & Culture](https://mobbin.com/screens/6bdb2388-7e2c-4117-9c21-b6f9fbdff354) | 그림 조각 맞추기와 하단 도구 | 블록 공급/클리어 구조와 달라 직접 적용 제외 |
| [Nibble](https://mobbin.com/screens/61e2a0be-afb6-4cc0-be46-b9affb586b45) | 그림의 빈 영역과 아래 선택 조각, 상단 진행 표시 | 퍼즐 종류가 달라 직접 적용 제외. 화면에 집중 대상을 하나 두는 계층만 참고 |
| [Finch 수집 화면](https://mobbin.com/screens/83509751-7c83-4eeb-ba04-f9e3c37689d3) | 종류별 수집 카드, 물음표 미획득 슬롯, 수집 개수 | 향후 재질/파츠 도감의 획득·미획득 구분 참고. 캐릭터/일러스트/장식은 게임에 복사하지 않음 |
| [Numo 잠금 화면](https://mobbin.com/screens/9b6c19d8-ef6d-47a6-8649-45de38abf36a) | 번호가 연결된 단계와 잠긴 보상 | 해금 순서 안내에만 참고. 탑 층수와 재질 해금 조건은 기존 성장 규칙 유지 |
| [Duolingo 배지 화면](https://mobbin.com/screens/c305d492-71c0-433b-99e7-71309ec14278) | 컬러 획득 항목과 회색 미획득 항목, 이름이 있는 격자 | 도감 상태·라벨 참고. 색상만으로 상태를 표시하지 않고 잠금 아이콘/조건 문구 추가 |
| [Azar 설정 전환 흐름](https://mobbin.com/flows/f888537a-dc6c-4a1f-b852-71471dd5fea5) | 토글 조작→배경을 가린 확인창→설정 결과 | 자동 클리어 전환 확인의 단계만 참고. 사용자를 붙잡는 설득 문구와 불균형한 선택 강조는 채택하지 않음 |
| [GoPro Quik 변경 취소 흐름](https://mobbin.com/flows/84561eb0-a1d4-4ddb-aca0-79ec90029fe4) | 변경 손실 설명, 취소/편집 복귀 선택 | 자동 전환/저장 실패에서 결과와 복귀 방법을 구체적으로 쓰는 원칙 참고. 게임의 저장 원자성은 별도 구현 |

Mobbin 화면은 관찰·링크 참조 자료다. 검색 결과가 반환되었다는 사실을 게임 배포용 이미지의 사용 허락으로 해석하지 않는다. 게임 에셋 폴더에 넣지 않았다. 링크는 만료되는 이미지 URL 대신 각 화면/흐름의 정식 Mobbin URL을 사용한다.

## 3. Godot Asset Library와 제작자 자료실

아래 버전·날짜는 확인한 등록 페이지의 표기다. 오래된 등록일 자체로 품질을 판단하지 않으며, 목표 엔진에서 실행한 것으로 표시하지 않는다.

| 후보·원문 | 확인한 배포 정보 | 용도와 판단 |
|---|---|---|
| [Kenney Particle Pack](https://godotengine.org/asset-library/asset/784) / [제작 저장소](https://github.com/Calinou/kenney-particle-pack) | 1.0.2, Godot 4.1 표기, 2023-07-16, CC0, 입자/빛용 스프라이트 80개 | **소수 텍스처 선별 후보.** 줄 제거의 빛/입자 원본으로 평가 가능. 첨부 시안의 sweep 위치·색·강도·시간은 자체 제작. 4.7.2 호환/성능 미검증 |
| [Kenney UI Audio](https://godotengine.org/asset-library/asset/796) | 1.0.0, Godot 4.1 표기, 2023-07-16, CC0, UI 효과음 50개 | **A09 청취 후보.** 선택/토글용 일부만 평가. 시안 외형 재현을 해결하지 않으며 청취·볼륨·중첩 검증 전 채택하지 않음 |
| [Main Menu Multi-Theme](https://godotengine.org/asset-library/asset/4258) / [소스](https://github.com/IYanel-DEV/MainMenu-MP) | 1.0, Godot 4.4 표기, 2025-08-25, MIT | **도입 제외.** 메뉴 테마 전환·StyleBox 구조 참고는 가능하지만 등록 설명의 네트워크 메뉴와 단색 테마는 이번 건축 퍼즐 외형을 제공하지 않음 |
| [Sprite Baker](https://godotengine.org/asset-library/asset/370) | 0.1.0, Godot 3.1 표기, 2019-09-15, MIT. 연결된 GitHub 원본은 이번 조회에서 404 | **도입 제외.** 3D→2D 목적은 유사하지만 4.7.2 호환·유지 상태 근거 부족. 기존 Blender 프리렌더 방향을 유지 |
| [Kenney UI Pack – Adventure](https://kenney.nl/assets/ui-pack-adventure) | 제작자 페이지 1.0/2024, 130 files, CC0 | **패널 제작/분할 참고 후보.** 원본과의 외형 일치는 검증하지 못했으므로 버튼을 그대로 대체하지 않음. 황동 프레임·재질·음영은 첨부 시안에 맞춰 제작 |
| [Kenney Building Kit](https://kenney.nl/assets/building-kit) | 제작자 페이지 1.0/2024, 80 files, CC0 | **모듈 구조 연구 후보.** 개별 모델/UV/앵커는 아직 검사하지 않음. 시안의 장식 탑과 같다고 간주하지 않고 그대로 최종 탑에 넣지 않음 |
| [Kenney Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit) | 제작자 페이지 2.0 재제작 표기, 160 files, CC0 | **건축 파츠 연구 후보.** 창·외벽 등의 실제 파일 검토와 재질/비례 수정이 필요. 시안의 세밀한 탑을 제공한다는 근거 없음 |

검색은 파티클, UI/테마, Kenney, building, 3D→2D/Sprite Baker를 대상으로 수행했다. 일부 Asset Library 필터 목록 URL은 웹 도구에서 열리지 않아 검색 색인과 개별 asset ID 페이지를 대조했다. 전체 자료실을 전수 조사했거나 동일한 상품이 전혀 없다는 결론은 아니다.

외부 자료를 실제로 도입할 때는 선택 파일만 검사하여 다운로드 URL·버전/커밋·원본 해시·라이선스 원문·수정 내역을 등록한다. 현재 표는 후보 조사 목록이며 기존 `vector_manifest.json`의 자체 제작 에셋과 합치지 않는다.

## 4. Godot에 적용할 구현 방식

| 시안 요소 | 적용 방식 | 검증할 부분 |
|---|---|---|
| 재질이 있는 패널/클리어 버튼 | 자체 제작 텍스처 + `StyleBoxTexture` + `Theme`. 모서리와 경계를 보존하고 중심만 늘리거나 반복 | 버튼 상태 4종, 긴 한국어, 0~16줄, 가장자리/중앙 무늬 왜곡. [공식 API](https://docs.godotengine.org/en/stable/classes/class_styleboxtexture.html) |
| 독립 장식 프레임 | `NinePatchRect`; 실제 버튼의 입력 영역과 분리 | 장식이 입력을 가리지 않음, 최소 크기에서 코너가 겹치지 않음. [공식 API](https://docs.godotengine.org/en/stable/classes/class_ninepatchrect.html) |
| 블록/빈 셀/프리뷰 | 자체 제작 재질 스프라이트, 공통 상태 오버레이. 필요 시 `AtlasTexture`로 영역 분리 | 외곽 alpha·인접 텍스처 번짐·명도/음영. 타일 반복용 배경은 별도 텍스처 사용. [공식 API](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html) |
| 건축 배경 | 자체 제작 화면 배경과 전경 장식의 별도 레이어 | 핵심 건축선 유지, 안전 영역·화면 비율별 crop, 보드 대비 확보 |
| 탑 | 동일 카메라/조명에서 만든 수정 가능한 3D 원본→투명 PNG 모듈→Godot 2D 합성 | 지붕 1개, 정확한 층수, 부분 구간, 모듈 간 그림자·원근·폭 연결 |

첫 확인용 가져오기는 UI/셀 lossless·linear filter를 기준으로 실제 원본과 대조하고, 탑 축소는 mipmap 유무를 비교한다. SVG는 기본적으로 가져올 때 래스터화되므로 벡터라는 이유만으로 모든 크기에서 품질을 보장하지 않는다. 최종 선택은 PNG/SVG의 실제 Godot 출력으로 판단한다. [Godot 이미지 가져오기](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)

위 방식은 조사에 따른 적용 설계이며 새 테마·탑 렌더가 구현 완료된 것은 아니다. 전체 화면을 한 장의 이미지로 붙여 놓고 재현 완료로 처리하지 않는다. 보드·조각·문자·버튼은 독립된 실제 게임 요소여야 한다.

## 5. 다음 제작에 넘기는 항목

제작 목록·결과물 경로·외형 검수 관문은 [디자인 가이드 §11](../Blocktower_Design_Asset_Guide.md#11-첨부-시안-재현-기준과-제작-관문)과 [visual target](../../art_source/visual_target.json)에만 관리한다. 조사 완료를 제작/렌더/실기기 검증 완료로 올리지 않는다. 현재 다음 행동은 선택한 조합의 전체 화면과 블록·버튼·목재 탑 샘플을 제작하고 원본과 대조하는 것이다.
