extends Node
## Manages zone transitions, encounter triggering, and world flags.
## EncounterStyle is the configurability axis for how players meet enemies.
## Add new styles by extending the enum and adding a match branch — never modify existing branches.

enum EncounterStyle {
	RANDOM,
	FIXED,
	VISIBLE_ENEMIES,
	# Future: SCRIPTED
}


func transition_to_zone(zone_id: String, spawn_point: String = "default") -> void:
	GameState.current_zone_id = zone_id
	GameState.zone_flags.clear()
	EventBus.zone_warp_requested.emit(zone_id, spawn_point)


func trigger_encounter(style: EncounterStyle, zone_id: String) -> void:
	match style:
		EncounterStyle.RANDOM:
			_trigger_random_encounter(zone_id)
		EncounterStyle.FIXED:
			push_warning("WorldManager: FIXED encounters not yet implemented")
		EncounterStyle.VISIBLE_ENEMIES:
			push_warning("WorldManager: VISIBLE_ENEMIES encounters not yet implemented")


func set_zone_flag(key: String, value: Variant) -> void:
	GameState.zone_flags[key] = value
	EventBus.zone_flag_changed.emit(key, value)


func get_zone_flag(key: String) -> Variant:
	return GameState.zone_flags.get(key, null)


func set_save_flag(key: String, value: Variant) -> void:
	GameState.save_flags[key] = value


func get_save_flag(key: String) -> Variant:
	return GameState.save_flags.get(key, null)


func _trigger_random_encounter(zone_id: String) -> void:
	var zone: ZoneResource = ConfigLoader.load_zone(zone_id)
	if zone == null or zone.default_encounter_table == null:
		return
	EventBus.zone_encounter_triggered.emit(zone.default_encounter_table)
