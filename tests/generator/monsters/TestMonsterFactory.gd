extends GdUnitTestSuite


func test_build_produces_config_with_correct_fields() -> void:
	# Step 1: set up inputs
	var factory := MonsterFactory.new()
	var stats := factory.build_stats(45, 60, 30, 65)

	# Step 2: run code under test
	var config := factory.build(
		"fire_lizard",
		"Fire Lizard",
		[TypeTag.Type.FIRE],
		stats,
		["ember", "scratch"]
	)

	# Step 3: validate output
	assert_str(config.id).is_equal("fire_lizard")
	assert_str(config.display_name).is_equal("Fire Lizard")
	assert_int(config.type_tags[0]).is_equal(TypeTag.Type.FIRE)
	assert_int(config.base_stats.max_hp).is_equal(45)
	assert_int(config.base_stats.attack).is_equal(60)
	assert_int(config.move_ids.size()).is_equal(2)
	assert_str(config.move_ids[0]).is_equal("ember")


func test_build_uses_default_ai_style() -> void:
	var factory := MonsterFactory.new()
	var stats := factory.build_stats(30, 20, 20, 20)

	var config := factory.build("test", "Test", [TypeTag.Type.NORMAL], stats, [])

	assert_int(config.ai_style).is_equal(MonsterConfig.AIStyle.RANDOM)


func test_build_uses_default_xp_and_weight() -> void:
	var factory := MonsterFactory.new()
	var stats := factory.build_stats(30, 20, 20, 20)

	var config := factory.build("test", "Test", [TypeTag.Type.NORMAL], stats, [])

	assert_int(config.base_xp_yield).is_equal(10)
	assert_float(config.encounter_weight).is_equal(1.0)


func test_build_respects_custom_xp_and_weight() -> void:
	var factory := MonsterFactory.new()
	var stats := factory.build_stats(30, 20, 20, 20)

	var config := factory.build(
		"rare_enemy", "Rare Enemy",
		[TypeTag.Type.NORMAL], stats, [],
		MonsterConfig.AIStyle.RANDOM, 100, 0.1
	)

	assert_int(config.base_xp_yield).is_equal(100)
	assert_float(config.encounter_weight).is_equal_approx(0.1, 0.001)


func test_build_stats_sets_all_fields() -> void:
	var factory := MonsterFactory.new()

	var stats := factory.build_stats(80, 55, 70, 20)

	assert_int(stats.max_hp).is_equal(80)
	assert_int(stats.attack).is_equal(55)
	assert_int(stats.defense).is_equal(70)
	assert_int(stats.speed).is_equal(20)


func test_factory_accepts_custom_rng() -> void:
	# Step 1: set up mocks
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Step 2: set up inputs
	var factory := MonsterFactory.new(rng)
	var stats := factory.build_stats(30, 20, 20, 20)

	# Step 3: run code under test
	var config := factory.build("test", "Test", [TypeTag.Type.NORMAL], stats, [])

	# Step 4: validate output
	assert_str(config.id).is_equal("test")

	# Step 5: validate mocks (rng was accepted — no error)
	assert_object(factory.rng).is_same(rng)


func test_built_config_can_create_monster_instance() -> void:
	var factory := MonsterFactory.new()
	var stats := factory.build_stats(60, 40, 35, 50)
	var config := factory.build("test", "Test", [TypeTag.Type.WATER], stats, ["splash"])

	var inst := MonsterInstance.create(config, 5)

	assert_int(inst.current_hp).is_equal(inst.max_hp())
	assert_bool(inst.is_fainted()).is_false()
