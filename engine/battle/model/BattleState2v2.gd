class_name BattleState2v2
extends BattleState
## Battle state for 2v2 combat. Extends BattleState so ActionResolver/Runner work unchanged.
## Inherited fields (turn, winner_id, is_active, combat_log) are reused.
## Inherited player/enemy fields are unused in 2v2.

var player_team: Array[MonsterInstance] = []
var enemy_team: Array[MonsterInstance] = []


## Returns the MonsterInstance for the given actor_id ("player_0", "player_1", "enemy_0", "enemy_1").
func get_combatant(actor_id: String) -> MonsterInstance:
	match actor_id:
		"player_0":
			return player_team[0] if player_team.size() > 0 else null
		"player_1":
			return player_team[1] if player_team.size() > 1 else null
		"enemy_0":
			return enemy_team[0] if enemy_team.size() > 0 else null
		"enemy_1":
			return enemy_team[1] if enemy_team.size() > 1 else null
	return null


## Returns all alive (non-fainted) members of the given team ("player" or "enemy").
func get_alive(team_id: String) -> Array[MonsterInstance]:
	var team: Array[MonsterInstance] = player_team if team_id == "player" else enemy_team
	var alive: Array[MonsterInstance] = []
	for m: MonsterInstance in team:
		if not m.is_fainted():
			alive.append(m)
	return alive


## Returns true if every member of the given team is fainted.
func is_team_wiped(team_id: String) -> bool:
	return get_alive(team_id).is_empty()
