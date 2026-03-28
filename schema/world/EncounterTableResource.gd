class_name EncounterTableResource
extends Resource
## A weighted encounter table for a zone or tile override.
## encounter_probability is the per-step roll chance (0.0–1.0).

@export var entries: Array = []                     # Array[EncounterEntryResource]
@export var encounter_probability: float = 0.1


## Picks one entry using weighted random selection.
## Returns null if entries is empty.
func weighted_pick(rng: RandomNumberGenerator) -> EncounterEntryResource:
	if entries.is_empty():
		return null
	var total: float = 0.0
	for entry: EncounterEntryResource in entries:
		total += entry.weight
	var roll: float = rng.randf() * total
	var accumulated: float = 0.0
	for entry: EncounterEntryResource in entries:
		accumulated += entry.weight
		if roll <= accumulated:
			return entry
	return entries[-1] as EncounterEntryResource


func serialize() -> Dictionary:
	var entry_data: Array = []
	for e: EncounterEntryResource in entries:
		entry_data.append(e.serialize())
	return {
		"entries": entry_data,
		"encounter_probability": encounter_probability,
	}


static func deserialize(data: Dictionary) -> EncounterTableResource:
	var r := EncounterTableResource.new()
	r.deserialize_update(data)
	return r


func deserialize_update(data: Dictionary) -> void:
	encounter_probability = data.get("encounter_probability", 0.1)
	entries = []
	for e: Dictionary in data.get("entries", []):
		entries.append(EncounterEntryResource.deserialize(e))


func deep_copy() -> EncounterTableResource:
	return EncounterTableResource.deserialize(serialize())
