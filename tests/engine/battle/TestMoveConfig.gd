extends GdUnitTestSuite


# --- serialize / deserialize ---

func test_serialize_damage_move_round_trip() -> void:
	var move := MoveConfig.new()
	move.id = "ember"
	move.display_name = "Ember"
	move.type_tag = TypeTag.Type.FIRE
	move.move_power = 40
	move.accuracy = 1.0
	move.target_mode = MoveConfig.TargetType.SINGLE_ENEMY
	move.damage_formula = "move_power * caster.special_attack / target.special_defense"

	var data: Dictionary = move.serialize()
	var restored: MoveConfig = MoveConfig.deserialize(data)

	assert_str(restored.id).is_equal("ember")
	assert_str(restored.display_name).is_equal("Ember")
	assert_int(restored.type_tag).is_equal(TypeTag.Type.FIRE)
	assert_int(restored.move_power).is_equal(40)
	assert_float(restored.accuracy).is_equal_approx(1.0, 0.001)
	assert_int(restored.target_mode).is_equal(MoveConfig.TargetType.SINGLE_ENEMY)
	assert_str(restored.damage_formula).is_equal("move_power * caster.special_attack / target.special_defense")


func test_serialize_heal_move_round_trip() -> void:
	var move := MoveConfig.new()
	move.id = "heal"
	move.heal_formula = "target.max_hp * 0.5"
	move.target_mode = MoveConfig.TargetType.SELF
	move.accuracy_node = "always_hit"

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_str(restored.id).is_equal("heal")
	assert_str(restored.heal_formula).is_equal("target.max_hp * 0.5")
	assert_int(restored.target_mode).is_equal(MoveConfig.TargetType.SELF)
	assert_str(restored.accuracy_node).is_equal("always_hit")


func test_target_mode_self_round_trips() -> void:
	var move := MoveConfig.new()
	move.id = "recover"
	move.target_mode = MoveConfig.TargetType.SELF

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_int(restored.target_mode).is_equal(MoveConfig.TargetType.SELF)


func test_target_mode_defaults_to_single_enemy() -> void:
	var restored: MoveConfig = MoveConfig.deserialize({})

	assert_int(restored.target_mode).is_equal(MoveConfig.TargetType.SINGLE_ENEMY)


func test_serialize_post_effects_round_trip() -> void:
	var entry := EffectEntry.new()
	entry.chance = 0.1
	entry.condition_id = "burn"
	entry.target = "target"
	var move := MoveConfig.new()
	move.id = "ember"
	move.post_effects = [entry]

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_int(restored.post_effects.size()).is_equal(1)
	assert_float(restored.post_effects[0].chance).is_equal_approx(0.1, 0.001)
	assert_str(restored.post_effects[0].condition_id).is_equal("burn")


func test_serialize_pre_effects_round_trip() -> void:
	var entry := EffectEntry.new()
	entry.chance = 1.0
	entry.condition_id = "weak"
	entry.if_crit = true
	var move := MoveConfig.new()
	move.id = "slash"
	move.pre_effects = [entry]

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_int(restored.pre_effects.size()).is_equal(1)
	assert_bool(restored.pre_effects[0].if_crit).is_true()


func test_deserialize_uses_defaults_for_missing_keys() -> void:
	var restored: MoveConfig = MoveConfig.deserialize({})

	assert_str(restored.id).is_equal("")
	assert_int(restored.move_power).is_equal(0)
	assert_float(restored.accuracy).is_equal_approx(1.0, 0.001)
	assert_str(restored.damage_formula).is_equal("")
	assert_str(restored.heal_formula).is_equal("")


func test_deserialize_update_modifies_fields_in_place() -> void:
	var move := MoveConfig.new()
	move.id = "old_id"
	move.move_power = 10

	move.deserialize_update({"id": "new_id", "move_power": 20})

	assert_str(move.id).is_equal("new_id")
	assert_int(move.move_power).is_equal(20)


func test_deserialize_update_preserves_untouched_fields() -> void:
	var move := MoveConfig.new()
	move.id = "my_move"
	move.accuracy = 0.8

	move.deserialize_update({"move_power": 15})

	assert_str(move.id).is_equal("my_move")
	assert_float(move.accuracy).is_equal_approx(0.8, 0.001)


func test_deep_copy_produces_independent_instance() -> void:
	var original := MoveConfig.new()
	original.id = "ember"
	original.move_power = 40

	var copy: MoveConfig = original.deep_copy()
	copy.move_power = 99

	assert_int(original.move_power).is_equal(40)
	assert_int(copy.move_power).is_equal(99)


func test_crit_rate_formula_round_trip() -> void:
	var move := MoveConfig.new()
	move.crit_rate_formula = "caster.crit_rate + 0.25"

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_str(restored.crit_rate_formula).is_equal("caster.crit_rate + 0.25")


func test_pp_defaults_to_10() -> void:
	var move := MoveConfig.new()

	assert_int(move.pp).is_equal(10)
