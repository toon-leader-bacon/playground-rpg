class_name RandomAI
extends MonsterAI
## Concrete AI strategy: picks a random move and a random valid target.

const _Action = preload("res://engine/battle/model/Action.gd")


func choose_action(
	actor_id: String,
	actor: MonsterInstance,
	move_library: Dictionary[String, MoveConfig],
	target_resolver: Callable,
	rng: RandomNumberGenerator
) -> Action:
	if actor.config == null or actor.config.move_ids.is_empty():
		return null

	# Pick a random move from the actor's known move list
	var move_idx: int = rng.randi_range(0, actor.config.move_ids.size() - 1)
	var move_id: String = actor.config.move_ids[move_idx]
	var move: MoveConfig = move_library.get(move_id, null) as MoveConfig

	# Resolve valid targets — Dictionary maps target_id (String) -> MonsterInstance
	# target_resolver signature: func(actor_id: String) -> Dictionary
	var valid_targets: Dictionary = target_resolver.call(actor_id)
	if valid_targets.is_empty():
		return null

	var target_ids: Array = valid_targets.keys()
	var target_id: String = target_ids[rng.randi_range(0, target_ids.size() - 1)]
	var target: MonsterInstance = valid_targets[target_id]

	return _Action.create(actor_id, target_id, actor, target, move)
