extends SceneTree
## 두 공급 설정의 빈 보드 추첨 결과를 같은 고정 시드로 집계한다.
const Generator = preload("res://scripts/core/generation/piece_generator.gd")
const Classic = preload("res://data/piece_generator_default.tres")
const Reduced = preload("res://data/piece_generator_low_single.tres")
const TRAYS := 10000

func _initialize() -> void:
    var reports := []
    for profile in [{"id":"classic","config":Classic},{"id":"reduced_single","config":Reduced}]:
        var created: Dictionary = Generator.create(profile.config)
        if not created.ok:
            quit(2)
            return
        var generator: RefCounted = created.generator
        var sample_results := {}
        for sample in ["empty","mixed"]:
            var checkpoint: Dictionary = generator.initial_checkpoint("20260925").checkpoint
            var board_rng := RandomNumberGenerator.new()
            board_rng.seed = 821913
            var singles := 0
            for i in range(TRAYS):
                var board: PackedByteArray = _make_board(i,board_rng) if sample == "mixed" else _make_board(0,board_rng)
                var drawn: Dictionary = generator.generate(board,[],checkpoint)
                if not drawn.ok or not drawn.guarantee_met:
                    quit(3)
                    return
                checkpoint = drawn.checkpoint
                for piece_id in drawn.piece_ids:
                    if piece_id == "single_v0": singles += 1
            sample_results[sample] = {"single_count":singles,"single_fraction":float(singles)/float(TRAYS*3)}
        reports.append({"profile":profile.id,"trays_per_condition":TRAYS,
            "config_hash":generator.config_snapshot().config_hash,"samples":sample_results})
    if reports[1].samples.empty.single_fraction >= reports[0].samples.empty.single_fraction or reports[1].samples.mixed.single_fraction >= reports[0].samples.mixed.single_fraction:
        quit(4)
        return
    var report := {"ok":true,"board_seed":"821913","generator_seed":"20260925",
        "board_mix":"10 equally repeated synthetic classes; no player model","profiles":reports}
    var args := OS.get_cmdline_user_args()
    if args.size() == 1:
        var file := FileAccess.open(args[0],FileAccess.WRITE)
        if file == null:
            quit(5)
            return
        file.store_string(JSON.stringify(report,"  "))
        file.close()
    print("SUPPLY_PROFILE_PROBE ",JSON.stringify(report))
    quit(0)

func _make_board(index: int, rng: RandomNumberGenerator) -> PackedByteArray:
    var board := PackedByteArray()
    board.resize(64)
    var kind := index % 10
    if kind == 0: return board
    if kind == 1:
        board.fill(1)
        return board
    if kind == 2:
        for cell in range(64): board[cell] = (cell / 8 + cell % 8) % 2
        return board
    var density: float = [0.25,0.5,0.7,0.85,0.95,0.7,0.9][kind-3]
    for cell in range(64): board[cell] = int(rng.randf() < density)
    if kind == 8:
        for i in range(8):
            board[3*8+i] = 1
            board[i*8+6] = 1
    if kind == 9:
        board.fill(1)
        for i in range(8): board[i*8+i] = 0
    return board
