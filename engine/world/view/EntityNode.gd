class_name EntityNode
extends CharacterBody2D
## Runtime Godot node for all zone entities.
## Behavior is driven entirely by the EntityDefinitionResource it is initialized with.
## Not subclassed per entity type — composition over inheritance.

const _MovementController = preload("res://engine/world/controller/MovementController.gd")
const _EntityRegistry = preload("res://engine/world/controller/EntityRegistry.gd")
const _TileEffectRegistry = preload("res://engine/world/controller/TileEffectRegistry.gd")

const TILE_SIZE: int = 16
const WANDER_TAG: String = "wander"

var logical_cell: Vector2i = Vector2i.ZERO
var definition: EntityDefinitionResource = null
var _zone_res: ZoneResource = null
var _rng: RandomNumberGenerator = null


func initialize(def: EntityDefinitionResource, zone_res: ZoneResource, rng: RandomNumberGenerator) -> void:
	definition = def
	_zone_res = zone_res
	_rng = rng
	logical_cell = def.position
	global_position = _cell_to_world(logical_cell)

	# Collision
	if not def.has_collision:
		var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape != null:
			shape.disabled = true

	_EntityRegistry.register(logical_cell, self)

	# Movement AI subscription
	if def.movement_behavior != null:
		var movement_tag: String = def.movement_behavior.get("effect_tag") if def.movement_behavior else ""
		if movement_tag == WANDER_TAG:
			WorldClock.tick.connect(_on_tick_wander)

	# Flag-driven visibility
	if not def.flag_open_condition.is_empty():
		EventBus.zone_flag_changed.connect(_on_flag_changed)

	# on_load effect
	if def.on_load != null:
		var ctx := ZoneEffectContext.make("", logical_cell, zone_res)
		ctx.entity_id = def.id
		_TileEffectRegistry.dispatch(def.on_load, ctx, rng)

	# Handle entity_removed signal to remove self
	EventBus.zone_entity_removed.connect(_on_entity_removed)


func interact() -> void:
	if definition == null or definition.on_interact == null:
		return
	var ctx := _make_ctx()
	_TileEffectRegistry.dispatch(definition.on_interact, ctx, _rng)


func _on_tick_wander() -> void:
	if _zone_res == null:
		return
	var directions: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)
	]
	var dir: Vector2i = directions[_rng.randi() % directions.size()]
	var result: Dictionary = _MovementController.try_move(
		self,
		logical_cell,
		dir,
		_zone_res,
		collision_mask,
		_rng,
		false)
	if result["success"]:
		logical_cell = result["new_cell"]


func _on_flag_changed(key: String, _value: Variant) -> void:
	if definition == null:
		return
	if key == definition.flag_open_condition:
		_re_evaluate_active_state()


func _on_entity_removed(entity_id: String) -> void:
	if definition != null and entity_id == definition.id:
		queue_free()


func _re_evaluate_active_state() -> void:
	if definition == null or definition.flag_open_condition.is_empty():
		return
	var is_open: bool = WorldBoard.get_zone(definition.flag_open_condition, false) \
		or WorldBoard.get_save(definition.flag_open_condition, false)
	var shape := $CollisionShape2D as CollisionShape2D
	if shape != null:
		shape.disabled = is_open
	visible = is_open


func _exit_tree() -> void:
	_EntityRegistry.unregister(logical_cell)


func _make_ctx() -> ZoneEffectContext:
	var ctx := ZoneEffectContext.make(
		"",
		logical_cell,
		_zone_res)
	ctx.entity_id = definition.id if definition != null else ""
	return ctx


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
