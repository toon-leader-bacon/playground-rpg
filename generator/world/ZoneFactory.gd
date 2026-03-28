class_name ZoneFactory
extends RefCounted
## Builds ZoneResource instances.
## RNG is injected via _init() so tests can produce deterministic output.

var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator = null) -> void:
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()


## Builds a simple route-style zone: grass terrain, tall-grass encounter patches,
## south-facing ledge, warp at top, encounter table, sign + wandering NPC.
func build_simple_route(id: String, display_name: String, width: int, height: int) -> ZoneResource:
	var zone := ZoneResource.new()
	zone.id = id
	zone.display_name = display_name
	zone.width = width
	zone.height = height

	zone.spawn_points["default"] = Vector2i(2, height - 4)
	zone.spawn_points["north_exit"] = Vector2i(width / 2, 1)

	zone.layers.append(_make_ground_layer(width, height))
	zone.layers.append(_make_collision_layer(width, height))

	zone.default_encounter_table = _make_default_encounter_table()
	zone.entities.append(_make_sign_entity(width / 2 - 1, height / 2))
	zone.entities.append(_make_wanderer_entity(width / 2 + 2, height / 2 + 1))

	return zone


# ---------------------------------------------------------------------------
# Ground layer
# ---------------------------------------------------------------------------

func _make_ground_layer(width: int, height: int) -> TileLayerResource:
	var layer := TileLayerResource.new()
	layer.name = "ground"
	layer.width = width
	layer.height = height

	# Build tiles.
	var grass := _make_grass_tile()
	var tall_grass := _make_tall_grass_tile()
	var water := _make_water_tile()
	var path := _make_path_tile()
	var warp_tile := _make_warp_tile()

	layer.tile_palette["g"] = grass
	layer.tile_palette["t"] = tall_grass
	layer.tile_palette["w"] = water
	layer.tile_palette["p"] = path
	layer.tile_palette["x"] = warp_tile

	# Fill with grass; add tall-grass patches in center; water on east edge;
	# path column down the middle; warp at (width/2, 0).
	var ids: Array[String] = []
	var warp_col: int = width / 2
	var tall_min_x: int = warp_col - 3
	var tall_max_x: int = warp_col + 3
	var tall_min_y: int = height / 2 - 2
	var tall_max_y: int = height / 2 + 2

	for y: int in range(height):
		for x: int in range(width):
			if y == 0 and x == warp_col:
				ids.append("x")
			elif x == width - 1:
				ids.append("w")
			elif x == warp_col and (y == 0 or y == 1):
				ids.append("p")
			elif _in_tall_grass_patch(x, y, tall_min_x, tall_max_x, tall_min_y, tall_max_y):
				ids.append("t")
			else:
				ids.append("g")

	layer.tile_ids = PackedStringArray(ids)
	return layer


func _in_tall_grass_patch(x: int, y: int, min_x: int, max_x: int, min_y: int, max_y: int) -> bool:
	return x >= min_x and x <= max_x and y >= min_y and y <= max_y


# ---------------------------------------------------------------------------
# Collision layer
# ---------------------------------------------------------------------------

func _make_collision_layer(width: int, height: int) -> TileLayerResource:
	var layer := TileLayerResource.new()
	layer.name = "collision"
	layer.width = width
	layer.height = height

	var wall := TileDefinitionResource.new()
	wall.tags = ["wall"]
	wall.passability_mask = TileDefinitionResource.IMPASSABLE

	# Ledge: passable only moving south (ENTER_N | EXIT_S = 0x21).
	var ledge := TileDefinitionResource.new()
	ledge.tags = ["ledge_south"]
	ledge.passability_mask = TileDefinitionResource.ENTER_N | TileDefinitionResource.EXIT_S

	layer.tile_palette["W"] = wall
	layer.tile_palette["L"] = ledge

	var ledge_row: int = height - 5
	var ids: Array[String] = []
	for y: int in range(height):
		for x: int in range(width):
			if _is_boundary_wall(x, y, width, height):
				ids.append("W")
			elif y == ledge_row:
				ids.append("L")
			else:
				ids.append("")
	layer.tile_ids = PackedStringArray(ids)
	return layer


func _is_boundary_wall(x: int, y: int, width: int, height: int) -> bool:
	return x == 0 or y == 0 or x == width - 1 or y == height - 1


# ---------------------------------------------------------------------------
# Tile builders
# ---------------------------------------------------------------------------

func _make_grass_tile() -> TileDefinitionResource:
	var t := TileDefinitionResource.new()
	t.tags = ["grass"]
	t.passability_mask = TileDefinitionResource.PASSABLE_ALL
	return t


func _make_tall_grass_tile() -> TileDefinitionResource:
	var effect := TileEffectResource.new()
	effect.effect_tag = "encounter_check"
	effect.args = {}

	var t := TileDefinitionResource.new()
	t.tags = ["tall_grass"]
	t.passability_mask = TileDefinitionResource.PASSABLE_ALL
	t.on_enter_effect = effect
	return t


func _make_water_tile() -> TileDefinitionResource:
	var t := TileDefinitionResource.new()
	t.tags = ["water"]
	t.passability_mask = TileDefinitionResource.IMPASSABLE
	return t


func _make_path_tile() -> TileDefinitionResource:
	var t := TileDefinitionResource.new()
	t.tags = ["path"]
	t.passability_mask = TileDefinitionResource.PASSABLE_ALL
	return t


func _make_warp_tile() -> TileDefinitionResource:
	var effect := TileEffectResource.new()
	effect.effect_tag = "warp"
	effect.args = {"zone_id": "test_zone", "spawn_point_id": "north_exit"}

	var t := TileDefinitionResource.new()
	t.tags = ["warp"]
	t.passability_mask = TileDefinitionResource.PASSABLE_ALL
	t.on_enter_effect = effect
	return t


# ---------------------------------------------------------------------------
# Encounter table
# ---------------------------------------------------------------------------

func _make_default_encounter_table() -> EncounterTableResource:
	var table := EncounterTableResource.new()
	table.encounter_probability = 0.15

	var e1 := EncounterEntryResource.new()
	e1.monster_id = "fire_lizard"
	e1.weight = 3.0
	e1.level_min = 2
	e1.level_max = 4

	var e2 := EncounterEntryResource.new()
	e2.monster_id = "stone_golem"
	e2.weight = 1.0
	e2.level_min = 3
	e2.level_max = 5

	table.entries.append(e1)
	table.entries.append(e2)
	return table


# ---------------------------------------------------------------------------
# Entities
# ---------------------------------------------------------------------------

func _make_sign_entity(x: int, y: int) -> EntityDefinitionResource:
	var effect := TileEffectResource.new()
	effect.effect_tag = "show_text"
	effect.args = {"text": "Hello, world!"}

	var e := EntityDefinitionResource.new()
	e.id = "sign_01"
	e.display_name = "Sign"
	e.position = Vector2i(x, y)
	e.on_interact_effect = effect
	e.movement_behavior_tag = ""
	e.collidable = true
	e.interactable = true
	return e


func _make_wanderer_entity(x: int, y: int) -> EntityDefinitionResource:
	var e := EntityDefinitionResource.new()
	e.id = "npc_wanderer"
	e.display_name = "Wanderer"
	e.position = Vector2i(x, y)
	e.movement_behavior_tag = "wander"
	e.collidable = true
	e.interactable = true
	e.wander_interval = 0.8
	return e
