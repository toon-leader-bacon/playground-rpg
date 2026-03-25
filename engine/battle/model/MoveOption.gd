class_name MoveOption
extends RefCounted
## Presentation value object for a single move choice offered to the player.

var move_id: String = ""
var display_name: String = ""


func _init(p_move_id: String = "", p_display_name: String = "") -> void:
	move_id = p_move_id
	display_name = p_display_name
