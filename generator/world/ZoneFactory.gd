class_name ZoneFactory
extends RefCounted
## Factory for generating ZoneResource instances.
## Accepts an RNG for reproducible output. All tile definitions are built locally.

const _SPRITE_BASE: String = "res://assets/sprites/raw/6 Colors Solid Objects Pack/solid_TEXTURES/"

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


## Build a simple grass route zone with border walls, tall-grass encounter patch,
## a warp tile, a path strip, a water column, and basic entities.
func build_route(id: String, display_name: String, w: int, h: int) -> ZoneResource:
	var zone := ZoneResource.new()
	zone.id = id
	zone.display_name = display_name
	zone.width = w
	zone.height = h

	# ── Tile palette ──────────────────────────────────────────────────────────
	# Index 0: wall
	var wall := _make_tile("wall", PackedStringArray(["wall", "solid"]),
		1, 0, _load_tex("red_solid.png"))
	# Index 1: grass
	var grass := _make_tile("grass_standard", PackedStringArray(["grass", "outdoor"]),
		0, 255, _load_tex("green_solid.png"))
	# Index 2: tall_grass (with encounter_check on_enter)
	var tall_grass := _make_tile("tall_grass", PackedStringArray(["grass", "tall_grass", "outdoor"]),
		0, 255, _load_tex("green_solid.png"))
	tall_grass.on_enter = _make_effect("encounter_check", {})
	# Index 3: path
	var path := _make_tile("path", PackedStringArray(["path", "outdoor"]),
		0, 255, _load_tex("orange_solid.png"))
	# Index 4: water
	var water := _make_tile("water_blocked", PackedStringArray(["water"]),
		2, 0, _load_tex("blue_solid.png"))
	# Index 5: warp
	var warp_tile := _make_tile("warp_north", PackedStringArray(["warp"]),
		0, 255, _load_tex("purple_solid.png"))
	warp_tile.on_enter = _make_effect("warp", {"zone_id": id, "spawn_point": "default"})

	zone.local_tile_palette = [wall, grass, tall_grass, path, water, warp_tile]

	# ── Layer ground ──────────────────────────────────────────────────────────
	var ground: PackedInt32Array = PackedInt32Array()
	ground.resize(w * h)
	for i: int in ground.size():
		ground[i] = 1  # default: grass

	# Border walls
	for x: int in range(w):
		ground[0 * w + x] = 0       # top row
		ground[(h - 1) * w + x] = 0 # bottom row
	for y: int in range(h):
		ground[y * w + 0] = 0       # left col
		ground[y * w + (w - 1)] = 0 # right col

	# Path strip: column x=4, rows 1..h-2
	for y: int in range(1, h - 1):
		ground[y * w + 4] = 3

	# Tall grass patch: rows 3..6, cols 6..9
	for y: int in range(3, min(7, h - 1)):
		for x: int in range(6, min(10, w - 1)):
			ground[y * w + x] = 2

	# Water column: x=w-3, rows 2..h-2
	for y: int in range(2, h - 2):
		ground[y * w + (w - 3)] = 4

	# Warp at top inside border (row 1, center)
	ground[1 * w + (w / 2)] = 5

	zone.layer_ground = ground

	# ── Layer decoration: all void ────────────────────────────────────────────
	var deco: PackedInt32Array = PackedInt32Array()
	deco.resize(w * h)
	for i: int in deco.size():
		deco[i] = -1
	zone.layer_decoration = deco

	# ── Spawn points ──────────────────────────────────────────────────────────
	zone.spawn_points = {
		"default": Vector2i(2, h - 3),
		"north_exit": Vector2i(w / 2, 2)
	}

	# ── Entities ──────────────────────────────────────────────────────────────
	var sign := EntityDefinitionResource.new()
	sign.id = "sign_01"
	sign.display_name = "Route Sign"
	sign.position = Vector2i(2, h - 4)
	sign.has_collision = false
	sign.physics_layer = 0
	sign.on_interact = _make_effect("show_text", {
		"text": "Route sign: tall grass ahead. Wild encounters await!"
	})
	sign.tags = PackedStringArray(["static_interactable", "sign"])

	var npc := EntityDefinitionResource.new()
	npc.id = "wanderer_01"
	npc.display_name = "Wandering NPC"
	npc.position = Vector2i(8, 8)
	npc.has_collision = true
	npc.physics_layer = 3
	npc.on_interact = _make_effect("show_text", {"text": "Hello, traveler!"})
	npc.movement_behavior = _make_effect("wander", {})
	npc.tags = PackedStringArray(["npc"])

	zone.entities = [sign, npc]

	# ── Encounter table ───────────────────────────────────────────────────────
	var table := EncounterTableResource.new()
	table.encounter_chance = 0.15

	var fire_entry := EncounterEntryResource.new()
	fire_entry.monster_id = "fire_lizard"
	fire_entry.weight = 1.0
	fire_entry.level_min = 3
	fire_entry.level_max = 8

	var golem_entry := EncounterEntryResource.new()
	golem_entry.monster_id = "stone_golem"
	golem_entry.weight = 0.5
	golem_entry.level_min = 4
	golem_entry.level_max = 9

	table.entries = [fire_entry, golem_entry]
	zone.default_encounter_table = table

	return zone


# ── Helpers ──────────────────────────────────────────────────────────────────

func _make_tile(id: String, tags: PackedStringArray, phys_layer: int,
		passability: int, tex: Texture2D) -> TileDefinitionResource:
	var td := TileDefinitionResource.new()
	td.id = id
	td.tags = tags
	td.physics_layer = phys_layer
	td.passability_mask = passability
	td.texture = tex
	return td


func _make_effect(tag: String, args: Dictionary) -> TileEffectResource:
	var eff := TileEffectResource.new()
	eff.effect_tag = tag
	eff.args = args
	return eff


func _load_tex(filename: String) -> Texture2D:
	var path: String = _SPRITE_BASE + filename
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
