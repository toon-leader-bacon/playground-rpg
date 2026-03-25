class_name Blackboard
extends RefCounted
## Generic key-value store for passing arbitrary, move-specific data between nodes or across turns.
##
## Usage: keys should be namespaced by the move or feature writing them to prevent collisions.
## Convention: "<feature>.<key>", e.g. "rollout.accumulator" or "fury_swipes.hit_count".
##
## Three instances exist at different scopes:
##   PipelineContext.bb        — per-move execution; discarded after fsm.run() returns
##   MonsterInstance.memory    — per-actor cross-turn; cleared at battle end
##   BattleStateNvM.field_bb   — per-battle; cleared at battle end

var _data: Dictionary[String, Variant] = {}


func read(key: String, default: Variant = null) -> Variant:
	return _data.get(key, default)


func write(key: String, value: Variant) -> void:
	_data[key] = value


func has(key: String) -> bool:
	return _data.has(key)


func erase(key: String) -> void:
	_data.erase(key)


func clear() -> void:
	_data.clear()
