class_name ZoneResource
extends Resource
## Top-level zone definition. One .tres file per zone in content/zones/.

@export var id: String = ""
@export var display_name: String = ""
@export var width: int = 0
@export var height: int = 0
## String → Vector2i. Must contain "default".
@export var spawn_points: Dictionary = {}
## Array[TileDefinitionResource] — untyped for .tres compatibility.
@export var local_tile_palette: Array = []
## Flat PackedInt32Array, row-major, length = width * height. -1 = void cell.
@export var layer_ground: PackedInt32Array = PackedInt32Array()
@export var layer_decoration: PackedInt32Array = PackedInt32Array()
## Array[EntityDefinitionResource] — untyped for .tres compatibility.
@export var entities: Array = []
@export var default_encounter_table: EncounterTableResource = null


## Returns the TileDefinitionResource at grid cell (x, y) from the ground layer.
## Returns null if the index is -1 (void) or out of bounds.
func get_tile_at_ground(x: int, y: int) -> TileDefinitionResource:
	if x < 0 or x >= width or y < 0 or y >= height:
		return null
	var idx: int = layer_ground[y * width + x]
	if idx == -1 or idx >= local_tile_palette.size():
		return null
	return local_tile_palette[idx] as TileDefinitionResource


## Returns the spawn Vector2i for the given name.
## Falls back to "default", then to Vector2i(1, 1).
func get_spawn(name: String) -> Vector2i:
	if spawn_points.has(name):
		return spawn_points[name] as Vector2i
	if spawn_points.has("default"):
		return spawn_points["default"] as Vector2i
	return Vector2i(1, 1)
