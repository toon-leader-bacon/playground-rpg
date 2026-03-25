extends GdUnitTestSuite
## Tests that each move .tres in content/moves/ loads correctly through ConfigLoader.


func test_load_ember() -> void:
	var move: MoveConfig = ConfigLoader.load_move("ember")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("ember")
	assert_str(move.display_name).is_equal("Ember")
	assert_int(move.type_tag).is_equal(TypeTag.Type.FIRE)
	assert_int(move.move_power).is_equal(40)
	assert_float(move.accuracy).is_equal_approx(1.0, 0.001)
	assert_int(move.post_effects.size()).is_equal(1)
	assert_str(move.post_effects[0].condition_id).is_equal("burn")


func test_load_scratch() -> void:
	var move: MoveConfig = ConfigLoader.load_move("scratch")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("scratch")
	assert_int(move.move_power).is_equal(40)
	assert_float(move.accuracy).is_equal_approx(1.0, 0.001)
	assert_str(move.damage_formula).is_not_empty()


func test_load_rock_slam() -> void:
	var move: MoveConfig = ConfigLoader.load_move("rock_slam")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("rock_slam")
	assert_int(move.move_power).is_equal(65)
	assert_str(move.damage_formula).is_not_empty()


func test_load_recover() -> void:
	var move: MoveConfig = ConfigLoader.load_move("recover")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("recover")
	assert_int(move.move_power).is_equal(0)
	assert_str(move.heal_formula).is_not_empty()
	assert_int(move.node_overrides.size()).is_equal(1)
	assert_str(move.node_overrides[0].override_tag).is_equal("always_hit")
	assert_int(move.target_mode).is_equal(MoveConfig.TargetType.SELF)


func test_load_quick_step() -> void:
	var move: MoveConfig = ConfigLoader.load_move("quick_step")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("quick_step")
	assert_int(move.post_effects.size()).is_equal(1)
	assert_str(move.post_effects[0].condition_id).is_equal("speed_up_1")


func test_load_slow_down() -> void:
	var move: MoveConfig = ConfigLoader.load_move("slow_down")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("slow_down")
	assert_int(move.post_effects.size()).is_equal(1)
	assert_str(move.post_effects[0].condition_id).is_equal("speed_down_1")
