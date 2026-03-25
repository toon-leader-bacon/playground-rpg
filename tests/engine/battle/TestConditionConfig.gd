extends GdUnitTestSuite
## Tests for ConditionConfig action-space fields: serialize/deserialize round-trips
## and default-value assertions.


func test_action_space_fields_default_empty() -> void:
	var cfg := ConditionConfig.new()

	assert_str(cfg.action_lock_move_id).is_equal("")
	assert_int(cfg.action_denied_tags.size()).is_equal(0)
	assert_str(cfg.action_injected_move_id).is_equal("")


func test_action_lock_move_id_round_trip() -> void:
	var cfg := ConditionConfig.new()
	cfg.id = "rolling_out"
	cfg.action_lock_move_id = "rollout"

	var restored: ConditionConfig = ConditionConfig.deserialize(cfg.serialize())

	assert_str(restored.action_lock_move_id).is_equal("rollout")


func test_action_denied_tags_round_trip() -> void:
	var cfg := ConditionConfig.new()
	cfg.id = "muted"
	cfg.action_denied_tags = ["magic", "sound"]

	var restored: ConditionConfig = ConditionConfig.deserialize(cfg.serialize())

	assert_int(restored.action_denied_tags.size()).is_equal(2)
	assert_bool(restored.action_denied_tags.has("magic")).is_true()
	assert_bool(restored.action_denied_tags.has("sound")).is_true()


func test_action_injected_move_id_round_trip() -> void:
	var cfg := ConditionConfig.new()
	cfg.id = "enraged"
	cfg.action_injected_move_id = "bull_rush"
	cfg.action_lock_move_id = "bull_rush"

	var restored: ConditionConfig = ConditionConfig.deserialize(cfg.serialize())

	assert_str(restored.action_injected_move_id).is_equal("bull_rush")
	assert_str(restored.action_lock_move_id).is_equal("bull_rush")


func test_deep_copy_isolates_action_denied_tags() -> void:
	var cfg := ConditionConfig.new()
	cfg.action_denied_tags = ["magic"]

	var copy: ConditionConfig = cfg.deep_copy()
	copy.action_denied_tags.append("ice")

	assert_int(cfg.action_denied_tags.size()).is_equal(1)
	assert_int(copy.action_denied_tags.size()).is_equal(2)


func test_deserialize_uses_defaults_for_missing_keys() -> void:
	var cfg: ConditionConfig = ConditionConfig.deserialize({})

	assert_str(cfg.action_lock_move_id).is_equal("")
	assert_int(cfg.action_denied_tags.size()).is_equal(0)
	assert_str(cfg.action_injected_move_id).is_equal("")
