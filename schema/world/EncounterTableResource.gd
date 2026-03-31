class_name EncounterTableResource
extends Resource
## Defines a random encounter pool and per-step trigger chance.

@export var encounter_chance: float = 0.1
## Array[EncounterEntryResource] — untyped for .tres compatibility.
@export var entries: Array = []


## Pick one entry using weighted random selection.
func weighted_pick(rng: RandomNumberGenerator) -> EncounterEntryResource:
	if entries.is_empty():
		return null
	var total: float = 0.0
	for e: Variant in entries:
		total += (e as EncounterEntryResource).weight
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for e: Variant in entries:
		var entry := e as EncounterEntryResource
		acc += entry.weight
		if roll < acc:
			return entry
	return entries[-1] as EncounterEntryResource
