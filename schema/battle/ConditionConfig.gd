class_name ConditionConfig
extends Resource
## Blueprint for a persistent combat condition (Burn, Paralysis, Sleep, etc.).
## ConditionInstance (engine/entities/model/) holds runtime state from this config.

enum DurationType { PERMANENT, COUNTDOWN, RANDOM_RANGE }

@export var id: String = ""
@export var display_name: String = ""
@export var trigger_event: String = ""             # EventBus signal name to subscribe to
@export var periodic_damage_formula: String = ""   # e.g. "target.max_hp * 0.0625"
## Each entry is a Dictionary with "stat" (String) and "multiplier" (float).
## Marked Array (untyped) for .tres compatibility — treat as Array[Dictionary].
@export var stat_modifiers: Array = []
@export var turn_denial_chance: float = 0.0
@export var duration_type: DurationType = DurationType.PERMANENT
@export var duration: int = -1                     # COUNTDOWN steps; -1 = n/a
@export var duration_min: int = 1                  # RANDOM_RANGE min
@export var duration_max: int = 3                  # RANDOM_RANGE max
@export var removal_trigger_event: String = ""     # EventBus signal that can remove this condition
@export var removal_move_type: int = -1            # TypeTag.Type that causes removal (Freeze)


func serialize() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"trigger_event": trigger_event,
		"periodic_damage_formula": periodic_damage_formula,
		"stat_modifiers": stat_modifiers.duplicate(true),
		"turn_denial_chance": turn_denial_chance,
		"duration_type": duration_type,
		"duration": duration,
		"duration_min": duration_min,
		"duration_max": duration_max,
		"removal_trigger_event": removal_trigger_event,
		"removal_move_type": removal_move_type,
	}


static func deserialize(data: Dictionary) -> ConditionConfig:
	var c := ConditionConfig.new()
	c.id = data.get("id", "")
	c.display_name = data.get("display_name", "")
	c.trigger_event = data.get("trigger_event", "")
	c.periodic_damage_formula = data.get("periodic_damage_formula", "")
	var raw_mods: Array = data.get("stat_modifiers", []) as Array
	c.stat_modifiers = raw_mods.duplicate(true)
	c.turn_denial_chance = data.get("turn_denial_chance", 0.0)
	c.duration_type = data.get("duration_type", DurationType.PERMANENT) as DurationType
	c.duration = data.get("duration", -1)
	c.duration_min = data.get("duration_min", 1)
	c.duration_max = data.get("duration_max", 3)
	c.removal_trigger_event = data.get("removal_trigger_event", "")
	c.removal_move_type = data.get("removal_move_type", -1)
	return c


func deep_copy() -> ConditionConfig:
	return ConditionConfig.deserialize(serialize())
