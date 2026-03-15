extends GdUnitTestSuite
## Tests for TurnBased2v2Controller using auto-submit helpers.
## Battle runs fully synchronously because auto-submit fires during waiting_for_input.emit()
## (no await is reached when the player action is submitted synchronously in the signal handler).
## Use Array containers for lambda captures (GDScript lambda rebinding limitation).

const _Controller = preload("res://engine/battle/controller/TurnBased2v2Controller.gd")


func _auto_submit_2v2(controller: Object) -> void:
	controller.waiting_for_input.connect(
		func(actor_id: String, _moves: Array) -> void:
			controller.submit_player_action(actor_id, 0)
	)
	controller.needs_target.connect(
		func(actor_id: String, target_ids: Array[String]) -> void:
			if not target_ids.is_empty():
				controller.submit_player_target(actor_id, target_ids[0])
	)


func test_battle_ends_and_one_team_wins() -> void:
	# Player team is all-powerful; enemy has 1HP — player team wins
	var p0: MonsterInstance = MonsterInstance.create(_make_config("p0", 9999, 999, 1, 999), 1)
	var p1: MonsterInstance = MonsterInstance.create(_make_config("p1", 9999, 999, 1, 999), 1)
	var e0: MonsterInstance = MonsterInstance.create(_make_config("e0", 1, 1, 1, 1), 1)
	var e1: MonsterInstance = MonsterInstance.create(_make_config("e1", 1, 1, 1, 1), 1)

	var move_lib: Dictionary[String, MoveConfig] = {
		"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE),
	}
	p0.config.move_ids = ["nuke"]
	p1.config.move_ids = ["nuke"]
	e0.config.move_ids = ["nuke"]
	e1.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit_2v2(controller)

	var result: Array = ["", 0]
	controller.battle_ended.connect(func(winner_id: String, turns: int) -> void:
		result[0] = winner_id
		result[1] = turns
	)

	var player_team: Array[MonsterInstance] = [p0, p1]
	var enemy_team: Array[MonsterInstance] = [e0, e1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	controller.run(player_team, enemy_team, move_lib, rng)

	assert_str(result[0]).is_equal("player")
	assert_bool(result[1] > 0).is_true()


func test_enemy_team_wins() -> void:
	# Enemy team all-powerful; player team has 1HP
	var p0: MonsterInstance = MonsterInstance.create(_make_config("p0", 1, 1, 1, 1), 1)
	var p1: MonsterInstance = MonsterInstance.create(_make_config("p1", 1, 1, 1, 1), 1)
	var e0: MonsterInstance = MonsterInstance.create(_make_config("e0", 9999, 999, 1, 999), 1)
	var e1: MonsterInstance = MonsterInstance.create(_make_config("e1", 9999, 999, 1, 999), 1)

	var move_lib: Dictionary[String, MoveConfig] = {
		"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE),
	}
	p0.config.move_ids = ["nuke"]
	p1.config.move_ids = ["nuke"]
	e0.config.move_ids = ["nuke"]
	e1.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit_2v2(controller)

	var result: Array = [""]
	controller.battle_ended.connect(func(w: String, _t: int) -> void: result[0] = w)

	var player_team: Array[MonsterInstance] = [p0, p1]
	var enemy_team: Array[MonsterInstance] = [e0, e1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	controller.run(player_team, enemy_team, move_lib, rng)

	assert_str(result[0]).is_equal("enemy")


func test_combatants_initialized_fires_with_all_four_names() -> void:
	var p0: MonsterInstance = MonsterInstance.create(_make_config("alpha", 80, 10, 10, 10), 1)
	var p1: MonsterInstance = MonsterInstance.create(_make_config("beta", 70, 10, 10, 10), 1)
	var e0: MonsterInstance = MonsterInstance.create(_make_config("gamma", 60, 10, 10, 10), 1)
	var e1: MonsterInstance = MonsterInstance.create(_make_config("delta", 50, 10, 10, 10), 1)

	var move_lib: Dictionary[String, MoveConfig] = {
		"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE),
	}
	p0.config.move_ids = ["nuke"]
	p1.config.move_ids = ["nuke"]
	e0.config.move_ids = ["nuke"]
	e1.config.move_ids = ["nuke"]

	var names: Array = ["", "", "", ""]
	var hps: Array = [0, 0, 0, 0]

	var controller: Object = _Controller.new()
	_auto_submit_2v2(controller)

	controller.combatants_initialized.connect(
		func(p0n: String, p0h: int, p1n: String, p1h: int, e0n: String, e0h: int, e1n: String, e1h: int) -> void:
			names[0] = p0n
			names[1] = p1n
			names[2] = e0n
			names[3] = e1n
			hps[0] = p0h
			hps[1] = p1h
			hps[2] = e0h
			hps[3] = e1h
	)

	var player_team: Array[MonsterInstance] = [p0, p1]
	var enemy_team: Array[MonsterInstance] = [e0, e1]
	controller.run(player_team, enemy_team, move_lib)

	assert_str(names[0]).is_equal("Alpha")
	assert_str(names[1]).is_equal("Beta")
	assert_str(names[2]).is_equal("Gamma")
	assert_str(names[3]).is_equal("Delta")
	assert_int(hps[0]).is_equal(80)
	assert_int(hps[1]).is_equal(70)
	assert_int(hps[2]).is_equal(60)
	assert_int(hps[3]).is_equal(50)


func test_fainted_monster_skipped_next_turn() -> void:
	# p0 has huge speed and power — kills e0 on turn 1.
	# e1 is alive. Battle continues. Battle should end with player winning eventually.
	var p0: MonsterInstance = MonsterInstance.create(_make_config("p0", 9999, 999, 1, 999), 1)
	var p1: MonsterInstance = MonsterInstance.create(_make_config("p1", 9999, 999, 1, 500), 1)
	var e0: MonsterInstance = MonsterInstance.create(_make_config("e0", 1, 1, 1, 1), 1)
	var e1: MonsterInstance = MonsterInstance.create(_make_config("e1", 1, 1, 1, 1), 1)

	var move_lib: Dictionary[String, MoveConfig] = {
		"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE),
	}
	p0.config.move_ids = ["nuke"]
	p1.config.move_ids = ["nuke"]
	e0.config.move_ids = ["nuke"]
	e1.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit_2v2(controller)

	var result: Array = ["", 0]
	controller.battle_ended.connect(func(w: String, t: int) -> void:
		result[0] = w
		result[1] = t
	)

	var player_team: Array[MonsterInstance] = [p0, p1]
	var enemy_team: Array[MonsterInstance] = [e0, e1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	controller.run(player_team, enemy_team, move_lib, rng)

	# Player should win; turn count > 0 confirms battle ran
	assert_str(result[0]).is_equal("player")
	assert_bool(result[1] > 0).is_true()


func test_battle_ended_signal_fires() -> void:
	var p0: MonsterInstance = MonsterInstance.create(_make_config("p0", 9999, 999, 1, 999), 1)
	var p1: MonsterInstance = MonsterInstance.create(_make_config("p1", 9999, 999, 1, 999), 1)
	var e0: MonsterInstance = MonsterInstance.create(_make_config("e0", 1, 1, 1, 1), 1)
	var e1: MonsterInstance = MonsterInstance.create(_make_config("e1", 1, 1, 1, 1), 1)

	var move_lib: Dictionary[String, MoveConfig] = {
		"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE),
	}
	p0.config.move_ids = ["nuke"]
	p1.config.move_ids = ["nuke"]
	e0.config.move_ids = ["nuke"]
	e1.config.move_ids = ["nuke"]

	var fired: Array = [false]
	var controller: Object = _Controller.new()
	_auto_submit_2v2(controller)
	controller.battle_ended.connect(func(_w: String, _t: int) -> void:
		fired[0] = true
	)

	var player_team: Array[MonsterInstance] = [p0, p1]
	var enemy_team: Array[MonsterInstance] = [e0, e1]
	controller.run(player_team, enemy_team, move_lib)

	assert_bool(fired[0]).is_true()


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
