extends GdUnitTestSuite
## Tests for engine/world/controller/ZoneController.gd

const _ZoneController := preload("res://engine/world/controller/ZoneController.gd")
const _TileEffectRegistry := preload("res://engine/world/controller/TileEffectRegistry.gd")
const _ZoneState := preload("res://engine/world/model/ZoneState.gd")
const _MoveResult := preload("res://engine/world/model/MoveResult.gd")


func before() -> void:
	_TileEffectRegistry.init_registry()


# ---------------------------------------------------------------------------
# try_move — basic passability
# ---------------------------------------------------------------------------

func test_try_move_passable_tile_succeeds() -> void:
	var state: ZoneState = _make_state()
	var rng := RandomNumberGenerator.new()

	var result: MoveResult = _ZoneController.try_move(state, "player", Vector2i(1, 0), rng)

	assert_bool(result.success).is_true()
	assert_that(result.new_pos).is_equal(Vector2i(2, 1))
	assert_that(state.player_position).is_equal(Vector2i(2, 1))


func test_try_move_impassable_tile_fails() -> void:
	var state: ZoneState = _make_state()
	var rng := RandomNumberGenerator.new()
	# Player at (1,1), wall at (2,2). Move south twice to reach wall row.
	_ZoneController.try_move(state, "player", Vector2i(0, 1), rng)  # now at (1,2)
	var result: MoveResult = _ZoneController.try_move(state, "player", Vector2i(1, 0), rng)  # tries (2,2)

	assert_bool(result.success).is_false()
	assert_str(result.blocked_reason).is_equal("impassable")
	assert_that(state.player_position).is_equal(Vector2i(1, 2))


func test_try_move_out_of_bounds_fails() -> void:
	var state: ZoneState = _make_state()
	var rng := RandomNumberGenerator.new()
	# Player at (1,1), try to move to (-1, 1).
	state.player_position = Vector2i(0, 1)
	var result: MoveResult = _ZoneController.try_move(state, "player", Vector2i(-1, 0), rng)

	assert_bool(result.success).is_false()
	assert_str(result.blocked_reason).is_equal("bounds")


func test_try_move_blocked_by_entity() -> void:
	var state: ZoneState = _make_state()
	var rng := RandomNumberGenerator.new()
	# NPC is at (3,3). Player at (1,1).
	state.player_position = Vector2i(2, 3)
	var result: MoveResult = _ZoneController.try_move(state, "player", Vector2i(1, 0), rng)

	assert_bool(result.success).is_false()
	assert_str(result.blocked_reason).is_equal("entity")


# ---------------------------------------------------------------------------
# try_move — ledge (south-only passability)
# ---------------------------------------------------------------------------

func test_try_move_ledge_south_allowed() -> void:
	var state: ZoneState = _make_state_with_ledge()
	var rng := RandomNumberGenerator.new()
	# Player above ledge row, moves south (direction 0,+1) — allowed (ENTER_N | EXIT_S).
	state.player_position = Vector2i(1, 2)

	var result: MoveResult = _ZoneController.try_move(state, "player", Vector2i(0, 1), rng)

	assert_bool(result.success).is_true()
	assert_that(result.new_pos).is_equal(Vector2i(1, 3))


func test_try_move_ledge_north_blocked() -> void:
	var state: ZoneState = _make_state_with_ledge()
	var rng := RandomNumberGenerator.new()
	# Player is below ledge row, tries to move north (direction 0,-1) — blocked.
	state.player_position = Vector2i(1, 3)

	var result: MoveResult = _ZoneController.try_move(state, "player", Vector2i(0, -1), rng)

	assert_bool(result.success).is_false()
	assert_str(result.blocked_reason).is_equal("impassable")


# ---------------------------------------------------------------------------
# try_move_entity
# ---------------------------------------------------------------------------

func test_try_move_entity_succeeds_on_passable_tile() -> void:
	var state: ZoneState = _make_state()
	var rng := RandomNumberGenerator.new()

	var result: MoveResult = _ZoneController.try_move_entity(state, "test_npc", Vector2i(-1, 0), rng)

	assert_bool(result.success).is_true()
	assert_that(result.new_pos).is_equal(Vector2i(2, 3))
	assert_that(state.entity_positions["test_npc"]).is_equal(Vector2i(2, 3))


