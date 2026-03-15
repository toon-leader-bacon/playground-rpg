extends GdUnitTestSuite
## Tests for BattleState2v2: get_combatant, get_alive, is_team_wiped.

const _BattleState2v2 = preload("res://engine/battle/model/BattleState2v2.gd")


func test_get_combatant_returns_correct_monster_for_each_actor_id() -> void:
	var state: BattleState2v2 = _BattleState2v2.new()
	var p0: MonsterInstance = MonsterInstance.create(_make_config("p0", 50, 10, 10, 10), 1)
	var p1: MonsterInstance = MonsterInstance.create(_make_config("p1", 50, 10, 10, 10), 1)
	var e0: MonsterInstance = MonsterInstance.create(_make_config("e0", 50, 10, 10, 10), 1)
	var e1: MonsterInstance = MonsterInstance.create(_make_config("e1", 50, 10, 10, 10), 1)
	state.player_team = [p0, p1]
	state.enemy_team = [e0, e1]

	assert_object(state.get_combatant("player_0")).is_equal(p0)
	assert_object(state.get_combatant("player_1")).is_equal(p1)
	assert_object(state.get_combatant("enemy_0")).is_equal(e0)
	assert_object(state.get_combatant("enemy_1")).is_equal(e1)


func test_get_combatant_returns_null_for_unknown_id() -> void:
	var state: BattleState2v2 = _BattleState2v2.new()
	state.player_team = []
	state.enemy_team = []

	assert_object(state.get_combatant("unknown")).is_null()


func test_get_alive_returns_only_non_fainted_members() -> void:
	var state: BattleState2v2 = _BattleState2v2.new()
	var p0: MonsterInstance = MonsterInstance.create(_make_config("p0", 50, 10, 10, 10), 1)
	var p1: MonsterInstance = MonsterInstance.create(_make_config("p1", 1, 10, 10, 10), 1)
	state.player_team = [p0, p1]
	state.enemy_team = []

	# Faint p1 by draining its HP
	p1.current_hp = 0

	var alive: Array[MonsterInstance] = state.get_alive("player")
	assert_int(alive.size()).is_equal(1)
	assert_object(alive[0]).is_equal(p0)


func test_get_alive_returns_all_when_none_fainted() -> void:
	var state: BattleState2v2 = _BattleState2v2.new()
	var e0: MonsterInstance = MonsterInstance.create(_make_config("e0", 50, 10, 10, 10), 1)
	var e1: MonsterInstance = MonsterInstance.create(_make_config("e1", 50, 10, 10, 10), 1)
	state.player_team = []
	state.enemy_team = [e0, e1]

	var alive: Array[MonsterInstance] = state.get_alive("enemy")
	assert_int(alive.size()).is_equal(2)


func test_is_team_wiped_returns_true_when_all_fainted() -> void:
	var state: BattleState2v2 = _BattleState2v2.new()
	var p0: MonsterInstance = MonsterInstance.create(_make_config("p0", 50, 10, 10, 10), 1)
	var p1: MonsterInstance = MonsterInstance.create(_make_config("p1", 50, 10, 10, 10), 1)
	state.player_team = [p0, p1]
	state.enemy_team = []

	p0.current_hp = 0
	p1.current_hp = 0

	assert_bool(state.is_team_wiped("player")).is_true()


func test_is_team_wiped_returns_false_when_one_alive() -> void:
	var state: BattleState2v2 = _BattleState2v2.new()
	var e0: MonsterInstance = MonsterInstance.create(_make_config("e0", 50, 10, 10, 10), 1)
	var e1: MonsterInstance = MonsterInstance.create(_make_config("e1", 50, 10, 10, 10), 1)
	state.player_team = []
	state.enemy_team = [e0, e1]

	e0.current_hp = 0
	# e1 still alive

	assert_bool(state.is_team_wiped("enemy")).is_false()


func test_is_team_wiped_returns_false_when_all_alive() -> void:
	var state: BattleState2v2 = _BattleState2v2.new()
	var e0: MonsterInstance = MonsterInstance.create(_make_config("e0", 50, 10, 10, 10), 1)
	var e1: MonsterInstance = MonsterInstance.create(_make_config("e1", 50, 10, 10, 10), 1)
	state.player_team = []
	state.enemy_team = [e0, e1]

	assert_bool(state.is_team_wiped("enemy")).is_false()


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
