## Integration demo: runs a full NvM battle.
## 3 stone_golems (player team) vs 7 fire_lizards (enemy team).
## Auto-submits move 0 on waiting_for_input; picks first target on needs_target.
## Run with:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path <project_root> res://tests/engine/battle/BattleNvMIntegration.tscn
extends Node


func _ready() -> void:
	_run()


func _run() -> void:
	print("")
	print("╔══════════════════════════════════════════════════════╗")
	print("║       NvM BATTLE INTEGRATION DEMO (3v7)              ║")
	print("╚══════════════════════════════════════════════════════╝")

	var golem_config: MonsterConfig = ConfigLoader.load_monster("stone_golem")
	var lizard_config: MonsterConfig = ConfigLoader.load_monster("fire_lizard")
	assert(golem_config != null, "FAIL: stone_golem failed to load")
	assert(lizard_config != null, "FAIL: fire_lizard failed to load")

	var player_team: Array[MonsterInstance] = []
	for i: int in range(3):
		player_team.append(MonsterInstance.create(golem_config, 5))

	var enemy_team: Array[MonsterInstance] = []
	for i: int in range(7):
		enemy_team.append(MonsterInstance.create(lizard_config, 5))

	print("\nPlayer Team (3 Stone Golems at level 5):")
	for i: int in range(player_team.size()):
		_print_combatant("player_" + str(i), player_team[i])

	print("\nEnemy Team (7 Fire Lizards at level 5):")
	for i: int in range(enemy_team.size()):
		_print_combatant("enemy_" + str(i), enemy_team[i])
	print("")

	# Connect EventBus signals for live output
	EventBus.battle_nvm_initialized.connect(_on_nvm_initialized)
	EventBus.battle_turn_advanced.connect(_on_turn_advanced)
	EventBus.battle_move_used.connect(_on_move_used)
	EventBus.battle_damage_dealt.connect(_on_damage_dealt)
	EventBus.battle_hp_restored.connect(_on_hp_restored)
	EventBus.battle_stat_changed.connect(_on_stat_changed)
	EventBus.battle_monster_fainted.connect(_on_monster_fainted)
	EventBus.battle_ended.connect(_on_battle_ended)

	# Auto-submit: always pick move 0, pick first available target
	EventBus.battle_waiting_for_input.connect(
		func(actor_id: String, _moves: Array) -> void:
			BattleManager.submit_player_action(actor_id, 0)
	)
	EventBus.battle_needs_target.connect(
		func(actor_id: String, target_ids: Array[String]) -> void:
			if not target_ids.is_empty():
				BattleManager.submit_player_target(actor_id, target_ids[0])
	)

	BattleManager.start_battle(
		BattleManager.CombatStyle.TURN_BASED_NVM_INTERACTIVE,
		[player_team, enemy_team]
	)


func _print_combatant(actor_id: String, inst: MonsterInstance) -> void:
	print("  [%s] %s | HP:%d  ATK:%d  DEF:%d  SPD:%d  Moves: %s" % [
		actor_id,
		inst.config.display_name,
		inst.max_hp(), inst.attack(), inst.defense(), inst.speed(),
		", ".join(inst.config.move_ids),
	])


func _on_nvm_initialized(p_names: Array, _p_hps: Array, e_names: Array, _e_hps: Array) -> void:
	print("Battle initialized: %s vs %s" % [
		", ".join(p_names), ", ".join(e_names)
	])


func _on_turn_advanced(turn_num: int) -> void:
	print("\n--- Turn %d ---" % turn_num)


func _on_move_used(user: String, move: String, target: String) -> void:
	print("  → %s uses %s on %s" % [user, move, target])


func _on_damage_dealt(target: String, amount: int, remaining: int, max_hp: int) -> void:
	print("    %s takes %d damage  (%d/%d HP)" % [target, amount, remaining, max_hp])


func _on_hp_restored(target: String, amount: int, new_hp: int, max_hp: int) -> void:
	print("    %s restores %d HP  (%d/%d HP)" % [target, amount, new_hp, max_hp])


func _on_stat_changed(target: String, stat: String, delta: int, total: int) -> void:
	var dir: String = "▲" if delta > 0 else "▼"
	print("    %s's %s %s (stage %+d)" % [target, stat, dir, total])


func _on_monster_fainted(name: String) -> void:
	print("  *** %s FAINTED! ***" % name)


func _on_battle_ended(winner: String, loser: String, turns: int) -> void:
	print("\n╔══════════════════════════════════════════════════════╗")
	print("║  WINNER: %-43s ║" % winner)
	print("║  Loser:  %-43s ║" % loser)
	print("║  Turns:  %-43s ║" % str(turns))
	print("╚══════════════════════════════════════════════════════╝")
	print("\n=== NvM Integration Demo Complete ===")
	get_tree().quit()
