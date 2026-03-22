class_name NodeRegistry
extends RefCounted
## Registry mapping string tags to Callable implementations for Tier 3 move nodes.
## Default accuracy and damage nodes are registered here.
##
## Accuracy node signature: func(ctx: PipelineContext, args: Array) -> void
##   Must set ctx.hit = true/false.
## Damage node signature: func(ctx: PipelineContext, args: Dictionary) -> void
##   Must set ctx.damage_value.

var _accuracy_nodes: Dictionary[String, Callable] = {}
var _damage_nodes: Dictionary[String, Callable] = {}


func register_accuracy_node(tag: String, fn: Callable) -> void:
	_accuracy_nodes[tag] = fn


func register_damage_node(tag: String, fn: Callable) -> void:
	_damage_nodes[tag] = fn


func get_accuracy_node(tag: String) -> Callable:
	return _accuracy_nodes.get(tag, Callable())


func get_damage_node(tag: String) -> Callable:
	return _damage_nodes.get(tag, Callable())


## Build a registry pre-populated with the default engine nodes.
static func create_default() -> NodeRegistry:
	var reg := NodeRegistry.new()

	reg.register_accuracy_node("always_hit", func(ctx: Object, _args: Array) -> void:
		ctx.hit = true
	)

	reg.register_accuracy_node("weather_accuracy", func(ctx: Object, args: Array) -> void:
		var battle_state: BattleStateNvM = ctx.battle_state
		var current_weather: int = WeatherType.Type.NONE
		if battle_state != null:
			current_weather = battle_state.weather
		var accuracy_pct: float = 70.0  # default fallback
		for entry: Dictionary in args:
			var entry_weather: int = entry.get("weather", -1) as int
			if entry_weather == current_weather or entry_weather == -1:
				var formula: String = entry.get("accuracy_formula", "70.0")
				var expr := Expression.new()
				if expr.parse(formula) == OK:
					var val = expr.execute()
					if not expr.has_execute_failed():
						accuracy_pct = float(val)
				break
		ctx.hit = ctx.rng.randf() < (accuracy_pct / 100.0)
	)

	return reg
