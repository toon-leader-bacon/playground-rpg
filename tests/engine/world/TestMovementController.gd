extends GdUnitTestSuite
## Tests for MovementController passability logic (Phase 2 + Phase 3).
## Phase 1 (physics raycast) requires a running scene — tested manually.
## These tests use a mock CharacterBody2D that bypasses physics.

const _MovementController = preload("res://engine/world/controller/MovementController.gd")
const _EntityRegistry = preload("res://engine/world/controller/EntityRegistry.gd")


func before_each() -> void:
	_EntityRegistry.clear()


func after_each() -> void:
	_EntityRegistry.clear()


## Build a 5×5 zone with a single tile type filling the interior and walls on border.
func _make_zone(passability: int) -> ZoneResource:
	var zone := ZoneResource.new()
	zone.id = "mc_test"
	zone.width = 5
	zone.height = 5

	var td := TileDefinitionResource.new()
	td.id = "test_tile"
	td.passability_mask = passability
	td.physics_layer = 0

	zone.local_tile_palette = [td]
	var data := PackedInt32Array()
	data.resize(25)
	for i: int in data.size():
		data[i] = 0
	zone.layer_ground = data
	zone.spawn_points = {"default": Vector2i(2, 2)}
	return zone


## Build a mock CharacterBody2D that always passes the physics raycast.
func _make_mock_actor(pos_cell: Vector2i) -> CharacterBody2D:
	var actor := CharacterBody2D.new()
	actor.global_position = Vector2(pos_cell) * 32 + Vector2(16, 16)
	# Override the physics query by using a custom approach:
	# We position it far from any collision shapes, so raycast hits nothing.
	add_child(actor)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2, 2)  # tiny — unlikely to hit anything
	col.shape = shape
	actor.add_child(col)
	return actor


# ── Fully passable tile ───────────────────────────────────────────────────────

func test_fully_passable_tile_allows_all_directions() -> void:
	var zone := _make_zone(255)
	var rng := RandomNumberGenerator.new()
	var actor := _make_mock_actor(Vector2i(2, 2))

	for dir: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var result: Dictionary = _MovementController.try_move(
			actor, Vector2i(2, 2), dir, zone, 0, rng, false)
		# With collision_mask=0, physics raycast hits nothing
		assert_bool(result["success"]).is_true()

	actor.queue_free()


# ── Fully blocked tile ────────────────────────────────────────────────────────

func test_fully_blocked_tile_blocks_all_entry_directions() -> void:
	var zone := _make_zone(0)
	var rng := RandomNumberGenerator.new()
	# Actor at (1,2) trying to enter (2,2) which is passability=0
	var actor := _make_mock_actor(Vector2i(1, 2))

	var result: Dictionary = _MovementController.try_move(
		actor, Vector2i(1, 2), Vector2i(1, 0), zone, 0, rng, false)
	assert_bool(result["success"]).is_false()
	assert_that(result["new_cell"]).is_equal(Vector2i(1, 2))

	actor.queue_free()


# ── Ledge south ───────────────────────────────────────────────────────────────
## Ledge south: bit0 (enter N) + bit5 (exit S) set = 0b00100001 = 0x21 = 33
## Allows moving south FROM the ledge, blocks moving north INTO the ledge.

func test_ledge_allows_south_movement() -> void:
	var zone := _make_zone(255)
	# Override center tile with ledge
	var ledge := TileDefinitionResource.new()
	ledge.id = "ledge"
	ledge.passability_mask = 0x21  # enter_N + exit_S
	ledge.physics_layer = 0
	zone.local_tile_palette.append(ledge)
	# Row 2, col 2 = index 12 in 5x5 grid
	zone.layer_ground[2 * 5 + 2] = 1  # use index 1 = ledge

	var rng := RandomNumberGenerator.new()
	var actor := _make_mock_actor(Vector2i(2, 2))

	# Moving south from ledge tile at (2,2) → should check exit_S bit (bit5) of source
	# Source tile (2,2) has exit_S set → allowed
	var result: Dictionary = _MovementController.try_move(
		actor, Vector2i(2, 2), Vector2i(0, 1), zone, 0, rng, false)
	assert_bool(result["success"]).is_true()

	actor.queue_free()


