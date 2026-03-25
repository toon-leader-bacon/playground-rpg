class_name NodeRegistry
extends RefCounted
## Registry mapping string tags to Callable implementations for custom FSM nodes and hooks.
##
## All registered callables share the signature:
##   func(ctx: PipelineContext, args: Dictionary) -> void
## Args are bound into the callable at FSM-build time by ActionResolver, so the FSM
## always sees the simpler func(ctx: PipelineContext) -> void interface.
##
## Edge routing conditions (bool-returning callables) live in EdgeRegistry, not here.

const _PipelineContext = preload("res://engine/battle/model/PipelineContext.gd")

var _nodes: Dictionary[String, Callable] = {}


func register_node(tag: String, fn: Callable) -> void:
	_nodes[tag] = fn


func get_node(tag: String) -> Callable:
	return _nodes.get(tag, Callable())


## Build a registry pre-populated with the default engine nodes.
static func create_default() -> NodeRegistry:
	var reg := NodeRegistry.new()

	## always_hit — forces ctx.hit = true regardless of the move's accuracy value.
	reg.register_node("always_hit", func(ctx: PipelineContext, _args: Dictionary) -> void:
		ctx.hit = true
	)

	## weather_accuracy — accuracy varies by current weather. args["entries"] is an Array of
	## { "weather": int, "accuracy_formula": String } dicts. The first matching entry wins;
	## weather == -1 acts as a catch-all fallback.
	reg.register_node("weather_accuracy", func(ctx: PipelineContext, args: Dictionary) -> void:
		var battle_state: BattleStateNvM = ctx.battle_state
		var current_weather: int = WeatherType.Type.NONE
		if battle_state != null:
			current_weather = battle_state.weather
		var accuracy_pct: float = 70.0  # default fallback
		var entries: Array = args.get("entries", []) as Array
		for entry: Dictionary in entries:
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

	## magnitude_declare — rolls a weighted magnitude level, writes level + power to ctx.bb.
	## args["table"] may override the default power table (Array of {level, power, weight} dicts).
	reg.register_node("magnitude_declare", func(ctx: PipelineContext, args: Dictionary) -> void:
		var default_table: Array = [
			{"level": 4, "power": 10, "weight": 5},
			{"level": 5, "power": 30, "weight": 10},
			{"level": 6, "power": 50, "weight": 20},
			{"level": 7, "power": 70, "weight": 30},
			{"level": 8, "power": 90, "weight": 20},
			{"level": 9, "power": 110, "weight": 10},
			{"level": 10, "power": 150, "weight": 5},
		]
		var table: Array = args.get("table", default_table) as Array
		var total_weight: int = 0
		for entry: Dictionary in table:
			total_weight += entry.get("weight", 0) as int
		var roll: float = ctx.rng.randf() * float(total_weight)
		var accumulated: float = 0.0
		var chosen_level: int = 7
		var chosen_power: int = 70
		for entry: Dictionary in table:
			accumulated += float(entry.get("weight", 0) as int)
			if roll < accumulated:
				chosen_level = entry.get("level", 7) as int
				chosen_power = entry.get("power", 70) as int
				break
		ctx.bb.write("magnitude.level", chosen_level)
		ctx.bb.write("magnitude.power", chosen_power)
	)

	## magnitude_damage — reads the rolled power from ctx.bb and applies a standard physical
	## damage formula (attack / defense), including the crit multiplier.
	reg.register_node("magnitude_damage", func(ctx: PipelineContext, _args: Dictionary) -> void:
		var power: int = ctx.bb.read("magnitude.power", 70) as int
		var caster_ctx: Dictionary = StatResolver.build_context(ctx.actor.config, ctx.actor, ctx.battle_state)
		var target_ctx: Dictionary = StatResolver.build_context(ctx.target.config, ctx.target, ctx.battle_state)
		var caster_atk: float = caster_ctx.get("attack", 1.0) as float
		var target_def: float = target_ctx.get("defense", 1.0) as float
		var raw_damage: float = float(power) * caster_atk / target_def
		if ctx.crit:
			raw_damage *= ActionResolver.CRIT_MULTIPLIER
		ctx.damage_value = maxi(1, int(raw_damage))
	)

	## fury_cutter_accuracy — post-hook on ACCURACY_CHECK.
	## Resets the actor's consecutive-hit streak when the move misses.
	## Key: "fury_cutter.streak" in actor.memory (int, 0–4).
	reg.register_node("fury_cutter_accuracy", func(ctx: PipelineContext, _args: Dictionary) -> void:
		if not ctx.hit:
			ctx.actor.memory.write("fury_cutter.streak", 0)
	)

	## fury_cutter_damage — override for DAMAGE_CALC.
	## Power doubles each consecutive hit: 10, 20, 40, 80, 160 (streak 0–4).
	## Increments the streak after calculating damage.
	reg.register_node("fury_cutter_damage", func(ctx: PipelineContext, _args: Dictionary) -> void:
		var streak: int = ctx.actor.memory.read("fury_cutter.streak", 0) as int
		var power: int = 10 * (1 << mini(streak, 4))
		var caster_ctx: Dictionary = StatResolver.build_context(ctx.actor.config, ctx.actor, ctx.battle_state)
		var target_ctx: Dictionary = StatResolver.build_context(ctx.target.config, ctx.target, ctx.battle_state)
		var caster_atk: float = caster_ctx.get("attack", 1.0) as float
		var target_def: float = target_ctx.get("defense", 1.0) as float
		var raw_damage: float = float(power) * caster_atk / target_def
		if ctx.crit:
			raw_damage *= ActionResolver.CRIT_MULTIPLIER
		ctx.damage_value = maxi(1, int(raw_damage))
		ctx.actor.memory.write("fury_cutter.streak", mini(streak + 1, 4))
	)

	## triple_kick_init — post-hook on DECLARE.
	## Writes hits_remaining = 2 to ctx.bb, marking that 2 additional loop iterations remain
	## after the first pass (3 total hits).
	reg.register_node("triple_kick_init", func(ctx: PipelineContext, _args: Dictionary) -> void:
		ctx.bb.write("triple_kick.hits_remaining", 2)
	)

	## supported_punch_damage — override for DAMAGE_CALC.
	## Each use adds to a field-wide stack counter (field_bb["supported_punch.stacks"]).
	## Power = move_power + stacks * 20, capped at 5 stacks.
	## Any monster using this move contributes to and benefits from the shared pool.
	reg.register_node("supported_punch_damage", func(ctx: PipelineContext, _args: Dictionary) -> void:
		var stacks: int = 0
		if ctx.battle_state != null:
			stacks = ctx.battle_state.field_bb.read("supported_punch.stacks", 0) as int
		var power: int = ctx.move.move_power + stacks * 20
		var caster_ctx: Dictionary = StatResolver.build_context(ctx.actor.config, ctx.actor, ctx.battle_state)
		var target_ctx: Dictionary = StatResolver.build_context(ctx.target.config, ctx.target, ctx.battle_state)
		var caster_atk: float = caster_ctx.get("attack", 1.0) as float
		var target_def: float = target_ctx.get("defense", 1.0) as float
		var raw_damage: float = float(power) * caster_atk / target_def
		if ctx.crit:
			raw_damage *= ActionResolver.CRIT_MULTIPLIER
		ctx.damage_value = maxi(1, int(raw_damage))
		if ctx.battle_state != null:
			ctx.battle_state.field_bb.write("supported_punch.stacks", mini(stacks + 1, 5))
	)

	return reg
