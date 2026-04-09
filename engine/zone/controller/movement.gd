extends Area2D

var tile_size = 64
var inputs = {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN
}

@onready var ray = $RayCast2D

func _ready() -> void:
	position = position.snapped(Vector2.ONE * tile_size)
	position += Vector2.ONE * tile_size / 2


func _unhandled_input(event: InputEvent) -> void:
	for dir in inputs.keys():
		if event.is_action_pressed(dir):
			move(dir)

func move(dir: String) -> void:
	ray.target_position = inputs[dir] * tile_size
	print("ray targeting collision mask %s" % ray.get_collision_mask())
	ray.force_raycast_update()
	if ray.is_colliding():
		print("colliding with %s" % ray.get_collider().name)
		return
	print("not colliding")
	print('\n')
	
	position += inputs[dir] * tile_size
