extends GdUnitTestSuite
## Tests for TurnBased1v1Controller using auto-submit (headless AI-vs-AI equivalent).
## Battle runs fully synchronously because auto-submit fires during waiting_for_input.emit()
## (no await is ever reached). Connect signals before run(), then check results after.
## Use Array containers for lambda captures (GDScript lambda rebinding limitation).

const _BattleState = preload("res://engine/battle/model/BattleState.gd")
const _Controller = preload("res://engine/battle/controller/TurnBased1v1Controller.gd")


func _auto_submit(controller: Object) -> void:
	controller.waiting_for_input.connect(
		func(_id: String, _moves: Array) -> void:
			controller.submit_player_action(0)
	)


func test_battle_ends_and_winner_is_set() -> void:
	var player := MonsterInstance.create(_make_config("player", 9999, 100, 1, 100), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 1, 1, 1, 1), 1)
	var move_lib: Dictionary[String, MoveConfig] = {
		"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE),
	}
	player.config.move_ids = ["nuke"]
	enemy.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit(controller)

	var result: Array = ["", 0]  # [winner_id, turns]
	controller.battle_ended.connect(func(winner_id: String, turns: int) -> void:
		result[0] = winner_id
		result[1] = turns
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	controller.run(player, enemy, move_lib, rng)

	assert_str(result[0]).is_equal("player")
	assert_bool(result[1] > 0).is_true()


func test_winner_id_enemy_when_player_weak() -> void:
	var player := MonsterInstance.create(_make_config("player", 1, 1, 1, 1), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 9999, 100, 1, 100), 1)
	var move_lib: Dictionary[String, MoveConfig] = {
		"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE),
	}
	player.config.move_ids = ["nuke"]
	enemy.config.move_ids = ["nuke"]

	var controller: Object = _Controller.new()
	_auto_submit(controller)

	var result: Array = [""]
	controller.battle_ended.connect(func(w: String, _t: int) -> void: result[0] = w)

	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	controller.run(player, enemy, move_lib, rng)

	assert_str(result[0]).is_equal("enemy")


func test_stat_stages_reset_at_start() -> void:
	var player := MonsterInstance.create(_make_config("player", 50, 10, 10, 20), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 50, 10, 10, 20), 1)
	player.modify_stat_stage("speed", 6)
	var move_lib: Dictionary[String, MoveConfig] = {
		"hit": _make_move("hit", 5, MoveConfig.Effect.NONE),
	}
	player.config.move_ids = ["hit"]
	enemy.config.move_ids = ["hit"]

	var controller: Object = _Controller.new()
	_auto_submit(controller)
	controller.run(player, enemy, move_lib)

	assert_bool(player.get_stat_stage("speed") != 6).is_true()


func test_fainted_monster_does_not_act() -> void:
	# Player has SPD=100, kills enemy on turn 1. Enemy must not deal damage.
	var player := MonsterInstance.create(_make_config("player", 9999, 100, 1, 100), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 1, 999, 1, 1), 1)
	var move_lib: Dictionary[String, MoveConfig] = {
		"nuke": _make_move("nuke", 100, MoveConfig.Effect.NONE),
	}
	player.config.move_ids = ["nuke"]
	enemy.config.move_ids = ["nuke"]

	var player_damage_taken: Array = [0]
	var controller: Object = _Controller.new()
	_auto_submit(controller)
	controller.damage_dealt.connect(func(name: String, amt: int, _h: int, _m: int) -> void:
		if name == "Player":
			player_damage_taken[0] += amt
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	controller.run(player, enemy, move_lib, rng)

	assert_int(player_damage_taken[0]).is_equal(0)


func test_combatants_initialized_signal_fires() -> void:
	var player := MonsterInstance.create(_make_config("hero", 80, 10, 10, 10), 1)
	var enemy := MonsterInstance.create(_make_config("foe", 60, 10, 10, 10), 1)
	var move_lib: Dictionary[String, MoveConfig] = {
		"hit": _make_move("hit", 100, MoveConfig.Effect.NONE),
	}
	player.config.move_ids = ["hit"]
	enemy.config.move_ids = ["hit"]

	var init_data: Array = ["", 0]  # [player_name, player_max_hp]
	var controller: Object = _Controller.new()
	_auto_submit(controller)
	controller.combatants_initialized.connect(
		func(pn: String, php: int, _en: String, _ehp: int) -> void:
			init_data[0] = pn
			init_data[1] = php
	)

	controller.run(player, enemy, move_lib)

	assert_str(init_data[0]).is_equal("Hero")
	assert_int(init_data[1]).is_equal(80)


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
	return move
