extends Node
## Manages zone transitions and encounter triggering.
## EncounterStyle is the configurability axis for how players meet enemies.
## Add new styles by extending the enum and adding a match branch — never modify existing branches.

enum EncounterStyle {
	RANDOM,
	FIXED,
	VISIBLE_ENEMIES,
	# Future: SCRIPTED
}


func transition_to_zone(zone_id: String) -> void:
	GameState.current_zone_id = zone_id


func trigger_encounter(style: EncounterStyle, zone_id: String) -> void:
	match style:
		EncounterStyle.RANDOM:
			_trigger_random_encounter(zone_id)
		EncounterStyle.FIXED:
			push_warning("WorldManager: FIXED encounters not yet implemented")
		EncounterStyle.VISIBLE_ENEMIES:
			push_warning("WorldManager: VISIBLE_ENEMIES encounters not yet implemented")


func _trigger_random_encounter(_zone_id: String) -> void:
	pass  # Wired in a future task — requires zone config and encounter table
