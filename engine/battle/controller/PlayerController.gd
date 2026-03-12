class_name PlayerController
extends RefCounted
## Bridges UI input to the DecisionCollector.
## The UI calls set_decision(move_index) when the player picks a move.

const _Action = preload("res://engine/battle/model/Action.gd")

var _actor_id: String = ""
var _actor: MonsterInstance
var _target: MonsterInstance
var _collector: DecisionCollector
var _move_library: Dictionary[String, MoveConfig] = {}


## Bind this controller for the current turn.
func bind(
	actor_id: String,
	actor: MonsterInstance,
	target: MonsterInstance,
	collector: DecisionCollector,
	move_library: Dictionary[String, MoveConfig]
) -> void:
	_actor_id = actor_id
	_actor = actor
	_target = target
	_collector = collector
	_move_library = move_library


## Called by UI when the player selects a move by index.
func set_decision(move_index: int) -> void:
	var move_id: String = _actor.config.move_ids[move_index]
	var move: MoveConfig = _move_library.get(move_id, null) as MoveConfig
	var target_id: String = "enemy" if _actor_id == "player" else "player"
	var action: Action = _Action.create(_actor_id, target_id, _actor, _target, move)
	_collector.submit(_actor_id, action)
