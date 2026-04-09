extends GdUnitTestSuite


func test_collide_handler_fires_on_player_collide() -> void:
	var fired: Array[bool] = [false]
	var c := TileCollidable.new()
	c.set_handler(func(_p: Node2D) -> void: fired[0] = true)

	c.on_player_collide(Node2D.new())

	assert_bool(fired[0]).is_true()


func test_enter_handler_fires_on_player_enter() -> void:
	var fired: Array[bool] = [false]
	var c := TileCollidable.new()
	c.set_enter_handler(func(_p: Node2D) -> void: fired[0] = true)

	c.on_player_enter(Node2D.new())

	assert_bool(fired[0]).is_true()


func test_exit_handler_fires_on_player_exit() -> void:
	var fired: Array[bool] = [false]
	var c := TileCollidable.new()
	c.set_exit_handler(func(_p: Node2D) -> void: fired[0] = true)

	c.on_player_exit(Node2D.new())

	assert_bool(fired[0]).is_true()


func test_no_crash_when_no_handlers_set() -> void:
	var c := TileCollidable.new()
	var player := Node2D.new()

	# None of these should error
	c.on_player_collide(player)
	c.on_player_enter(player)
	c.on_player_exit(player)

	assert_bool(true).is_true()


func test_collide_does_not_trigger_enter_or_exit() -> void:
	var enter_fired: Array[bool] = [false]
	var exit_fired: Array[bool] = [false]
	var c := TileCollidable.new()
	c.set_enter_handler(func(_p: Node2D) -> void: enter_fired[0] = true)
	c.set_exit_handler(func(_p: Node2D) -> void: exit_fired[0] = true)

	c.on_player_collide(Node2D.new())

	assert_bool(enter_fired[0]).is_false()
	assert_bool(exit_fired[0]).is_false()
