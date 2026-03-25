extends GdUnitTestSuite
## Unit tests for MoveFactory — verifies each build method produces a correctly
## shaped MoveConfig with the expected formula, target mode, and field defaults.

const _MoveFactory = preload("res://generator/moves/MoveFactory.gd")


# ── build_physical_attack ─────────────────────────────────────────────────────

func test_physical_attack_id_and_name() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_physical_attack("test_id", "Test Move")
	assert_str(move.id).is_equal("test_id")
	assert_str(move.display_name).is_equal("Test Move")


func test_physical_attack_defaults() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_physical_attack("m", "M")
	assert_int(move.move_power).is_equal(40)
	assert_float(move.accuracy).is_equal_approx(1.0, 0.001)
	assert_int(move.pp).is_equal(20)
	assert_int(move.type_tag).is_equal(TypeTag.Type.NORMAL)
	assert_int(move.target_mode).is_equal(MoveConfig.TargetType.SINGLE_ENEMY)
	assert_str(move.crit_rate_formula).is_equal("")
	assert_int(move.post_effects.size()).is_equal(0)


func test_physical_attack_damage_formula_uses_attack_stats() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_physical_attack("m", "M")
	assert_bool(move.damage_formula.contains("caster.attack")).is_true()
	assert_bool(move.damage_formula.contains("target.defense")).is_true()
	assert_bool(move.damage_formula.contains("move_power")).is_true()


func test_physical_attack_custom_power_pp_accuracy() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_physical_attack("m", "M", 80, 0.85, 15)
	assert_int(move.move_power).is_equal(80)
	assert_float(move.accuracy).is_equal_approx(0.85, 0.001)
	assert_int(move.pp).is_equal(15)


func test_physical_attack_crit_rate_formula_applied() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_physical_attack("m", "M", 40, 1.0, 20,
			TypeTag.Type.NORMAL, [], "0.25")
	assert_str(move.crit_rate_formula).is_equal("0.25")


func test_physical_attack_post_effects_passed_through() -> void:
	var factory := _MoveFactory.new()
	var fx := EffectEntry.new()
	fx.chance = 0.3
	fx.condition_id = "burn"
	var move: MoveConfig = factory.build_physical_attack("m", "M", 40, 1.0, 20,
			TypeTag.Type.NORMAL, [fx])
	assert_int(move.post_effects.size()).is_equal(1)
	assert_float(move.post_effects[0].chance).is_equal_approx(0.3, 0.001)
	assert_str(move.post_effects[0].condition_id).is_equal("burn")


# ── build_special_attack ──────────────────────────────────────────────────────

func test_special_attack_formula_uses_special_stats() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_special_attack("m", "M")
	assert_bool(move.damage_formula.contains("caster.special_attack")).is_true()
	assert_bool(move.damage_formula.contains("target.special_defense")).is_true()


func test_special_attack_does_not_use_physical_stats() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_special_attack("m", "M")
	# Must not use the physical formula
	assert_bool(move.damage_formula.contains("caster.attack")).is_false()
	assert_bool(move.damage_formula.contains("target.defense")).is_false()


# ── build_status ──────────────────────────────────────────────────────────────

func test_status_move_has_zero_power_and_no_formula() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_status("sand_atk", "Sand Attack")
	assert_int(move.move_power).is_equal(0)
	assert_str(move.damage_formula).is_equal("")


func test_status_move_default_targets_single_enemy() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_status("s", "S")
	assert_int(move.target_mode).is_equal(MoveConfig.TargetType.SINGLE_ENEMY)


func test_status_move_custom_target_mode() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_status("s", "S", 1.0, 20,
			TypeTag.Type.NORMAL, MoveConfig.TargetType.SELF)
	assert_int(move.target_mode).is_equal(MoveConfig.TargetType.SELF)


# ── build_heal ────────────────────────────────────────────────────────────────

func test_heal_targets_self() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_heal("heal", "Heal")
	assert_int(move.target_mode).is_equal(MoveConfig.TargetType.SELF)


func test_heal_uses_always_hit_node() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_heal("heal", "Heal")
	assert_int(move.node_overrides.size()).is_equal(1)
	assert_str(move.node_overrides[0].override_tag).is_equal("always_hit")


func test_heal_formula_includes_max_hp_and_fraction() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_heal("heal", "Heal", 0.5)
	assert_bool(move.heal_formula.contains("target.max_hp")).is_true()
	assert_bool(move.heal_formula.contains("0.5")).is_true()


func test_heal_custom_fraction() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_heal("big_heal", "Big Heal", 0.75, 5)
	assert_bool(move.heal_formula.contains("0.75")).is_true()
	assert_int(move.pp).is_equal(5)


func test_heal_zero_move_power() -> void:
	var factory := _MoveFactory.new()
	var move: MoveConfig = factory.build_heal("heal", "Heal")
	assert_int(move.move_power).is_equal(0)
	assert_str(move.damage_formula).is_equal("")
