extends Node2D

@onready var ground_tml: TileMapLayer = $"../Ground"
@onready var decoration_tml: TileMapLayer = $"../Decoration"
@onready var decoration_effects_tml: TileMapLayer = $"../Decoration/Effects"
@onready var overhead_tml: TileMapLayer = $"../Overhead"
@onready var overhead_effects_tml: TileMapLayer = $"../Overhead/Effects"


func _ready() -> void:
	print("Initializing tile placer")
	print(ground_tml)
	nocab()
	ground_tml.set_cell(
		Vector2i(2, 4), # position in the game world tile map to place
		0, # source_id (UUID of the sprite-sheet in the tileset atlas)
		Vector2i(1, 1), # atlas_coordinates (The specific sprite in the sprite sheet to use)
		0 # alternative_tile
	)

func call_print(message: String) -> void:
	print(message)

func _process(_delta: float) -> void:
	pass

func nocab() -> void:
	var tile_lookup: Dictionary = {
	"0": {
			"collision_layer": [],
			"sprite": "ground",
			"sprite_sheet_uuid": 0,
			"sprite_sheet_position_x": 16,
			"sprite_sheet_position_y": 5
		},
	"water": {
			"collision_layer": [2],
			"sprite": "water",
			"sprite_sheet_uuid": 3,
			"sprite_sheet_position_x": 12,
			"sprite_sheet_position_y": 11
		},
	"2": {
			"collision_layer": [1, 2],
			"sprite": "wall",
			"sprite_sheet_uuid": 0,
			"sprite_sheet_position_x": 16,
			"sprite_sheet_position_y": 6
		}
	}

	var tile_array: Array = [
		["0", "0", "0",     "0"],
		["0", "0", "water", "0", "none", "none", "0", "0"],
		["2", "0", "water", "0", "0",    "0",    "0", "0"],
		["2", "0", "0",     "0", "0",    "0",    "0", "0"]
	]

	load_tiles(tile_lookup, tile_array)


func load_tiles(tile_lookup: Dictionary, 
				ground_tile_array: Array) -> void:
	var tile_set: TileSet = ground_tml.tile_set;

	for cur_row_index in ground_tile_array.size():
		var world_y = cur_row_index
		var current_row = ground_tile_array[cur_row_index]

		for cur_column_index in current_row.size():
			var world_x = cur_column_index
			var current_cell_id = current_row[cur_column_index]
			if current_cell_id == "none":
				continue
			
			var current_tile_def = tile_lookup[current_cell_id]
			var tile_x = current_tile_def["sprite_sheet_position_x"]
			var tile_y = current_tile_def["sprite_sheet_position_y"]
			var sprite_sheet_uuid = current_tile_def["sprite_sheet_uuid"]

			ground_tml.set_cell(
				Vector2i(world_x, world_y),
				sprite_sheet_uuid,
				Vector2i(tile_x, tile_y)
			)
			
			# Add collision to the tile
			# TODO: Consider doing Maximal Rectangle here to merge collision shapes for performance
			var tileCollisionObj = create_static_collision(
				collision_mask_to_bitmask(current_tile_def["collision_layer"]),
				64,
				Vector2i(world_x, world_y),
				true
			)
			ground_tml.add_child(tileCollisionObj)
		# Finished processing the current row
	# Finished processing the entire tile array

func create_static_collision(collision_layer: int,
							tile_side_length: int = 64,
							tile_position: Vector2i = Vector2i(0, 0),
							adjust_to_center: bool = true) -> StaticBody2D:
	# The static body to return
	var tileCollisionObj = StaticBody2D.new()
	tileCollisionObj.collision_layer = collision_layer

	# Specify the shape of the collision shape
	var tileCollisionShape = CollisionShape2D.new()
	tileCollisionShape.shape = RectangleShape2D.new()
	tileCollisionShape.shape.size = Vector2(tile_side_length, tile_side_length)
	var nudge_x = 0.5 if adjust_to_center else 0.0
	var nudge_y = 0.5 if adjust_to_center else 0.0
	tileCollisionShape.position = Vector2(
		(tile_position.x + nudge_x) * tile_side_length, 
		(tile_position.y + nudge_y) * tile_side_length
	)
	tileCollisionObj.add_child(tileCollisionShape)
	return tileCollisionObj

func collision_mask_to_bitmask(collision_mask: Array) -> int:
	var bitmask = 0
	for layer in collision_mask:
		bitmask |= 1 << (layer - 1)
	print("Collision mask to bitmask: %s -> %s" % [collision_mask, bitmask])
	return bitmask
