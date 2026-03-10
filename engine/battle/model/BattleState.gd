class_name BattleState
extends Resource
## Holds the final outcome and event log of a completed battle.
## Created and populated by TurnBased1v1.run().

var player: MonsterInstance
var enemy: MonsterInstance
var turn: int = 0
var winner_id: String = ""  # config.id of winner; "draw" = both fainted; "" = battle still active
var is_active: bool = true
var combat_log: Array[String] = []


func serialize() -> Dictionary:
	return {
		"player": player.serialize() if player != null else {},
		"enemy": enemy.serialize() if enemy != null else {},
		"turn": turn,
		"winner_id": winner_id,
		"is_active": is_active,
		"combat_log": combat_log.duplicate(),
	}


## Deserialize requires externally resolved MonsterConfig references.
static func deserialize(
	data: Dictionary,
	p_player_config: MonsterConfig,
	p_enemy_config: MonsterConfig
) -> BattleState:
	var state := BattleState.new()
	var player_data: Dictionary = data.get("player", {}) as Dictionary
	var enemy_data: Dictionary = data.get("enemy", {}) as Dictionary
	if not player_data.is_empty():
		state.player = MonsterInstance.deserialize(player_data, p_player_config)
	if not enemy_data.is_empty():
		state.enemy = MonsterInstance.deserialize(enemy_data, p_enemy_config)
	state.turn = data.get("turn", 0)
	state.winner_id = data.get("winner_id", "")
	state.is_active = data.get("is_active", true)
	var raw_log: Array = data.get("combat_log", []) as Array
	state.combat_log.assign(raw_log)
	return state
