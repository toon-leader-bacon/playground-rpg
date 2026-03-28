extends GdUnitTestSuite
## Tests for engine/world/model/ZoneState.gd

const _ZoneState := preload("res://engine/world/model/ZoneState.gd")


func test_create_initializes_player_at_spawn_point() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()

	var state: ZoneState = ZoneState.create(zone, "default", bb)

	assert_that(state.player_position).is_equal(Vector2i(1, 1))


func test_create_uses_fallback_spawn_when_name_missing() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()

	var state: ZoneState = ZoneState.create(zone, "nonexistent_spawn", bb)

	# Fallback is "default" → (1,1)
	assert_that(state.player_position).is_equal(Vector2i(1, 1))


func test_create_initializes_entity_positions() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()

	var state: ZoneState = ZoneState.create(zone, "default", bb)

	assert_bool(state.entity_positions.has("test_npc")).is_true()
	assert_that(state.entity_positions["test_npc"]).is_equal(Vector2i(3, 3))


func test_get_tile_at_ground_layer() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()
	var state: ZoneState = ZoneState.create(zone, "default", bb)

	var tile: TileDefinitionResource = state.get_tile_at("ground", Vector2i(1, 1))
	assert_object(tile).is_not_null()
	assert_array(tile.tags).contains(["floor"])


func test_get_tile_at_missing_layer_returns_null() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()
	var state: ZoneState = ZoneState.create(zone, "default", bb)

	assert_object(state.get_tile_at("collision", Vector2i(1, 1))).is_null()


func test_get_effective_collision_tile_falls_back_to_ground() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()
	var state: ZoneState = ZoneState.create(zone, "default", bb)

	# No collision layer exists — should fall back to ground.
	var tile: TileDefinitionResource = state.get_effective_collision_tile(Vector2i(2, 2))
	assert_object(tile).is_not_null()
	assert_array(tile.tags).contains(["wall"])


func test_is_entity_at_returns_true() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()
	var state: ZoneState = ZoneState.create(zone, "default", bb)

	assert_bool(state.is_entity_at(Vector2i(3, 3))).is_true()


func test_is_entity_at_returns_false_for_empty_tile() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()
	var state: ZoneState = ZoneState.create(zone, "default", bb)

	assert_bool(state.is_entity_at(Vector2i(1, 1))).is_false()


func test_is_entity_at_returns_false_after_removal() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()
	var state: ZoneState = ZoneState.create(zone, "default", bb)

	state.removed_entities.append("test_npc")
	assert_bool(state.is_entity_at(Vector2i(3, 3))).is_false()


func test_get_entity_at_returns_id() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()
	var state: ZoneState = ZoneState.create(zone, "default", bb)

	assert_str(state.get_entity_at(Vector2i(3, 3))).is_equal("test_npc")


func test_get_entity_at_empty_tile_returns_empty_string() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()
	var state: ZoneState = ZoneState.create(zone, "default", bb)

	assert_str(state.get_entity_at(Vector2i(0, 0))).is_equal("")


func test_is_in_bounds_edge_cases() -> void:
	var zone: ZoneResource = _make_5x5_zone()
	var bb := Blackboard.new()
	var state: ZoneState = ZoneState.create(zone, "default", bb)

	# Inside.
	assert_bool(state.is_in_bounds(Vector2i(0, 0))).is_true()
	assert_bool(state.is_in_bounds(Vector2i(4, 4))).is_true()
	# Outside.
	assert_bool(state.is_in_bounds(Vector2i(-1, 0))).is_false()
	assert_bool(state.is_in_bounds(Vector2i(0, -1))).is_false()
	assert_bool(state.is_in_bounds(Vector2i(5, 0))).is_false()
	assert_bool(state.is_in_bounds(Vector2i(0, 5))).is_false()


# ---------------------------------------------------------------------------
# Helper — 5×5 zone with ground layer and one NPC
# ---------------------------------------------------------------------------

func _make_5x5_zone() -> ZoneResource:
	var zone := ZoneResource.new()
	zone.id = "unit_zone"
	zone.display_name = "Unit Zone"
	zone.width = 5
	zone.height = 5
	zone.spawn_points["default"] = Vector2i(1, 1)

	var floor_tile := TileDefinitionResource.new()
	floor_tile.tags = ["floor"]
	floor_tile.passability_mask = TileDefinitionResource.PASSABLE_ALL

	var wall_tile := TileDefinitionResource.new()
	wall_tile.tags = ["wall"]
	wall_tile.passability_mask = TileDefinitionResource.IMPASSABLE

	var ground_layer := TileLayerResource.new()
	ground_layer.name = "ground"
	ground_layer.width = 5
	ground_layer.height = 5
	ground_layer.tile_palette["f"] = floor_tile
	ground_layer.tile_palette["w"] = wall_tile
	var ids: Array[String] = []
	for y: int in range(5):
		for x: int in range(5):
			if x == 2 and y == 2:
				ids.append("w")
			else:
				ids.append("f")
	ground_layer.tile_ids = PackedStringArray(ids)
	zone.layers.append(ground_layer)

	var entity := EntityDefinitionResource.new()
	entity.id = "test_npc"
	entity.position = Vector2i(3, 3)
	entity.collidable = true
	entity.interactable = true
	zone.entities.append(entity)

	return zone
