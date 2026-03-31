extends GdUnitTestSuite
## Tests for EntityRegistry spatial index.

const _EntityRegistry = preload("res://engine/world/controller/EntityRegistry.gd")


func before_each() -> void:
	_EntityRegistry.clear()


func after_each() -> void:
	_EntityRegistry.clear()


func test_register_and_get() -> void:
	var node := Node.new()
	add_child(node)
	_EntityRegistry.register(Vector2i(2, 3), node)
	assert_object(_EntityRegistry.get_entity_at(Vector2i(2, 3))).is_equal(node)
	node.queue_free()


func test_get_empty_cell_returns_null() -> void:
	assert_object(_EntityRegistry.get_entity_at(Vector2i(0, 0))).is_null()


func test_unregister_removes_entry() -> void:
	var node := Node.new()
	add_child(node)
	_EntityRegistry.register(Vector2i(1, 1), node)
	_EntityRegistry.unregister(Vector2i(1, 1))
	assert_object(_EntityRegistry.get_entity_at(Vector2i(1, 1))).is_null()
	node.queue_free()


func test_move_entity() -> void:
	var node := Node.new()
	add_child(node)
	_EntityRegistry.register(Vector2i(0, 0), node)
	_EntityRegistry.move_entity(Vector2i(0, 0), Vector2i(1, 0))
	assert_object(_EntityRegistry.get_entity_at(Vector2i(0, 0))).is_null()
	assert_object(_EntityRegistry.get_entity_at(Vector2i(1, 0))).is_equal(node)
	node.queue_free()


func test_move_entity_missing_source_is_noop() -> void:
	_EntityRegistry.move_entity(Vector2i(5, 5), Vector2i(6, 5))
	assert_object(_EntityRegistry.get_entity_at(Vector2i(6, 5))).is_null()


func test_clear_empties_map() -> void:
	var n1 := Node.new()
	var n2 := Node.new()
	add_child(n1)
	add_child(n2)
	_EntityRegistry.register(Vector2i(0, 0), n1)
	_EntityRegistry.register(Vector2i(1, 1), n2)
	_EntityRegistry.clear()
	assert_object(_EntityRegistry.get_entity_at(Vector2i(0, 0))).is_null()
	assert_object(_EntityRegistry.get_entity_at(Vector2i(1, 1))).is_null()
	n1.queue_free()
	n2.queue_free()


func test_overwrite_registration() -> void:
	var n1 := Node.new()
	var n2 := Node.new()
	add_child(n1)
	add_child(n2)
	_EntityRegistry.register(Vector2i(0, 0), n1)
	_EntityRegistry.register(Vector2i(0, 0), n2)
	assert_object(_EntityRegistry.get_entity_at(Vector2i(0, 0))).is_equal(n2)
	n1.queue_free()
	n2.queue_free()
