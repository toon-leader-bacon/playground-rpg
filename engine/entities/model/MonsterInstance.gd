class_name MonsterInstance
extends Resource
## Runtime state for a single monster in play.
## The config is the species blueprint; MonsterInstance holds per-encounter mutable state.

var config: MonsterConfig
var level: int = 1
var current_hp: int = 0
## Per-battle stat stage modifiers. Keys are stat names (e.g. "speed").
## Values are integers clamped to [-6, 6]. Reset at the start of each battle.
var stat_stages: Dictionary = {}

## Active conditions on this monster (Array of ConditionInstance objects).
var active_conditions: Array = []

## Condition stat modifiers keyed by stat name.
## Each entry is an Array of Dictionaries: [{ "multiplier": float, "source": String }]
var condition_modifiers: Dictionary = {}

## PP tracking: { move_id: remaining_pp }
var current_pp: Dictionary = {}

## Turn denial flag — set by ConditionInstance, cleared by ActionResolver at DECLARE.
var _turn_denied: bool = false
## Per-actor cross-turn blackboard. Cleared at battle end.
## For moves that need to persist state across their actor's turns (e.g. Rollout accumulator).
var memory: Blackboard = Blackboard.new()


## Create a fresh MonsterInstance from a config at a given level.
## current_hp is initialized to max_hp.
static func create(p_config: MonsterConfig, p_level: int = 1) -> MonsterInstance:
	var inst := MonsterInstance.new()
	inst.config = p_config
	inst.level = p_level
	inst.current_hp = inst.max_hp()
	return inst


# --- Stat accessors (incorporate level scaling) ---
# TODO: Leveling formula is a placeholder (linear). Revisit when Design Bible §7 leveling question
# is resolved. Currently: stat = base + (level - 1) * multiplier.

func max_hp() -> int:
	if config == null:
		return 0
	return config.base_stats.max_hp + (level - 1) * 2


func attack() -> int:
	if config == null:
		return 0
	return config.base_stats.attack + (level - 1)


func defense() -> int:
	if config == null:
		return 0
	return config.base_stats.defense + (level - 1)


func speed() -> int:
	if config == null:
		return 0
	return config.base_stats.speed + (level - 1)


## Speed incorporating the current speed stage modifier.
## Stage formula: (2 + max(stage,0)) / (2 + max(-stage,0)) applied to base speed.
## This is the pokemon implementation of status altering moves.
func effective_speed() -> int:
	var stage: int = get_stat_stage("speed")
	var base: int = speed()
	if stage == 0:
		return base
	elif stage > 0:
		return int(float(base) * float(2 + stage) / 2.0)
	else:
		return int(float(base) * 2.0 / float(2 - stage))


func get_stat_stage(stat: String) -> int:
	return stat_stages.get(stat, 0) as int


func modify_stat_stage(stat: String, delta: int) -> void:
	var current: int = stat_stages.get(stat, 0) as int
	stat_stages[stat] = clampi(current + delta, -6, 6)


func reset_stat_stages() -> void:
	stat_stages.clear()


## Count of positive stat stage values (used by Stored Power formula).
func buff_count() -> int:
	var count: int = 0
	for val: int in stat_stages.values():
		if val > 0:
			count += val
	return count


# --- PP tracking ---

func deduct_pp(move_id: String, max_pp: int) -> void:
	var remaining: int = get_pp(move_id, max_pp)
	current_pp[move_id] = maxi(0, remaining - 1)


func get_pp(move_id: String, max_pp: int) -> int:
	return current_pp.get(move_id, max_pp) as int


# --- Turn denial ---

func deny_turn() -> void:
	_turn_denied = true


func is_turn_denied() -> bool:
	return _turn_denied


func clear_turn_denied() -> void:
	_turn_denied = false


# --- Condition modifiers ---

func add_condition_modifier(stat: String, multiplier: float, source_id: String) -> void:
	if not condition_modifiers.has(stat):
		condition_modifiers[stat] = []
	var mod_list: Array = condition_modifiers[stat] as Array
	mod_list.append({"multiplier": multiplier, "source": source_id})


func remove_condition_modifier(stat: String, source_id: String) -> void:
	if not condition_modifiers.has(stat):
		return
	var mod_list: Array = condition_modifiers[stat] as Array
	for i: int in range(mod_list.size() - 1, -1, -1):
		var entry: Dictionary = mod_list[i] as Dictionary
		if entry.get("source", "") == source_id:
			mod_list.remove_at(i)
	if mod_list.is_empty():
		condition_modifiers.erase(stat)


# --- Combat helpers ---

func apply_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)


func restore_hp(amount: int) -> void:
	current_hp = min(max_hp(), current_hp + amount)


func is_fainted() -> bool:
	return current_hp <= 0


# --- Serialization ---

func serialize() -> Dictionary:
	return {
		"config_id": config.id if config != null else "",
		"level": level,
		"current_hp": current_hp,
		"stat_stages": stat_stages.duplicate(),
	}


## Deserialize requires the caller to supply the resolved config (via ConfigLoader).
static func deserialize(data: Dictionary, p_config: MonsterConfig) -> MonsterInstance:
	var inst := MonsterInstance.new()
	inst.config = p_config
	inst.level = data.get("level", 1)
	inst.current_hp = data.get("current_hp", inst.max_hp())
	inst.stat_stages = (data.get("stat_stages", {}) as Dictionary).duplicate()
	return inst
