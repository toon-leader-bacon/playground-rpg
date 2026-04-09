extends Node
## WorldBoard — zone-aware state manager. Registered as the "WorldBoard" autoload.
##
## IMPORTANT: WorldBoard is NOT a key-value store. It is a scope manager.
## The actual storage is handled by Blackboard instances (engine/shared/model/Blackboard.gd).
## If you are confused about the difference: Blackboard = a dictionary with a clean API.
## WorldBoard = the system that decides what lives in each dictionary and for how long.
##
## Two scopes are exposed:
##
##   zone scope  — ephemeral. Cleared every time a new zone is loaded.
##                 Use for anything that should reset when the player re-enters a zone.
##                 Examples: puzzle state, NPC positions, bonk counters.
##
##   save scope  — persistent. Survives zone transitions; serialized to the save file.
##                 Use for anything that should persist across the entire game session.
##                 Examples: collected items, defeated trainers, lifetime counters.
##
## Usage:
##   WorldBoard.set_zone("puzzle.door_open", true)
##   WorldBoard.get_zone("puzzle.door_open", false)
##   WorldBoard.set_save("player.has_surf", true)
##   WorldBoard.get_save("player.has_surf", false)
##
## Key convention: namespace by feature to avoid collisions.
##   "<feature>.<key>", e.g. "water.bonk_count" or "gym_1.switch_a_pressed"

var _zone: Blackboard
var _save: Blackboard


func _ready() -> void:
	_zone = Blackboard.new()
	_save = Blackboard.new()


func set_zone(key: String, value: Variant) -> void:
	_zone.write(key, value)


func get_zone(key: String, default: Variant = null) -> Variant:
	return _zone.read(key, default)


func set_save(key: String, value: Variant) -> void:
	_save.write(key, value)


func get_save(key: String, default: Variant = null) -> Variant:
	return _save.read(key, default)


func clear_zone_scope() -> void:
	_zone.clear()


func clear_save_scope() -> void:
	_save.clear()
