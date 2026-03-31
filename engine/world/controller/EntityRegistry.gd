## Spatial index mapping grid cells to live entity nodes.
## The authoritative answer to "what entity is at cell X,Y?"
## No class_name — preloaded by scripts that need it.

static var _map: Dictionary = {}


static func register(cell: Vector2i, entity: Node) -> void:
	_map[cell] = entity


static func unregister(cell: Vector2i) -> void:
	_map.erase(cell)


static func get_entity_at(cell: Vector2i) -> Node:
	var node: Variant = _map.get(cell, null)
	if node == null:
		return null
	if not is_instance_valid(node):
		_map.erase(cell)
		return null
	return node as Node


static func move_entity(from: Vector2i, to: Vector2i) -> void:
	var entity: Node = _map.get(from, null)
	if entity == null:
		return
	_map.erase(from)
	_map[to] = entity


static func clear() -> void:
	_map.clear()
