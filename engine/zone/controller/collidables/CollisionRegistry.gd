extends RefCounted
class_name CollisionRegistry

# Maps tag -> factory: func(config: Array) -> TileCollidable
static var _registry: Dictionary[String, Callable] = {}

static func register(tag: String, factory: Callable) -> void:
	_registry[tag] = factory

## Returns null if tag is empty or not registered. Callers must null-check before use.
static func create(tag: String, config: Array) -> TileCollidable:
	if tag == "":
		return null
	if not _registry.has(tag):
		push_error("Unknown collision tag: %s" % tag)
		return null
	return _registry[tag].call(config)
