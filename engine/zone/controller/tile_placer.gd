extends Node2D
class_name TilePlacer

@onready var ground_tml: TileMapLayer = $"../Ground"
@onready var decoration_tml: TileMapLayer = $"../Decoration"
@onready var decoration_effects_tml: TileMapLayer = $"../Decoration/Effects"
@onready var overhead_tml: TileMapLayer = $"../Overhead"
@onready var overhead_effects_tml: TileMapLayer = $"../Overhead/Effects"

@onready var _player: Node2D = $"../Player"

var _dispatcher: TileEventDispatcher


func _ready() -> void:
	_register_collision_handlers()
	print("Initializing tile placer")
	print(ground_tml)
	var tile_body_map: Dictionary[Vector2i, StaticBody2D] = nocab()
	ground_tml.set_cell(
		Vector2i(2, 4), # position in the game world tile map to place
		0, # source_id (UUID of the sprite-sheet in the tileset atlas)
		Vector2i(1, 1), # atlas_coordinates (The specific sprite in the sprite sheet to use)
		0 # alternative_tile
	)
	_dispatcher = TileEventDispatcher.new()
	add_child(_dispatcher)
	_dispatcher.setup(_player, tile_body_map)


func _register_collision_handlers() -> void:
	CollisionRegistry.register("call_print", func(config: Array) -> TileCollidable:
		var c := TileCollidable.new()
		c.set_handler(func(_player: Node2D) -> void:
			print(config[0] if config.size() > 0 else "")
		)
		return c
	)
	CollisionRegistry.register("bonk_counter", func(_config: Array) -> TileCollidable:
		return BonkCounterCollidable.new()
	)
	CollisionRegistry.register("water_bonk_counter", func(_config: Array) -> TileCollidable:
		return WaterBonkCollidable.new()
	)
	CollisionRegistry.register("call_print_enter", func(config: Array) -> TileCollidable:
		var c := TileCollidable.new()
		c.set_enter_handler(func(_player: Node2D) -> void:
			print(config[0] if config.size() > 0 else "entered tile")
		)
		return c
	)
	CollisionRegistry.register("call_print_exit", func(config: Array) -> TileCollidable:
		var c := TileCollidable.new()
		c.set_exit_handler(func(_player: Node2D) -> void:
			print(config[0] if config.size() > 0 else "exited tile")
		)
		return c
	)

func call_print(message: String) -> void:
	print(message)

func nocab() -> Dictionary[Vector2i, StaticBody2D]:
	var tile_lookup: Dictionary = {
	"0": {
			"collision_layer": [],
			"sprite": "ground",
			"sprite_sheet_uuid": 0,
			"sprite_sheet_position_x": 16,
			"sprite_sheet_position_y": 5,
			"on_enter": {"function": "call_print_enter", "config": ["-> ground"]},
			"on_exit": {"function": "call_print_exit", "config": ["<- ground"]}
		},
	"water": {
			"collision_layer": [2],
			"sprite": "water",
			"sprite_sheet_uuid": 3,
			"sprite_sheet_position_x": 12,
			"sprite_sheet_position_y": 11,
			"on_collision": {"function": "water_bonk_counter"}
		},
	"2": {
			"collision_layer": [1, 2],
			"sprite": "wall",
			"sprite_sheet_uuid": 0,
			"sprite_sheet_position_x": 16,
			"sprite_sheet_position_y": 6,
			"on_collision": {"function": "bonk_counter"}
		}
	}

	var tile_array: Array = [
		["0", "0", "0",     "0"],
		["0", "0", "water", "0", "none", "none", "0", "0"],
		["2", "0", "water", "0", "0",    "0",    "0", "0"],
		["2", "0", "0",     "0", "0",    "0",    "0", "0"]
	]

	return load_tiles(tile_lookup, tile_array)


func load_tiles(tile_lookup: Dictionary,
				ground_tile_array: Array) -> Dictionary[Vector2i, StaticBody2D]:
	var tile_body_map: Dictionary[Vector2i, StaticBody2D] = {}

	for cur_row_index: int in ground_tile_array.size():
		var world_y: int = cur_row_index
		var current_row: Array = ground_tile_array[cur_row_index]

		for cur_column_index: int in current_row.size():
			var world_x: int = cur_column_index
			var current_cell_id: String = current_row[cur_column_index]
			if current_cell_id == "none":
				continue

			var current_tile_def: Dictionary = tile_lookup[current_cell_id]
			var tile_x: int = current_tile_def["sprite_sheet_position_x"]
			var tile_y: int = current_tile_def["sprite_sheet_position_y"]
			var sprite_sheet_uuid: int = current_tile_def["sprite_sheet_uuid"]

			ground_tml.set_cell(
				Vector2i(world_x, world_y),
				sprite_sheet_uuid,
				Vector2i(tile_x, tile_y)
			)

			# Add collision to the tile
			# TODO: Consider doing Maximal Rectangle here to merge collision shapes for performance
			var tile_pos: Vector2i = Vector2i(world_x, world_y)
			var tile_body: StaticBody2D = create_static_collision(
				collision_mask_to_bitmask(current_tile_def["collision_layer"]),
				64,
				tile_pos,
				true,
				_parse_collision_config(current_tile_def.get("on_collision", null)),
				_parse_collision_config(current_tile_def.get("on_enter", null)),
				_parse_collision_config(current_tile_def.get("on_exit", null))
			)
			ground_tml.add_child(tile_body)
			tile_body_map[tile_pos] = tile_body
		# Finished processing the current row
	# Finished processing the entire tile array
	return tile_body_map


func _parse_collision_config(raw: Variant) -> Dictionary:
	if raw == null:
		return {}
	if raw is String:
		return {"tag": raw, "config": []}
	if raw is Dictionary:
		return {
			"tag": raw.get("function", ""),
			"config": raw.get("config", [])
		}
	return {}

func create_static_collision(collision_layer: int,
							tile_side_length: int = 64,
							tile_position: Vector2i = Vector2i(0, 0),
							adjust_to_center: bool = true,
							on_collision: Dictionary = {},
							on_enter: Dictionary = {},
							on_exit: Dictionary = {}) -> StaticBody2D:
	var tile_body: StaticBody2D = StaticBody2D.new()
	tile_body.collision_layer = collision_layer

	var tile_shape: CollisionShape2D = CollisionShape2D.new()
	tile_shape.shape = RectangleShape2D.new()
	tile_shape.shape.size = Vector2(tile_side_length, tile_side_length)
	var nudge_x: float = 0.5 if adjust_to_center else 0.0
	var nudge_y: float = 0.5 if adjust_to_center else 0.0
	tile_shape.position = Vector2(
		(tile_position.x + nudge_x) * tile_side_length,
		(tile_position.y + nudge_y) * tile_side_length
	)
	tile_body.add_child(tile_shape)

	_attach_collidable(tile_body, on_collision)
	_attach_collidable(tile_body, on_enter)
	_attach_collidable(tile_body, on_exit)

	return tile_body


func _attach_collidable(body: StaticBody2D, config: Dictionary) -> void:
	if config.is_empty():
		return
	var collidable: TileCollidable = CollisionRegistry.create(
		config.get("tag", ""),
		config.get("config", []))
	if collidable != null:
		body.add_child(collidable)

func collision_mask_to_bitmask(collision_mask: Array) -> int:
	var bitmask: int = 0
	for layer: int in collision_mask:
		bitmask |= 1 << (layer - 1)
	print("Collision mask to bitmask: %s -> %s" % [collision_mask, bitmask])
	return bitmask
