class_name StatResolver
extends RefCounted
## Stateless utility for resolving effective stat values.
## Applies level scaling, stat stage modifiers, and condition modifiers in sequence.

const BASE_CRIT_RATE: float = 1.0 / 16.0

## Level-scaling multipliers per stat.
const LEVEL_MULTIPLIERS: Dictionary = {
	"max_hp": 2,
	"attack": 1,
	"defense": 1,
	"speed": 1,
	"special_attack": 1,
	"special_defense": 1,
}


## Resolve the effective value of a stat for the given instance in the given battle state.
## Applies: base + level scale + stat_stage + condition modifiers + floor clamp.
static func resolve(
	stat_name: String,
	config: MonsterConfig,
	instance: MonsterInstance,
	_battle_state: BattleStateNvM
) -> float:
	var base_stats: Dictionary = config.base_stats.serialize()
	if not base_stats.has(stat_name):
		return 0.0

	var base: float = float(base_stats[stat_name] as int)
	var level: int = instance.level
	var multiplier: int = LEVEL_MULTIPLIERS.get(stat_name, 1) as int

	# 1. Level scaling
	var value: float = base + float((level - 1) * multiplier)

	# 2. Stat stage modifier (skip for max_hp)
	if stat_name != "max_hp":
		var stage: int = instance.get_stat_stage(stat_name)
		if stage > 0:
			value = value * float(2 + stage) / 2.0
		elif stage < 0:
			value = value * 2.0 / float(2 - stage)

	# 3. Condition modifiers
	var cond_mods: Dictionary = instance.condition_modifiers
	if cond_mods.has(stat_name):
		var mod_list: Array = cond_mods[stat_name] as Array
		for entry: Dictionary in mod_list:
			var mult: float = entry.get("multiplier", 1.0) as float
			value *= mult

	# 4. Floor clamp (min 1 for all stats)
	return maxf(1.0, value)


## Resolve the max value of a stat (same as resolve for HP-typed stats).
static func resolve_max(
	stat_name: String,
	config: MonsterConfig,
	instance: MonsterInstance,
	battle_state: BattleStateNvM
) -> float:
	return resolve(stat_name, config, instance, battle_state)


## Build the expression context Dictionary for a combatant.
## Returns a flat Dictionary usable as the `caster` or `target` object in formulas.
static func build_context(
	config: MonsterConfig,
	instance: MonsterInstance,
	battle_state: BattleStateNvM
) -> Dictionary:
	var ctx: Dictionary = {}
	var stat_keys: Array = config.base_stats.serialize().keys()
	for stat_name: String in stat_keys:
		ctx[stat_name] = resolve(stat_name, config, instance, battle_state)
		ctx["max_" + stat_name] = resolve_max(stat_name, config, instance, battle_state)

	# Computed values not directly from StatBlock
	ctx["hp"] = float(instance.current_hp)
	ctx["buff_count"] = float(instance.buff_count())
	ctx["crit_rate"] = BASE_CRIT_RATE
	return ctx
