class_name ZoneState
extends RefCounted
## Runtime mutable state for one loaded zone.
## Analogous to BattleStateNvM in the battle system.
## zone_config holds the immutable ZoneResource; all mutable state lives here.

const _Blackboard := preload("res://engine/shared/model/Blackboard.gd")

var zone_config: Resource = null         # ZoneResource at runtime
var zone_bb: Blackboard = null           # points to GameState.zone_bb
var entity_positions: Dictionary = {}    # { entity_id: String → Vector2i }
var removed_entities: Array[String] = []
var player_position: Vector2i = Vector2i.ZERO
var player_facing: Vector2i = Vector2i(0, 1)   # default facing south


static func create(config: Resource, spawn_point_id: String, bb: Blackboard) -> ZoneState:
	var s := ZoneState.new()
	s.zone_config = config
	s.zone_bb = bb
	s.player_position = config.get_spawn(spawn_point_id)
	for entity_def: EntityDefinitionResource in config.entities:
		s.entity_positions[entity_def.id] = entity_def.position
	return s


## Returns the tile at (x, y) in the named layer, or null if void/OOB.
func get_tile_at(layer_name: String, pos: Vector2i) -> TileDefinitionResource:
	var layer: TileLayerResource = zone_config.get_layer(layer_name)
	if layer == null:
		return null
	return layer.get_tile(pos.x, pos.y)


## Collision layer takes precedence; falls back to ground layer.
func get_effective_collision_tile(pos: Vector2i) -> TileDefinitionResource:
	var collision: TileDefinitionResource = get_tile_at("collision", pos)
	if collision != null:
		return collision
	return get_tile_at("ground", pos)


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < zone_config.width and pos.y < zone_config.height


## Returns true if any non-removed entity occupies pos.
func is_entity_at(pos: Vector2i) -> bool:
	for id: String in entity_positions:
		if id not in removed_entities and entity_positions[id] == pos:
			return true
	return false


## Returns the entity_id at pos, or "" if none.
func get_entity_at(pos: Vector2i) -> String:
	for id: String in entity_positions:
		if id not in removed_entities and entity_positions[id] == pos:
			return id
	return ""
