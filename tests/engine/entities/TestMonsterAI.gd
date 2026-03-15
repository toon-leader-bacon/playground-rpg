extends GdUnitTestSuite
## Tests for the RandomAI strategy (the concrete MonsterAI subclass).

const _RandomAI = preload("res://engine/entities/controller/ai/RandomAI.gd")


func test_choose_action_returns_valid_action() -> void:
	var config := _make_config(["tackle", "growl", "ember"])
	var actor := MonsterInstance.create(config, 1)
	var target := MonsterInstance.create(config, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var ai := _RandomAI.new()
	var lib := _make_lib(["tackle", "growl", "ember"])
	var resolver := _make_resolver("enemy", target)

	var action: Action = ai.choose_action("player", actor, lib, resolver, rng)

	assert_object(action).is_not_null()
	assert_str(action.actor_id).is_equal("player")
	assert_str(action.target_id).is_equal("enemy")
	assert_object(action.actor).is_equal(actor)
	assert_object(action.target).is_equal(target)
	assert_object(action.move).is_not_null()


func test_choose_action_returns_null_with_no_moves() -> void:
	var config := _make_config([])
	var actor := MonsterInstance.create(config, 1)
	var target := MonsterInstance.create(config, 1)
	var rng := RandomNumberGenerator.new()

	var ai := _RandomAI.new()
	var lib: Dictionary[String, MoveConfig] = {}
	var resolver := _make_resolver("enemy", target)

	var action: Action = ai.choose_action("player", actor, lib, resolver, rng)

	assert_object(action).is_null()


func test_choose_action_returns_null_with_null_config() -> void:
	var actor := MonsterInstance.new()
	actor.config = null
	var target := MonsterInstance.create(_make_config(["tackle"]), 1)
	var rng := RandomNumberGenerator.new()

	var ai := _RandomAI.new()
	var lib := _make_lib(["tackle"])
	var resolver := _make_resolver("enemy", target)

	var action: Action = ai.choose_action("player", actor, lib, resolver, rng)

	assert_object(action).is_null()


func test_choose_action_with_one_move_always_picks_that_move() -> void:
	var config := _make_config(["tackle"])
	var actor := MonsterInstance.create(config, 1)
	var target := MonsterInstance.create(config, 1)
	var lib := _make_lib(["tackle"])
	var resolver := _make_resolver("enemy", target)
	var rng := RandomNumberGenerator.new()

	var ai := _RandomAI.new()
	for i: int in 10:
		rng.seed = i
		var action: Action = ai.choose_action("player", actor, lib, resolver, rng)
		assert_object(action).is_not_null()
		assert_str(action.move.id).is_equal("tackle")


func test_choose_action_distributes_across_moves() -> void:
	var config := _make_config(["a", "b", "c"])
	var actor := MonsterInstance.create(config, 1)
	var target := MonsterInstance.create(config, 1)
	var lib := _make_lib(["a", "b", "c"])
	var resolver := _make_resolver("enemy", target)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	var ai := _RandomAI.new()
	var seen: Dictionary = {}
	for i: int in 30:
		var action: Action = ai.choose_action("player", actor, lib, resolver, rng)
		seen[action.move.id] = true

	assert_int(seen.size()).is_greater(1)


func test_base_class_choose_action_returns_null_and_errors() -> void:
	# MonsterAI base class should push an error and return null — subclasses must override.
	var config := _make_config(["tackle"])
	var actor := MonsterInstance.create(config, 1)
	var target := MonsterInstance.create(config, 1)
	var lib := _make_lib(["tackle"])
	var resolver := _make_resolver("enemy", target)
	var rng := RandomNumberGenerator.new()

	var base_ai := MonsterAI.new()
	var action: Action = base_ai.choose_action("player", actor, lib, resolver, rng)

	assert_object(action).is_null()


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


func _make_lib(move_ids: Array[String]) -> Dictionary[String, MoveConfig]:
	var lib: Dictionary[String, MoveConfig] = {}
	for id: String in move_ids:
		var m := MoveConfig.new()
		m.id = id
		m.display_name = id
		m.power = 10
		m.accuracy = 100
		lib[id] = m
	return lib


func _make_resolver(target_id: String, target: MonsterInstance) -> Callable:
	# Returns a Callable matching: func(actor_id: String) -> Dictionary
	return func(_actor_id: String) -> Dictionary:
		return {target_id: target}
