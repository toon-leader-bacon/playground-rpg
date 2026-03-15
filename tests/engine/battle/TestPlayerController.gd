extends GdUnitTestSuite

const _BattleState = preload("res://engine/battle/model/BattleState.gd")
const _DecisionCollector = preload("res://engine/battle/controller/DecisionCollector.gd")
const _PlayerController = preload("res://engine/battle/controller/PlayerController.gd")


func test_self_targeting_move_submits_immediately() -> void:
	# SELF move: select_move should submit to collector without needing select_target.
	var player := MonsterInstance.create(_make_config("player", 100, 10, 10, 10), 1)
	player.config.move_ids = ["recover"]
	var heal_move := _make_move("recover", 30, MoveConfig.Effect.HEAL, MoveConfig.TargetType.SELF)
	var move_library: Dictionary[String, MoveConfig] = {"recover": heal_move}

	var collector: DecisionCollector = _DecisionCollector.create_all_submitted(["player"])
	var received_action: Array = [null]
	collector.committed.connect(func(q: Array[Action]) -> void:
		received_action[0] = q[0] if not q.is_empty() else null
	)

	var resolver: Callable = func(_id: String) -> Dictionary: return {}
	var controller: PlayerController = _PlayerController.new()
	controller.bind("player", player, collector, move_library, resolver)

	controller.select_move(0)  # pick recover — SELF targeting

	assert_object(received_action[0]).is_not_null()
	var action: Action = received_action[0] as Action
	assert_str(action.actor_id).is_equal("player")
	assert_str(action.target_id).is_equal("player")  # targets self
	assert_object(action.move).is_equal(heal_move)


func test_enemy_targeting_move_emits_needs_target() -> void:
	# SINGLE_ENEMY move: select_move should emit needs_target, not submit yet.
	var player := MonsterInstance.create(_make_config("player", 100, 10, 10, 10), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 100, 10, 10, 10), 1)
	player.config.move_ids = ["ember"]
	var ember := _make_move("ember", 25, MoveConfig.Effect.NONE, MoveConfig.TargetType.SINGLE_ENEMY)
	var move_library: Dictionary[String, MoveConfig] = {"ember": ember}

	var collector: DecisionCollector = _DecisionCollector.create_all_submitted(["player"])
	var needs_target_fired: Array = [false]
	var emitted_target_ids: Array[String] = []

	var resolver: Callable = func(_id: String) -> Dictionary: return {"enemy": enemy}
	var controller: PlayerController = _PlayerController.new()
	controller.bind("player", player, collector, move_library, resolver)
	controller.needs_target.connect(func(_actor_id: String, ids: Array[String]) -> void:
		needs_target_fired[0] = true
		emitted_target_ids.assign(ids)
	)

	controller.select_move(0)

	assert_bool(needs_target_fired[0]).is_true()
	assert_bool(emitted_target_ids.has("enemy")).is_true()
	assert_bool(collector.is_committed).is_false()  # not submitted yet


func test_select_target_submits_correct_action() -> void:
	# Full two-step flow: select_move → select_target → action submitted.
	var player := MonsterInstance.create(_make_config("player", 100, 10, 10, 10), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 100, 10, 10, 10), 1)
	player.config.move_ids = ["ember", "scratch"]
	var ember := _make_move("ember", 25, MoveConfig.Effect.NONE, MoveConfig.TargetType.SINGLE_ENEMY)
	var scratch := _make_move("scratch", 10, MoveConfig.Effect.NONE, MoveConfig.TargetType.SINGLE_ENEMY)
	var move_library: Dictionary[String, MoveConfig] = {"ember": ember, "scratch": scratch}

	var collector: DecisionCollector = _DecisionCollector.create_all_submitted(["player"])
	var received_action: Array = [null]
	collector.committed.connect(func(q: Array[Action]) -> void:
		for a: Action in q:
			if a.actor_id == "player":
				received_action[0] = a
	)

	var resolver: Callable = func(_id: String) -> Dictionary: return {"enemy": enemy}
	var controller: PlayerController = _PlayerController.new()
	controller.bind("player", player, collector, move_library, resolver)

	controller.select_move(1)       # pick scratch (index 1)
	controller.select_target("enemy")

	assert_object(received_action[0]).is_not_null()
	var action: Action = received_action[0] as Action
	assert_object(action.move).is_equal(scratch)
	assert_str(action.actor_id).is_equal("player")
	assert_str(action.target_id).is_equal("enemy")
	assert_object(action.target).is_equal(enemy)


func test_select_target_invalid_id_does_not_submit() -> void:
	var player := MonsterInstance.create(_make_config("player", 100, 10, 10, 10), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 100, 10, 10, 10), 1)
	player.config.move_ids = ["ember"]
	var ember := _make_move("ember", 25, MoveConfig.Effect.NONE, MoveConfig.TargetType.SINGLE_ENEMY)
	var move_library: Dictionary[String, MoveConfig] = {"ember": ember}

	var collector: DecisionCollector = _DecisionCollector.create_all_submitted(["player"])
	var resolver: Callable = func(_id: String) -> Dictionary: return {"enemy": enemy}
	var controller: PlayerController = _PlayerController.new()
	controller.bind("player", player, collector, move_library, resolver)

	controller.select_move(0)
	controller.select_target("nonexistent")  # invalid — should not submit

	assert_bool(collector.is_committed).is_false()


# --- Helpers ---

func _make_config(id: String, hp: int, atk: int, def_val: int, spd: int) -> MonsterConfig:
	var config := MonsterConfig.new()
	config.id = id
	config.display_name = id.capitalize()
	var stats := StatBlock.new()
	stats.max_hp = hp
	stats.attack = atk
	stats.defense = def_val
	stats.speed = spd
	config.base_stats = stats
	config.type_tags = [TypeTag.Type.NORMAL]
	config.ai_style = MonsterConfig.AIStyle.RANDOM
	return config


func _make_move(id: String, power: int, effect: MoveConfig.Effect, target_type: MoveConfig.TargetType) -> MoveConfig:
	var move := MoveConfig.new()
	move.id = id
	move.display_name = id.capitalize()
	move.type_tag = TypeTag.Type.NORMAL
	move.power = power
	move.accuracy = 1.0
	move.effect = effect
	move.target_type = target_type
	return move
