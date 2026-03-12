extends Node
## Manages battle flow. CombatStyle is the configurability axis for battle system type.
## Add new styles by extending the enum and adding a match branch — never modify existing branches.

## Explicit preload ensures TurnBased1v1 is available regardless of class cache state.
## (class_name registration is not guaranteed when autoloads are parsed headlessly.)
const _TurnBased1v1 := preload("res://engine/battle/controller/TurnBased1v1.gd")
const _TurnBased1v1Controller := preload("res://engine/battle/controller/TurnBased1v1Controller.gd")

enum CombatStyle {
	TURN_BASED_1V1,
	ATB_1V1,
	TURN_BASED_1V1_INTERACTIVE,
	# Future: TURN_BASED_NVN, ATB_NVN
}

var _active_battle: Object
var _active_player: MonsterInstance
var _active_enemy: MonsterInstance


func start_battle(style: CombatStyle, combatants: Array) -> void:
	match style:
		CombatStyle.TURN_BASED_1V1:
			_start_turn_based_1v1(combatants)
		CombatStyle.ATB_1V1:
			push_warning("BattleManager: ATB_1V1 not yet implemented")
		CombatStyle.TURN_BASED_1V1_INTERACTIVE:
			_start_turn_based_1v1_interactive(combatants)


## Called by UI or scene to forward the player's move choice into the active battle.
func submit_player_action(actor_id: String, move_index: int) -> void:
	if _active_battle == null:
		return
	_active_battle.call("submit_player_action", move_index)


func end_battle(result: Dictionary) -> void:
	pass  # Future: persist result, trigger world state change, etc.


func _start_turn_based_1v1(combatants: Array) -> void:
	assert(combatants.size() == 2, "TURN_BASED_1V1 requires exactly 2 combatants")
	var player := combatants[0] as MonsterInstance
	var enemy := combatants[1] as MonsterInstance
	assert(player != null and enemy != null, "Both combatants must be MonsterInstance")

	EventBus.battle_started.emit(player.config.display_name, enemy.config.display_name)

	var move_library: Dictionary[String, MoveConfig] = _build_move_library([player, enemy])

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


func _start_turn_based_1v1_interactive(combatants: Array) -> void:
	assert(combatants.size() == 2, "TURN_BASED_1V1_INTERACTIVE requires exactly 2 combatants")
	var player := combatants[0] as MonsterInstance
	var enemy := combatants[1] as MonsterInstance
	assert(player != null and enemy != null, "Both combatants must be MonsterInstance")

	_active_player = player
	_active_enemy = enemy

	var move_library: Dictionary[String, MoveConfig] = _build_move_library([player, enemy])

	var battle: Object = _TurnBased1v1Controller.new()
	_active_battle = battle

	battle.connect("combatants_initialized",
		func(pn: String, php: int, en: String, ehp: int) -> void:
			EventBus.battle_combatants_initialized.emit(pn, php, en, ehp)
	)
	battle.connect("battle_started",
		func(pn: String, en: String) -> void:
			EventBus.battle_started.emit(pn, en)
	)
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
	battle.connect("waiting_for_input",
		func(actor_id: String, available_moves: Array) -> void:
			EventBus.battle_waiting_for_input.emit(actor_id, available_moves)
	)
	battle.connect("battle_ended",
		func(winner_id: String, turn_count: int) -> void:
			_on_battle_ended_interactive(winner_id, turn_count)
	)

	battle.call("run", player, enemy, move_library)


func _on_battle_ended_interactive(winner_id: String, turn_count: int) -> void:
	var winner_name: String = winner_id
	if winner_id == _active_player.config.id:
		winner_name = _active_player.config.display_name
	elif winner_id == _active_enemy.config.id:
		winner_name = _active_enemy.config.display_name

	var loser_name: String = ""
	if winner_id == _active_player.config.id:
		loser_name = _active_enemy.config.display_name
	elif winner_id == _active_enemy.config.id:
		loser_name = _active_player.config.display_name

	EventBus.battle_ended.emit(winner_name, loser_name, turn_count)
	_active_battle = null


## Resolves all move IDs from each combatant's config into a shared move library.
func _build_move_library(combatants: Array[MonsterInstance]) -> Dictionary[String, MoveConfig]:
	var library: Dictionary[String, MoveConfig] = {}
	for combatant: MonsterInstance in combatants:
		if combatant.config == null:
			continue
		for move_id: String in combatant.config.move_ids:
			if not library.has(move_id):
				var move: MoveConfig = ConfigLoader.load_move(move_id)
				if move != null:
					library[move_id] = move
	return library
