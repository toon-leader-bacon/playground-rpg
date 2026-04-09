extends Area2D

signal tile_changed(from_tile: Vector2i, to_tile: Vector2i)
signal movement_blocked(collider: Node)

var tile_size: int = 64
var inputs: Dictionary[String, Vector2] = {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN
}

@onready var ray: RayCast2D = $RayCast2D

func _ready() -> void:
	position = position.snapped(Vector2.ONE * tile_size)
	position += Vector2.ONE * tile_size / 2


func _unhandled_input(event: InputEvent) -> void:
	for dir: String in inputs.keys():
		if event.is_action_pressed(dir):
			move(dir)

func move(dir: String) -> void:
	ray.target_position = inputs[dir] * tile_size
	ray.force_raycast_update()
	if ray.is_colliding():
		movement_blocked.emit(ray.get_collider())
		return

	var current_tile: Vector2i = _world_to_tile(position)
	var next_tile: Vector2i = current_tile + Vector2i(inputs[dir])
	position += inputs[dir] * tile_size
	tile_changed.emit(current_tile, next_tile)


func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_pos / tile_size)
