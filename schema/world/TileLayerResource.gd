class_name TileLayerResource
extends Resource
## A single named layer of tiles in a zone (e.g. "ground", "decoration", "collision").
##
## Uses a palette approach: tile_palette maps a short string key to a TileDefinitionResource,
## and tile_ids is a flat PackedStringArray of width*height entries (row-major, "" = void/empty).
##
## Access a tile: tile_palette.get(tile_ids[y * width + x], null)

@export var name: String = ""
@export var width: int = 0
@export var height: int = 0
@export var tile_palette: Dictionary = {}        # { key: String → TileDefinitionResource }
@export var tile_ids: PackedStringArray = PackedStringArray()


func get_tile(x: int, y: int) -> TileDefinitionResource:
	if x < 0 or y < 0 or x >= width or y >= height:
		return null
	var key: String = tile_ids[y * width + x]
	if key == "":
		return null
	return tile_palette.get(key, null) as TileDefinitionResource


func serialize() -> Dictionary:
	var palette_data: Dictionary = {}
	for key: String in tile_palette:
		var tile: TileDefinitionResource = tile_palette[key]
		palette_data[key] = tile.serialize()
	return {
		"name": name,
		"width": width,
		"height": height,
		"tile_palette": palette_data,
		"tile_ids": Array(tile_ids),
	}


static func deserialize(data: Dictionary) -> TileLayerResource:
	var r := TileLayerResource.new()
	r.deserialize_update(data)
	return r


func deserialize_update(data: Dictionary) -> void:
	name = data.get("name", "")
	width = data.get("width", 0)
	height = data.get("height", 0)
	tile_palette = {}
	for key: String in data.get("tile_palette", {}):
		tile_palette[key] = TileDefinitionResource.deserialize(data["tile_palette"][key])
	tile_ids = PackedStringArray(data.get("tile_ids", []))


func deep_copy() -> TileLayerResource:
	return TileLayerResource.deserialize(serialize())
