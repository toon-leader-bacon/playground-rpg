extends GdUnitTestSuite


func test_choose_action_returns_valid_index() -> void:
	# Step 1: set up inputs
	var config := _make_config(["tackle", "growl", "ember"])
	var actor := MonsterInstance.create(config, 1)
	var target := MonsterInstance.create(config, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Step 2: run code under test
	var action := MonsterAI.choose_action(actor, target, rng)

	# Step 3: validate output
	assert_int(action).is_between(0, 2)


func test_choose_action_returns_minus_one_with_no_moves() -> void:
	var config := _make_config([])
	var actor := MonsterInstance.create(config, 1)
	var target := MonsterInstance.create(config, 1)

	var action := MonsterAI.choose_action(actor, target)

	assert_int(action).is_equal(-1)


func test_choose_action_with_one_move_always_returns_zero() -> void:
	var config := _make_config(["tackle"])
	var actor := MonsterInstance.create(config, 1)
	var target := MonsterInstance.create(config, 1)
	var rng := RandomNumberGenerator.new()

	for i in 10:
		rng.seed = i
		var action := MonsterAI.choose_action(actor, target, rng)
		assert_int(action).is_equal(0)


func test_choose_action_returns_minus_one_with_null_config() -> void:
	var actor := MonsterInstance.new()
	actor.config = null
	var target := MonsterInstance.create(_make_config(["tackle"]), 1)

	var action := MonsterAI.choose_action(actor, target)

	assert_int(action).is_equal(-1)


func test_choose_action_produces_distribution_across_moves() -> void:
	# Verify RANDOM strategy actually picks different moves over many calls
	var config := _make_config(["a", "b", "c"])
	var actor := MonsterInstance.create(config, 1)
	var target := MonsterInstance.create(config, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	var seen := {}
	for i in 30:
		var action := MonsterAI.choose_action(actor, target, rng)
		seen[action] = true

	assert_int(seen.size()).is_greater(1)


# --- Helpers ---

func _make_config(move_ids: Array[String]) -> MonsterConfig:
	var config := MonsterConfig.new()
	config.id = "test_monster"
	config.display_name = "Test Monster"
	config.base_stats = _make_stats(50, 30, 25, 35)
	config.type_tags = [TypeTag.Type.NORMAL]
	config.move_ids = move_ids
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
