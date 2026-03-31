## Three-phase movement resolution. Used by both PlayerEntityNode and EntityNode.
## Phase 1: Godot physics raycast — geometry blocking.
## Phase 2: Software passability bitmask + condition evaluation.
## Phase 3: Entity conflict check via EntityRegistry.
## Phase 4 (commit): fire effects, update logical_cell, tween visual position.
##
## No class_name — preloaded by scripts that need it.

const _EntityRegistry = preload("res://engine/world/controller/EntityRegistry.gd")
const _TileEffectRegistry = preload("res://engine/world/controller/TileEffectRegistry.gd")

## Direction → entry bit mapping.
## "Enter from North" (bit 0) = the actor approaches from the north = moving SOUTH.
## So moving South checks bit 0, moving North checks bit 1, etc.
const _ENTRY_BIT: Dictionary = {
	Vector2i(0,  1): 0,   # Moving South → entering from north side → ENTER_N = bit 0
	Vector2i(0, -1): 1,   # Moving North → entering from south side → ENTER_S = bit 1
	Vector2i(1,  0): 3,   # Moving East  → entering from west side  → ENTER_W = bit 3
	Vector2i(-1, 0): 2,   # Moving West  → entering from east side  → ENTER_E = bit 2
}
## Exit bits: which direction the actor leaves the source tile.
const _EXIT_BIT: Dictionary = {
	Vector2i(0, -1): 4,   # Moving North → EXIT_N = bit 4
	Vector2i(0,  1): 5,   # Moving South → EXIT_S = bit 5
	Vector2i(1,  0): 6,   # Moving East  → EXIT_E = bit 6
	Vector2i(-1, 0): 7,   # Moving West  → EXIT_W = bit 7
}

const TILE_SIZE: int = 16


## Attempt to move actor one cell in direction.
## Returns {"success": bool, "new_cell": Vector2i}.
## actor must be a CharacterBody2D with logical_cell: Vector2i.
static func try_move(
		actor: CharacterBody2D,
		logical_cell: Vector2i,
		direction: Vector2i,
		zone_res: ZoneResource,
		collision_mask: int,
		rng: RandomNumberGenerator,
		is_player: bool) -> Dictionary:

	var target_cell: Vector2i = logical_cell + direction
	var target_world_pos: Vector2 = Vector2(target_cell) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	var actor_world_pos: Vector2 = actor.global_position

	# Phase 1 — Physics raycast (terrain and entity bodies)
	var space: PhysicsDirectSpaceState2D = actor.get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(actor_world_pos, target_world_pos, collision_mask)
	params.exclude = [actor.get_rid()]
	var hit: Dictionary = space.intersect_ray(params)
	if not hit.is_empty():
		return {"success": false, "new_cell": logical_cell}

	# Phase 2 — Software passability (bitmask + conditions)
	var source_tile: TileDefinitionResource = zone_res.get_tile_at_ground(logical_cell.x, logical_cell.y)
	var target_tile: TileDefinitionResource = zone_res.get_tile_at_ground(target_cell.x, target_cell.y)

	if target_tile != null:
		var entry_bit: int = _ENTRY_BIT.get(direction, 0)
		if not (target_tile.passability_mask >> entry_bit) & 1:
			return {"success": false, "new_cell": logical_cell}

		for cond: Variant in target_tile.conditions:
			var c := cond as PassabilityConditionResource
			if not _evaluate_condition(c, direction):
				return {"success": false, "new_cell": logical_cell}

	if source_tile != null:
		var exit_bit: int = _EXIT_BIT.get(direction, 4)
		if not (source_tile.passability_mask >> exit_bit) & 1:
			return {"success": false, "new_cell": logical_cell}

	# Phase 3 — Entity conflict
	var occupant: Node = _EntityRegistry.get_entity_at(target_cell)
	if occupant != null and occupant != actor:
		return {"success": false, "new_cell": logical_cell}

	# Phase 4 — Commit
	var ctx := ZoneEffectContext.make(
		actor.name if is_player else "",
		logical_cell,
		zone_res)

	if is_player and source_tile != null:
		_TileEffectRegistry.dispatch(source_tile.on_exit, ctx, rng)

	if not is_player:
		_EntityRegistry.move_entity(logical_cell, target_cell)

	ctx.actor_cell = target_cell

	# Tween visual position (skipped if not in a rendering context)
	if actor.is_inside_tree():
		var tween: Tween = actor.create_tween()
		if tween != null:
			tween.tween_property(actor, "global_position", target_world_pos,
				WorldClock.tick_duration * 0.9)

	return {"success": true, "new_cell": target_cell}


## Dispatch on_enter effects for the new cell. Called by ZoneScene post_tick.
static func dispatch_enter_effects(
		actor_id: String,
		cell: Vector2i,
		zone_res: ZoneResource,
		rng: RandomNumberGenerator) -> void:
	var tile: TileDefinitionResource = zone_res.get_tile_at_ground(cell.x, cell.y)
	if tile == null:
		return
	var ctx := ZoneEffectContext.make(actor_id, cell, zone_res)
	_TileEffectRegistry.dispatch(tile.on_enter, ctx, rng)
	# Also check tile encounter table override
	var table: EncounterTableResource = tile.encounter_table_override
	if table != null and rng.randf() < table.encounter_chance:
		EventBus.zone_encounter_triggered.emit(table)


# ── Condition evaluation ─────────────────────────────────────────────────────

static func _evaluate_condition(cond: PassabilityConditionResource, direction: Vector2i) -> bool:
	var entry_bit: int = _ENTRY_BIT.get(direction, 0)
	# Check if this condition guards the direction we're moving into
	if not (cond.direction_mask >> entry_bit) & 1:
		return true  # This condition doesn't guard this direction — pass

	var tag: String = cond.condition_tag
	var args: Dictionary = cond.condition_args

	match tag:
		"blackboard_flag":
			var key: String = args.get("key", "")
			return WorldBoard.get_zone(key, false) or WorldBoard.get_save(key, false)
		"has_item":
			# Stub: item system not yet implemented
			push_warning("MovementController: 'has_item' condition not yet implemented — blocking")
			return false
		_:
			push_warning("MovementController: unknown condition tag '%s' — blocking" % tag)
			return false