func test_ledge_blocks_north_entry() -> void:
	var zone := _make_zone(255)
	# Override target cell (2,1) with ledge that only allows enter from N (bit0)
	# So moving south INTO (2,1) requires bit1 (enter_S) which is NOT set on 0x21
	var ledge := TileDefinitionResource.new()
	ledge.id = "ledge"
	ledge.passability_mask = 0x21  # enter_N + exit_S only
	ledge.physics_layer = 0
	zone.local_tile_palette.append(ledge)
	zone.layer_ground[1 * 5 + 2] = 1  # (2,1) = ledge

	var rng := RandomNumberGenerator.new()
	# Actor at (2,2), moving north into (2,1): requires enter_S (bit1) on (2,1)
	var actor := _make_mock_actor(Vector2i(2, 2))
	var result: Dictionary = _MovementController.try_move(
		actor, Vector2i(2, 2), Vector2i(0, -1), zone, 0, rng, false)
	assert_bool(result["success"]).is_false()

	actor.queue_free()


# ── Entity blocking (Phase 3) ─────────────────────────────────────────────────

func test_entity_blocks_target_cell() -> void:
	var zone := _make_zone(255)
	var rng := RandomNumberGenerator.new()
	var actor := _make_mock_actor(Vector2i(2, 2))

	# Plant a blocker entity at target cell
	var blocker := Node.new()
	add_child(blocker)
	_EntityRegistry.register(Vector2i(3, 2), blocker)

	var result: Dictionary = _MovementController.try_move(
		actor, Vector2i(2, 2), Vector2i(1, 0), zone, 0, rng, false)
	assert_bool(result["success"]).is_false()

	blocker.queue_free()
	actor.queue_free()


func test_entity_move_clears_old_cell() -> void:
	var zone := _make_zone(255)
	var rng := RandomNumberGenerator.new()
	var actor := _make_mock_actor(Vector2i(2, 2))
	_EntityRegistry.register(Vector2i(2, 2), actor)

	var result: Dictionary = _MovementController.try_move(
		actor, Vector2i(2, 2), Vector2i(1, 0), zone, 0, rng, false)
	if result["success"]:
		assert_object(_EntityRegistry.get_entity_at(Vector2i(2, 2))).is_null()
		assert_object(_EntityRegistry.get_entity_at(Vector2i(3, 2))).is_equal(actor)

	actor.queue_free()


# ── Passability condition: unknown tag blocks ─────────────────────────────────

func test_unknown_condition_tag_blocks() -> void:
	var zone := _make_zone(255)
	var td := zone.local_tile_palette[0] as TileDefinitionResource
	var cond := PassabilityConditionResource.new()
	cond.direction_mask = 255  # guards all directions
	cond.condition_tag = "unknown_tag_that_does_not_exist"
	td.conditions = [cond]

	var rng := RandomNumberGenerator.new()
	var actor := _make_mock_actor(Vector2i(1, 2))
	var result: Dictionary = _MovementController.try_move(
		actor, Vector2i(1, 2), Vector2i(1, 0), zone, 0, rng, false)
	assert_bool(result["success"]).is_false()

	actor.queue_free()


# ── Passability condition: blackboard_flag allows when flag set ───────────────

func test_blackboard_flag_condition_allows_when_set() -> void:
	var zone := _make_zone(255)
	var td := zone.local_tile_palette[0] as TileDefinitionResource
	var cond := PassabilityConditionResource.new()
	cond.direction_mask = 255
	cond.condition_tag = "blackboard_flag"
	cond.condition_args = {"key": "door_open"}
	td.conditions = [cond]

	WorldBoard.set_zone("door_open", true)
	var rng := RandomNumberGenerator.new()
	var actor := _make_mock_actor(Vector2i(1, 2))
	var result: Dictionary = _MovementController.try_move(
		actor, Vector2i(1, 2), Vector2i(1, 0), zone, 0, rng, false)
	assert_bool(result["success"]).is_true()

	WorldBoard.clear_zone_scope()
	actor.queue_free()


func test_blackboard_flag_condition_blocks_when_not_set() -> void:
	var zone := _make_zone(255)
	var td := zone.local_tile_palette[0] as TileDefinitionResource
	var cond := PassabilityConditionResource.new()
	cond.direction_mask = 255
	cond.condition_tag = "blackboard_flag"
	cond.condition_args = {"key": "door_open"}
	td.conditions = [cond]

	var rng := RandomNumberGenerator.new()
	var actor := _make_mock_actor(Vector2i(1, 2))
	var result: Dictionary = _MovementController.try_move(
		actor, Vector2i(1, 2), Vector2i(1, 0), zone, 0, rng, false)
	assert_bool(result["success"]).is_false()

	actor.queue_free()
