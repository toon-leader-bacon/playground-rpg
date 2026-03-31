class_name EntityDefinitionResource
extends Resource
## Defines a placed entity in a zone.
## Composition-based: behavior is expressed through effect tags, not subclasses.

@export var id: String = ""
@export var display_name: String = ""
@export var position: Vector2i = Vector2i.ZERO

# Visual
@export var sprite: Texture2D = null
@export var z_index: int = 2

# Physics
@export var has_collision: bool = true
@export var physics_layer: int = 3

# Behavior
@export var on_interact: TileEffectResource = null
@export var on_enter: TileEffectResource = null
@export var on_load: TileEffectResource = null
## null = static; tag "wander" or "patrol" drives movement AI
@export var movement_behavior: TileEffectResource = null

# State
@export var tags: PackedStringArray = PackedStringArray()
## "": none, "zone": ephemeral, "save": persistent
@export var persistence_scope: String = ""
## Blackboard flag that controls active/visible state. "" = always active.
@export var flag_open_condition: String = ""
