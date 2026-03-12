extends GdUnitTestSuite

const _BattleState = preload("res://engine/battle/model/BattleState.gd")
const _DecisionCollector = preload("res://engine/battle/controller/DecisionCollector.gd")
const _PlayerController = preload("res://engine/battle/controller/PlayerController.gd")


func test_set_decision_submits_correct_move() -> void:
	var player := MonsterInstance.create(_make_config("player", 100, 10, 10, 10), 1)
	var enemy := MonsterInstance.create(_make_config("enemy", 100, 10, 10, 10), 1)
	var move0 := _make_move("ember", 10, MoveConfig.Effect.NONE)
	var move1 := _make_move("scratch", 5, MoveConfig.Effect.NONE)
	player.config.move_ids = ["ember", "scratch"]
	var move_library: Dictionary[String, MoveConfig] = {"ember": move0, "scratch": move1}

	var collector: DecisionCollector = _DecisionCollector.create_all_submitted(["player", "enemy"])
	var received_action: Array = [null]
	collector.committed.connect(func(q: Array[Action]) -> void:
		for a: Action in q:
			if a.actor_id == "player":
				received_action[0] = a
	)

	var controller: PlayerController = _PlayerController.new()
	controller.bind("player", player, enemy, collector, move_library)

	# Submit enemy so commit fires when player submits
	var dummy: Action = Action.create("enemy", "player", enemy, player, move1)
	collector.submit("enemy", dummy)

	controller.set_decision(1)  # pick scratch (index 1)

	assert_object(received_action[0]).is_not_null()
	assert_object((received_action[0] as Action).move).is_equal(move1)
	assert_str((received_action[0] as Action).actor_id).is_equal("player")


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


func _make_move(id: String, power: int, effect: MoveConfig.Effect) -> MoveConfig:
	var move := MoveConfig.new()
	move.id = id
	move.display_name = id.capitalize()
	move.type_tag = TypeTag.Type.NORMAL
	move.power = power
	move.accuracy = 1.0
	move.effect = effect
	return move
