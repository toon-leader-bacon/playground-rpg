extends GdUnitTestSuite


# --- serialize / deserialize ---

func test_serialize_damage_move_round_trip() -> void:
	# Step 1: set up inputs
	var move := MoveConfig.new()
	move.id = "ember"
	move.display_name = "Ember"
	move.type_tag = TypeTag.Type.FIRE
	move.power = 25
	move.accuracy = 0.9
	move.effect = MoveConfig.Effect.NONE
	move.target_type = MoveConfig.TargetType.SINGLE_ENEMY

	# Step 2: run code under test
	var data: Dictionary = move.serialize()
	var restored: MoveConfig = MoveConfig.deserialize(data)

	# Step 3: validate output
	assert_str(restored.id).is_equal("ember")
	assert_str(restored.display_name).is_equal("Ember")
	assert_int(restored.type_tag).is_equal(TypeTag.Type.FIRE)
	assert_int(restored.power).is_equal(25)
	assert_float(restored.accuracy).is_equal_approx(0.9, 0.001)
	assert_int(restored.effect).is_equal(MoveConfig.Effect.NONE)
	assert_int(restored.target_type).is_equal(MoveConfig.TargetType.SINGLE_ENEMY)


func test_target_type_self_round_trips() -> void:
	var move := MoveConfig.new()
	move.id = "recover"
	move.effect = MoveConfig.Effect.HEAL
	move.target_type = MoveConfig.TargetType.SELF

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_int(restored.target_type).is_equal(MoveConfig.TargetType.SELF)


func test_target_type_defaults_to_single_enemy() -> void:
	var restored: MoveConfig = MoveConfig.deserialize({})

	assert_int(restored.target_type).is_equal(MoveConfig.TargetType.SINGLE_ENEMY)


func test_serialize_heal_move_round_trip() -> void:
	var move := MoveConfig.new()
	move.id = "recover"
	move.effect = MoveConfig.Effect.HEAL
	move.power = 30

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_str(restored.id).is_equal("recover")
	assert_int(restored.effect).is_equal(MoveConfig.Effect.HEAL)
	assert_int(restored.power).is_equal(30)


func test_serialize_buff_speed_self_round_trip() -> void:
	var move := MoveConfig.new()
	move.id = "quick_step"
	move.effect = MoveConfig.Effect.BUFF_SPEED_SELF

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_int(restored.effect).is_equal(MoveConfig.Effect.BUFF_SPEED_SELF)


func test_serialize_debuff_speed_target_round_trip() -> void:
	var move := MoveConfig.new()
	move.id = "slow_down"
	move.effect = MoveConfig.Effect.DEBUFF_SPEED_TARGET

	var restored: MoveConfig = MoveConfig.deserialize(move.serialize())

	assert_int(restored.effect).is_equal(MoveConfig.Effect.DEBUFF_SPEED_TARGET)


func test_deserialize_uses_defaults_for_missing_keys() -> void:
	var restored: MoveConfig = MoveConfig.deserialize({})

	assert_str(restored.id).is_equal("")
	assert_int(restored.power).is_equal(0)
	assert_float(restored.accuracy).is_equal_approx(1.0, 0.001)
	assert_int(restored.effect).is_equal(MoveConfig.Effect.NONE)


# --- deserialize_update ---

func test_deserialize_update_modifies_fields_in_place() -> void:
	var move := MoveConfig.new()
	move.id = "old_id"
	move.power = 10

	move.deserialize_update({"id": "new_id", "power": 20})

	assert_str(move.id).is_equal("new_id")
	assert_int(move.power).is_equal(20)


func test_deserialize_update_preserves_untouched_fields() -> void:
	var move := MoveConfig.new()
	move.id = "my_move"
	move.accuracy = 0.8

	move.deserialize_update({"power": 15})

	assert_str(move.id).is_equal("my_move")
	assert_float(move.accuracy).is_equal_approx(0.8, 0.001)


# --- deep_copy ---

func test_deep_copy_produces_independent_instance() -> void:
	var original := MoveConfig.new()
	original.id = "ember"
	original.power = 25

	var copy: MoveConfig = original.deep_copy()
	copy.power = 99

	assert_int(original.power).is_equal(25)
	assert_int(copy.power).is_equal(99)
