extends GdUnitTestSuite
## Tests for ZoneResource schema class and its helper methods.

# ── Defaults ─────────────────────────────────────────────────────────────────

func test_zone_resource_defaults() -> void:
	var zone := ZoneResource.new()
	assert_str(zone.id).is_equal("")
	assert_str(zone.display_name).is_equal("")
	assert_int(zone.width).is_equal(0)
	assert_int(zone.height).is_equal(0)
	assert_that(zone.spawn_points).is_equal({})
	assert_that(zone.local_tile_palette).is_equal([])
	assert_that(zone.layer_ground).is_equal(PackedInt32Array())
	assert_that(zone.layer_decoration).is_equal(PackedInt32Array())
	assert_that(zone.entities).is_equal([])
	assert_object(zone.default_encounter_table).is_null()


func test_tile_definition_defaults() -> void:
	var td := TileDefinitionResource.new()
	assert_str(td.id).is_equal("")
	assert_int(td.passability_mask).is_equal(255)
	assert_int(td.physics_layer).is_equal(0)
	assert_that(td.conditions).is_equal([])
	assert_object(td.on_enter).is_null()
	assert_object(td.on_exit).is_null()
	assert_object(td.encounter_table_override).is_null()


func test_tile_effect_resource_defaults() -> void:
	var eff := TileEffectResource.new()
	assert_str(eff.effect_tag).is_equal("")
	assert_that(eff.args).is_equal({})


func test_entity_definition_defaults() -> void:
	var ent := EntityDefinitionResource.new()
	assert_str(ent.id).is_equal("")
	assert_int(ent.z_index).is_equal(2)
	assert_bool(ent.has_collision).is_true()
	assert_int(ent.physics_layer).is_equal(3)
	assert_str(ent.persistence_scope).is_equal("")
	assert_str(ent.flag_open_condition).is_equal("")


func test_encounter_entry_defaults() -> void:
	var entry := EncounterEntryResource.new()
	assert_str(entry.monster_id).is_equal("")
	assert_float(entry.weight).is_equal(1.0)
	assert_int(entry.level_min).is_equal(1)
	assert_int(entry.level_max).is_equal(5)


func test_encounter_table_defaults() -> void:
	var table := EncounterTableResource.new()
	assert_float(table.encounter_chance).is_equal(0.1)
	assert_that(table.entries).is_equal([])

# ── get_tile_at_ground ────────────────────────────────────────────────────────

func _make_zone_3x3() -> ZoneResource:
	var zone := ZoneResource.new()
	zone.id = "test"
	zone.width = 3
	zone.height = 3

	var grass := TileDefinitionResource.new()
	grass.id = "grass"
	grass.passability_mask = 255

	var water := TileDefinitionResource.new()
	water.id = "water"
	water.passability_mask = 0
	water.physics_layer = 2

	zone.local_tile_palette = [grass, water]
	# row y=0: grass grass grass
	# row y=1: water grass grass
	# row y=2: grass grass grass
	zone.layer_ground = PackedInt32Array([0, 0, 0,  1, 0, 0,  0, 0, 0])
	zone.layer_decoration = PackedInt32Array([-1, -1, -1,  -1, -1, -1,  -1, -1, -1])
	zone.spawn_points = {"default": Vector2i(1, 1)}
	return zone


func test_get_tile_at_ground_grass_cell() -> void:
	var zone := _make_zone_3x3()
	var td: TileDefinitionResource = zone.get_tile_at_ground(0, 0)
	assert_object(td).is_not_null()
	assert_str(td.id).is_equal("grass")


func test_get_tile_at_ground_water_cell() -> void:
	var zone := _make_zone_3x3()
	var td: TileDefinitionResource = zone.get_tile_at_ground(0, 1)
	assert_object(td).is_not_null()
	assert_str(td.id).is_equal("water")


func test_get_tile_at_ground_center_grass() -> void:
	var zone := _make_zone_3x3()
	var td: TileDefinitionResource = zone.get_tile_at_ground(1, 1)
	assert_object(td).is_not_null()
	assert_str(td.id).is_equal("grass")


func test_get_tile_at_ground_void_index() -> void:
	var zone := _make_zone_3x3()
	# Manually set a void (-1) cell
	zone.layer_ground[4] = -1  # center cell
	var td: TileDefinitionResource = zone.get_tile_at_ground(1, 1)
	assert_object(td).is_null()


func test_get_tile_at_ground_out_of_bounds_negative() -> void:
	var zone := _make_zone_3x3()
	assert_object(zone.get_tile_at_ground(-1, 0)).is_null()
	assert_object(zone.get_tile_at_ground(0, -1)).is_null()


func test_get_tile_at_ground_out_of_bounds_positive() -> void:
	var zone := _make_zone_3x3()
	assert_object(zone.get_tile_at_ground(3, 0)).is_null()
	assert_object(zone.get_tile_at_ground(0, 3)).is_null()

# ── get_spawn ─────────────────────────────────────────────────────────────────

func test_get_spawn_named() -> void:
	var zone := _make_zone_3x3()
	zone.spawn_points["north"] = Vector2i(1, 0)
	var result: Vector2i = zone.get_spawn("north")
	assert_that(result).is_equal(Vector2i(1, 0))


func test_get_spawn_default_fallback() -> void:
	var zone := _make_zone_3x3()
	var result: Vector2i = zone.get_spawn("nonexistent")
	assert_that(result).is_equal(Vector2i(1, 1))  # "default" spawn in test zone


func test_get_spawn_hardcoded_fallback() -> void:
	var zone := _make_zone_3x3()
	zone.spawn_points.clear()
	var result: Vector2i = zone.get_spawn("anything")
	assert_that(result).is_equal(Vector2i(1, 1))  # final hardcoded fallback

# ── EncounterTableResource.weighted_pick ──────────────────────────────────────

func test_weighted_pick_returns_null_on_empty() -> void:
	var table := EncounterTableResource.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	assert_object(table.weighted_pick(rng)).is_null()


func test_weighted_pick_single_entry() -> void:
	var table := EncounterTableResource.new()
	var entry := EncounterEntryResource.new()
	entry.monster_id = "fire_lizard"
	entry.weight = 1.0
	table.entries = [entry]

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var result: EncounterEntryResource = table.weighted_pick(rng)
	assert_object(result).is_not_null()
	assert_str(result.monster_id).is_equal("fire_lizard")


func test_weighted_pick_high_weight_wins_majority() -> void:
	var table := EncounterTableResource.new()
	var common := EncounterEntryResource.new()
	common.monster_id = "common"
	common.weight = 99.0
	var rare := EncounterEntryResource.new()
	rare.monster_id = "rare"
	rare.weight = 1.0
	table.entries = [common, rare]

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var common_count: int = 0
	for _i: int in range(100):
		var result: EncounterEntryResource = table.weighted_pick(rng)
		if result.monster_id == "common":
			common_count += 1
	assert_int(common_count).is_greater(85)  # should win the vast majority
