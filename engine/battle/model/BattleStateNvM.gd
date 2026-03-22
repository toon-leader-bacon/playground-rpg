class_name BattleStateNvM
extends BattleState
## Battle state for NvM combat (arbitrary team sizes).
## Extends BattleState so ActionResolver/SpeedOrderedActionRunner work unchanged.
## Inherited player/enemy MonsterInstance fields are unused here.

var player_team: Array[MonsterInstance] = []
var enemy_team: Array[MonsterInstance] = []
var weather: int = WeatherType.Type.NONE
var weather_duration: int = -1  # -1 = permanent/no weather active


## Returns the MonsterInstance for an actor_id like "player_2" or "enemy_5".
## "player_" is 7 characters; "enemy_" is 6 characters.
func get_combatant(actor_id: String) -> MonsterInstance:
	if actor_id.begins_with("player_"):
		var idx: int = actor_id.substr(7).to_int()
		return player_team[idx] if idx < player_team.size() else null
	elif actor_id.begins_with("enemy_"):
		var idx: int = actor_id.substr(6).to_int()
		return enemy_team[idx] if idx < enemy_team.size() else null
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


## Decrement weather duration. Clears weather when countdown reaches 0.
func advance_weather() -> void:
	if weather_duration < 0:
		return
	weather_duration -= 1
	if weather_duration <= 0:
		weather = WeatherType.Type.NONE
		weather_duration = -1


## Set weather with a given duration (-1 = permanent).
func set_weather(type: int, duration: int) -> void:
	weather = type
	weather_duration = duration
