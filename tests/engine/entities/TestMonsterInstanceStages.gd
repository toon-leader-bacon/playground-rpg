extends GdUnitTestSuite


# --- get_stat_stage ---

func test_get_stat_stage_returns_zero_by_default() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	assert_int(inst.get_stat_stage("speed")).is_equal(0)


func test_get_stat_stage_returns_zero_for_unknown_stat() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	assert_int(inst.get_stat_stage("magic")).is_equal(0)


# --- modify_stat_stage ---

func test_modify_stat_stage_increases_stage() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	inst.modify_stat_stage("speed", 1)

	assert_int(inst.get_stat_stage("speed")).is_equal(1)


func test_modify_stat_stage_decreases_stage() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	inst.modify_stat_stage("speed", -1)

	assert_int(inst.get_stat_stage("speed")).is_equal(-1)


func test_modify_stat_stage_clamps_to_positive_max() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	inst.modify_stat_stage("speed", 10)

	assert_int(inst.get_stat_stage("speed")).is_equal(6)


func test_modify_stat_stage_clamps_to_negative_min() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	inst.modify_stat_stage("speed", -10)

	assert_int(inst.get_stat_stage("speed")).is_equal(-6)


func test_modify_stat_stage_accumulates() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	inst.modify_stat_stage("speed", 2)
	inst.modify_stat_stage("speed", 1)

	assert_int(inst.get_stat_stage("speed")).is_equal(3)


# --- reset_stat_stages ---

func test_reset_stat_stages_clears_all() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)
	inst.modify_stat_stage("speed", 3)

	inst.reset_stat_stages()

	assert_int(inst.get_stat_stage("speed")).is_equal(0)


# --- effective_speed ---

func test_effective_speed_at_stage_zero_equals_base_speed() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	assert_int(inst.effective_speed()).is_equal(inst.speed())


func test_effective_speed_positive_stage_increases() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)
	inst.modify_stat_stage("speed", 1)

	assert_bool(inst.effective_speed() > inst.speed()).is_true()


func test_effective_speed_negative_stage_decreases() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)
	inst.modify_stat_stage("speed", -1)

	assert_bool(inst.effective_speed() < inst.speed()).is_true()


func test_effective_speed_stage_plus_one_is_one_point_five_times_base() -> void:
	# Stage +1 formula: base * 3 / 2
	var inst := MonsterInstance.create(_make_config(), 1)
	var base: int = inst.speed()

	inst.modify_stat_stage("speed", 1)

	assert_int(inst.effective_speed()).is_equal(int(float(base) * 3.0 / 2.0))


func test_effective_speed_stage_minus_one_is_two_thirds_base() -> void:
	# Stage -1 formula: base * 2 / 3
	var inst := MonsterInstance.create(_make_config(), 1)
	var base: int = inst.speed()

	inst.modify_stat_stage("speed", -1)

	assert_int(inst.effective_speed()).is_equal(int(float(base) * 2.0 / 3.0))


# --- serialization ---

func test_serialize_includes_stat_stages() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)
	inst.modify_stat_stage("speed", 2)

	var data: Dictionary = inst.serialize()

	assert_dict(data).contains_key_value("stat_stages", {"speed": 2})


func test_deserialize_restores_stat_stages() -> void:
	# Step 1: set up inputs
	var config := _make_config()
	var inst := MonsterInstance.create(config, 1)
	inst.modify_stat_stage("speed", -1)

	# Step 2: run code under test
	var data: Dictionary = inst.serialize()
	var restored := MonsterInstance.deserialize(data, config)

	# Step 3: validate output
	assert_int(restored.get_stat_stage("speed")).is_equal(-1)


func test_deserialize_empty_stat_stages_defaults_to_zero() -> void:
	var config := _make_config()
	var data: Dictionary = {"level": 1, "current_hp": 50, "config_id": "test"}

	var restored := MonsterInstance.deserialize(data, config)

	assert_int(restored.get_stat_stage("speed")).is_equal(0)


# --- Helpers ---

func _make_config() -> MonsterConfig:
	var config := MonsterConfig.new()
	config.id = "test_monster"
	config.display_name = "Test Monster"
	var stats := StatBlock.new()
	stats.max_hp = 50
	stats.attack = 30
	stats.defense = 25
	stats.speed = 40
	config.base_stats = stats
	config.type_tags = [TypeTag.Type.NORMAL]
	config.move_ids = ["test_move"]
	config.ai_style = MonsterConfig.AIStyle.RANDOM
	return config
