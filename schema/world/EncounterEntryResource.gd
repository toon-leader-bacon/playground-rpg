class_name EncounterEntryResource
extends Resource
## One entry in a random encounter table. weight controls relative frequency;
## level_min/level_max define the range from which the encounter level is sampled.

@export var monster_id: String = ""
@export var weight: float = 1.0
@export var level_min: int = 1
@export var level_max: int = 5


func serialize() -> Dictionary:
	return {
		"monster_id": monster_id,
		"weight": weight,
		"level_min": level_min,
		"level_max": level_max,
	}


static func deserialize(data: Dictionary) -> EncounterEntryResource:
	var e := EncounterEntryResource.new()
	e.monster_id = data.get("monster_id", "")
	e.weight = data.get("weight", 1.0)
	e.level_min = data.get("level_min", 1)
	e.level_max = data.get("level_max", 5)
	return e


func deserialize_update(data: Dictionary) -> void:
	monster_id = data.get("monster_id", "")
	weight = data.get("weight", 1.0)
	level_min = data.get("level_min", 1)
	level_max = data.get("level_max", 5)


func deep_copy() -> EncounterEntryResource:
	return EncounterEntryResource.deserialize(serialize())
