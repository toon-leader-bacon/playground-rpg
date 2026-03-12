extends GdUnitTestSuite

const _BattleState = preload("res://engine/battle/model/BattleState.gd")
const _Action = preload("res://engine/battle/model/Action.gd")
const _SpeedOrderedActionRunner = preload("res://engine/battle/controller/SpeedOrderedActionRunner.gd")


func test_faster_actor_goes_first() -> void:
	# Fast player kills slow enemy (1 HP) before enemy acts
	var player := MonsterInstance.create(_make_config("player", 100, 100, 1, 100), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 1, 1, 1, 1), 1)
	var big_hit := _make_move("big_hit", 100, MoveConfig.Effect.NONE)
	var tiny_hit := _make_move("tiny_hit", 1, MoveConfig.Effect.NONE)

	var action_p: Action = _Action.create("player", "enemy", player, enemy, big_hit)
	var action_e: Action = _Action.create("enemy", "player", enemy, player, tiny_hit)

	# Array mutation for lambda capture
	var damage_log: Array[String] = []
	var runner: SpeedOrderedActionRunner = _SpeedOrderedActionRunner.new()
	runner.damage_dealt.connect(func(name: String, _a: int, _h: int, _m: int) -> void:
		damage_log.append(name)
	)

	var state := BattleState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var queue: Array[Action] = [action_p, action_e]
	runner.run(queue, state, rng)

	# Enemy had 1 HP so dies first; player should not have taken damage
	assert_str(damage_log[0]).is_equal("Enemy")
	assert_int(damage_log.size()).is_equal(1)


func test_fainted_actor_skipped() -> void:
	var player := MonsterInstance.create(_make_config("player", 100, 10, 1, 100), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 100, 10, 1, 1), 1)
	enemy.apply_damage(100)  # already fainted
	var hit := _make_move("hit", 10, MoveConfig.Effect.NONE)

	var action_e: Action = _Action.create("enemy", "player", enemy, player, hit)

	var damage_taken: Array = [0]
	var runner: SpeedOrderedActionRunner = _SpeedOrderedActionRunner.new()
	runner.damage_dealt.connect(func(_n: String, amt: int, _h: int, _m: int) -> void:
		damage_taken[0] += amt
	)

	var state := BattleState.new()
	var queue: Array[Action] = [action_e]
	runner.run(queue, state, RandomNumberGenerator.new())

	assert_int(damage_taken[0]).is_equal(0)


func test_signals_fired_for_damage() -> void:
	var attacker := MonsterInstance.create(_make_config("a", 100, 100, 1, 10), 1)
	var defender := MonsterInstance.create(_make_config("b", 100, 1, 1, 1), 1)
	var hit := _make_move("hit", 10, MoveConfig.Effect.NONE)
	var action: Action = _Action.create("a", "b", attacker, defender, hit)

	# Use arrays for lambda capture
	var flags: Array = [false, false]  # [move_used_fired, damage_fired]
	var runner: SpeedOrderedActionRunner = _SpeedOrderedActionRunner.new()
	runner.move_used.connect(func(_u: String, _m: String, _t: String) -> void:
		flags[0] = true
	)
	runner.damage_dealt.connect(func(_n: String, _a: int, _h: int, _mx: int) -> void:
		flags[1] = true
	)

	var state := BattleState.new()
	var queue: Array[Action] = [action]
	runner.run(queue, state, RandomNumberGenerator.new())

	assert_bool(flags[0]).is_true()
	assert_bool(flags[1]).is_true()


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
