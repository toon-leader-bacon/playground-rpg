extends GdUnitTestSuite

const _NodeRegistry = preload("res://engine/battle/resolver/NodeRegistry.gd")
const _PipelineContext = preload("res://engine/battle/model/PipelineContext.gd")
const _BattleStateNvM = preload("res://engine/battle/model/BattleStateNvM.gd")


func test_always_hit_forces_hit_true() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.hit = false
	ctx.rng = RandomNumberGenerator.new()
	ctx.battle_state = null

	var fn: Callable = reg.get_node("always_hit")
	assert_bool(fn.is_valid()).is_true()
	fn.call(ctx, {})

	assert_bool(ctx.hit).is_true()


func test_always_hit_bypasses_accuracy_regardless_of_rng() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()

	for seed_val: int in [0, 42, 999, 12345]:
		var ctx := _PipelineContext.new()
		ctx.hit = false
		ctx.rng = RandomNumberGenerator.new()
		ctx.rng.seed = seed_val
		ctx.battle_state = null
		var fn: Callable = reg.get_node("always_hit")
		fn.call(ctx, {})
		assert_bool(ctx.hit).is_true()


func test_weather_accuracy_returns_invalid_for_unknown_tag() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var fn: Callable = reg.get_node("nonexistent_tag")

	assert_bool(fn.is_valid()).is_false()


func test_weather_accuracy_always_hits_in_hail() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var state: BattleStateNvM = _BattleStateNvM.new()
	state.weather = WeatherType.Type.HAIL

	var args: Dictionary = {"entries": [
		{"weather": WeatherType.Type.HAIL, "accuracy_formula": "100.0"},
		{"weather": WeatherType.Type.SUN, "accuracy_formula": "30.0"},
		{"weather": -1, "accuracy_formula": "70.0"},
	]}

	for i: int in range(20):
		var ctx := _PipelineContext.new()
		ctx.rng = RandomNumberGenerator.new()
		ctx.battle_state = state
		var fn: Callable = reg.get_node("weather_accuracy")
		fn.call(ctx, args)
		assert_bool(ctx.hit).is_true()


func test_register_custom_accuracy_node() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var called: Array = [false]
	reg.register_node("custom_node", func(ctx: PipelineContext, _args: Dictionary) -> void:
		ctx.hit = true
		called[0] = true
	)

	var ctx := _PipelineContext.new()
	ctx.hit = false
	var fn: Callable = reg.get_node("custom_node")
	fn.call(ctx, {})

	assert_bool(called[0]).is_true()
	assert_bool(ctx.hit).is_true()


# ============================================================
# Magnitude — declare node and damage node
# ============================================================

func test_magnitude_declare_callable_is_registered() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	assert_bool(reg.get_node("magnitude_declare").is_valid()).is_true()


func test_magnitude_damage_callable_is_registered() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	assert_bool(reg.get_node("magnitude_damage").is_valid()).is_true()


func test_magnitude_declare_writes_level_and_power_to_bb() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.rng = RandomNumberGenerator.new()

	reg.get_node("magnitude_declare").call(ctx, {})

	assert_bool(ctx.bb.has("magnitude.level")).is_true()
	assert_bool(ctx.bb.has("magnitude.power")).is_true()


func test_magnitude_declare_level_always_in_valid_range() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var valid_levels: Array[int] = [4, 5, 6, 7, 8, 9, 10]
	var fn: Callable = reg.get_node("magnitude_declare")

	for seed_val: int in range(60):
		var ctx := _PipelineContext.new()
		ctx.rng = RandomNumberGenerator.new()
		ctx.rng.seed = seed_val
		fn.call(ctx, {})
		var level: int = ctx.bb.read("magnitude.level", -1) as int
		assert_bool(valid_levels.has(level)).is_true()


func test_magnitude_declare_power_matches_level() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var level_to_power: Dictionary = {4: 10, 5: 30, 6: 50, 7: 70, 8: 90, 9: 110, 10: 150}
	var fn: Callable = reg.get_node("magnitude_declare")

	for seed_val: int in range(60):
		var ctx := _PipelineContext.new()
		ctx.rng = RandomNumberGenerator.new()
		ctx.rng.seed = seed_val
		fn.call(ctx, {})
		var level: int = ctx.bb.read("magnitude.level", -1) as int
		var power: int = ctx.bb.read("magnitude.power", -1) as int
		assert_int(power).is_equal(level_to_power.get(level, -1) as int)


func test_magnitude_damage_reads_power_from_bb() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.crit = false
	ctx.battle_state = null
	ctx.actor = _make_monster("a", 100, 50, 20, 30, 50, 20)
	ctx.target = _make_monster("b", 100, 20, 40, 30, 20, 40)
	ctx.bb.write("magnitude.power", 70)

	reg.get_node("magnitude_damage").call(ctx, {})

	# 70 * 50.0 / 40.0 = 87.5 → 87
	assert_int(ctx.damage_value).is_equal(87)


