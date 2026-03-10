extends GdUnitTestSuite


# --- StatBlock serialization ---

func test_stat_block_serialize_round_trip() -> void:
	# Step 1: set up inputs
	var stats := StatBlock.new()
	stats.max_hp = 100
	stats.attack = 50
	stats.defense = 40
	stats.speed = 60

	# Step 2: run code under test
	var data := stats.serialize()
	var restored := StatBlock.deserialize(data)

	# Step 3: validate output
	assert_int(restored.max_hp).is_equal(100)
	assert_int(restored.attack).is_equal(50)
	assert_int(restored.defense).is_equal(40)
	assert_int(restored.speed).is_equal(60)


func test_stat_block_deserialize_uses_defaults_for_missing_keys() -> void:
	var restored := StatBlock.deserialize({})

	assert_int(restored.max_hp).is_equal(10)
	assert_int(restored.attack).is_equal(5)
	assert_int(restored.defense).is_equal(5)
	assert_int(restored.speed).is_equal(5)


# --- MonsterInstance creation ---

func test_create_sets_current_hp_to_max() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	assert_int(inst.current_hp).is_equal(inst.max_hp())
	assert_bool(inst.is_fainted()).is_false()


func test_level_affects_max_hp() -> void:
	var config := _make_config()
	var inst_l1 := MonsterInstance.create(config, 1)
	var inst_l5 := MonsterInstance.create(config, 5)

	assert_bool(inst_l5.max_hp() > inst_l1.max_hp()).is_true()


# --- Damage and healing ---

func test_apply_damage_reduces_current_hp() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	inst.apply_damage(10)

	assert_int(inst.current_hp).is_equal(inst.max_hp() - 10)


func test_apply_damage_clamps_to_zero() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	inst.apply_damage(9999)

	assert_int(inst.current_hp).is_equal(0)
	assert_bool(inst.is_fainted()).is_true()


func test_apply_zero_damage_has_no_effect() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)
	var hp_before := inst.current_hp

	inst.apply_damage(0)

	assert_int(inst.current_hp).is_equal(hp_before)


func test_restore_hp_heals_partial_amount() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)
	inst.apply_damage(20)

	inst.restore_hp(10)

	assert_int(inst.current_hp).is_equal(inst.max_hp() - 10)


func test_restore_hp_clamps_to_max() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)
	inst.apply_damage(5)

	inst.restore_hp(9999)

	assert_int(inst.current_hp).is_equal(inst.max_hp())


func test_is_fainted_false_when_hp_above_zero() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)

	assert_bool(inst.is_fainted()).is_false()


func test_is_fainted_true_at_exactly_zero_hp() -> void:
	var inst := MonsterInstance.create(_make_config(), 1)
	inst.apply_damage(inst.max_hp())

	assert_bool(inst.is_fainted()).is_true()


# --- MonsterInstance serialization ---

func test_serialize_round_trip_preserves_level_and_hp() -> void:
	# Step 1: set up inputs
	var config := _make_config()
	var inst := MonsterInstance.create(config, 3)
	inst.apply_damage(5)

	# Step 2: run code under test
	var data := inst.serialize()
	var restored := MonsterInstance.deserialize(data, config)

	# Step 3: validate output
	assert_str(data["config_id"]).is_equal(config.id)
	assert_int(restored.level).is_equal(3)
	assert_int(restored.current_hp).is_equal(inst.current_hp)


func test_serialize_includes_config_id() -> void:
	var config := _make_config()
	var inst := MonsterInstance.create(config, 1)

	var data := inst.serialize()

	assert_str(data["config_id"]).is_equal("test_monster")


# --- Helpers ---

func _make_config() -> MonsterConfig:
	var config := MonsterConfig.new()
	config.id = "test_monster"
	config.display_name = "Test Monster"
	config.base_stats = _make_stats(50, 30, 25, 35)
	config.type_tags = [TypeTag.Type.NORMAL]
	config.move_ids = ["tackle", "growl"]
	config.ai_style = MonsterConfig.AIStyle.RANDOM
	config.base_xp_yield = 10
	config.encounter_weight = 1.0
	return config


func _make_stats(hp: int, atk: int, def_val: int, spd: int) -> StatBlock:
	var s := StatBlock.new()
	s.max_hp = hp
	s.attack = atk
	s.defense = def_val
	s.speed = spd
	return s
