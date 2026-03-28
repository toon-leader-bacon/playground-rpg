class_name EntityDefinitionResource
extends Resource
## Defines a non-player entity in a zone: NPCs, signs, objects.
## movement_behavior_tag controls autonomous movement ("" = static, "wander", "patrol").
## patrol_path holds ordered waypoints as Vector2i; kept untyped for .tres compatibility.

@export var id: String = ""
@export var display_name: String = ""
@export var position: Vector2i = Vector2i.ZERO
@export var tags: Array = []                      # Array[String]
@export var on_interact_effect: TileEffectResource = null
@export var movement_behavior_tag: String = ""    # "" | "wander" | "patrol"
@export var patrol_path: Array = []               # Array[Vector2i], untyped for .tres compat
@export var collidable: bool = true
@export var interactable: bool = true
@export var wander_interval: float = 0.8


func serialize() -> Dictionary:
	var path_data: Array = []
	for p: Vector2i in patrol_path:
		path_data.append({"x": p.x, "y": p.y})
	return {
		"id": id,
		"display_name": display_name,
		"position": {"x": position.x, "y": position.y},
		"tags": tags.duplicate(),
		"on_interact_effect": on_interact_effect.serialize() if on_interact_effect else null,
		"movement_behavior_tag": movement_behavior_tag,
		"patrol_path": path_data,
		"collidable": collidable,
		"interactable": interactable,
		"wander_interval": wander_interval,
	}


static func deserialize(data: Dictionary) -> EntityDefinitionResource:
	var e := EntityDefinitionResource.new()
	e.deserialize_update(data)
	return e


func deserialize_update(data: Dictionary) -> void:
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	var pos: Dictionary = data.get("position", {"x": 0, "y": 0})
	position = Vector2i(pos.get("x", 0), pos.get("y", 0))
	tags = data.get("tags", []).duplicate()
	var interact_data: Variant = data.get("on_interact_effect", null)
	on_interact_effect = TileEffectResource.deserialize(interact_data) if interact_data else null
	movement_behavior_tag = data.get("movement_behavior_tag", "")
	patrol_path = []
	for p: Dictionary in data.get("patrol_path", []):
		patrol_path.append(Vector2i(p.get("x", 0), p.get("y", 0)))
	collidable = data.get("collidable", true)
	interactable = data.get("interactable", true)
	wander_interval = data.get("wander_interval", 0.8)


func deep_copy() -> EntityDefinitionResource:
	return EntityDefinitionResource.deserialize(serialize())
