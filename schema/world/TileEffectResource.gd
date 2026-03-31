class_name TileEffectResource
extends Resource
## Atomic unit of behavior for tiles and entities.
## Never contains logic — only a tag and args resolved by TileEffectRegistry at runtime.

@export var effect_tag: String = ""
@export var args: Dictionary = {}
