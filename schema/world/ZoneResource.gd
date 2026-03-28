class_name ZoneResource
extends Resource
## Top-level zone configuration. Loaded by ConfigLoader.load_zone().
## layers is an ordered Array[TileLayerResource]; "ground" is drawn first, "collision" provides
## passability. spawn_points maps name → Vector2i tile position.

@export var id: String = ""
@export var display_name: String = ""
@export var width: int = 20
@export var height: int = 15
@export var spawn_points: Dictionary = {}     # { name: String → Vector2i }
@export var layers: Array = []                # Array[TileLayerResource]
@export var entities: Array = []              # Array[EntityDefinitionResource]
@export var default_encounter_table: EncounterTableResource = null


## Returns the named layer, or null if not found.
func get_layer(layer_name: String) -> TileLayerResource:
	for layer: TileLayerResource in layers:
		if layer.name == layer_name:
			return layer
	return null


## Returns the spawn Vector2i for the given name.
## Falls back to "default", then to Vector2i(1, 1).
func get_spawn(spawn_name: String) -> Vector2i:
	if spawn_points.has(spawn_name):
		return spawn_points[spawn_name]
	if spawn_points.has("default"):
		return spawn_points["default"]
	return Vector2i(1, 1)


func serialize() -> Dictionary:
	var spawn_data: Dictionary = {}
	for k: String in spawn_points:
		var v: Vector2i = spawn_points[k]
		spawn_data[k] = {"x": v.x, "y": v.y}
	var layer_data: Array = []
	for l: TileLayerResource in layers:
		layer_data.append(l.serialize())
	var entity_data: Array = []
	for e: EntityDefinitionResource in entities:
		entity_data.append(e.serialize())
	return {
		"id": id,
		"display_name": display_name,
		"width": width,
		"height": height,
		"spawn_points": spawn_data,
		"layers": layer_data,
		"entities": entity_data,
		"default_encounter_table": default_encounter_table.serialize() if default_encounter_table else null,
	}


static func deserialize(data: Dictionary) -> ZoneResource:
	var r := ZoneResource.new()
	r.deserialize_update(data)
	return r


func deserialize_update(data: Dictionary) -> void:
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	width = data.get("width", 20)
	height = data.get("height", 15)
	spawn_points = {}
	for k: String in data.get("spawn_points", {}):
		var v: Dictionary = data["spawn_points"][k]
		spawn_points[k] = Vector2i(v.get("x", 0), v.get("y", 0))
	layers = []
	for l: Dictionary in data.get("layers", []):
		layers.append(TileLayerResource.deserialize(l))
	entities = []
	for e: Dictionary in data.get("entities", []):
		entities.append(EntityDefinitionResource.deserialize(e))
	var table_data: Variant = data.get("default_encounter_table", null)
	default_encounter_table = EncounterTableResource.deserialize(table_data) if table_data else null


func deep_copy() -> ZoneResource:
	return ZoneResource.deserialize(serialize())
