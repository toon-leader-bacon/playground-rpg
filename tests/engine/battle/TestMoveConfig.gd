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
	var override := NodeOverrideEntry.new()
	override.node_id = "ACCURACY_CHECK"
	override.override_tag = "always_hit"
	move.node_overrides = [override]

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_str(restored.id).is_equal("heal")
	assert_str(restored.heal_formula).is_equal("target.max_hp * 0.5")
	assert_int(restored.target_mode).is_equal(MoveConfig.TargetType.SELF)
	assert_int(restored.node_overrides.size()).is_equal(1)
	assert_str(restored.node_overrides[0].override_tag).is_equal("always_hit")


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


# --- EdgeOverrideEntry serialize / deserialize ---

func test_edge_override_entry_round_trip() -> void:
	var entry := EdgeOverrideEntry.new()
	entry.from_node = "APPLY_POST_EFFECTS"
	entry.to_node = "APPLY_PRE_EFFECTS"
	entry.condition_tag = "triple_kick_loop"
	entry.args = {"key": "value"}

	var restored: EdgeOverrideEntry = EdgeOverrideEntry.deserialize(entry.serialize())

	assert_str(restored.from_node).is_equal("APPLY_POST_EFFECTS")
	assert_str(restored.to_node).is_equal("APPLY_PRE_EFFECTS")
	assert_str(restored.condition_tag).is_equal("triple_kick_loop")
	assert_str(restored.args.get("key", "") as String).is_equal("value")


func test_edge_override_entry_deep_copy_isolation() -> void:
	var entry := EdgeOverrideEntry.new()
	entry.from_node = "A"
	entry.to_node = "B"
	entry.args = {"x": 1}

	var copy: EdgeOverrideEntry = entry.deep_copy()
	copy.from_node = "Z"
	copy.args["x"] = 99

	assert_str(entry.from_node).is_equal("A")
	assert_int(entry.args.get("x", -1) as int).is_equal(1)


func test_edge_override_entry_deserialize_defaults() -> void:
	var entry: EdgeOverrideEntry = EdgeOverrideEntry.deserialize({})

	assert_str(entry.from_node).is_equal("")
	assert_str(entry.to_node).is_equal("")
	assert_str(entry.condition_tag).is_equal("")


func test_move_tags_default_empty() -> void:
	var move := MoveConfig.new()

	assert_int(move.move_tags.size()).is_equal(0)


func test_move_tags_round_trip() -> void:
	var move := MoveConfig.new()
	move.id = "blizzard"
	move.move_tags = ["magic", "ice"]

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_int(restored.move_tags.size()).is_equal(2)
	assert_bool(restored.move_tags.has("magic")).is_true()
	assert_bool(restored.move_tags.has("ice")).is_true()


func test_move_config_edge_overrides_round_trip() -> void:
	var entry := EdgeOverrideEntry.new()
	entry.from_node = "APPLY_POST_EFFECTS"
	entry.to_node = "APPLY_PRE_EFFECTS"
	entry.condition_tag = "triple_kick_loop"
	var move := MoveConfig.new()
	move.id = "triple_kick"
	move.edge_overrides = [entry]

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_int(restored.edge_overrides.size()).is_equal(1)
	assert_str(restored.edge_overrides[0].from_node).is_equal("APPLY_POST_EFFECTS")
	assert_str(restored.edge_overrides[0].to_node).is_equal("APPLY_PRE_EFFECTS")
	assert_str(restored.edge_overrides[0].condition_tag).is_equal("triple_kick_loop")
