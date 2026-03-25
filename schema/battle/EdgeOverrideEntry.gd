class_name EdgeOverrideEntry
extends Resource
## Specifies a custom FSM edge to inject into the move pipeline.
## Works as a parallel to NodeOverrideEntry — moves declare edges by tag and
## ActionResolver injects them at Stage 1.
##
## from_node:      FSM node name the edge departs from (e.g. "APPLY_POST_EFFECTS").
## to_node:        FSM node name the edge arrives at (e.g. "APPLY_PRE_EFFECTS").
## condition_tag:  NodeRegistry tag for a bool-returning callable. Empty = unconditional.
## args:           Bound to the condition callable at FSM-build time (same as NodeOverrideEntry).

@export var from_node: String = ""
@export var to_node: String = ""
@export var condition_tag: String = ""  # NodeRegistry tag → func(ctx, args) -> bool; empty = unconditional
@export var args: Dictionary = {}


func serialize() -> Dictionary:
	return {
		"from_node": from_node,
		"to_node": to_node,
		"condition_tag": condition_tag,
		"args": args.duplicate(true),
	}


static func deserialize(data: Dictionary) -> EdgeOverrideEntry:
	var e := EdgeOverrideEntry.new()
	e.from_node = data.get("from_node", "")
	e.to_node = data.get("to_node", "")
	e.condition_tag = data.get("condition_tag", "")
	e.args = (data.get("args", {}) as Dictionary).duplicate(true)
	return e


func deserialize_update(data: Dictionary) -> void:
	from_node = data.get("from_node", from_node)
	to_node = data.get("to_node", to_node)
	condition_tag = data.get("condition_tag", condition_tag)
	if data.has("args"):
		args = (data["args"] as Dictionary).duplicate(true)


func deep_copy() -> EdgeOverrideEntry:
	return EdgeOverrideEntry.deserialize(serialize())