func test_try_move_entity_does_not_trigger_tile_effects() -> void:
	# An entity stepping on an effect tile should not emit zone_tile_effect_triggered.
	var state: ZoneState = _make_state_with_effect_tile()
	var rng := RandomNumberGenerator.new()
	# Place entity one step away from effect tile at (2,1).
	state.entity_positions["test_npc"] = Vector2i(1, 1)

	var triggered: Array[bool] = [false]
	EventBus.zone_tile_effect_triggered.connect(func(_tag: String, _actor: String) -> void:
		triggered[0] = true
	)

	var _result: MoveResult = _ZoneController.try_move_entity(state, "test_npc", Vector2i(1, 0), rng)

	# Effect tile at (2,1): entity move should NOT fire it.
	assert_bool(triggered[0]).is_false()


# ---------------------------------------------------------------------------
# try_interact
# ---------------------------------------------------------------------------

func test_try_interact_with_entity_dispatches_effect() -> void:
	var state: ZoneState = _make_state()
	var effect := TileEffectResource.new()
	effect.effect_tag = "show_text"
	effect.args = {"text": "Hi there!"}
	# Give the test_npc an interact effect.
	for e: EntityDefinitionResource in state.zone_config.entities:
		if e.id == "test_npc":
			e.on_interact_effect = effect
			break

	var messages: Array[String] = []
	EventBus.zone_message_shown.connect(func(text: String) -> void:
		messages.append(text)
	)

	state.player_position = Vector2i(2, 3)
	var facing: Vector2i = Vector2i(1, 0)  # facing east toward (3,3)
	var interacted: bool = _ZoneController.try_interact(state, state.player_position, facing)

	assert_bool(interacted).is_true()
	assert_int(messages.size()).is_equal(1)
	assert_str(messages[0]).is_equal("Hi there!")


func test_try_interact_with_empty_tile_returns_false() -> void:
	var state: ZoneState = _make_state()
	var facing: Vector2i = Vector2i(1, 0)
	# Facing east from (0,0) — no entity at (1,0).
	state.player_position = Vector2i(0, 0)

	var result: bool = _ZoneController.try_interact(state, state.player_position, facing)

	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_state() -> ZoneState:
	var zone := _make_5x5_zone()
	return ZoneState.create(zone, "default", Blackboard.new())


func _make_state_with_ledge() -> ZoneState:
	var zone := _make_5x5_zone()
	# Add a collision layer with a ledge at y=3 (ENTER_N | EXIT_S = 0x21).
	var ledge_tile := TileDefinitionResource.new()
	ledge_tile.tags = ["ledge_south"]
	ledge_tile.passability_mask = TileDefinitionResource.ENTER_N | TileDefinitionResource.EXIT_S

	var floor_tile := TileDefinitionResource.new()
	floor_tile.tags = ["floor"]
	floor_tile.passability_mask = TileDefinitionResource.PASSABLE_ALL

	var collision := TileLayerResource.new()
	collision.name = "collision"
	collision.width = 5
	collision.height = 5
	collision.tile_palette["l"] = ledge_tile
	collision.tile_palette["f"] = floor_tile
	var ids: Array[String] = []
	for y: int in range(5):
		for x: int in range(5):
			if y == 3:
				ids.append("l")
			else:
				ids.append("f")
	collision.tile_ids = PackedStringArray(ids)
	zone.layers.append(collision)
	return ZoneState.create(zone, "default", Blackboard.new())


func _make_state_with_effect_tile() -> ZoneState:
	var zone := _make_5x5_zone()
	# Add an on_enter_effect to the tile at (2,1) in the ground layer.
	var effect := TileEffectResource.new()
	effect.effect_tag = "show_text"
	effect.args = {"text": "effect fired"}

	var effect_tile := TileDefinitionResource.new()
	effect_tile.tags = ["floor"]
	effect_tile.passability_mask = TileDefinitionResource.PASSABLE_ALL
	effect_tile.on_enter_effect = effect

	var ground: TileLayerResource = zone.get_layer("ground")
	ground.tile_palette["e"] = effect_tile
	# Overwrite cell (2,1) with effect tile key.
	var ids: PackedStringArray = ground.tile_ids.duplicate()
	ids[1 * 5 + 2] = "e"
	ground.tile_ids = ids

	return ZoneState.create(zone, "default", Blackboard.new())


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

	var ground := TileLayerResource.new()
	ground.name = "ground"
	ground.width = 5
	ground.height = 5
	ground.tile_palette["f"] = floor_tile
	ground.tile_palette["w"] = wall_tile
	var ids: Array[String] = []
	for y: int in range(5):
		for x: int in range(5):
			if x == 2 and y == 2:
				ids.append("w")
			else:
				ids.append("f")
	ground.tile_ids = PackedStringArray(ids)
	zone.layers.append(ground)

	var entity := EntityDefinitionResource.new()
	entity.id = "test_npc"
	entity.position = Vector2i(3, 3)
	entity.collidable = true
	entity.interactable = true
	zone.entities.append(entity)

	return zone
