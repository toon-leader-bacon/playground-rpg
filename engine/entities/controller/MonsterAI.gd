class_name MonsterAI
extends RefCounted
## Base class for AI strategies. Subclasses implement choose_action().
##
## target_resolver signature: func(actor_id: String) -> Dictionary
## The dictionary maps target_actor_id (String) -> target MonsterInstance.
## RandomAI picks randomly from that set; future strategies may weight by HP, type, etc.
##
## To add a new AI strategy:
##   1. Create a subclass of MonsterAI in engine/entities/controller/ai/
##   2. Override choose_action()
##   3. Wire the new class in the BattleController via AIStyle enum (schema/monsters/MonsterConfig.gd)


## Select an action for the given actor. Must be overridden by subclasses.
## Returns null if no valid action can be constructed.
func choose_action(
	actor_id: String,
	actor: MonsterInstance,
	move_library: Dictionary[String, MoveConfig],
	target_resolver: Callable,
	rng: RandomNumberGenerator
) -> Action:
	push_error("MonsterAI.choose_action() must be overridden by a subclass.")
	return null
