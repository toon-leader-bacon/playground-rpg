## Integration demo: runs a full 1v1 battle between fire_lizard and stone_golem.
## Prints a turn-by-turn play-by-play to the console.
## Run with:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path <project_root> res://tests/engine/battle/BattleIntegration.tscn
extends Node

## Preload ensures BattleState.gd is compiled before this script is parsed,
## guaranteeing class_name "BattleState" is available as a type.
const _load_battle_state = preload("res://engine/battle/model/BattleState.gd")


func _ready() -> void:
	_run()
	get_tree().quit()


func _run() -> void:
	print("")
	print("╔══════════════════════════════════════════════════════╗")
	print("║           BATTLE INTEGRATION DEMO                   ║")
	print("╚══════════════════════════════════════════════════════╝")

	var lizard_config: MonsterConfig = ConfigLoader.load_monster("fire_lizard")
	var golem_config: MonsterConfig = ConfigLoader.load_monster("stone_golem")
	assert(lizard_config != null, "FAIL: fire_lizard failed to load")
	assert(golem_config != null, "FAIL: stone_golem failed to load")

	var player := MonsterInstance.create(lizard_config, 5)
	var enemy := MonsterInstance.create(golem_config, 5)

	print("\nCombatants at level 5:")
	_print_combatant(player)
	_print_combatant(enemy)
	print("")

	# Connect EventBus signals for live output BEFORE the battle starts.
	EventBus.battle_turn_started.connect(_on_turn_started)
	EventBus.battle_move_used.connect(_on_move_used)
	EventBus.battle_damage_dealt.connect(_on_damage_dealt)
	EventBus.battle_hp_restored.connect(_on_hp_restored)
	EventBus.battle_stat_changed.connect(_on_stat_changed)
	EventBus.battle_monster_fainted.connect(_on_monster_fainted)
	EventBus.battle_ended.connect(_on_battle_ended)

	# Run the battle through BattleManager (the proper architectural path).
	BattleManager.start_battle(BattleManager.CombatStyle.TURN_BASED_1V1, [player, enemy])

	print("\n=== Full Combat Log ===")
	var state: BattleState = GameState.last_battle_state as BattleState
	if state != null:
		for line: String in state.combat_log:
			print(line)

	print("\n=== Integration Demo Complete ===")


func _print_combatant(inst: MonsterInstance) -> void:
	print("  %s | HP:%d  ATK:%d  DEF:%d  SPD:%d  Moves: %s" % [
		inst.config.display_name,
		inst.max_hp(), inst.attack(), inst.defense(), inst.speed(),
		", ".join(inst.config.move_ids),
	])


# --- EventBus listeners ---

func _on_turn_started(turn: int, pn: String, php: int, en: String, ehp: int) -> void:
	print("\n[Turn %d] %s HP:%d  vs  %s HP:%d" % [turn, pn, php, en, ehp])


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
