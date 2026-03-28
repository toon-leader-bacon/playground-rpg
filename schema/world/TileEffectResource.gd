class_name TileEffectResource
extends Resource
## A single tile effect descriptor. effect_tag identifies the handler in TileEffectRegistry;
## args holds effect-specific, flat key-value arguments.
## Keep args as a flat Dictionary — no nested sub-resources.

@export var effect_tag: String = ""
@export var args: Dictionary = {}


func serialize() -> Dictionary:
	return {
		"effect_tag": effect_tag,
		"args": args.duplicate(true),
	}


static func deserialize(data: Dictionary) -> TileEffectResource:
	var r := TileEffectResource.new()
	r.effect_tag = data.get("effect_tag", "")
	r.args = data.get("args", {}).duplicate(true)
	return r


func deserialize_update(data: Dictionary) -> void:
	effect_tag = data.get("effect_tag", "")
	args = data.get("args", {}).duplicate(true)


func deep_copy() -> TileEffectResource:
	return TileEffectResource.deserialize(serialize())
