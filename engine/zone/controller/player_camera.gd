extends Camera2D

@onready var player_area: Area2D = $Player
@onready var ground_tml: TileMapLayer = $"../../Ground"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_camera_limits()
	zoom = Vector2(1.0, 1.0)

func setup_camera_limits() -> void:
	var used_rect = ground_tml.get_used_rect()
	var tile_size = ground_tml.tile_set.tile_size

	limit_left   = used_rect.position.x * tile_size.x
	limit_top    = used_rect.position.y * tile_size.y
	limit_right  = used_rect.end.x * tile_size.x
	limit_bottom = used_rect.end.y * tile_size.y
