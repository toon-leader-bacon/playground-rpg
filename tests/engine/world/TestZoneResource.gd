extends GdUnitTestSuite
## Tests for schema/world/ — serialization round-trips, tile palette lookups,
## encounter table helpers, and passability constant values.


# ---------------------------------------------------------------------------
# ZoneResource
# ---------------------------------------------------------------------------

func test_zone_resource_serialize_round_trip() -> void:
	var zone := ZoneResource.new()
	zone.id = "test_zone"
	zone.display_name = "Test Zone"
	zone.width = 10
	zone.height = 8
	zone.spawn_points["default"] = Vector2i(2, 3)
	zone.spawn_points["north_exit"] = Vector2i(5, 1)

	var data: Dictionary = zone.serialize()
	var copy := ZoneResource.deserialize(data)

	assert_str(copy.id).is_equal("test_zone")
	assert_str(copy.display_name).is_equal("Test Zone")
	assert_int(copy.width).is_equal(10)
	assert_int(copy.height).is_equal(8)
	assert_that(copy.get_spawn("default")).is_equal(Vector2i(2, 3))
	assert_that(copy.get_spawn("north_exit")).is_equal(Vector2i(5, 1))


func test_zone_resource_get_spawn_fallback_to_default() -> void:
	var zone := ZoneResource.new()
	zone.spawn_points["default"] = Vector2i(1, 1)

	assert_that(zone.get_spawn("nonexistent")).is_equal(Vector2i(1, 1))


func test_zone_resource_get_spawn_fallback_to_1_1() -> void:
	var zone := ZoneResource.new()
	# No spawn points set.
	assert_that(zone.get_spawn("any")).is_equal(Vector2i(1, 1))


func test_zone_resource_get_layer_by_name() -> void:
	var zone := ZoneResource.new()
	var layer := TileLayerResource.new()
	layer.name = "ground"
	zone.layers.append(layer)

	var result: TileLayerResource = zone.get_layer("ground")
	assert_object(result).is_not_null()
	assert_str(result.name).is_equal("ground")


func test_zone_resource_get_layer_missing_returns_null() -> void:
	var zone := ZoneResource.new()
	assert_object(zone.get_layer("collision")).is_null()


# ---------------------------------------------------------------------------
# TileDefinitionResource
# ---------------------------------------------------------------------------

func test_tile_definition_serialize_round_trip() -> void:
	var tile := TileDefinitionResource.new()
	tile.tags = ["grass", "walkable"]
	tile.passability_mask = TileDefinitionResource.PASSABLE_ALL

	var data: Dictionary = tile.serialize()
	var copy := TileDefinitionResource.deserialize(data)

	assert_array(copy.tags).contains(["grass", "walkable"])
	assert_int(copy.passability_mask).is_equal(TileDefinitionResource.PASSABLE_ALL)


func test_tile_definition_with_effect_round_trips() -> void:
	var effect := TileEffectResource.new()
	effect.effect_tag = "show_text"
	effect.args = {"text": "Hello!"}

	var tile := TileDefinitionResource.new()
	tile.on_enter_effect = effect

	var copy := TileDefinitionResource.deserialize(tile.serialize())

	assert_object(copy.on_enter_effect).is_not_null()
	assert_str(copy.on_enter_effect.effect_tag).is_equal("show_text")
	assert_str(copy.on_enter_effect.args.get("text", "")).is_equal("Hello!")


# ---------------------------------------------------------------------------
# TileLayerResource
# ---------------------------------------------------------------------------

func test_tile_layer_get_tile_at_valid_pos() -> void:
	var layer: TileLayerResource = _make_3x3_layer()

	var result: TileDefinitionResource = layer.get_tile(1, 1)
	assert_object(result).is_not_null()
	assert_array(result.tags).contains(["floor"])


func test_tile_layer_get_tile_at_void_returns_null() -> void:
	var layer := TileLayerResource.new()
	layer.width = 2
	layer.height = 2
	layer.tile_ids = PackedStringArray(["", "", "", ""])

	assert_object(layer.get_tile(0, 0)).is_null()
	assert_object(layer.get_tile(1, 1)).is_null()


func test_tile_layer_get_tile_at_out_of_bounds_returns_null() -> void:
	var layer: TileLayerResource = _make_3x3_layer()

	assert_object(layer.get_tile(-1, 0)).is_null()
	assert_object(layer.get_tile(0, -1)).is_null()
	assert_object(layer.get_tile(3, 0)).is_null()
	assert_object(layer.get_tile(0, 3)).is_null()


func test_tile_layer_serialize_round_trip() -> void:
	var layer: TileLayerResource = _make_3x3_layer()
	var copy := TileLayerResource.deserialize(layer.serialize())

	assert_str(copy.name).is_equal("ground")
	assert_int(copy.width).is_equal(3)
	assert_int(copy.height).is_equal(3)
	assert_int(copy.tile_palette.size()).is_equal(1)
	assert_object(copy.get_tile(1, 1)).is_not_null()


# ---------------------------------------------------------------------------
# EncounterTableResource
# ---------------------------------------------------------------------------

