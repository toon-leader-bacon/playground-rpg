class_name PlayerController
extends RefCounted
## Bridges UI input to the DecisionCollector via a two-step move → target flow.
##
## Step 1: UI calls select_move(move_index).
##   - SELF moves: action is submitted immediately (no target UI needed).
##   - All others: needs_target is emitted with the list of valid target IDs.
## Step 2: UI (or auto-targeting logic) calls select_target(target_id).
##   - Builds and submits the Action to the DecisionCollector.
##
## target_resolver signature: func(actor_id: String) -> Dictionary
## The dictionary maps target_actor_id (String) -> target MonsterInstance.

signal needs_target(actor_id: String, valid_target_ids: Array[String])
signal submitted(actor_id: String)

const _Action = preload("res://engine/battle/model/Action.gd")

var _actor_id: String = ""
var _actor: MonsterInstance
var _collector: DecisionCollector
var _move_library: Dictionary[String, MoveConfig] = {}
var _target_resolver: Callable
var _pending_move: MoveConfig


## Bind this controller for the current turn.
func bind(
	actor_id: String,
	actor: MonsterInstance,
	collector: DecisionCollector,
	move_library: Dictionary[String, MoveConfig],
	target_resolver: Callable
) -> void:
	_actor_id = actor_id
	_actor = actor
	_collector = collector
	_move_library = move_library
	_target_resolver = target_resolver
	_pending_move = null


## Step 1: player selects which move to use by index.
## SELF moves are submitted immediately. All others emit needs_target.
func select_move(move_index: int) -> void:
	var move_id: String = _actor.config.move_ids[move_index]
	_pending_move = _move_library.get(move_id, null) as MoveConfig

	if _pending_move != null and _pending_move.target_type == MoveConfig.TargetType.SELF:
		_submit(_actor_id, _actor)
		return

	var valid_targets: Dictionary = _target_resolver.call(_actor_id)
	var target_ids: Array[String] = []
	target_ids.assign(valid_targets.keys())
	needs_target.emit(_actor_id, target_ids)


## Step 2: player (or auto-targeting) confirms a target by ID.
func select_target(target_id: String) -> void:
	var valid_targets: Dictionary = _target_resolver.call(_actor_id)
	var target: MonsterInstance = valid_targets.get(target_id, null) as MonsterInstance
	if target == null:
		push_error("PlayerController.select_target: invalid target_id '%s'" % target_id)
		return
	_submit(target_id, target)


func _submit(target_id: String, target: MonsterInstance) -> void:
	var action: Action = _Action.create(_actor_id, target_id, _actor, target, _pending_move)
	_collector.submit(_actor_id, action)
	submitted.emit(_actor_id)
