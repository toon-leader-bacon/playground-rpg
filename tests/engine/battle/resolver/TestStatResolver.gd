extends GdUnitTestSuite

const _StatResolver = preload("res://engine/battle/resolver/StatResolver.gd")
const _BattleStateNvM = preload("res://engine/battle/model/BattleStateNvM.gd")


func test_resolve_base_stat() -> void:
	var config := _make_config("a", 50, 30, 20, 15, 25, 20)
	var instance := MonsterInstance.create(config, 1)

	var val: float = _StatResolver.resolve("attack", config, instance, null)

	assert_float(val).is_equal_approx(30.0, 0.001)


func test_resolve_includes_level_scaling() -> void:
	var config := _make_config("a", 50, 10, 10, 10, 10, 10)
	var instance := MonsterInstance.create(config, 5)

	# attack level scale: base + (level - 1) * 1 = 10 + 4 = 14
	var val: float = _StatResolver.resolve("attack", config, instance, null)

	assert_float(val).is_equal_approx(14.0, 0.001)


func test_resolve_applies_positive_stat_stage() -> void:
	var config := _make_config("a", 50, 20, 10, 10, 10, 10)
	var instance := MonsterInstance.create(config, 1)
	instance.modify_stat_stage("attack", 2)

	# stage +2: value * (2+2)/2 = 20 * 2.0 = 40
	var val: float = _StatResolver.resolve("attack", config, instance, null)

	assert_float(val).is_equal_approx(40.0, 0.001)


func test_resolve_applies_negative_stat_stage() -> void:
	var config := _make_config("a", 50, 20, 10, 10, 10, 10)
	var instance := MonsterInstance.create(config, 1)
	instance.modify_stat_stage("attack", -2)

	# stage -2: value * 2 / (2 + 2) = 20 * 0.5 = 10
	var val: float = _StatResolver.resolve("attack", config, instance, null)

	assert_float(val).is_equal_approx(10.0, 0.001)


func test_resolve_applies_condition_modifier() -> void:
	var config := _make_config("a", 50, 60, 10, 10, 10, 10)
	var instance := MonsterInstance.create(config, 1)
	instance.add_condition_modifier("attack", 0.5, "burn")

	var val: float = _StatResolver.resolve("attack", config, instance, null)

	assert_float(val).is_equal_approx(30.0, 0.001)


func test_resolve_floors_at_one() -> void:
	var config := _make_config("a", 10, 1, 1, 1, 1, 1)
	var instance := MonsterInstance.create(config, 1)
	instance.modify_stat_stage("attack", -6)
	instance.add_condition_modifier("attack", 0.01, "debuff")

	var val: float = _StatResolver.resolve("attack", config, instance, null)

	assert_float(val).is_greater_equal(1.0)


func test_build_context_includes_all_stat_keys() -> void:
	var config := _make_config("a", 50, 30, 20, 15, 25, 20)
	var instance := MonsterInstance.create(config, 1)

	var ctx: Dictionary = _StatResolver.build_context(config, instance, null)

	assert_bool(ctx.has("attack")).is_true()
	assert_bool(ctx.has("defense")).is_true()
	assert_bool(ctx.has("speed")).is_true()
	assert_bool(ctx.has("special_attack")).is_true()
	assert_bool(ctx.has("special_defense")).is_true()
	assert_bool(ctx.has("max_hp")).is_true()
	assert_bool(ctx.has("hp")).is_true()
	assert_bool(ctx.has("buff_count")).is_true()
	assert_bool(ctx.has("crit_rate")).is_true()


func test_build_context_hp_is_current_hp() -> void:
	var config := _make_config("a", 100, 10, 10, 10, 10, 10)
	var instance := MonsterInstance.create(config, 1)
	instance.apply_damage(40)

	var ctx: Dictionary = _StatResolver.build_context(config, instance, null)

	assert_float(ctx["hp"] as float).is_equal_approx(60.0, 0.001)
	assert_float(ctx["max_hp"] as float).is_equal_approx(100.0, 0.001)


func test_build_context_buff_count_sums_positive_stages() -> void:
	var config := _make_config("a", 50, 10, 10, 10, 10, 10)
	var instance := MonsterInstance.create(config, 1)
	instance.modify_stat_stage("attack", 2)
	instance.modify_stat_stage("defense", 1)
	instance.modify_stat_stage("speed", -1)  # negative should not count

	var ctx: Dictionary = _StatResolver.build_context(config, instance, null)

	assert_float(ctx["buff_count"] as float).is_equal_approx(3.0, 0.001)


func _make_config(id: String, hp: int, atk: int, def_val: int, spd: int, sp_atk: int, sp_def: int) -> MonsterConfig:
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
	return config
