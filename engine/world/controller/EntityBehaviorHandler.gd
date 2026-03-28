## Drives autonomous entity movement.
## No class_name — always preloaded.
##
## update() is called by ZoneScene on each entity's wander Timer.timeout.
## Returns a MoveResult; caller updates EntityNode position if success = true.

const _ZoneController := preload("res://engine/world/controller/ZoneController.gd")
const _MoveResult := preload("res://engine/world/model/MoveResult.gd")

static var _DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),   # North
	Vector2i(0, 1),    # South
	Vector2i(-1, 0),   # West
	Vector2i(1, 0),    # East
]


static func update(entity_def: EntityDefinitionResource, entity_id: String, state: ZoneState, rng: RandomNumberGenerator) -> MoveResult:
	match entity_def.movement_behavior_tag:
		"wander":
			return _wander(entity_id, state, rng)
		"patrol":
			return _patrol(entity_def, entity_id, state, rng)
		_:
			return MoveResult.fail("static")


static func _wander(entity_id: String, state: ZoneState, rng: RandomNumberGenerator) -> MoveResult:
	var dir: Vector2i = _DIRECTIONS[rng.randi() % 4]
	return _ZoneController.try_move_entity(state, entity_id, dir, rng)


static func _patrol(entity_def: EntityDefinitionResource, entity_id: String, state: ZoneState, rng: RandomNumberGenerator) -> MoveResult:
	if entity_def.patrol_path.is_empty():
		return MoveResult.fail("empty_patrol")

	var wp_key: String = "patrol_wp_" + entity_id
	var wp_index: int = state.zone_bb.read(wp_key, 0)
	var path_size: int = entity_def.patrol_path.size()

	var target_pos: Vector2i = entity_def.patrol_path[wp_index % path_size]
	var current_pos: Vector2i = state.entity_positions.get(entity_id, Vector2i.ZERO)

	if current_pos == target_pos:
		wp_index = (wp_index + 1) % path_size
		state.zone_bb.write(wp_key, wp_index)
		target_pos = entity_def.patrol_path[wp_index]

	var delta: Vector2i = target_pos - current_pos
	# Move one axis at a time — prefer horizontal.
	var dir: Vector2i = Vector2i.ZERO
	if delta.x != 0:
		dir = Vector2i(sign(delta.x), 0)
	elif delta.y != 0:
		dir = Vector2i(0, sign(delta.y))

	if dir == Vector2i.ZERO:
		return MoveResult.fail("static")

	return _ZoneController.try_move_entity(state, entity_id, dir, rng)
