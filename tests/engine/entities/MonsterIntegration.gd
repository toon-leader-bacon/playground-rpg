## Integration scene: exercises the full monster pipeline end-to-end.
## Runs automatically on _ready() — this is a test scene, not engine code.
## Expected output is printed to the Godot console.
extends Node


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== Monster Integration Test ===")

	# --- Load configs via ConfigLoader ---
	var lizard_config: MonsterConfig = ConfigLoader.load_monster("fire_lizard")
	var golem_config: MonsterConfig = ConfigLoader.load_monster("stone_golem")

	assert(lizard_config != null, "FAIL: fire_lizard config failed to load")
	assert(golem_config != null, "FAIL: stone_golem config failed to load")
	print("Configs loaded: OK")

	# --- Create runtime instances ---
	var lizard := MonsterInstance.create(lizard_config, 5)
	var golem := MonsterInstance.create(golem_config, 5)

	print("Fire Lizard  | HP: %d/%d  ATK: %d  DEF: %d  SPD: %d" % [
		lizard.current_hp, lizard.max_hp(),
		lizard.attack(), lizard.defense(), lizard.speed()
	])
	print("Stone Golem  | HP: %d/%d  ATK: %d  DEF: %d  SPD: %d" % [
		golem.current_hp, golem.max_hp(),
		golem.attack(), golem.defense(), golem.speed()
	])

	# --- Simulate AI move selection for 3 rounds ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	print("--- AI move selection (3 rounds) ---")
	for round_num in range(3):
		var lizard_action := MonsterAI.choose_action(lizard, golem, rng)
		var golem_action := MonsterAI.choose_action(golem, lizard, rng)
		var lizard_move := lizard_config.move_ids[lizard_action] if lizard_action >= 0 else "(no moves)"
		var golem_move := golem_config.move_ids[golem_action] if golem_action >= 0 else "(no moves)"
		print("Round %d | Lizard: %-12s | Golem: %s" % [round_num + 1, lizard_move, golem_move])

	# --- Simulate some damage ---
	lizard.apply_damage(30)
	golem.apply_damage(15)
	print("After combat  | Lizard HP: %d  Golem HP: %d" % [lizard.current_hp, golem.current_hp])
	print("Fainted       | Lizard: %s  Golem: %s" % [lizard.is_fainted(), golem.is_fainted()])

	# --- Serialization round-trip ---
	var data := lizard.serialize()
	var restored := MonsterInstance.deserialize(data, lizard_config)
	var serialize_ok := restored.level == lizard.level and restored.current_hp == lizard.current_hp
	print("Serialization | %s" % ("PASS" if serialize_ok else "FAIL"))

	print("=== Integration Test Complete ===")
