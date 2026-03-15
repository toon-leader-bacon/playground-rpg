extends GdUnitTestSuite
## Tests for BattleStateNvM: dynamic get_combatant, get_alive, is_team_wiped.

const _BattleStateNvM = preload("res://engine/battle/model/BattleStateNvM.gd")


func test_get_combatant_returns_correct_player_by_index() -> void:
	var state: BattleStateNvM = _BattleStateNvM.new()
	var p0: MonsterInstance = MonsterInstance.create(_make_config("p0", 50, 10, 10, 10), 1)
	var p1: MonsterInstance = MonsterInstance.create(_make_config("p1", 50, 10, 10, 10), 1)
	var p2: MonsterInstance = MonsterInstance.create(_make_config("p2", 50, 10, 10, 10), 1)
	state.player_team = [p0, p1, p2]
	state.enemy_team = []

	assert_object(state.get_combatant("player_0")).is_equal(p0)
	assert_object(state.get_combatant("player_1")).is_equal(p1)
	assert_object(state.get_combatant("player_2")).is_equal(p2)


func test_get_combatant_returns_correct_enemy_by_index() -> void:
	var state: BattleStateNvM = _BattleStateNvM.new()
	var e0: MonsterInstance = MonsterInstance.create(_make_config("e0", 50, 10, 10, 10), 1)
	var e5: MonsterInstance = MonsterInstance.create(_make_config("e5", 50, 10, 10, 10), 1)
	var e6: MonsterInstance = MonsterInstance.create(_make_config("e6", 50, 10, 10, 10), 1)
	state.player_team = []
	state.enemy_team = [e0, e5, e6]

	assert_object(state.get_combatant("enemy_0")).is_equal(e0)
	assert_object(state.get_combatant("enemy_1")).is_equal(e5)
	assert_object(state.get_combatant("enemy_2")).is_equal(e6)


func test_get_combatant_returns_null_for_out_of_bounds() -> void:
	var state: BattleStateNvM = _BattleStateNvM.new()
	state.player_team = []
	state.enemy_team = []

	assert_object(state.get_combatant("player_0")).is_null()
	assert_object(state.get_combatant("enemy_0")).is_null()


func test_get_combatant_returns_null_for_unknown_prefix() -> void:
	var state: BattleStateNvM = _BattleStateNvM.new()
	state.player_team = []
	state.enemy_team = []

	assert_object(state.get_combatant("unknown_0")).is_null()
	assert_object(state.get_combatant("")).is_null()


func test_get_alive_returns_only_non_fainted_for_large_team() -> void:
	var state: BattleStateNvM = _BattleStateNvM.new()
	var monsters: Array[MonsterInstance] = []
	for i: int in range(7):
		monsters.append(MonsterInstance.create(_make_config("e" + str(i), 50, 10, 10, 10), 1))
	state.player_team = []
	state.enemy_team = monsters

	# Faint indices 0, 2, 4
	monsters[0].current_hp = 0
	monsters[2].current_hp = 0
	monsters[4].current_hp = 0

	var alive: Array[MonsterInstance] = state.get_alive("enemy")
	assert_int(alive.size()).is_equal(4)
	assert_bool(alive.has(monsters[1])).is_true()
	assert_bool(alive.has(monsters[3])).is_true()
	assert_bool(alive.has(monsters[5])).is_true()
	assert_bool(alive.has(monsters[6])).is_true()


func test_is_team_wiped_true_when_all_fainted() -> void:
	var state: BattleStateNvM = _BattleStateNvM.new()
	var p0: MonsterInstance = MonsterInstance.create(_make_config("p0", 50, 10, 10, 10), 1)
	var p1: MonsterInstance = MonsterInstance.create(_make_config("p1", 50, 10, 10, 10), 1)
	var p2: MonsterInstance = MonsterInstance.create(_make_config("p2", 50, 10, 10, 10), 1)
	state.player_team = [p0, p1, p2]
	state.enemy_team = []

	p0.current_hp = 0
	p1.current_hp = 0
	p2.current_hp = 0

	assert_bool(state.is_team_wiped("player")).is_true()


func test_is_team_wiped_false_when_one_alive() -> void:
	var state: BattleStateNvM = _BattleStateNvM.new()
	var monsters: Array[MonsterInstance] = []
	for i: int in range(3):
		monsters.append(MonsterInstance.create(_make_config("p" + str(i), 50, 10, 10, 10), 1))
	state.player_team = monsters
	state.enemy_team = []

	monsters[0].current_hp = 0
	monsters[1].current_hp = 0
	# monsters[2] still alive

	assert_bool(state.is_team_wiped("player")).is_false()


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
