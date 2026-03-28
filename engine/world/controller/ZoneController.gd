## Main zone movement controller. No class_name — always preloaded.
## Analogous to ActionResolver in the battle system.
##
## try_move:        move the player through passability checks + tile effect dispatch.
## try_move_entity: move an NPC through passability checks only (no tile effects).
## try_interact:    dispatch the entity's on_interact_effect at the player's facing tile.

const _TileEffectRegistry := preload("res://engine/world/controller/TileEffectRegistry.gd")
const _ZoneEffectContext := preload("res://engine/world/model/ZoneEffectContext.gd")
const _MoveResult := preload("res://engine/world/model/MoveResult.gd")

# Passability bits mirrored from TileDefinitionResource for lookup convenience.
const _ENTER_N: int = 1 << 0
const _ENTER_S: int = 1 << 1
const _ENTER_E: int = 1 << 2
const _ENTER_W: int = 1 << 3
const _EXIT_N: int = 1 << 4
const _EXIT_S: int = 1 << 5
const _EXIT_E: int = 1 << 6
const _EXIT_W: int = 1 << 7


## Attempt to move actor_id in direction. Runs full passability checks, dispatches tile
## effects (on_exit of source, on_enter of dest), and updates state.player_position.
static func try_move(state: ZoneState, actor_id: String, direction: Vector2i, rng: RandomNumberGenerator) -> MoveResult:
	var source_pos: Vector2i = state.player_position
	var dest_pos: Vector2i = source_pos + direction

	if not state.is_in_bounds(dest_pos):
		return MoveResult.fail("bounds")

	var source_tile: TileDefinitionResource = state.get_effective_collision_tile(source_pos)
	var dest_tile: TileDefinitionResource = state.get_effective_collision_tile(dest_pos)

	var bits: Dictionary = _direction_to_bits(direction)
	var entry_bit: int = bits["entry"]
	var exit_bit: int = bits["exit"]

	if not _check_exit(source_tile, exit_bit):
		return MoveResult.fail("impassable")
	if not _check_entry(dest_tile, entry_bit):
		return MoveResult.fail("impassable")
	if not _check_passability_conditions(dest_tile, entry_bit, state):
		return MoveResult.fail("condition")

	if state.is_entity_at(dest_pos):
		return MoveResult.fail("entity")

	# Dispatch on_exit of source tile.
	if source_tile != null and source_tile.on_exit_effect != null:
		var ctx: ZoneEffectContext = ZoneEffectContext.make(state, actor_id, source_pos)
		_TileEffectRegistry.dispatch(source_tile.on_exit_effect, ctx, rng)

	state.player_position = dest_pos

	# Dispatch on_enter of dest tile.
	if dest_tile != null and dest_tile.on_enter_effect != null:
		var ctx: ZoneEffectContext = ZoneEffectContext.make(state, actor_id, dest_pos)
		_TileEffectRegistry.dispatch(dest_tile.on_enter_effect, ctx, rng)

	return MoveResult.ok(dest_pos)


## Attempt to move entity_id in direction. Passability checks only — no tile effects,
## no encounter rolls, no EventBus zone signals beyond what the caller emits.
static func try_move_entity(state: ZoneState, entity_id: String, direction: Vector2i, rng: RandomNumberGenerator) -> MoveResult:
	if not state.entity_positions.has(entity_id):
		return MoveResult.fail("unknown_entity")

	var source_pos: Vector2i = state.entity_positions[entity_id]
	var dest_pos: Vector2i = source_pos + direction

	if not state.is_in_bounds(dest_pos):
		return MoveResult.fail("bounds")

	var source_tile: TileDefinitionResource = state.get_effective_collision_tile(source_pos)
	var dest_tile: TileDefinitionResource = state.get_effective_collision_tile(dest_pos)

	var bits: Dictionary = _direction_to_bits(direction)
	var entry_bit: int = bits["entry"]
	var exit_bit: int = bits["exit"]

	if not _check_exit(source_tile, exit_bit):
		return MoveResult.fail("impassable")
	if not _check_entry(dest_tile, entry_bit):
		return MoveResult.fail("impassable")

	# Entities block each other and block the player tile too.
	if dest_pos == state.player_position:
		return MoveResult.fail("entity")
	if state.is_entity_at(dest_pos):
		return MoveResult.fail("entity")

	state.entity_positions[entity_id] = dest_pos
	return MoveResult.ok(dest_pos)