func test_magnitude_damage_applies_crit_multiplier() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()

	var base_ctx := _PipelineContext.new()
	base_ctx.crit = false
	base_ctx.battle_state = null
	base_ctx.actor = _make_monster("a", 100, 50, 20, 30, 50, 20)
	base_ctx.target = _make_monster("b", 100, 20, 40, 30, 20, 40)
	base_ctx.bb.write("magnitude.power", 70)

	var crit_ctx := _PipelineContext.new()
	crit_ctx.crit = true
	crit_ctx.battle_state = null
	crit_ctx.actor = _make_monster("a", 100, 50, 20, 30, 50, 20)
	crit_ctx.target = _make_monster("b", 100, 20, 40, 30, 20, 40)
	crit_ctx.bb.write("magnitude.power", 70)

	var fn: Callable = reg.get_node("magnitude_damage")
	fn.call(base_ctx, {})
	fn.call(crit_ctx, {})

	# base = 87, crit = int(87.5 * 1.5) = 131
	assert_int(base_ctx.damage_value).is_equal(87)
	assert_int(crit_ctx.damage_value).is_equal(131)


func test_magnitude_declare_unknown_tag_returns_invalid() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	assert_bool(reg.get_node("nonexistent_tag").is_valid()).is_false()


# ============================================================
# Fury Cutter — streak counter in actor.memory
# ============================================================

func test_fury_cutter_accuracy_callable_is_registered() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	assert_bool(reg.get_node("fury_cutter_accuracy").is_valid()).is_true()


func test_fury_cutter_damage_callable_is_registered() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	assert_bool(reg.get_node("fury_cutter_damage").is_valid()).is_true()


func test_fury_cutter_accuracy_resets_streak_on_miss() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.rng = RandomNumberGenerator.new()
	ctx.actor = _make_monster("a", 100, 50, 20, 30, 50, 20)
	ctx.actor.memory.write("fury_cutter.streak", 3)
	ctx.hit = false

	reg.get_node("fury_cutter_accuracy").call(ctx, {})

	assert_int(ctx.actor.memory.read("fury_cutter.streak", -1) as int).is_equal(0)


func test_fury_cutter_accuracy_does_not_reset_streak_on_hit() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.rng = RandomNumberGenerator.new()
	ctx.actor = _make_monster("a", 100, 50, 20, 30, 50, 20)
	ctx.actor.memory.write("fury_cutter.streak", 2)
	ctx.hit = true

	reg.get_node("fury_cutter_accuracy").call(ctx, {})

	assert_int(ctx.actor.memory.read("fury_cutter.streak", -1) as int).is_equal(2)


func test_fury_cutter_damage_streak_0_uses_power_10() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.crit = false
	ctx.battle_state = null
	ctx.actor = _make_monster("a", 100, 10, 20, 30, 10, 20)
	ctx.target = _make_monster("b", 100, 10, 10, 30, 10, 10)
	ctx.move = MoveConfig.new()
	ctx.actor.memory.write("fury_cutter.streak", 0)

	reg.get_node("fury_cutter_damage").call(ctx, {})

	# power = 10 * 2^0 = 10; 10 * 10.0 / 10.0 = 10
	assert_int(ctx.damage_value).is_equal(10)


func test_fury_cutter_damage_streak_2_uses_power_40() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.crit = false
	ctx.battle_state = null
	ctx.actor = _make_monster("a", 100, 10, 20, 30, 10, 20)
	ctx.target = _make_monster("b", 100, 10, 10, 30, 10, 10)
	ctx.move = MoveConfig.new()
	ctx.actor.memory.write("fury_cutter.streak", 2)

	reg.get_node("fury_cutter_damage").call(ctx, {})

	# power = 10 * 2^2 = 40; 40 * 10.0 / 10.0 = 40
	assert_int(ctx.damage_value).is_equal(40)


func test_fury_cutter_damage_increments_streak_after_use() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.crit = false
	ctx.battle_state = null
	ctx.actor = _make_monster("a", 100, 10, 20, 30, 10, 20)
	ctx.target = _make_monster("b", 100, 10, 10, 30, 10, 10)
	ctx.move = MoveConfig.new()
	ctx.actor.memory.write("fury_cutter.streak", 1)

	reg.get_node("fury_cutter_damage").call(ctx, {})

	assert_int(ctx.actor.memory.read("fury_cutter.streak", -1) as int).is_equal(2)


