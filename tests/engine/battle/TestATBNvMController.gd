extends GdUnitTestSuite
## Tests for ATBNvMController.
## Battle runs synchronously: auto-submit fires during waiting_for_input.emit(),
## and tick() is called in a loop to advance time. No await needed in tests.

const _Controller = preload("res://engine/battle/controller/ATBNvMController.gd")


# --- Auto-submit helper ---

func _auto_submit(controller: Object) -> void:
	controller.waiting_for_input.connect(
		func(actor_id: String, _moves: Array) -> void:
			controller.submit_player_action(actor_id, 0)
	)
	controller.needs_target.connect(
		func(actor_id: String, target_ids: Array[String]) -> void:
			if not target_ids.is_empty():
				controller.submit_player_target(actor_id, target_ids[0])
	)


## Drive ticks until battle_ended fires or max_ticks is reached.
## Returns true if battle ended within the tick budget.
func _drive_to_end(controller: Object, ended_flag: Array, max_ticks: int = 10000) -> bool:
	var ticks: int = 0
	while not ended_flag[0] and ticks < max_ticks:
		controller.tick(1.0 / 60.0)
		ticks += 1
	return ended_flag[0]


# --- Tests ---

func test_player_team_wins_when_overpowered() -> void:
	var player_team: Array[MonsterInstance] = []
	for i: int in range(3):
		player_team.append(MonsterInstance.create(_make_config("p" + str(i), 9999, 999, 1, 10), 1))

	var enemy_team: Array[MonsterInstance] = []
	for i: int in range(5):
		enemy_team.append(MonsterInstance.create(_make_config("e" + str(i), 1, 1, 1, 10), 1))

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	for m: MonsterInstance in player_team + enemy_team:
		m.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit(controller)

	var result: Array = ["", 0, false]
	controller.battle_ended.connect(func(w: String, cnt: int) -> void:
		result[0] = w
		result[1] = cnt
		result[2] = true
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	controller.run(player_team, enemy_team, move_lib, rng)
	_drive_to_end(controller, [result[2]])
	# re-check result[2] after drive (Array container workaround)
	assert_bool(result[2]).is_true()
	assert_str(result[0]).is_equal("player")
	assert_bool(result[1] > 0).is_true()


func test_enemy_team_wins_when_overpowered() -> void:
	var player_team: Array[MonsterInstance] = []
	for i: int in range(3):
		player_team.append(MonsterInstance.create(_make_config("p" + str(i), 1, 1, 1, 10), 1))

	var enemy_team: Array[MonsterInstance] = []
	for i: int in range(5):
		enemy_team.append(MonsterInstance.create(_make_config("e" + str(i), 9999, 999, 1, 10), 1))

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	for m: MonsterInstance in player_team + enemy_team:
		m.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit(controller)

	var result: Array = ["", false]
	controller.battle_ended.connect(func(w: String, _cnt: int) -> void:
		result[0] = w
		result[1] = true
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	controller.run(player_team, enemy_team, move_lib, rng)
	_drive_to_end(controller, [result[1]])

	assert_bool(result[1]).is_true()
	assert_str(result[0]).is_equal("enemy")


func test_battle_ended_signal_fires() -> void:
	var player_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("p0", 9999, 999, 1, 10), 1),
	]
	var enemy_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("e0", 1, 1, 1, 10), 1),
	]

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	player_team[0].config.move_ids = ["nuke"]
	enemy_team[0].config.move_ids = ["nuke"]

	var fired: Array = [false]
	var controller: Object = _Controller.new()
	_auto_submit(controller)
	controller.battle_ended.connect(func(_w: String, _cnt: int) -> void: fired[0] = true)

	controller.run(player_team, enemy_team, move_lib)
	_drive_to_end(controller, fired)

	assert_bool(fired[0]).is_true()


func test_combatants_initialized_fires_with_correct_data() -> void:
	var player_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("alpha", 80, 10, 10, 10), 1),
		MonsterInstance.create(_make_config("beta", 70, 10, 10, 10), 1),
	]
	var enemy_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("delta", 50, 10, 10, 10), 1),
		MonsterInstance.create(_make_config("epsilon", 40, 10, 10, 10), 1),
		MonsterInstance.create(_make_config("zeta", 30, 10, 10, 10), 1),
	]

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	for m: MonsterInstance in player_team + enemy_team:
		m.config.move_ids = ["nuke"]

	var received: Array = [[], [], [], []]
	var controller: Object = _Controller.new()
	_auto_submit(controller)
	controller.combatants_initialized.connect(
		func(p_names: Array[String], p_hps: Array[int], e_names: Array[String], e_hps: Array[int]) -> void:
			received[0].assign(p_names)
			received[1].assign(p_hps)
			received[2].assign(e_names)
			received[3].assign(e_hps)
	)

	var ended: Array = [false]
	controller.battle_ended.connect(func(_w: String, _c: int) -> void: ended[0] = true)
	controller.run(player_team, enemy_team, move_lib)
	_drive_to_end(controller, ended)

	assert_int(received[0].size()).is_equal(2)
	assert_str(received[0][0]).is_equal("Alpha")
	assert_str(received[0][1]).is_equal("Beta")
	assert_int(received[1][0]).is_equal(80)
	assert_int(received[1][1]).is_equal(70)
	assert_int(received[2].size()).is_equal(3)
	assert_str(received[2][0]).is_equal("Delta")
	assert_int(received[3][2]).is_equal(30)


