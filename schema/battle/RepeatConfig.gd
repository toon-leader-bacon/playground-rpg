class_name RepeatConfig
extends Resource
## Configures how the ActionResolver FSM loops for multi-hit moves.
## When attached to a MoveConfig, the FSM re-enters at reentry_node
## after each hit, executing up to max_hits total times.
## Accuracy is always checked once before the first hit and not re-checked.

## Controls which node subsequent hits re-enter the pipeline at.
enum ReentryPoint {
	CRIT_CHECK = 0,   ## Each hit rolls its own crit independently.
	DAMAGE_CALC = 1,  ## Crit is determined once on the first hit and fixed for all subsequent hits.
}

@export var reentry_node: int = ReentryPoint.CRIT_CHECK
@export var min_hits: int = 2
@export var max_hits: int = 5


func serialize() -> Dictionary:
	return {
		"reentry_node": reentry_node,
		"min_hits": min_hits,
		"max_hits": max_hits,
	}


static func deserialize(data: Dictionary) -> RepeatConfig:
	var r := RepeatConfig.new()
	r.reentry_node = data.get("reentry_node", ReentryPoint.CRIT_CHECK)
	r.min_hits = data.get("min_hits", 2)
	r.max_hits = data.get("max_hits", 5)
	return r


func deserialize_update(data: Dictionary) -> void:
	reentry_node = data.get("reentry_node", reentry_node)
	min_hits = data.get("min_hits", min_hits)
	max_hits = data.get("max_hits", max_hits)


func deep_copy() -> RepeatConfig:
	return RepeatConfig.deserialize(serialize())
