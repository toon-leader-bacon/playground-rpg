extends GdUnitTestSuite
## Tests that each move .tres in content/moves/ loads correctly through ConfigLoader.


func test_load_ember() -> void:
	var move: MoveConfig = ConfigLoader.load_move("ember")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("ember")
	assert_str(move.display_name).is_equal("Ember")
	assert_int(move.type_tag).is_equal(TypeTag.Type.FIRE)
	assert_int(move.power).is_equal(25)
	assert_float(move.accuracy).is_equal_approx(0.9, 0.001)
	assert_int(move.effect).is_equal(MoveConfig.Effect.NONE)


func test_load_scratch() -> void:
	var move: MoveConfig = ConfigLoader.load_move("scratch")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("scratch")
	assert_int(move.power).is_equal(15)
	assert_float(move.accuracy).is_equal_approx(1.0, 0.001)
	assert_int(move.effect).is_equal(MoveConfig.Effect.NONE)


func test_load_rock_slam() -> void:
	var move: MoveConfig = ConfigLoader.load_move("rock_slam")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("rock_slam")
	assert_int(move.power).is_equal(20)
	assert_int(move.effect).is_equal(MoveConfig.Effect.NONE)


func test_load_recover() -> void:
	var move: MoveConfig = ConfigLoader.load_move("recover")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("recover")
	assert_int(move.power).is_equal(30)
	assert_int(move.effect).is_equal(MoveConfig.Effect.HEAL)


func test_load_quick_step() -> void:
	var move: MoveConfig = ConfigLoader.load_move("quick_step")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("quick_step")
	assert_int(move.power).is_equal(0)
	assert_int(move.effect).is_equal(MoveConfig.Effect.BUFF_SPEED_SELF)


func test_load_slow_down() -> void:
	var move: MoveConfig = ConfigLoader.load_move("slow_down")

	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("slow_down")
	assert_int(move.power).is_equal(0)
	assert_int(move.effect).is_equal(MoveConfig.Effect.DEBUFF_SPEED_TARGET)
