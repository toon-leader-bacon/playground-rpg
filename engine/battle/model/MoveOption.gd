class_name MoveOption
extends RefCounted
## Presentation value object for a single move choice offered to the player.

var index: int = 0
var display_name: String = ""


func _init(p_index: int = 0, p_display_name: String = "") -> void:
	index = p_index
	display_name = p_display_name
