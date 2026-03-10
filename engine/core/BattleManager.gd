extends Node
## Manages battle flow. CombatStyle is the configurability axis for battle system type.
## Add new styles by extending the enum and adding a match branch — never modify existing branches.

## Explicit preload ensures TurnBased1v1 is available regardless of class cache state.
## (class_name registration is not guaranteed when autoloads are parsed headlessly.)
const _TurnBased1v1 := preload("res://engine/battle/controller/TurnBased1v1.gd")

enum CombatStyle {
	TURN_BASED_1V1,
	ATB_1V1,
	# Future: TURN_BASED_NVN, ATB_NVN
}


func start_battle(style: CombatStyle, combatants: Array) -> void:
	match style:
		CombatStyle.TURN_BASED_1V1:
			_start_turn_based_1v1(combatants)
		CombatStyle.ATB_1V1:
			push_warning("BattleManager: ATB_1V1 not yet implemented")


func end_battle(result: Dictionary) -> void:
	pass  # Future: persist result, trigger world state change, etc.


func _start_turn_based_1v1(combatants: Array) -> void:
	assert(combatants.size() == 2, "TURN_BASED_1V1 requires exactly 2 combatants")
	var player := combatants[0] as MonsterInstance
	var enemy := combatants[1] as MonsterInstance
	assert(player != null and enemy != null, "Both combatants must be MonsterInstance")

	EventBus.battle_started.emit(player.config.display_name, enemy.config.display_name)

	var move_library: Dictionary = _build_move_library([player, enemy])

	# Instantiate via preloaded const. Use Object API for calls and signal connections
	# since class_name resolution is not guaranteed in autoload context.
	var battle: Object = _TurnBased1v1.new()

	battle.connect("turn_started",
		func(t: int, pn: String, ph: int, en: String, eh: int) -> void:
			EventBus.battle_turn_started.emit(t, pn, ph, en, eh)
	)
	battle.connect("move_used",
		func(u: String, m: String, tgt: String) -> void:
			EventBus.battle_move_used.emit(u, m, tgt)
	)
	battle.connect("damage_dealt",
		func(tgt: String, amt: int, hp: int, max_hp: int) -> void:
			EventBus.battle_damage_dealt.emit(tgt, amt, hp, max_hp)
	)
	battle.connect("hp_restored",
		func(tgt: String, amt: int, hp: int, max_hp: int) -> void:
			EventBus.battle_hp_restored.emit(tgt, amt, hp, max_hp)
	)
	battle.connect("stat_changed",
		func(tgt: String, stat: String, delta: int, stage: int) -> void:
			EventBus.battle_stat_changed.emit(tgt, stat, delta, stage)
	)
	battle.connect("monster_fainted",
		func(name: String) -> void:
			EventBus.battle_monster_fainted.emit(name)
	)
	battle.connect("battle_ended",
		func(winner: String, loser: String, turns: int) -> void:
			EventBus.battle_ended.emit(winner, loser, turns)
	)

	var result: Resource = battle.call("run", player, enemy, move_library) as Resource
	GameState.last_battle_state = result


## Resolves all move IDs from each combatant's config into a shared move library.
func _build_move_library(combatants: Array[MonsterInstance]) -> Dictionary:
	var library: Dictionary = {}
	for combatant: MonsterInstance in combatants:
		if combatant.config == null:
			continue
		for move_id: String in combatant.config.move_ids:
			if not library.has(move_id):
				var move: MoveConfig = ConfigLoader.load_move(move_id)
				if move != null:
					library[move_id] = move
	return library
