class_name EdgeRegistry
extends RefCounted
## Registry mapping string tags to condition Callables for custom FSM edge routing.
##
## All registered callables share the signature:
##   func(ctx: PipelineContext, args: Dictionary) -> bool
## Args are bound into the callable at FSM-build time by ActionResolver, so the FSM
## always sees the simpler func(ctx: PipelineContext) -> bool interface.
##
## Condition callables are distinct from node/hook callables (NodeRegistry) in that they
## return bool rather than void. Keeping them separate makes the two concerns easy to
## search, read, and maintain independently.

const _PipelineContext = preload("res://engine/battle/model/PipelineContext.gd")

var _conditions: Dictionary[String, Callable] = {}


func register_condition(tag: String, fn: Callable) -> void:
	_conditions[tag] = fn


func get_condition(tag: String) -> Callable:
	return _conditions.get(tag, Callable())


## Build a registry pre-populated with the default engine edge conditions.
static func create_default() -> EdgeRegistry:
	var reg := EdgeRegistry.new()

	## triple_kick_loop — condition for the back-edge APPLY_POST_EFFECTS → APPLY_PRE_EFFECTS.
	## Returns true (and decrements hits_remaining) while hits remain; returns false to fall
	## through to the default forward-edge (APPLY_POST_EFFECTS → APPLY_HEAL → END).
	reg.register_condition("triple_kick_loop", func(ctx: PipelineContext, _args: Dictionary) -> bool:
		var remaining: int = ctx.bb.read("triple_kick.hits_remaining", 0) as int
		if remaining > 0:
			ctx.bb.write("triple_kick.hits_remaining", remaining - 1)
			return true
		return false
	)

	return reg
