extends GdUnitTestSuite
## Tests for ActionResolver — behavioral parity with TurnBased1v1 mechanics.

const _BattleState = preload("res://engine/battle/model/BattleState.gd")
const _Action = preload("res://engine/battle/model/Action.gd")
const _ActionResolver = preload("res://engine/battle/controller/ActionResolver.gd")


# --- damage formula ---

func test_damage_formula_basic() -> void:
	# max(1, 20 * 30 / (20 + 10)) = 20
	var attacker := MonsterInstance.create(_make_config("a", 50, 30, 10, 20), 1)
	var defender := MonsterInstance.create(_make_config("b", 50, 20, 10, 20), 1)
	var move := _make_move("hit", 20, MoveConfig.Effect.NONE)
	var action: Action = _Action.create("a", "b", attacker, defender, move)
	var state := BattleState.new()
	var rng := _seeded_rng(0)

	var result: ActionResult = _ActionResolver.apply(action, state, rng)

	assert_int(result.damage).is_equal(20)


func test_damage_formula_minimum_one() -> void:
	var attacker := MonsterInstance.create(_make_config("a", 50, 1, 1, 10), 1)
	var defender := MonsterInstance.create(_make_config("b", 50, 1, 999, 10), 1)
	var move := _make_move("hit", 1, MoveConfig.Effect.NONE)
	var action: Action = _Action.create("a", "b", attacker, defender, move)
	var state := BattleState.new()

	var result: ActionResult = _ActionResolver.apply(action, state, _seeded_rng(0))

	assert_int(result.damage).is_greater_equal(1)


func test_miss_on_accuracy() -> void:
	var attacker := MonsterInstance.create(_make_config("a", 50, 100, 1, 10), 1)
	var defender := MonsterInstance.create(_make_config("b", 50, 1, 1, 10), 1)
	var move := _make_move("miss", 100, MoveConfig.Effect.NONE)
	move.accuracy = 0.0  # Always misses
	var action: Action = _Action.create("a", "b", attacker, defender, move)
	var state := BattleState.new()
	var hp_before: int = defender.current_hp

	var result: ActionResult = _ActionResolver.apply(action, state, _seeded_rng(0))

	assert_bool(result.hit).is_false()
	assert_int(result.damage).is_equal(0)
	assert_int(defender.current_hp).is_equal(hp_before)


func test_heal_restores_hp() -> void:
	var actor := MonsterInstance.create(_make_config("a", 100, 10, 10, 10), 1)
	actor.apply_damage(50)
	var target := MonsterInstance.create(_make_config("b", 100, 10, 10, 10), 1)
	var move := _make_move("heal", 20, MoveConfig.Effect.HEAL)
	var action: Action = _Action.create("a", "b", actor, target, move)
	var state := BattleState.new()

	var result: ActionResult = _ActionResolver.apply(action, state, _seeded_rng(0))

	assert_int(result.healed).is_equal(20)
	assert_int(actor.current_hp).is_equal(70)


func test_buff_speed_self() -> void:
	var actor := MonsterInstance.create(_make_config("a", 100, 10, 10, 40), 1)
	var target := MonsterInstance.create(_make_config("b", 100, 10, 10, 10), 1)
	var move := _make_move("buff", 0, MoveConfig.Effect.BUFF_SPEED_SELF)
	var action: Action = _Action.create("a", "b", actor, target, move)
	var state := BattleState.new()

	var result: ActionResult = _ActionResolver.apply(action, state, _seeded_rng(0))

	assert_str(result.stat_name).is_equal("speed")
	assert_int(result.stat_delta).is_equal(1)
	assert_int(actor.get_stat_stage("speed")).is_equal(1)


func test_debuff_speed_target() -> void:
	var actor := MonsterInstance.create(_make_config("a", 100, 10, 10, 40), 1)
	var target := MonsterInstance.create(_make_config("b", 100, 10, 10, 40), 1)
	var move := _make_move("debuff", 0, MoveConfig.Effect.DEBUFF_SPEED_TARGET)
	var action: Action = _Action.create("a", "b", actor, target, move)
	var state := BattleState.new()

	var result: ActionResult = _ActionResolver.apply(action, state, _seeded_rng(0))

	assert_str(result.stat_name).is_equal("speed")
	assert_int(result.stat_delta).is_equal(-1)
	assert_int(target.get_stat_stage("speed")).is_equal(-1)


func test_fainted_flag_set_when_target_dies() -> void:
	var attacker := MonsterInstance.create(_make_config("a", 100, 999, 1, 10), 1)
	var defender := MonsterInstance.create(_make_config("b", 1, 1, 1, 10), 1)
	var move := _make_move("nuke", 100, MoveConfig.Effect.NONE)
	var action: Action = _Action.create("a", "b", attacker, defender, move)
	var state := BattleState.new()

	var result: ActionResult = _ActionResolver.apply(action, state, _seeded_rng(0))

	assert_bool(result.fainted).is_true()
	assert_bool(defender.is_fainted()).is_true()


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


func _seeded_rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng
