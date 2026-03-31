class_name ZoneEffectContext
extends RefCounted
## Data carrier passed to every TileEffectRegistry handler.

var actor_id: String = ""
var actor_cell: Vector2i = Vector2i.ZERO
var entity_id: String = ""
var zone_resource: Resource = null


static func make(actor: String, cell: Vector2i, zone: Resource) -> ZoneEffectContext:
	var ctx := ZoneEffectContext.new()
	ctx.actor_id = actor
	ctx.actor_cell = cell
	ctx.zone_resource = zone
	return ctx