func test_fury_cutter_damage_streak_caps_at_4() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.crit = false
	ctx.battle_state = null
	ctx.actor = _make_monster("a", 100, 10, 20, 30, 10, 20)
	ctx.target = _make_monster("b", 100, 10, 10, 30, 10, 10)
	ctx.move = MoveConfig.new()
	ctx.actor.memory.write("fury_cutter.streak", 4)

	reg.get_node("fury_cutter_damage").call(ctx, {})

	# power = 10 * 2^4 = 160; streak stays at 4
	assert_int(ctx.actor.memory.read("fury_cutter.streak", -1) as int).is_equal(4)
	assert_int(ctx.damage_value).is_equal(160)


# ============================================================
# Supported Punch — shared power stack in field_bb
# ============================================================

func test_supported_punch_damage_callable_is_registered() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	assert_bool(reg.get_node("supported_punch_damage").is_valid()).is_true()


func test_supported_punch_damage_stack_0_uses_base_power() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var state: BattleStateNvM = _BattleStateNvM.new()
	var ctx := _PipelineContext.new()
	ctx.crit = false
	ctx.battle_state = state
	ctx.actor = _make_monster("a", 100, 10, 20, 30, 10, 20)
	ctx.target = _make_monster("b", 100, 10, 10, 30, 10, 10)
	ctx.move = MoveConfig.new()
	ctx.move.move_power = 50

	reg.get_node("supported_punch_damage").call(ctx, {})

	# power = 50 + 0 * 20 = 50; 50 * 10.0 / 10.0 = 50
	assert_int(ctx.damage_value).is_equal(50)


func test_supported_punch_damage_increments_stack_after_use() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var state: BattleStateNvM = _BattleStateNvM.new()
	var ctx := _PipelineContext.new()
	ctx.crit = false
	ctx.battle_state = state
	ctx.actor = _make_monster("a", 100, 10, 20, 30, 10, 20)
	ctx.target = _make_monster("b", 100, 10, 10, 30, 10, 10)
	ctx.move = MoveConfig.new()
	ctx.move.move_power = 50

	reg.get_node("supported_punch_damage").call(ctx, {})

	assert_int(state.field_bb.read("supported_punch.stacks", -1) as int).is_equal(1)


func test_supported_punch_damage_stack_2_increases_power() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var state: BattleStateNvM = _BattleStateNvM.new()
	state.field_bb.write("supported_punch.stacks", 2)
	var ctx := _PipelineContext.new()
	ctx.crit = false
	ctx.battle_state = state
	ctx.actor = _make_monster("a", 100, 10, 20, 30, 10, 20)
	ctx.target = _make_monster("b", 100, 10, 10, 30, 10, 10)
	ctx.move = MoveConfig.new()
	ctx.move.move_power = 50

	reg.get_node("supported_punch_damage").call(ctx, {})

	# power = 50 + 2 * 20 = 90; 90 * 10.0 / 10.0 = 90
	assert_int(ctx.damage_value).is_equal(90)


func test_supported_punch_damage_stack_caps_at_5() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var state: BattleStateNvM = _BattleStateNvM.new()
	state.field_bb.write("supported_punch.stacks", 5)
	var ctx := _PipelineContext.new()
	ctx.crit = false
	ctx.battle_state = state
	ctx.actor = _make_monster("a", 100, 10, 20, 30, 10, 20)
	ctx.target = _make_monster("b", 100, 10, 10, 30, 10, 10)
	ctx.move = MoveConfig.new()
	ctx.move.move_power = 50

	reg.get_node("supported_punch_damage").call(ctx, {})

	# stack capped: still 5 after use
	assert_int(state.field_bb.read("supported_punch.stacks", -1) as int).is_equal(5)


# ============================================================
# Triple Kick — init hook (node callable, stays in NodeRegistry)
# ============================================================

func test_triple_kick_init_callable_is_registered() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	assert_bool(reg.get_node("triple_kick_init").is_valid()).is_true()


func test_triple_kick_init_writes_hits_remaining_2() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()

	reg.get_node("triple_kick_init").call(ctx, {})

	assert_int(ctx.bb.read("triple_kick.hits_remaining", -1) as int).is_equal(2)


# ============================================================
# Helpers
# ============================================================

func _make_monster(
	id: String, hp: int, atk: int, def_val: int, spd: int, sp_atk: int, sp_def: int
) -> MonsterInstance:
	var config := MonsterConfig.new()
	config.id = id
	config.display_name = id.capitalize()
	var stats := StatBlock.new()
	stats.max_hp = hp
	stats.attack = atk
	stats.defense = def_val
	stats.speed = spd
	stats.special_attack = sp_atk
	stats.special_defense = sp_def
	config.base_stats = stats
	config.type_tags = [TypeTag.Type.NORMAL]
	config.ai_style = MonsterConfig.AIStyle.RANDOM
	return MonsterInstance.create(config, 1)
