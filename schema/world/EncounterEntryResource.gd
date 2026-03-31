class_name EncounterEntryResource
extends Resource
## One entry in an encounter table — a monster candidate with weight and level range.

@export var monster_id: String = ""
@export var weight: float = 1.0
@export var level_min: int = 1
@export var level_max: int = 5
