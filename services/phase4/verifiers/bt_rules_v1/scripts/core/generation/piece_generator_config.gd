extends Resource
## 계열 순서는 카탈로그와 고정된다. 실행기는 생성 시 복사/검증하여 외부 변경을 격리한다.

@export var catalog_version: String = "bt_catalog_29_v0_2"
@export var supply_policy_version: String = "bt_soft_one_move_v0_2"
@export var family_weights: Array[int] = [5, 6, 8, 4, 1, 6, 1, 5, 2, 3, 1, 1, 2]
@export var easy_families: Array[String] = ["single", "line2", "line3", "elbow3"]
@export_range(0, 3) var max_rerolls: int = 3
