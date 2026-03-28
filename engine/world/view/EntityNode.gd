class_name EntityNode
extends Node2D
## Visual representation of a zone entity (NPC, sign, object).
## Autonomous movement behavior is driven by an internal Timer when
## movement_behavior_tag is non-empty; ZoneScene handles the actual state update.

signal update_requested(entity_id: String)

const TILE_SIZE: int = 32
const ENTITY_COLOR: Color = Color(0.9, 0.4, 0.2)
const STATIC_COLOR: Color = Color(0.6, 0.6, 0.9)

var entity_id: String = ""
var entity_def: EntityDefinitionResource = null
var tile_position: Vector2i = Vector2i.ZERO


func setup(def: EntityDefinitionResource) -> void:
	entity_id = def.id
	entity_def = def
	set_tile_position(def.position)
	if def.movement_behavior_tag != "":
		var timer := Timer.new()
		add_child(timer)
		timer.wait_time = def.wander_interval
		timer.autostart = true
		timer.timeout.connect(_on_timer_timeout)


func set_tile_position(pos: Vector2i) -> void:
	tile_position = pos
	position = Vector2(pos.x * TILE_SIZE + TILE_SIZE / 2.0, pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	queue_redraw()


func _on_timer_timeout() -> void:
	update_requested.emit(entity_id)


func _draw() -> void:
	var color: Color = STATIC_COLOR if (entity_def == null or entity_def.movement_behavior_tag == "") else ENTITY_COLOR
	var half: float = TILE_SIZE * 0.3
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), color)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0, 0, 0, 0.4), false)
