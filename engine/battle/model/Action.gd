class_name Action
extends RefCounted
## Value object representing a single actor's decision for a turn.

var actor_id: String = ""
var target_id: String = ""
var actor: MonsterInstance
var target: MonsterInstance
var move: MoveConfig


static func create(
	p_actor_id: String,
	p_target_id: String,
	p_actor: MonsterInstance,
	p_target: MonsterInstance,
	p_move: MoveConfig
) -> Action:
	var a := Action.new()
	a.actor_id = p_actor_id
	a.target_id = p_target_id
	a.actor = p_actor
	a.target = p_target
	a.move = p_move
	return a
