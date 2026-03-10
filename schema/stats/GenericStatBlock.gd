class_name GenericStatBlock
extends Resource
## A flexible stat block mapping stat name strings to float values.
## Keys should use StatName constants for consistency.
## Supports configurable stat lists — not tied to a fixed set of fields.

@export var stats: Dictionary = {}


func get_stat(stat_name: String, default_val: float = 0.0) -> float:
	return float(stats.get(stat_name, default_val))


func set_stat(stat_name: String, value: float) -> void:
	stats[stat_name] = value


func has_stat(stat_name: String) -> bool:
	return stats.has(stat_name)


func stat_names() -> Array[String]:
	var names: Array[String] = []
	for key in stats.keys():
		names.append(str(key))
	return names


func serialize() -> Dictionary:
	var data: Dictionary = {}
	for key in stats.keys():
		data[str(key)] = stats[key]
	return data


static func deserialize(data: Dictionary) -> GenericStatBlock:
	var block := GenericStatBlock.new()
	for key in data.keys():
		block.stats[str(key)] = float(data[key])
	return block


func deserialize_update(data: Dictionary) -> void:
	for key in data.keys():
		stats[str(key)] = float(data[key])


func deep_copy() -> GenericStatBlock:
	return GenericStatBlock.deserialize(serialize())
