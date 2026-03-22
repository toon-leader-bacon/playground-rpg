class_name EffectEntry
extends Resource
## A single entry in a move's pre_effects or post_effects array.
## Describes one atomic effect that fires as part of a move's resolution.

@export var chance: float = 1.0
@export var target: String = "target"       # "target" | "caster"
@export var condition_id: String = ""       # e.g. "burn", "paralysis"
@export var effect_type: String = ""        # "recoil" | "set_weather" | "stat_change"
@export var recoil_fraction: float = 0.0   # for effect_type = "recoil"
@export var weather: int = -1              # WeatherType.Type value; -1 = none
@export var weather_duration: int = 5      # for effect_type = "set_weather"
@export var if_crit: bool = false          # only apply when crit is true
@export var unless_crit: bool = false      # only apply when crit is false


func serialize() -> Dictionary:
	return {
		"chance": chance,
		"target": target,
		"condition_id": condition_id,
		"effect_type": effect_type,
		"recoil_fraction": recoil_fraction,
		"weather": weather,
		"weather_duration": weather_duration,
		"if_crit": if_crit,
		"unless_crit": unless_crit,
	}


static func deserialize(data: Dictionary) -> EffectEntry:
	var e := EffectEntry.new()
	e.chance = data.get("chance", 1.0)
	e.target = data.get("target", "target")
	e.condition_id = data.get("condition_id", "")
	e.effect_type = data.get("effect_type", "")
	e.recoil_fraction = data.get("recoil_fraction", 0.0)
	e.weather = data.get("weather", -1)
	e.weather_duration = data.get("weather_duration", 5)
	e.if_crit = data.get("if_crit", false)
	e.unless_crit = data.get("unless_crit", false)
	return e


func deep_copy() -> EffectEntry:
	return EffectEntry.deserialize(serialize())
