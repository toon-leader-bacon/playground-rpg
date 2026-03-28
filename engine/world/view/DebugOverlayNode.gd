extends Node2D
## Internal implementation detail of ZoneTileRenderer.
## Draws a semi-transparent passability tint over the collision layer.
## Must be the last child of ZoneTileRenderer so it renders above the TileMapLayer nodes.

var _collision_layer: TileLayerResource = null
var _tile_size: int = 32
var _enabled: bool = false


func configure(layer: TileLayerResource, tile_size: int) -> void:
	_collision_layer = layer
	_tile_size = tile_size
	queue_redraw()


func set_debug_enabled(enabled: bool) -> void:
	_enabled = enabled
	queue_redraw()


func _draw() -> void:
	if not _enabled or _collision_layer == null:
		return
	for y: int in range(_collision_layer.height):
		for x: int in range(_collision_layer.width):
			var tile: TileDefinitionResource = _collision_layer.get_tile(x, y)
			if tile == null:
				continue
			var mask: int = tile.passability_mask
			if mask == TileDefinitionResource.PASSABLE_ALL:
				continue
			var rect := Rect2(x * _tile_size, y * _tile_size, _tile_size, _tile_size)
			# Red tint for fully impassable; yellow tint for directional (ledges/gates).
			if mask == TileDefinitionResource.IMPASSABLE:
				draw_rect(rect, Color(1.0, 0.0, 0.0, 0.35))
			else:
				draw_rect(rect, Color(1.0, 1.0, 0.0, 0.35))
