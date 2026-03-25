class_name NodeOverrideEntry
extends Resource
## Specifies how a MoveConfig overrides or hooks a single FSM node.
## All three override points are optional; absent strings mean "use default".
##
## override_tag:  replaces the node callable entirely.
## pre_hook_tag:  runs before the node callable.
## post_hook_tag: runs after the node callable.
## args: passed (bound) to whichever tags are set at FSM-build time.

@export var node_id: String = ""         # FSM node name: "DECLARE", "ACCURACY_CHECK", etc.
@export var override_tag: String = ""    # NodeRegistry tag; replaces the node if non-empty
@export var pre_hook_tag: String = ""    # NodeRegistry tag; runs before the node if non-empty
@export var post_hook_tag: String = ""   # NodeRegistry tag; runs after the node if non-empty
@export var args: Dictionary = {}        # Passed to whichever of the above are set


func serialize() -> Dictionary:
	return {
		"node_id": node_id,
		"override_tag": override_tag,
		"pre_hook_tag": pre_hook_tag,
		"post_hook_tag": post_hook_tag,
		"args": args.duplicate(true),
	}


static func deserialize(data: Dictionary) -> NodeOverrideEntry:
	var e := NodeOverrideEntry.new()
	e.node_id = data.get("node_id", "")
	e.override_tag = data.get("override_tag", "")
	e.pre_hook_tag = data.get("pre_hook_tag", "")
	e.post_hook_tag = data.get("post_hook_tag", "")
	e.args = (data.get("args", {}) as Dictionary).duplicate(true)
	return e


func deserialize_update(data: Dictionary) -> void:
	node_id = data.get("node_id", node_id)
	override_tag = data.get("override_tag", override_tag)
	pre_hook_tag = data.get("pre_hook_tag", pre_hook_tag)
	post_hook_tag = data.get("post_hook_tag", post_hook_tag)
	if data.has("args"):
		args = (data["args"] as Dictionary).duplicate(true)


func deep_copy() -> NodeOverrideEntry:
	return NodeOverrideEntry.deserialize(serialize())
