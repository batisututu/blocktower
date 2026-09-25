# B안 세부 외형 실행 증거

- [원본·실행 비교](comparison.html), [최종 판정과 수정 이력](finish-review.md), [19상태 검사](native/summary.json).
- native/는 fidelity_review_fix1의 13개 비탑 상태와 fidelity_roof_final의 6개 탑 상태를 합친 최종 목록이다. 각 report의 capture_directory가 원본 실행 폴더를 가리킨다. 각 PNG 옆 JSON/log를 함께 보존했다.
- [전체 테스트 기록](last_test_run.json): 74개/오류 0, 2,592개 단언은 gut.stdout.log/gut_unit.xml에 기록. 최종 UV 지붕 재질 변경 전 실행이다. 이후 재질 변경은 fidelity_import_final.log 및 탑 6상태로 다시 검증했다.
- [소스 SHA-256](source_manifest.json)은 최종 외형 소스·에셋·캡처 도구의 추적용이다. 원본 사용자 시안 해시는 art_source/visual_target.json이 소유한다.
- 기존 W0/W3/W4 실행 증거를 대체하지 않는다. Android 실기기·전체 연출 체험·사용자 최종 승인은 이 증거의 범위가 아니다.
