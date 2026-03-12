class_name SpeedBasedScheduler
extends RefCounted
## Turn scheduler for simultaneous-submission combat (Pokemon style).
## Both actors submit each round; faster actor resolves first.

const _DecisionCollector = preload("res://engine/battle/controller/DecisionCollector.gd")


## Returns a collector requiring both "player" and "enemy" to submit.
func next_collector(_state: BattleState) -> DecisionCollector:
	var actors: Array[String] = ["player", "enemy"]
	return _DecisionCollector.create_all_submitted(actors)


## Advance the turn counter on the battle state.
func advance(state: BattleState) -> void:
	state.turn += 1
