extends Node
class_name TileEventDispatcher

var _player: Node2D
var _tile_body_map: Dictionary[Vector2i, StaticBody2D] = {}


## Connect to the player node and take ownership of the tile body map.
## Must be called before any player movement occurs.
func setup(player: Node2D, tile_body_map: Dictionary[Vector2i, StaticBody2D]) -> void:
	_player = player
	_tile_body_map = tile_body_map
	_player.movement_blocked.connect(_on_player_movement_blocked)
	_player.tile_changed.connect(_on_player_tile_changed)


func get_tile_body(tile_pos: Vector2i) -> StaticBody2D:
	return _tile_body_map.get(tile_pos, null)


func _on_player_movement_blocked(collider: Node) -> void:
	for child: Node in collider.get_children():
		if child is TileCollidable:
			child.on_player_collide(_player)
			break


func _on_player_tile_changed(from_tile: Vector2i, to_tile: Vector2i) -> void:
	_dispatch_tile_exit(from_tile)
	_dispatch_tile_enter(to_tile)


func _dispatch_tile_enter(tile_pos: Vector2i) -> void:
	var body: StaticBody2D = get_tile_body(tile_pos)
	if body == null:
		return
	for child: Node in body.get_children():
		if child is TileCollidable:
			child.on_player_enter(_player)


func _dispatch_tile_exit(tile_pos: Vector2i) -> void:
	var body: StaticBody2D = get_tile_body(tile_pos)
	if body == null:
		return
	for child: Node in body.get_children():
		if child is TileCollidable:
			child.on_player_exit(_player)
