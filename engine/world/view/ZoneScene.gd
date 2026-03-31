extends Node2D
## Main runtime scene for any zone. Loaded by WorldManager / zone transitions.
## Populates TileMapLayers from ZoneResource, spawns entities, handles warp transitions.

const _TileEffectRegistry = preload("res://engine/world/controller/TileEffectRegistry.gd")
const _EntityRegistry = preload("res://engine/world/controller/EntityRegistry.gd")
const _MovementController = preload("res://engine/world/controller/MovementController.gd")

const TILE_SIZE: int = 16

@export var zone_id: String = "test_zone"
@export var spawn_point: String = "default"

@onready var _ground_layer: TileMapLayer = $ground
@onready var _deco_layer: TileMapLayer = $decoration
@onready var _entities_root: Node2D = $Entities
@onready var _camera: Camera2D = $Camera2D

var _zone_res: ZoneResource = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _player: PlayerEntityNode = null
var _pending_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_TileEffectRegistry.init_registry()
	_EntityRegistry.clear()
	_rng.randomize()
	_load_zone(zone_id, spawn_point)
	EventBus.zone_warp_requested.connect(_on_warp_requested)
	WorldClock.post_tick.connect(_on_post_tick)
	EventBus.zone_show_text.connect(_on_show_text)


func _load_zone(id: String, spawn: String) -> void:
	_zone_res = ConfigLoader.load_zone(id)
	if _zone_res == null:
		push_error("ZoneScene: failed to load zone '%s'" % id)
		return

	var global_registry: GlobalTileRegistry = ConfigLoader.load_global_tile_registry()
	var palette: Array = []
	if global_registry != null:
		palette.append_array(global_registry.tiles)
	palette.append_array(_zone_res.local_tile_palette)

	var tile_set_data: Dictionary = _build_tile_set(palette)
	var built_ts: TileSet = tile_set_data["tile_set"]
	var source_ids: Array = tile_set_data["source_ids"]

	_ground_layer.tile_set = built_ts
	_deco_layer.tile_set = built_ts

	_populate_layer(_ground_layer, _zone_res.layer_ground, palette, source_ids)
	_populate_layer(_deco_layer, _zone_res.layer_decoration, palette, source_ids)

	_EntityRegistry.clear()
	for child: Node in _entities_root.get_children():
		child.queue_free()

	for ent_def: Variant in _zone_res.entities:
		_spawn_entity(ent_def as EntityDefinitionResource)

	var spawn_cell: Vector2i = _zone_res.get_spawn(spawn)
	_spawn_player(spawn_cell)

	_setup_camera()
	EventBus.zone_loaded.emit(id, _zone_res.display_name)


func _build_tile_set(palette: Array) -> Dictionary:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Add physics layers: world_static (1), water (2), entities (3)
	ts.add_physics_layer()  # index 0 → physics layer 1 (world_static)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.add_physics_layer()  # index 1 → physics layer 2 (water)
	ts.set_physics_layer_collision_layer(1, 2)

	var source_ids: Array = []
	for i: int in palette.size():
		var td := palette[i] as TileDefinitionResource
		if td == null:
			source_ids.append(-1)
			continue

		var tex: Texture2D = td.texture if td.texture != null else _make_color_texture(_tag_color(td))

		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		src.create_tile(Vector2i(0, 0))

		# Source must be added to TileSet BEFORE accessing TileData physics layers
		var sid: int = ts.add_source(src)
		source_ids.append(sid)

		if td.physics_layer == 1:
			var tile_data: TileData = src.get_tile_data(Vector2i(0, 0), 0)
			tile_data.set_collision_polygons_count(0, 1)
			tile_data.set_collision_polygon_points(0, 0,
				PackedVector2Array([
					Vector2(0, 0), Vector2(TILE_SIZE, 0),
					Vector2(TILE_SIZE, TILE_SIZE), Vector2(0, TILE_SIZE)
				]))
		elif td.physics_layer == 2:
			var tile_data: TileData = src.get_tile_data(Vector2i(0, 0), 0)
			tile_data.set_collision_polygons_count(1, 1)
			tile_data.set_collision_polygon_points(1, 0,
				PackedVector2Array([
					Vector2(0, 0), Vector2(TILE_SIZE, 0),
					Vector2(TILE_SIZE, TILE_SIZE), Vector2(0, TILE_SIZE)
				]))

	return {"tile_set": ts, "source_ids": source_ids}


