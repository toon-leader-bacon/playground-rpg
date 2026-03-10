class_name MonsterAI
extends RefCounted
## Stateless controller that selects a move index for a monster.
## Returns an index into actor.config.move_ids, or -1 if no moves are available.
##
## To add a new AI strategy:
##   1. Add a value to MonsterConfig.AIStyle
##   2. Add a match branch in choose_action()
##   3. Implement the private handler


## Select a move for actor to use against target.
## Accepts an optional rng for deterministic testing.
static func choose_action(
	actor: MonsterInstance,
	_target: MonsterInstance,
	rng: RandomNumberGenerator = null
) -> int:
	if actor.config == null or actor.config.move_ids.is_empty():
		return -1

	match actor.config.ai_style:
		MonsterConfig.AIStyle.RANDOM:
			return _choose_random(actor, rng)
		_:
			return _choose_random(actor, rng)


static func _choose_random(actor: MonsterInstance, rng: RandomNumberGenerator = null) -> int:
	var r := rng if rng != null else RandomNumberGenerator.new()
	return r.randi_range(0, actor.config.move_ids.size() - 1)
