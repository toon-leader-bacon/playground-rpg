class_name PlayerEntityNode
extends Node2D
## Visual representation of the player on the tile grid.
## Emits move_requested / interact_requested signals; ZoneScene handles the logic.

signal move_requested(direction: Vector2i)
signal interact_requested

const TILE_SIZE: int = 32
const PLAYER_COLOR: Color = Color(1.0, 0.9, 0.2)
const ARROW_COLOR: Color = Color(1.0, 0.6, 0.0)

var tile_position: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i(0, 1)


func set_tile_position(pos: Vector2i) -> void:
	tile_position = pos
	position = Vector2(pos.x * TILE_SIZE + TILE_SIZE / 2.0, pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.is_action_pressed("ui_up"):
		move_requested.emit(Vector2i(0, -1))
	elif event.is_action_pressed("ui_down"):
		move_requested.emit(Vector2i(0, 1))
	elif event.is_action_pressed("ui_left"):
		move_requested.emit(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		move_requested.emit(Vector2i(1, 0))
	elif event.is_action_pressed("ui_accept"):
		interact_requested.emit()


func _draw() -> void:
	var radius: float = TILE_SIZE * 0.35
	draw_circle(Vector2.ZERO, radius, PLAYER_COLOR)
	# Direction arrow tip.
	var tip: Vector2 = Vector2(facing.x, facing.y) * radius
	var left: Vector2 = tip.rotated(PI * 0.75) * 0.5
	var right: Vector2 = tip.rotated(-PI * 0.75) * 0.5
	var points: PackedVector2Array = PackedVector2Array([tip, left, right])
	draw_colored_polygon(points, ARROW_COLOR)
