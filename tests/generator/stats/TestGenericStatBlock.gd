extends GdUnitTestSuite


# --- get_stat / set_stat ---

func test_set_and_get_stat() -> void:
	# Step 1: set up inputs
	var block := GenericStatBlock.new()

	# Step 2: run code under test
	block.set_stat(StatName.HP, 75.0)

	# Step 3: validate output
	assert_float(block.get_stat(StatName.HP)).is_equal_approx(75.0, 0.001)


func test_get_stat_returns_default_for_missing_key() -> void:
	var block := GenericStatBlock.new()

	assert_float(block.get_stat(StatName.MAGIC, 99.0)).is_equal_approx(99.0, 0.001)


func test_has_stat_true_after_set() -> void:
	var block := GenericStatBlock.new()
	block.set_stat(StatName.ATTACK, 10.0)

	assert_bool(block.has_stat(StatName.ATTACK)).is_true()


func test_has_stat_false_for_missing_key() -> void:
	var block := GenericStatBlock.new()

	assert_bool(block.has_stat(StatName.SPEED)).is_false()


func test_stat_names_returns_all_keys() -> void:
	var block := GenericStatBlock.new()
	block.set_stat(StatName.HP, 10.0)
	block.set_stat(StatName.ATTACK, 5.0)

	var names: Array[String] = block.stat_names()

	assert_int(names.size()).is_equal(2)
	assert_bool(names.has(StatName.HP)).is_true()
	assert_bool(names.has(StatName.ATTACK)).is_true()


# --- serialize / deserialize ---

func test_serialize_round_trip_single_stat() -> void:
	# Step 1: set up inputs
	var block := GenericStatBlock.new()
	block.set_stat(StatName.HP, 50.0)
	block.set_stat(StatName.SPEED, 30.0)

	# Step 2: run code under test
	var data: Dictionary = block.serialize()
	var restored: GenericStatBlock = GenericStatBlock.deserialize(data)

	# Step 3: validate output
	assert_float(restored.get_stat(StatName.HP)).is_equal_approx(50.0, 0.001)
	assert_float(restored.get_stat(StatName.SPEED)).is_equal_approx(30.0, 0.001)


func test_serialize_preserves_all_stat_names() -> void:
	var block := GenericStatBlock.new()
	for stat_name: String in StatProfiles.POKEMON:
		block.set_stat(stat_name, 40.0)

	var restored: GenericStatBlock = GenericStatBlock.deserialize(block.serialize())

	for stat_name: String in StatProfiles.POKEMON:
		assert_bool(restored.has_stat(stat_name)).is_true()


func test_deserialize_empty_dict_produces_empty_block() -> void:
	var block: GenericStatBlock = GenericStatBlock.deserialize({})

	assert_int(block.stat_names().size()).is_equal(0)


# --- deserialize_update ---

func test_deserialize_update_overwrites_existing_keys() -> void:
	var block := GenericStatBlock.new()
	block.set_stat(StatName.HP, 10.0)

	block.deserialize_update({StatName.HP: 99.0})

	assert_float(block.get_stat(StatName.HP)).is_equal_approx(99.0, 0.001)


func test_deserialize_update_adds_new_keys() -> void:
	var block := GenericStatBlock.new()
	block.set_stat(StatName.HP, 10.0)

	block.deserialize_update({StatName.ATTACK: 25.0})

	assert_float(block.get_stat(StatName.HP)).is_equal_approx(10.0, 0.001)
	assert_float(block.get_stat(StatName.ATTACK)).is_equal_approx(25.0, 0.001)


# --- deep_copy ---

func test_deep_copy_produces_independent_instance() -> void:
	# Step 1: set up inputs
	var original := GenericStatBlock.new()
	original.set_stat(StatName.ATTACK, 30.0)

	# Step 2: run code under test
	var copy: GenericStatBlock = original.deep_copy()
	copy.set_stat(StatName.ATTACK, 99.0)

	# Step 3: validate output
	assert_float(original.get_stat(StatName.ATTACK)).is_equal_approx(30.0, 0.001)
	assert_float(copy.get_stat(StatName.ATTACK)).is_equal_approx(99.0, 0.001)
