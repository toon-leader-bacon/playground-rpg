extends GdUnitTestSuite
## Verifies that .tres config files load correctly through ConfigLoader
## and produce resources with the expected values.


func test_load_fire_lizard_returns_non_null() -> void:
	var config := ConfigLoader.load_monster("fire_lizard")

	assert_object(config).is_not_null()


func test_fire_lizard_has_correct_id_and_name() -> void:
	var config := ConfigLoader.load_monster("fire_lizard")

	assert_str(config.id).is_equal("fire_lizard")
	assert_str(config.display_name).is_equal("Fire Lizard")


func test_fire_lizard_has_fire_type() -> void:
	var config := ConfigLoader.load_monster("fire_lizard")

	assert_bool(config.type_tags.has(TypeTag.Type.FIRE)).is_true()


func test_fire_lizard_has_base_stats() -> void:
	var config := ConfigLoader.load_monster("fire_lizard")

	assert_object(config.base_stats).is_not_null()
	assert_int(config.base_stats.max_hp).is_greater(0)


func test_fire_lizard_has_move_ids() -> void:
	var config := ConfigLoader.load_monster("fire_lizard")

	assert_bool(config.move_ids.size() > 0).is_true()


func test_load_stone_golem_returns_non_null() -> void:
	var config := ConfigLoader.load_monster("stone_golem")

	assert_object(config).is_not_null()


func test_stone_golem_has_correct_id_and_name() -> void:
	var config := ConfigLoader.load_monster("stone_golem")

	assert_str(config.id).is_equal("stone_golem")
	assert_str(config.display_name).is_equal("Stone Golem")


func test_stone_golem_has_earth_type() -> void:
	var config := ConfigLoader.load_monster("stone_golem")

	assert_bool(config.type_tags.has(TypeTag.Type.EARTH)).is_true()


func test_stone_golem_has_higher_hp_than_fire_lizard() -> void:
	var lizard := ConfigLoader.load_monster("fire_lizard")
	var golem := ConfigLoader.load_monster("stone_golem")

	assert_bool(golem.base_stats.max_hp > lizard.base_stats.max_hp).is_true()


func test_loaded_config_can_create_monster_instance() -> void:
	var config := ConfigLoader.load_monster("fire_lizard")

	var inst := MonsterInstance.create(config, 1)

	assert_object(inst).is_not_null()
	assert_int(inst.current_hp).is_equal(inst.max_hp())
	assert_bool(inst.is_fainted()).is_false()
