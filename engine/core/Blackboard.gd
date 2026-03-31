extends Node
## Key-value store with two lifetime scopes.
## Zone scope is ephemeral — cleared on zone load.
## Save scope is persistent — serialized to save file.
##
## Only controller-layer scripts may write to the Blackboard.

var _zone: Dictionary = {}
var _save: Dictionary = {}


func set_zone(key: String, value: Variant) -> void:
	_zone[key] = value


func get_zone(key: String, default: Variant = null) -> Variant:
	return _zone.get(key, default)


func set_save(key: String, value: Variant) -> void:
	_save[key] = value


func get_save(key: String, default: Variant = null) -> Variant:
	return _save.get(key, default)


func clear_zone_scope() -> void:
	_zone.clear()


func serialize_save() -> Dictionary:
	return _save.duplicate()


func deserialize_save(data: Dictionary) -> void:
	_save = data.duplicate()
