class_name PlayerEntityNode
extends CharacterBody2D
## The player's runtime node in the zone.
## Input is read on pre_tick; movement is committed on tick.
## Interact key triggers entity interaction on facing cell.

const _MovementController = preload("res://engine/world/controller/MovementController.gd")
const _EntityRegistry = preload("res://engine/world/controller/EntityRegistry.gd")

const TILE_SIZE: int = 16
const INTERACT_ACTION: String = "ui_accept"

var logical_cell: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i(0, 1)  # Default facing south
var _intended_direction: Vector2i = Vector2i.ZERO
var _zone_res: ZoneResource = null
var _rng: RandomNumberGenerator = null


func setup(start_cell: Vector2i, zone_res: ZoneResource, rng: RandomNumberGenerator) -> void:
	logical_cell = start_cell
	_zone_res = zone_res
	_rng = rng
	global_position = _cell_to_world(start_cell)
	WorldClock.pre_tick.connect(_on_pre_tick)
	WorldClock.tick.connect(_on_tick)


func _on_pre_tick() -> void:
	_intended_direction = Vector2i.ZERO
	if Input.is_action_pressed("ui_up"):
		_intended_direction = Vector2i(0, -1)
		facing = _intended_direction
	elif Input.is_action_pressed("ui_down"):
		_intended_direction = Vector2i(0, 1)
		facing = _intended_direction
	elif Input.is_action_pressed("ui_left"):
		_intended_direction = Vector2i(-1, 0)
		facing = _intended_direction
	elif Input.is_action_pressed("ui_right"):
		_intended_direction = Vector2i(1, 0)
		facing = _intended_direction

	if Input.is_action_just_pressed(INTERACT_ACTION):
		try_interact()


func _on_tick() -> void:
	if _intended_direction == Vector2i.ZERO or _zone_res == null:
		return
	var result: Dictionary = _MovementController.try_move(
		self,
		logical_cell,
		_intended_direction,
		_zone_res,
		collision_mask,
		_rng,
		true)
	if result["success"]:
		logical_cell = result["new_cell"]
		EventBus.zone_player_moved.emit(logical_cell)


func try_interact() -> void:
	var facing_cell: Vector2i = logical_cell + facing
	var entity: Node = _EntityRegistry.get_entity_at(facing_cell)
	if entity != null and entity.has_method("interact"):
		entity.interact()


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
