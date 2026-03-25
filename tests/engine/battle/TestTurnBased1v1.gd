extends GdUnitTestSuite
const _load_battle_state = preload("res://engine/battle/model/BattleState.gd")


# --- damage calculation ---

func test_damage_formula_basic() -> void:
	# damage = max(1, move_power * atk / (20 + def))
	# 20 * 30 / (20 + 10) = 600 / 30 = 20
	var attacker := MonsterInstance.create(_make_config("a", 50, 30, 10, 20), 1)
	var defender := MonsterInstance.create(_make_config("b", 50, 20, 10, 20), 1)
	var move := _make_move("hit", 20)

	var dmg: int = TurnBased1v1._calculate_damage(attacker, move, defender)

	assert_int(dmg).is_equal(20)


func test_damage_formula_minimum_one() -> void:
	# Very high defense, low power -> still at least 1
	var attacker := MonsterInstance.create(_make_config("a", 50, 1, 1, 10), 1)
	var defender := MonsterInstance.create(_make_config("b", 50, 1, 999, 10), 1)
	var move := _make_move("hit", 1)

	var dmg: int = TurnBased1v1._calculate_damage(attacker, move, defender)

	assert_int(dmg).is_greater_equal(1)


# --- turn order ---

func test_faster_monster_deals_damage_first() -> void:
	var player := MonsterInstance.create(_make_config("player", 50, 100, 1, 100), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 1, 1, 1, 1), 1)
	var move_lib: Dictionary[String, MoveConfig] = {
		"big_hit": _make_move("big_hit", 100),
		"tiny_hit": _make_move("tiny_hit", 1),
	}
	player.config.move_ids = ["big_hit"]
	enemy.config.move_ids = ["tiny_hit"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var state: BattleState = TurnBased1v1.new().run(player, enemy, move_lib, rng)

	assert_str(state.winner_id).is_equal("player")
	assert_int(state.turn).is_equal(1)


func test_slower_monster_acts_second_in_turn() -> void:
	var player := MonsterInstance.create(_make_config("player", 100, 1, 50, 1), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 100, 1, 50, 100), 1)
	var damage_log: Array[String] = []
	var move_lib: Dictionary[String, MoveConfig] = {
		"attack": _make_move("attack", 10),
	}
	player.config.move_ids = ["attack"]
	enemy.config.move_ids = ["attack"]

	var battle := TurnBased1v1.new()
	battle.damage_dealt.connect(func(name: String, _amt: int, _hp: int, _max: int) -> void:
		if damage_log.is_empty():
			damage_log.append(name)
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	battle.run(player, enemy, move_lib, rng)

	assert_str(damage_log[0]).is_equal("Player")


# --- move effects ---

func test_heal_effect_restores_hp() -> void:
	var actor := MonsterInstance.create(_make_config("a", 100, 10, 10, 10), 1)
	actor.apply_damage(50)
	var target := MonsterInstance.create(_make_config("b", 100, 10, 10, 10), 1)
	var move_lib: Dictionary[String, MoveConfig] = {
		"heal": _make_heal_move("heal", 20),
		"filler": _make_move("filler", 1),
	}
	actor.config.move_ids = ["heal"]
	target.config.move_ids = ["filler"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	TurnBased1v1.new().run(actor, target, move_lib, rng)

	assert_bool(actor.current_hp > 50).is_true()


# --- stat stage reset ---

func test_stat_stages_reset_at_battle_start() -> void:
	var player := MonsterInstance.create(_make_config("player", 50, 10, 10, 20), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 50, 10, 10, 20), 1)
	player.modify_stat_stage("speed", 6)
	var move_lib: Dictionary[String, MoveConfig] = {
		"hit": _make_move("hit", 5),
	}
	player.config.move_ids = ["hit"]
	enemy.config.move_ids = ["hit"]

	TurnBased1v1.new().run(player, enemy, move_lib)

	assert_bool(player.get_stat_stage("speed") != 6).is_true()


# --- win condition ---

func test_winner_id_set_when_enemy_faints() -> void:
	var player := MonsterInstance.create(_make_config("the_winner", 9999, 100, 1, 50), 1)
	var enemy := MonsterInstance.create(_make_config("the_loser", 1, 1, 1, 1), 1)
	var move_lib: Dictionary[String, MoveConfig] = {
		"nuke": _make_move("nuke", 100),
		"tickle": _make_move("tickle", 1),
	}
	player.config.move_ids = ["nuke"]
	enemy.config.move_ids = ["tickle"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var state: BattleState = TurnBased1v1.new().run(player, enemy, move_lib, rng)

	assert_str(state.winner_id).is_equal("the_winner")
	assert_bool(state.is_active).is_false()


func test_fainted_monster_does_not_act_after_fainting() -> void:
	var player := MonsterInstance.create(_make_config("player", 9999, 100, 1, 100), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 1, 999, 1, 1), 1)
	var player_damage_taken: int = 0
	var move_lib: Dictionary[String, MoveConfig] = {
		"nuke": _make_move("nuke", 100),
	}
	player.config.move_ids = ["nuke"]
	enemy.config.move_ids = ["nuke"]

	var battle := TurnBased1v1.new()
	battle.damage_dealt.connect(func(name: String, amt: int, _hp: int, _max: int) -> void:
		if name == "player":
			player_damage_taken += amt
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	battle.run(player, enemy, move_lib, rng)

	assert_int(player_damage_taken).is_equal(0)


func test_combat_log_has_entries() -> void:
	var player := MonsterInstance.create(_make_config("a", 50, 20, 10, 20), 1)
	var enemy := MonsterInstance.create(_make_config("b", 50, 20, 10, 20), 1)
	var move_lib: Dictionary[String, MoveConfig] = {
		"hit": _make_move("hit", 5),
	}
	player.config.move_ids = ["hit"]
	enemy.config.move_ids = ["hit"]

	var state: BattleState = TurnBased1v1.new().run(player, enemy, move_lib)

	assert_bool(state.combat_log.size() > 0).is_true()


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


func _make_move(id: String, power: int) -> MoveConfig:
	var move := MoveConfig.new()
	move.id = id
	move.display_name = id.capitalize()
	move.type_tag = TypeTag.Type.NORMAL
	move.move_power = power
	move.accuracy = 1.0
	if power > 0:
		move.damage_formula = "move_power * caster.attack / target.defense"
	return move


func _make_heal_move(id: String, heal_amount: int) -> MoveConfig:
	var move := MoveConfig.new()
	move.id = id
	move.display_name = id.capitalize()
	move.type_tag = TypeTag.Type.NORMAL
	move.move_power = heal_amount
	move.accuracy = 1.0
	move.heal_formula = "move_power"
	move.target_mode = MoveConfig.TargetType.SELF
	var override := NodeOverrideEntry.new()
	override.node_id = "ACCURACY_CHECK"
	override.override_tag = "always_hit"
	move.node_overrides = [override]
	return move
