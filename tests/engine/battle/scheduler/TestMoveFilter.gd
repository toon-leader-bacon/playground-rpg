extends GdUnitTestSuite
## Unit tests for MoveFilter.build_available().

const _MoveFilter = preload("res://engine/battle/scheduler/MoveFilter.gd")


# ============================================================
# Helpers
# ============================================================

func _make_monster(move_ids: Array[String]) -> MonsterInstance:
	var config := MonsterConfig.new()
	config.id = "test_monster"
	config.display_name = "Test Monster"
	var stats := StatBlock.new()
	stats.max_hp = 100
	config.base_stats = stats
	config.move_ids = move_ids
	return MonsterInstance.create(config, 1)


func _make_move(id: String, tags: Array = []) -> MoveConfig:
	var m := MoveConfig.new()
	m.id = id
	m.display_name = id.capitalize()
	m.move_tags = tags
	m.accuracy = 1.0
	m.damage_formula = "move_power * caster.attack / target.defense"
	m.move_power = 10
	m.target_mode = MoveConfig.TargetType.SINGLE_ENEMY
	return m


func _make_condition(
	lock_id: String = "",
	denied_tags: Array = [],
	injected_id: String = ""
) -> Object:
	var cfg := ConditionConfig.new()
	cfg.id = "test_cond"
	cfg.action_lock_move_id = lock_id
	cfg.action_denied_tags = denied_tags
	cfg.action_injected_move_id = injected_id
	cfg.duration_type = ConditionConfig.DurationType.PERMANENT

	# Build a minimal ConditionInstance-like object by preloading the real one
	const _ConditionInstance = preload("res://engine/entities/model/ConditionInstance.gd")
	# We only need an object that exposes `config`; we do not call apply() in these tests
	var inst: Object = _ConditionInstance.new()
	inst.set("config", cfg)
	return inst


# ============================================================
# Tests
# ============================================================

func test_no_conditions_returns_full_moveset() -> void:
	var monster: MonsterInstance = _make_monster(["ember", "scratch"])
	var lib: Dictionary[String, MoveConfig] = {
		"ember": _make_move("ember"),
		"scratch": _make_move("scratch"),
	}

	var result: Array[String] = _MoveFilter.build_available(monster, lib)

	assert_int(result.size()).is_equal(2)
	assert_bool(result.has("ember")).is_true()
	assert_bool(result.has("scratch")).is_true()


func test_native_lock_in_returns_only_locked_move() -> void:
	var monster: MonsterInstance = _make_monster(["ember", "scratch", "heal"])
	var lib: Dictionary[String, MoveConfig] = {
		"ember": _make_move("ember"),
		"scratch": _make_move("scratch"),
		"heal": _make_move("heal"),
	}
	monster.active_conditions.append(_make_condition("scratch"))

	var result: Array[String] = _MoveFilter.build_available(monster, lib)

	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("scratch")


func test_injected_move_added_to_pool() -> void:
	var monster: MonsterInstance = _make_monster(["ember"])
	var injected := _make_move("bull_rush")
	var lib: Dictionary[String, MoveConfig] = {
		"ember": _make_move("ember"),
		"bull_rush": injected,
	}
	monster.active_conditions.append(_make_condition("", [], "bull_rush"))

	var result: Array[String] = _MoveFilter.build_available(monster, lib)

	assert_int(result.size()).is_equal(2)
	assert_bool(result.has("ember")).is_true()
	assert_bool(result.has("bull_rush")).is_true()


func test_injected_lock_in_wins_over_native_lock_in() -> void:
	# One condition injects "bull_rush" and locks to it; another locks to "ember".
	# Injected+lock condition is processed first so "bull_rush" lock wins.
	var monster: MonsterInstance = _make_monster(["ember", "scratch"])
	var lib: Dictionary[String, MoveConfig] = {
		"ember": _make_move("ember"),
		"scratch": _make_move("scratch"),
		"bull_rush": _make_move("bull_rush"),
	}
	# Injected lock — appended first so it is processed first
	monster.active_conditions.append(_make_condition("bull_rush", [], "bull_rush"))
	# Native lock
	monster.active_conditions.append(_make_condition("ember"))

	var result: Array[String] = _MoveFilter.build_available(monster, lib)

	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("bull_rush")


func test_denied_tag_removes_matching_moves() -> void:
	var monster: MonsterInstance = _make_monster(["fireball", "scratch"])
	var lib: Dictionary[String, MoveConfig] = {
		"fireball": _make_move("fireball", ["magic"]),
		"scratch": _make_move("scratch", ["physical"]),
	}
	monster.active_conditions.append(_make_condition("", ["magic"]))

	var result: Array[String] = _MoveFilter.build_available(monster, lib)

	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("scratch")


func test_denied_tags_do_not_remove_untagged_moves() -> void:
	var monster: MonsterInstance = _make_monster(["scratch", "status_move"])
	var lib: Dictionary[String, MoveConfig] = {
		"scratch": _make_move("scratch", ["physical"]),
		"status_move": _make_move("status_move"),  # no tags
	}
	monster.active_conditions.append(_make_condition("", ["magic"]))

	var result: Array[String] = _MoveFilter.build_available(monster, lib)

	assert_int(result.size()).is_equal(2)
	assert_bool(result.has("scratch")).is_true()
	assert_bool(result.has("status_move")).is_true()


func test_multiple_denied_tag_sets_unioned() -> void:
	var monster: MonsterInstance = _make_monster(["fireball", "thunder", "scratch"])
	var lib: Dictionary[String, MoveConfig] = {
		"fireball": _make_move("fireball", ["magic", "fire"]),
		"thunder": _make_move("thunder", ["magic", "electric"]),
		"scratch": _make_move("scratch", ["physical"]),
	}
	monster.active_conditions.append(_make_condition("", ["fire"]))
	monster.active_conditions.append(_make_condition("", ["electric"]))

	var result: Array[String] = _MoveFilter.build_available(monster, lib)

	# fireball has "fire" → denied; thunder has "electric" → denied; scratch survives
	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("scratch")


func test_all_moves_denied_returns_empty() -> void:
	var monster: MonsterInstance = _make_monster(["fireball", "thunder"])
	var lib: Dictionary[String, MoveConfig] = {
		"fireball": _make_move("fireball", ["magic"]),
		"thunder": _make_move("thunder", ["magic"]),
	}
	monster.active_conditions.append(_make_condition("", ["magic"]))

	var result: Array[String] = _MoveFilter.build_available(monster, lib)

	assert_int(result.size()).is_equal(0)


func test_multiple_native_lock_ins_first_wins() -> void:
	var monster: MonsterInstance = _make_monster(["ember", "scratch", "heal"])
	var lib: Dictionary[String, MoveConfig] = {
		"ember": _make_move("ember"),
		"scratch": _make_move("scratch"),
		"heal": _make_move("heal"),
	}
	monster.active_conditions.append(_make_condition("scratch"))
	monster.active_conditions.append(_make_condition("heal"))

	var result: Array[String] = _MoveFilter.build_available(monster, lib)

	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("scratch")
