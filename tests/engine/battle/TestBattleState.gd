extends GdUnitTestSuite
const _load_battle_state = preload("res://engine/battle/model/BattleState.gd")


func test_battle_state_serialize_round_trip() -> void:
	# Step 1: set up inputs
	var config := _make_config("test_a", 50, 30, 20, 40)
	var enemy_config := _make_config("test_b", 60, 25, 30, 30)
	var player := MonsterInstance.create(config, 3)
	var enemy := MonsterInstance.create(enemy_config, 3)
	player.apply_damage(10)

	var state := BattleState.new()
	state.player = player
	state.enemy = enemy
	state.turn = 5
	state.winner_id = "test_a"
	state.is_active = false
	state.combat_log = ["Turn 1 log", "Turn 2 log"]

	# Step 2: run code under test
	var data: Dictionary = state.serialize()
	var restored: BattleState = BattleState.deserialize(data, config, enemy_config)

	# Step 3: validate output
	assert_int(restored.turn).is_equal(5)
	assert_str(restored.winner_id).is_equal("test_a")
	assert_bool(restored.is_active).is_false()
	assert_int(restored.combat_log.size()).is_equal(2)
	assert_str(restored.combat_log[0]).is_equal("Turn 1 log")
	assert_int(restored.player.current_hp).is_equal(player.current_hp)
	assert_int(restored.player.level).is_equal(3)


func test_battle_state_default_is_active_true() -> void:
	var state := BattleState.new()

	assert_bool(state.is_active).is_true()
	assert_str(state.winner_id).is_equal("")
	assert_int(state.turn).is_equal(0)


# --- Helpers ---

func _make_config(id: String, hp: int, atk: int, def_val: int, spd: int) -> MonsterConfig:
	var config := MonsterConfig.new()
	config.id = id
	config.display_name = id
	var stats := StatBlock.new()
	stats.max_hp = hp
	stats.attack = atk
	stats.defense = def_val
	stats.speed = spd
	config.base_stats = stats
	config.type_tags = [TypeTag.Type.NORMAL]
	config.move_ids = ["test_move"]
	config.ai_style = MonsterConfig.AIStyle.RANDOM
	return config
