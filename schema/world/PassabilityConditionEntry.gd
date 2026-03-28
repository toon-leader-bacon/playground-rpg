class_name PassabilityConditionEntry
extends Resource
## A conditional gate on tile passability.
## direction_mask restricts which directions this condition applies to (bitmask matching
## TileDefinitionResource direction bits). condition_tag names the runtime check;
## condition_args holds tag-specific parameters.

@export var direction_mask: int = 0xFF
@export var condition_tag: String = ""
@export var condition_args: Dictionary = {}


func serialize() -> Dictionary:
	return {
		"direction_mask": direction_mask,
		"condition_tag": condition_tag,
		"condition_args": condition_args.duplicate(true),
	}


static func deserialize(data: Dictionary) -> PassabilityConditionEntry:
	var e := PassabilityConditionEntry.new()
	e.direction_mask = data.get("direction_mask", 0xFF)
	e.condition_tag = data.get("condition_tag", "")
	e.condition_args = data.get("condition_args", {}).duplicate(true)
	return e


func deserialize_update(data: Dictionary) -> void:
	direction_mask = data.get("direction_mask", 0xFF)
	condition_tag = data.get("condition_tag", "")
	condition_args = data.get("condition_args", {}).duplicate(true)


func deep_copy() -> PassabilityConditionEntry:
	return PassabilityConditionEntry.deserialize(serialize())
