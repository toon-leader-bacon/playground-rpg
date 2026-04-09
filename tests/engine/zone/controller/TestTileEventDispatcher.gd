extends GdUnitTestSuite

# Stub player node that carries the two signals TileEventDispatcher connects to.
class StubPlayer extends Node2D:
	signal movement_blocked(collider: Node)
	signal tile_changed(from_tile: Vector2i, to_tile: Vector2i)

# Spy collidable that counts calls to each event method independently.
class CallCounter extends TileCollidable:
	var collide_count: int = 0
	var enter_count: int = 0
	var exit_count: int = 0

	func on_player_collide(_player: Node2D) -> void:
		collide_count += 1

	func on_player_enter(_player: Node2D) -> void:
		enter_count += 1

	func on_player_exit(_player: Node2D) -> void:
		exit_count += 1


# --- helpers ---

func _make_body_with_counter() -> Array:
	var body := StaticBody2D.new()
	var counter := CallCounter.new()
	body.add_child(counter)
	add_child(body)
	return [body, counter]


func _make_dispatcher(player: StubPlayer, map: Dictionary[Vector2i, StaticBody2D]) -> TileEventDispatcher:
	var dispatcher := TileEventDispatcher.new()
	add_child(dispatcher)
	dispatcher.setup(player, map)
	return dispatcher


# --- movement_blocked ---

func test_movement_blocked_fires_on_player_collide() -> void:
	var player := StubPlayer.new()
	var parts: Array = _make_body_with_counter()
	var body: StaticBody2D = parts[0]
	var counter: CallCounter = parts[1]
	var map: Dictionary[Vector2i, StaticBody2D] = {}
	_make_dispatcher(player, map)

	player.movement_blocked.emit(body)

	assert_int(counter.collide_count).is_equal(1)


func test_movement_blocked_does_not_fire_enter_or_exit() -> void:
	var player := StubPlayer.new()
	var parts: Array = _make_body_with_counter()
	var body: StaticBody2D = parts[0]
	var counter: CallCounter = parts[1]
	var map: Dictionary[Vector2i, StaticBody2D] = {}
	_make_dispatcher(player, map)

	player.movement_blocked.emit(body)

	assert_int(counter.enter_count).is_equal(0)
	assert_int(counter.exit_count).is_equal(0)


func test_movement_blocked_only_hits_first_collidable() -> void:
	# The dispatcher breaks after the first TileCollidable on collision.
	var player := StubPlayer.new()
	var body := StaticBody2D.new()
	var first := CallCounter.new()
	var second := CallCounter.new()
	body.add_child(first)
	body.add_child(second)
	add_child(body)
	var map: Dictionary[Vector2i, StaticBody2D] = {}
	_make_dispatcher(player, map)

	player.movement_blocked.emit(body)

	assert_int(first.collide_count).is_equal(1)
	assert_int(second.collide_count).is_equal(0)


# --- tile_changed ---

func test_tile_changed_fires_exit_on_source_tile() -> void:
	var player := StubPlayer.new()
	var parts: Array = _make_body_with_counter()
	var counter: CallCounter = parts[1]
	var from_pos := Vector2i(1, 0)
	var to_pos := Vector2i(2, 0)
	var map: Dictionary[Vector2i, StaticBody2D] = {from_pos: parts[0]}
	_make_dispatcher(player, map)

	player.tile_changed.emit(from_pos, to_pos)

	assert_int(counter.exit_count).is_equal(1)
	assert_int(counter.enter_count).is_equal(0)


func test_tile_changed_fires_enter_on_dest_tile() -> void:
	var player := StubPlayer.new()
	var parts: Array = _make_body_with_counter()
	var counter: CallCounter = parts[1]
	var from_pos := Vector2i(1, 0)
	var to_pos := Vector2i(2, 0)
	var map: Dictionary[Vector2i, StaticBody2D] = {to_pos: parts[0]}
	_make_dispatcher(player, map)

	player.tile_changed.emit(from_pos, to_pos)

	assert_int(counter.enter_count).is_equal(1)
	assert_int(counter.exit_count).is_equal(0)


func test_tile_changed_fires_exit_before_enter() -> void:
	# Exit must fire before enter — handlers see the player leave the old tile
	# before arriving on the new one.
	var player := StubPlayer.new()
	var call_order: Array[String] = []
	var from_body := StaticBody2D.new()
	var to_body := StaticBody2D.new()
	add_child(from_body)
	add_child(to_body)

	var exit_spy := TileCollidable.new()
	exit_spy.set_exit_handler(func(_p: Node2D) -> void: call_order.append("exit"))
	from_body.add_child(exit_spy)

	var enter_spy := TileCollidable.new()
	enter_spy.set_enter_handler(func(_p: Node2D) -> void: call_order.append("enter"))
	to_body.add_child(enter_spy)

	var from_pos := Vector2i(0, 0)
	var to_pos := Vector2i(1, 0)
	var map: Dictionary[Vector2i, StaticBody2D] = {from_pos: from_body, to_pos: to_body}
	_make_dispatcher(player, map)

	player.tile_changed.emit(from_pos, to_pos)

	assert_int(call_order.size()).is_equal(2)
	assert_str(call_order[0]).is_equal("exit")
	assert_str(call_order[1]).is_equal("enter")


func test_enter_dispatches_to_all_collidables_on_tile() -> void:
	# Unlike collision (which breaks), enter fires on every TileCollidable child.
	var player := StubPlayer.new()
	var body := StaticBody2D.new()
	var first := CallCounter.new()
	var second := CallCounter.new()
	body.add_child(first)
	body.add_child(second)
	add_child(body)
	var to_pos := Vector2i(3, 0)
	var map: Dictionary[Vector2i, StaticBody2D] = {to_pos: body}
	_make_dispatcher(player, map)

	player.tile_changed.emit(Vector2i(2, 0), to_pos)

	assert_int(first.enter_count).is_equal(1)
	assert_int(second.enter_count).is_equal(1)


func test_dispatch_to_unmapped_tile_does_not_crash() -> void:
	var player := StubPlayer.new()
	var map: Dictionary[Vector2i, StaticBody2D] = {}
	_make_dispatcher(player, map)

	# Positions with no entry in the map — should be silent no-ops
	player.tile_changed.emit(Vector2i(99, 99), Vector2i(100, 99))
	player.movement_blocked.emit(StaticBody2D.new())

	assert_bool(true).is_true()