func test_encounter_table_resource_round_trip() -> void:
	var table := EncounterTableResource.new()
	table.encounter_probability = 0.2
	var entry := EncounterEntryResource.new()
	entry.monster_id = "fire_lizard"
	entry.weight = 3.0
	entry.level_min = 2
	entry.level_max = 4
	table.entries.append(entry)

	var copy := EncounterTableResource.deserialize(table.serialize())

	assert_float(copy.encounter_probability).is_equal(0.2)
	assert_int(copy.entries.size()).is_equal(1)
	var copy_entry: EncounterEntryResource = copy.entries[0] as EncounterEntryResource
	assert_str(copy_entry.monster_id).is_equal("fire_lizard")
	assert_float(copy_entry.weight).is_equal(3.0)
	assert_int(copy_entry.level_min).is_equal(2)
	assert_int(copy_entry.level_max).is_equal(4)


func test_encounter_table_weighted_pick_returns_entry() -> void:
	var table := EncounterTableResource.new()
	var entry := EncounterEntryResource.new()
	entry.monster_id = "stone_golem"
	entry.weight = 1.0
	table.entries.append(entry)

	var rng := RandomNumberGenerator.new()
	var result: EncounterEntryResource = table.weighted_pick(rng)
	assert_object(result).is_not_null()
	assert_str(result.monster_id).is_equal("stone_golem")


func test_encounter_table_weighted_pick_empty_returns_null() -> void:
	var table := EncounterTableResource.new()
	var rng := RandomNumberGenerator.new()
	assert_object(table.weighted_pick(rng)).is_null()


# ---------------------------------------------------------------------------
# EntityDefinitionResource
# ---------------------------------------------------------------------------

func test_entity_definition_round_trip() -> void:
	var entity := EntityDefinitionResource.new()
	entity.id = "sign_01"
	entity.display_name = "Old Sign"
	entity.position = Vector2i(5, 5)
	entity.movement_behavior_tag = ""
	entity.collidable = true
	entity.interactable = true

	var copy := EntityDefinitionResource.deserialize(entity.serialize())

	assert_str(copy.id).is_equal("sign_01")
	assert_str(copy.display_name).is_equal("Old Sign")
	assert_that(copy.position).is_equal(Vector2i(5, 5))
	assert_bool(copy.collidable).is_true()
	assert_bool(copy.interactable).is_true()


func test_entity_definition_patrol_path_round_trip() -> void:
	var entity := EntityDefinitionResource.new()
	entity.id = "patrol_npc"
	entity.movement_behavior_tag = "patrol"
	entity.patrol_path = [Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3)]

	var copy := EntityDefinitionResource.deserialize(entity.serialize())

	assert_str(copy.movement_behavior_tag).is_equal("patrol")
	assert_int(copy.patrol_path.size()).is_equal(3)
	assert_that(copy.patrol_path[0]).is_equal(Vector2i(1, 1))
	assert_that(copy.patrol_path[2]).is_equal(Vector2i(3, 3))


# ---------------------------------------------------------------------------
# PassabilityConditionEntry
# ---------------------------------------------------------------------------

func test_passability_condition_entry_round_trip() -> void:
	var cond := PassabilityConditionEntry.new()
	cond.direction_mask = TileDefinitionResource.ENTER_N
	cond.condition_tag = "flag:bridge_repaired"

	var copy := PassabilityConditionEntry.deserialize(cond.serialize())

	assert_int(copy.direction_mask).is_equal(TileDefinitionResource.ENTER_N)
	assert_str(copy.condition_tag).is_equal("flag:bridge_repaired")


# ---------------------------------------------------------------------------
# Passability constant values
# ---------------------------------------------------------------------------

func test_passability_constants_all_directions() -> void:
	assert_int(TileDefinitionResource.ENTER_N).is_equal(1)
	assert_int(TileDefinitionResource.ENTER_S).is_equal(2)
	assert_int(TileDefinitionResource.ENTER_E).is_equal(4)
	assert_int(TileDefinitionResource.ENTER_W).is_equal(8)
	assert_int(TileDefinitionResource.EXIT_N).is_equal(16)
	assert_int(TileDefinitionResource.EXIT_S).is_equal(32)
	assert_int(TileDefinitionResource.EXIT_E).is_equal(64)
	assert_int(TileDefinitionResource.EXIT_W).is_equal(128)
	assert_int(TileDefinitionResource.PASSABLE_ALL).is_equal(0xFF)
	assert_int(TileDefinitionResource.IMPASSABLE).is_equal(0x00)


func test_ledge_south_mask_value() -> void:
	var ledge_south: int = TileDefinitionResource.ENTER_N | TileDefinitionResource.EXIT_S
	assert_int(ledge_south).is_equal(0x21)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_3x3_layer() -> TileLayerResource:
	var layer := TileLayerResource.new()
	layer.name = "ground"
	layer.width = 3
	layer.height = 3
	var floor_tile := TileDefinitionResource.new()
	floor_tile.tags = ["floor"]
	floor_tile.passability_mask = TileDefinitionResource.PASSABLE_ALL
	layer.tile_palette["f"] = floor_tile
	layer.tile_ids = PackedStringArray(["f", "f", "f", "f", "f", "f", "f", "f", "f"])
	return layer