func _populate_layer(layer: TileMapLayer, data: PackedInt32Array, palette: Array, source_ids: Array) -> void:
	for i: int in data.size():
		var tile_idx: int = data[i]
		if tile_idx == -1:
			continue
		if tile_idx >= palette.size() or tile_idx >= source_ids.size():
			continue
		var sid: int = source_ids[tile_idx]
		if sid == -1:
			continue
		var cell: Vector2i = Vector2i(i % _zone_res.width, i / _zone_res.width)
		layer.set_cell(cell, sid, Vector2i(0, 0))


func _spawn_entity(def: EntityDefinitionResource) -> void:
	if def == null:
		return
	var entity := EntityNode.new()
	entity.name = def.id

	# Add collision shape
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	col.shape = shape
	entity.add_child(col)

	# Add sprite with texture (fallback color if no sprite asset defined)
	var sprite := Sprite2D.new()
	if def.sprite != null:
		sprite.texture = def.sprite
	else:
		sprite.texture = _make_entity_color_texture(def.tags)
	entity.add_child(sprite)

	_entities_root.add_child(entity)
	entity.initialize(def, _zone_res, _rng)
	# Set collision layer/mask for entities (physics layer 3 = bit 4)
	entity.set_collision_layer_value(3, def.has_collision)
	entity.set_collision_mask_value(1, true)
	entity.set_collision_mask_value(3, true)


func _spawn_player(cell: Vector2i) -> void:
	if _player != null:
		_player.queue_free()
	_player = PlayerEntityNode.new()
	_player.name = "Player"

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	col.shape = shape
	_player.add_child(col)

	var sprite := Sprite2D.new()
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.7, 1.0))  # cyan — player
	sprite.texture = ImageTexture.create_from_image(img)
	_player.add_child(sprite)

	_entities_root.add_child(_player)

	# Physics: layer=3(entities), mask=1(world_static)+3(entities)
	_player.set_collision_layer_value(3, true)
	_player.set_collision_mask_value(1, true)
	_player.set_collision_mask_value(2, true)  # water blocks by default
	_player.set_collision_mask_value(3, true)

	_player.setup(cell, _zone_res, _rng)
	_pending_cell = cell

	if _camera != null:
		_camera.global_position = _cell_to_world(cell)


func _setup_camera() -> void:
	if _camera == null or _zone_res == null:
		return
	var zone_width_px: float = _zone_res.width * TILE_SIZE
	var zone_height_px: float = _zone_res.height * TILE_SIZE
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(zone_width_px)
	_camera.limit_bottom = int(zone_height_px)
	# Zoom so 16px tiles are legible at 1920×1080.
	# Each tile appears as TILE_SIZE * zoom pixels on screen.
	_camera.zoom = Vector2(3.0, 3.0)


func _on_post_tick() -> void:
	if _player == null or _zone_res == null:
		return
	# Follow player with camera
	if _camera != null:
		_camera.global_position = _player.global_position
	# Dispatch on_enter for current player cell and encounter check
	_MovementController.dispatch_enter_effects(
		_player.name,
		_player.logical_cell,
		_zone_res,
		_rng)


func _on_show_text(text: String) -> void:
	print("[Zone] ", text)


func _on_warp_requested(warp_zone_id: String, warp_spawn: String) -> void:
	# Reload same scene with new zone
	_EntityRegistry.clear()
	WorldBoard.clear_zone_scope()
	_load_zone(warp_zone_id, warp_spawn)


# ── Procedural tile color fallback ───────────────────────────────────────────

## Returns a color for a tile based on its tags when no texture is assigned.
func _tag_color(td: TileDefinitionResource) -> Color:
	var tags: PackedStringArray = td.tags
	if tags.has("wall"):
		return Color(0.4, 0.4, 0.4)
	if tags.has("water"):
		return Color(0.2, 0.4, 0.8)
	if tags.has("warp"):
		return Color(0.8, 0.3, 0.9)
	if tags.has("path"):
		return Color(0.7, 0.6, 0.4)
	if tags.has("tall_grass"):
		return Color(0.2, 0.5, 0.15)
	if tags.has("grass"):
		return Color(0.3, 0.6, 0.2)
	return Color(0.15, 0.15, 0.15)


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5


func _make_entity_color_texture(tags: PackedStringArray) -> ImageTexture:
	var color: Color = Color(1.0, 0.85, 0.1)  # yellow — generic entity
	if tags.has("npc"):
		color = Color(0.9, 0.5, 0.1)           # orange — NPC
	elif tags.has("sign"):
		color = Color(0.6, 0.4, 0.2)           # brown — sign
	return _make_color_texture(color)


## Creates a 32×32 solid-color ImageTexture for procedural tile rendering.
func _make_color_texture(color: Color) -> ImageTexture:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGB8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