func test_gauges_frozen_during_player_input() -> void:
	# Give player a weak monster, enemy very weak — battle should not end quickly.
	# We check that gauge_updated stops changing while waiting_for_input is pending.
	var player_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("p0", 9999, 1, 100, 10), 1),
	]
	var enemy_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("e0", 9999, 1, 100, 10), 1),
	]

	var move_lib: Dictionary[String, MoveConfig] = {"scratch": _make_move("scratch", 5, MoveConfig.Effect.NONE)}
	player_team[0].config.move_ids = ["scratch"]
	enemy_team[0].config.move_ids = ["scratch"]

	var controller: Object = _Controller.new()

	# Do NOT wire auto-submit — we want the controller to park at waiting_for_input
	var gauge_snapshots_while_waiting: Array = []
	var is_waiting: Array = [false]

	controller.waiting_for_input.connect(
		func(_actor_id: String, _moves: Array) -> void:
			is_waiting[0] = true
	)

	controller.gauge_updated.connect(
		func(_actor_id: String, value: float) -> void:
			if is_waiting[0]:
				gauge_snapshots_while_waiting.append(value)
	)

	controller.run(player_team, enemy_team, move_lib)

	# Drive enough ticks for the first actor to become ready
	for _i: int in range(200):
		controller.tick(1.0 / 60.0)
		if is_waiting[0]:
			break

	assert_bool(is_waiting[0]).is_true()

	# Drive a few more ticks — gauges should be frozen (all values 0.0 because paused)
	var snapshot_before: int = gauge_snapshots_while_waiting.size()
	for _i: int in range(30):
		controller.tick(1.0 / 60.0)

	# All gauge_updated emissions after waiting started should be 0.0 (gauge frozen at reset)
	for v in gauge_snapshots_while_waiting:
		assert_float(v as float).is_equal(0.0)

	# Clean up: submit so the coroutine can finish
	controller.submit_player_action("player_0", 0)
	# needs_target not needed for SINGLE_ENEMY move


func test_faster_actor_acts_more_often() -> void:
	# player speed=20, enemy speed=10 → player should act ~2x more often
	var player_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("fast", 9999, 1, 100, 20), 1),
	]
	var enemy_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("slow", 9999, 1, 100, 10), 1),
	]

	var move_lib: Dictionary[String, MoveConfig] = {"scratch": _make_move("scratch", 1, MoveConfig.Effect.NONE)}
	player_team[0].config.move_ids = ["scratch"]
	enemy_team[0].config.move_ids = ["scratch"]

	var controller: Object = _Controller.new()
	_auto_submit(controller)

	var player_actions: Array = [0]
	var enemy_actions: Array = [0]
	controller.move_used.connect(func(user_name: String, _m: String, _t: String) -> void:
		if user_name == "Fast":
			player_actions[0] += 1
		elif user_name == "Slow":
			enemy_actions[0] += 1
	)

	var ended: Array = [false]
	controller.battle_ended.connect(func(_w: String, _c: int) -> void: ended[0] = true)

	controller.run(player_team, enemy_team, move_lib)
	_drive_to_end(controller, ended, 50000)

	# Player (speed 20) should act roughly 2× more than enemy (speed 10)
	# Allow tolerance: ratio should be at least 1.5 and at most 2.5
	if enemy_actions[0] > 0:
		var ratio: float = float(player_actions[0]) / float(enemy_actions[0])
		assert_float(ratio).is_greater_equal(1.5)
		assert_float(ratio).is_less_equal(2.5)


func test_fainted_actor_in_queue_is_skipped() -> void:
	# Two enemies with same speed: e0 gets pre-charged so it fills first.
	# Player has massive attack — kills e0 on first action.
	# e1 then fills — should act normally.
	var player_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("p0", 9999, 999, 1, 5), 1),
	]
	var e0 := MonsterInstance.create(_make_config("e0", 1, 1, 1, 10), 1)
	var e1 := MonsterInstance.create(_make_config("e1", 9999, 1, 1, 10), 1)
	var enemy_team: Array[MonsterInstance] = [e0, e1]

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	for m: MonsterInstance in player_team + enemy_team:
		m.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit(controller)

	var ended: Array = [false]
	var winner: Array = [""]
	controller.battle_ended.connect(func(w: String, _c: int) -> void:
		winner[0] = w
		ended[0] = true
	)

	controller.run(player_team, enemy_team, move_lib)
	_drive_to_end(controller, ended)

	# Battle should complete without errors; e1 outlives e0
	assert_bool(ended[0]).is_true()
	assert_bool(e0.is_fainted()).is_true()


# --- Helpers ---

func _make_config(id: String, hp: int, atk: int, def_val: int, spd: int) -> MonsterConfig:
	var config := MonsterConfig.new()
	config.id = id
	config.display_name = id.capitalize()
	var stats := StatBlock.new()
	stats.max_hp = hp
	stats.attack = atk
	stats.defense = def_val
	stats.speed = spd
	config.base_stats = stats
	config.type_tags = [TypeTag.Type.NORMAL]
	config.ai_style = MonsterConfig.AIStyle.RANDOM
	return config


func _make_move(id: String, power: int, effect: MoveConfig.Effect) -> MoveConfig:
	var move := MoveConfig.new()
	move.id = id
	move.display_name = id.capitalize()
	move.type_tag = TypeTag.Type.NORMAL
	move.power = power
	move.accuracy = 1.0
	move.effect = effect
	move.target_type = MoveConfig.TargetType.SINGLE_ENEMY
	return move
