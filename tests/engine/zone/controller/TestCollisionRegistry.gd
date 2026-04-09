extends GdUnitTestSuite

# CollisionRegistry uses a static var that persists across tests.
# All tags in this file use a unique prefix ("test_cr_") to avoid
# colliding with tags registered by other test suites or the engine.


func test_register_and_create_returns_collidable() -> void:
	CollisionRegistry.register("test_cr_basic", func(_config: Array) -> TileCollidable:
		return TileCollidable.new()
	)

	var result: TileCollidable = CollisionRegistry.create("test_cr_basic", [])

	assert_object(result).is_not_null()
	assert_bool(result is TileCollidable).is_true()


func test_create_unknown_tag_returns_null() -> void:
	var result: TileCollidable = CollisionRegistry.create("test_cr_definitely_not_registered", [])

	assert_object(result).is_null()


func test_create_empty_tag_returns_null() -> void:
	var result: TileCollidable = CollisionRegistry.create("", [])

	assert_object(result).is_null()


func test_config_is_passed_to_factory() -> void:
	var received_config: Array[Array] = [[]]
	CollisionRegistry.register("test_cr_config", func(config: Array) -> TileCollidable:
		received_config[0] = config
		return TileCollidable.new()
	)

	CollisionRegistry.create("test_cr_config", ["hello", 42])

	assert_int(received_config[0].size()).is_equal(2)
	assert_str(received_config[0][0] as String).is_equal("hello")
	assert_int(received_config[0][1] as int).is_equal(42)


func test_registering_same_tag_twice_uses_second_factory() -> void:
	CollisionRegistry.register("test_cr_overwrite", func(_config: Array) -> TileCollidable:
		return TileCollidable.new()
	)
	CollisionRegistry.register("test_cr_overwrite", func(_config: Array) -> TileCollidable:
		return BonkCounterCollidable.new()
	)

	var result: TileCollidable = CollisionRegistry.create("test_cr_overwrite", [])

	assert_bool(result is BonkCounterCollidable).is_true()
