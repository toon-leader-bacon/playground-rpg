class_name SpeedBasedScheduler
extends RefCounted
## Turn scheduler for simultaneous-submission combat (Pokemon style).
## All actors submit each round; speed order is resolved by SpeedOrderedActionRunner.
##
## actor_ids: the set of combatant IDs that must submit each turn.
## 1v1 usage: SpeedBasedScheduler.new(["player", "enemy"])
## 2v2 usage: SpeedBasedScheduler.new(["player_0", "player_1", "enemy_0", "enemy_1"])

const _DecisionCollector = preload("res://engine/battle/controller/DecisionCollector.gd")

var _actor_ids: Array[String] = []


func _init(actor_ids: Array[String] = ["player", "enemy"]) -> void:
	_actor_ids = actor_ids


## Returns a collector requiring all actor_ids to submit before committing.
func next_collector() -> DecisionCollector:
	return _DecisionCollector.create_all_submitted(_actor_ids)


## Advance the turn counter on the battle state.
func advance(state: BattleState) -> void:
	state.turn += 1
