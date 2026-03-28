class_name ZoneEffectContext
extends RefCounted
## Execution context passed to TileEffectRegistry handlers.
## Analogous to PipelineContext in the battle system.

var zone_state: ZoneState = null
var actor_id: String = ""
var actor_position: Vector2i = Vector2i.ZERO
var entity_id: String = ""   # populated when dispatching entity interaction effects


static func make(state: ZoneState, actor: String, pos: Vector2i) -> ZoneEffectContext:
	var ctx := ZoneEffectContext.new()
	ctx.zone_state = state
	ctx.actor_id = actor
	ctx.actor_position = pos
	return ctx
