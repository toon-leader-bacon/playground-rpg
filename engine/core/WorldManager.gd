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


func transition_to_zone(zone_id: String, spawn_point_id: String = "default") -> void:
	GameState.current_zone_id = zone_id
	GameState.zone_bb.call("clear")
	EventBus.zone_warp_requested.emit(zone_id, spawn_point_id)


func trigger_encounter(style: EncounterStyle, zone_id: String) -> void:
	match style:
		EncounterStyle.RANDOM:
			_trigger_random_encounter(zone_id)
		EncounterStyle.FIXED:
			push_warning("WorldManager: FIXED encounters not yet implemented")
		EncounterStyle.VISIBLE_ENEMIES:
			push_warning("WorldManager: VISIBLE_ENEMIES encounters not yet implemented")


func _trigger_random_encounter(zone_id: String) -> void:
	var zone: Resource = ConfigLoader.load_zone(zone_id)
	if zone == null:
		return
	var table: Resource = zone.get("default_encounter_table") as Resource
	if table == null:
		return
	var rng := RandomNumberGenerator.new()
	var entry: Resource = table.call("weighted_pick", rng)
	if entry == null:
		return
	var monster_id: String = entry.get("monster_id")
	var level_min: int = entry.get("level_min")
	var level_max: int = entry.get("level_max")
	var level: int = rng.randi_range(level_min, level_max)
	EventBus.zone_encounter_triggered.emit(monster_id, level)
