class_name ZoneTileRenderer
extends Node2D
## Renders a zone's tile layers using TileMapLayer nodes (GPU-batched draw calls).
## Ground and decoration layers each become a TileMapLayer child node.
## A DebugOverlayNode child (added last, so it draws on top) optionally
## visualises the collision layer passability mask.
##
## To swap in real sprites later: replace ImageTexture.create_from_image(solid_img)
## with an atlas texture and update texture_region_size + atlas coords. No other
## changes are needed (palette keys become sprite IDs).

const TILE_SIZE: int = 32

const _TAG_COLORS: Dictionary = {
	"grass": Color(0.3, 0.6, 0.2),
	"tall_grass": Color(0.1, 0.45, 0.1),
	"water": Color(0.2, 0.4, 0.8),
	"wall": Color(0.4, 0.4, 0.4),
	"path": Color(0.7, 0.6, 0.4),
	"warp": Color(0.8, 0.3, 0.9),
	"_default": Color(0.15, 0.15, 0.15),
}

const _DebugOverlay := preload("res://engine/world/view/DebugOverlayNode.gd")

var _zone_state: ZoneState = null
var _debug_overlay: Node2D = null


func setup(state: ZoneState) -> void:
	_zone_state = state
	_rebuild()


func set_collision_debug(enabled: bool) -> void:
	if _debug_overlay != null:
		(_debug_overlay as Node2D).call("set_debug_enabled", enabled)


# ---------------------------------------------------------------------------
# Internal build
# ---------------------------------------------------------------------------

func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	_debug_overlay = null

	if _zone_state == null:
		return

	_build_tile_map_layer("ground")
	_build_tile_map_layer("decoration")

	# Overlay is added last: children render after parent in Godot, so last
	# child draws on top of the TileMapLayer nodes.
	var overlay: Node2D = _DebugOverlay.new()
	var collision_layer: TileLayerResource = _zone_state.zone_config.get_layer("collision")
	overlay.call("configure", collision_layer, TILE_SIZE)
	add_child(overlay)
	_debug_overlay = overlay


func _build_tile_map_layer(layer_name: String) -> void:
	var layer: TileLayerResource = _zone_state.zone_config.get_layer(layer_name)
	if layer == null:
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# One TileSetAtlasSource per palette entry.
	var key_to_source_id: Dictionary = {}
	for palette_key: String in layer.tile_palette:
		var tile_def: TileDefinitionResource = layer.tile_palette[palette_key]
		key_to_source_id[palette_key] = _add_color_source(tile_set, _tile_color(tile_def))

	# Add to the scene tree before calling set_cell().
	var map_layer := TileMapLayer.new()
	map_layer.tile_set = tile_set
	add_child(map_layer)

	for y: int in range(layer.height):
		for x: int in range(layer.width):
			var key: String = layer.tile_ids[y * layer.width + x]
			if key == "" or not key_to_source_id.has(key):
				continue
			map_layer.set_cell(Vector2i(x, y), key_to_source_id[key], Vector2i(0, 0))


## Builds a single solid-colour TileSetAtlasSource, adds it to tile_set,
## and returns the assigned source_id.
func _add_color_source(tile_set: TileSet, color: Color) -> int:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)

	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i(0, 0))

	return tile_set.add_source(source)


func _tile_color(tile: TileDefinitionResource) -> Color:
	for tag: String in tile.tags:
		if _TAG_COLORS.has(tag):
			return _TAG_COLORS[tag]
	return _TAG_COLORS["_default"]