## Interact with the entity facing the player. Returns true if an entity was found and
## its on_interact_effect was dispatched.
static func try_interact(state: ZoneState, actor_pos: Vector2i, facing: Vector2i) -> bool:
	var target_pos: Vector2i = actor_pos + facing
	var entity_id: String = state.get_entity_at(target_pos)
	if entity_id == "":
		return false

	var entity_def: EntityDefinitionResource = _find_entity_def(state, entity_id)
	if entity_def == null or not entity_def.interactable:
		return false

	if entity_def.on_interact_effect != null:
		var ctx: ZoneEffectContext = ZoneEffectContext.make(state, "player", actor_pos)
		ctx.entity_id = entity_id
		var rng := RandomNumberGenerator.new()
		_TileEffectRegistry.dispatch(entity_def.on_interact_effect, ctx, rng)

	var tag: String = entity_def.on_interact_effect.effect_tag if entity_def.on_interact_effect else ""
	EventBus.zone_entity_interacted.emit(entity_id, tag)
	return true


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Returns a Dictionary {"entry": int, "exit": int} for the given direction.
## Moving south (+Y) exits the south face of source and enters the north face of dest.
static func _direction_to_bits(direction: Vector2i) -> Dictionary:
	if direction == Vector2i(0, 1):      # South
		return {"entry": _ENTER_N, "exit": _EXIT_S}
	elif direction == Vector2i(0, -1):   # North
		return {"entry": _ENTER_S, "exit": _EXIT_N}
	elif direction == Vector2i(1, 0):    # East
		return {"entry": _ENTER_W, "exit": _EXIT_E}
	elif direction == Vector2i(-1, 0):   # West
		return {"entry": _ENTER_E, "exit": _EXIT_W}
	return {"entry": 0, "exit": 0}


## Returns true if source_tile permits exiting via exit_bit.
## Null tile (void) is treated as impassable.
static func _check_exit(tile: TileDefinitionResource, exit_bit: int) -> bool:
	if tile == null:
		return false
	return (tile.passability_mask & exit_bit) != 0


## Returns true if dest_tile permits entering via entry_bit.
## Null tile (void) is treated as impassable.
static func _check_entry(tile: TileDefinitionResource, entry_bit: int) -> bool:
	if tile == null:
		return false
	return (tile.passability_mask & entry_bit) != 0


## Evaluates all passability_conditions on dest_tile that apply to entry_bit.
## Prototype: only "flag:" and "zone_flag:" prefixes supported; all other tags block.
static func _check_passability_conditions(tile: TileDefinitionResource, entry_bit: int, state: ZoneState) -> bool:
	if tile == null:
		return true
	for cond: PassabilityConditionEntry in tile.passability_conditions:
		if (cond.direction_mask & entry_bit) == 0:
			continue  # condition does not gate this direction
		if not _evaluate_condition(cond, state):
			return false
	return true


## Evaluates a single passability condition. Returns true to allow passage.
static func _evaluate_condition(cond: PassabilityConditionEntry, state: ZoneState) -> bool:
	if cond.condition_tag.begins_with("flag:"):
		var flag_key: String = cond.condition_tag.substr(5)
		return GameState.flags.get(flag_key, false)
	if cond.condition_tag.begins_with("zone_flag:"):
		var flag_key: String = cond.condition_tag.substr(10)
		return state.zone_bb.read(flag_key, false)
	push_warning("ZoneController: unknown condition_tag '%s' — blocking movement" % cond.condition_tag)
	return false


static func _find_entity_def(state: ZoneState, entity_id: String) -> EntityDefinitionResource:
	for e: EntityDefinitionResource in state.zone_config.entities:
		if e.id == entity_id:
			return e
	return null
