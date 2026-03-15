extends GdUnitTestSuite
## Tests for TurnBasedNvMController using auto-submit helpers.
## Battle runs fully synchronously because auto-submit fires during waiting_for_input.emit()
## (no await is reached when the player action is submitted synchronously in the signal handler).

const _Controller = preload("res://engine/battle/controller/TurnBasedNvMController.gd")


func _auto_submit_nvm(controller: Object) -> void:
	controller.waiting_for_input.connect(
		func(actor_id: String, _moves: Array) -> void:
			controller.submit_player_action(actor_id, 0)
	)
	controller.needs_target.connect(
		func(actor_id: String, target_ids: Array[String]) -> void:
			if not target_ids.is_empty():
				controller.submit_player_target(actor_id, target_ids[0])
	)


func test_player_team_wins_when_overpowered() -> void:
	# 3 overpowered players vs 7 weak enemies — player team wins
	var player_team: Array[MonsterInstance] = []
	for i: int in range(3):
		player_team.append(MonsterInstance.create(_make_config("p" + str(i), 9999, 999, 1, 999), 1))

	var enemy_team: Array[MonsterInstance] = []
	for i: int in range(7):
		enemy_team.append(MonsterInstance.create(_make_config("e" + str(i), 1, 1, 1, 1), 1))

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	for m: MonsterInstance in player_team + enemy_team:
		m.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit_nvm(controller)

	var result: Array = ["", 0]
	controller.battle_ended.connect(func(winner_id: String, turns: int) -> void:
		result[0] = winner_id
		result[1] = turns
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	controller.run(player_team, enemy_team, move_lib, rng)

	assert_str(result[0]).is_equal("player")
	assert_bool(result[1] > 0).is_true()


func test_enemy_team_wins_when_overpowered() -> void:
	# 7 overpowered enemies vs 3 weak players — enemy team wins
	var player_team: Array[MonsterInstance] = []
	for i: int in range(3):
		player_team.append(MonsterInstance.create(_make_config("p" + str(i), 1, 1, 1, 1), 1))

	var enemy_team: Array[MonsterInstance] = []
	for i: int in range(7):
		enemy_team.append(MonsterInstance.create(_make_config("e" + str(i), 9999, 999, 1, 999), 1))

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	for m: MonsterInstance in player_team + enemy_team:
		m.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit_nvm(controller)

	var result: Array = [""]
	controller.battle_ended.connect(func(w: String, _t: int) -> void: result[0] = w)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	controller.run(player_team, enemy_team, move_lib, rng)

	assert_str(result[0]).is_equal("enemy")


func test_combatants_initialized_signal_contains_correct_names_and_hps() -> void:
	var player_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("alpha", 80, 10, 10, 10), 1),
		MonsterInstance.create(_make_config("beta", 70, 10, 10, 10), 1),
		MonsterInstance.create(_make_config("gamma", 60, 10, 10, 10), 1),
	]
	var enemy_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("delta", 50, 10, 10, 10), 1),
		MonsterInstance.create(_make_config("epsilon", 40, 10, 10, 10), 1),
	]

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	for m: MonsterInstance in player_team + enemy_team:
		m.config.move_ids = ["nuke"]

	var received_p_names: Array = []
	var received_p_hps: Array = []
	var received_e_names: Array = []
	var received_e_hps: Array = []

	var controller: Object = _Controller.new()
	_auto_submit_nvm(controller)

	controller.combatants_initialized.connect(
		func(p_names: Array[String], p_hps: Array[int], e_names: Array[String], e_hps: Array[int]) -> void:
			received_p_names.assign(p_names)
			received_p_hps.assign(p_hps)
			received_e_names.assign(e_names)
			received_e_hps.assign(e_hps)
	)

	controller.run(player_team, enemy_team, move_lib)

	assert_int(received_p_names.size()).is_equal(3)
	assert_str(received_p_names[0]).is_equal("Alpha")
	assert_str(received_p_names[1]).is_equal("Beta")
	assert_str(received_p_names[2]).is_equal("Gamma")
	assert_int(received_p_hps[0]).is_equal(80)
	assert_int(received_p_hps[1]).is_equal(70)
	assert_int(received_p_hps[2]).is_equal(60)
	assert_int(received_e_names.size()).is_equal(2)
	assert_str(received_e_names[0]).is_equal("Delta")
	assert_str(received_e_names[1]).is_equal("Epsilon")
	assert_int(received_e_hps[0]).is_equal(50)
	assert_int(received_e_hps[1]).is_equal(40)


func test_fainted_monsters_are_skipped_in_subsequent_turns() -> void:
	# 3 overpowered players kill enemies one by one each turn
	var player_team: Array[MonsterInstance] = []
	for i: int in range(3):
		player_team.append(MonsterInstance.create(_make_config("p" + str(i), 9999, 999, 1, 999), 1))

	var enemy_team: Array[MonsterInstance] = []
	for i: int in range(3):
		enemy_team.append(MonsterInstance.create(_make_config("e" + str(i), 1, 1, 1, 1), 1))

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	for m: MonsterInstance in player_team + enemy_team:
		m.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit_nvm(controller)

	var result: Array = ["", 0]
	controller.battle_ended.connect(func(w: String, t: int) -> void:
		result[0] = w
		result[1] = t
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	controller.run(player_team, enemy_team, move_lib, rng)

	assert_str(result[0]).is_equal("player")
	assert_bool(result[1] > 0).is_true()


func test_battle_ended_signal_fires() -> void:
	var player_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("p0", 9999, 999, 1, 999), 1),
	]
	var enemy_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("e0", 1, 1, 1, 1), 1),
	]

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	player_team[0].config.move_ids = ["nuke"]
	enemy_team[0].config.move_ids = ["nuke"]

	var fired: Array = [false]
	var controller: Object = _Controller.new()
	_auto_submit_nvm(controller)
	controller.battle_ended.connect(func(_w: String, _t: int) -> void:
		fired[0] = true
	)

	controller.run(player_team, enemy_team, move_lib)

	assert_bool(fired[0]).is_true()


func test_single_player_vs_single_enemy_works_as_1v1() -> void:
	# NvM with N=1, M=1 should behave identically to a 1v1
	var player_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("p0", 100, 50, 10, 10), 1),
	]
	var enemy_team: Array[MonsterInstance] = [
		MonsterInstance.create(_make_config("e0", 1, 1, 1, 1), 1),
	]

	var move_lib: Dictionary[String, MoveConfig] = {"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE)}
	player_team[0].config.move_ids = ["nuke"]
	enemy_team[0].config.move_ids = ["nuke"]

	var result: Array = [""]
	var controller: Object = _Controller.new()
	_auto_submit_nvm(controller)
	controller.battle_ended.connect(func(w: String, _t: int) -> void: result[0] = w)

	controller.run(player_team, enemy_team, move_lib)

	assert_str(result[0]).is_equal("player")


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
