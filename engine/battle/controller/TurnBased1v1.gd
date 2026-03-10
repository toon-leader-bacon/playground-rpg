class_name TurnBased1v1
extends RefCounted
## Controller for synchronous turn-based 1v1 battles.
##
## Preload ensures BattleState.gd is compiled before this script is parsed,
## guaranteeing class_name "BattleState" is registered in all execution contexts.
const _load_battle_state = preload("res://engine/battle/model/BattleState.gd")
## The full battle runs to completion before run() returns.
##
## Usage:
##   var battle := TurnBased1v1.new()
##   battle.move_used.connect(my_handler)
##   var state := battle.run(player, enemy, move_library)
##
## move_library: Dictionary mapping move_id (String) -> MoveConfig
## All signals fire in real time during the synchronous run() call.

const MAX_TURNS := 100  # Safety cap to prevent infinite loops

# Signals — names follow past-tense convention (event already occurred).
signal turn_started(turn_num: int, player_name: String, player_hp: int, enemy_name: String, enemy_hp: int)
signal move_used(user_name: String, move_name: String, target_name: String)
signal damage_dealt(target_name: String, amount: int, remaining_hp: int, max_hp: int)
signal hp_restored(target_name: String, amount: int, new_hp: int, max_hp: int)
signal stat_changed(target_name: String, stat: String, delta: int, total_stage: int)
signal monster_fainted(monster_name: String)
signal battle_ended(winner_name: String, loser_name: String, turn_count: int)

var _rng: RandomNumberGenerator
var _move_library: Dictionary  # String -> MoveConfig


## Run a complete battle. Returns the final BattleState.
func run(
	player: MonsterInstance,
	enemy: MonsterInstance,
	move_library: Dictionary,
	rng: RandomNumberGenerator = null
) -> BattleState:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_move_library = move_library

	var state := BattleState.new()
	state.player = player
	state.enemy = enemy

	player.reset_stat_stages()
	enemy.reset_stat_stages()

	_log(state, "=== Battle Start: %s (HP:%d SPD:%d) vs %s (HP:%d SPD:%d) ===" % [
		player.config.display_name, player.current_hp, player.effective_speed(),
		enemy.config.display_name, enemy.current_hp, enemy.effective_speed(),
	])

	while not player.is_fainted() and not enemy.is_fainted() and state.turn < MAX_TURNS:
		state.turn += 1
		_execute_turn(state)

	state.is_active = false

	if player.is_fainted() and enemy.is_fainted():
		state.winner_id = "draw"
		_log(state, "=== Result: DRAW after %d turns ===" % state.turn)
		battle_ended.emit("(draw)", "(draw)", state.turn)
	elif player.is_fainted():
		state.winner_id = enemy.config.id
		_log(state, "=== Result: %s WINS after %d turns ===" % [enemy.config.display_name, state.turn])
		battle_ended.emit(enemy.config.display_name, player.config.display_name, state.turn)
	elif enemy.is_fainted():
		state.winner_id = player.config.id
		_log(state, "=== Result: %s WINS after %d turns ===" % [player.config.display_name, state.turn])
		battle_ended.emit(player.config.display_name, enemy.config.display_name, state.turn)
	else:
		state.winner_id = ""
		_log(state, "=== Result: MAX TURNS REACHED — no winner ===")
		battle_ended.emit("(none)", "(none)", state.turn)

	return state


func _execute_turn(state: BattleState) -> void:
	var player := state.player
	var enemy := state.enemy

	turn_started.emit(
		state.turn,
		player.config.display_name, player.current_hp,
		enemy.config.display_name, enemy.current_hp
	)
	_log(state, "--- Turn %d | %s HP:%d/%d SPD:%d | %s HP:%d/%d SPD:%d ---" % [
		state.turn,
		player.config.display_name, player.current_hp, player.max_hp(), player.effective_speed(),
		enemy.config.display_name, enemy.current_hp, enemy.max_hp(), enemy.effective_speed(),
	])

	# Both monsters choose simultaneously before any action resolves.
	var player_move_idx: int = MonsterAI.choose_action(player, enemy, _rng)
	var enemy_move_idx: int = MonsterAI.choose_action(enemy, player, _rng)
	var player_move: MoveConfig = _resolve_move(player, player_move_idx)
	var enemy_move: MoveConfig = _resolve_move(enemy, enemy_move_idx)

	# Faster monster acts first; ties broken randomly.
	if _goes_first(player, enemy):
		_execute_action(state, player, enemy, player_move)
		if not enemy.is_fainted():
			_execute_action(state, enemy, player, enemy_move)
	else:
		_execute_action(state, enemy, player, enemy_move)
		if not player.is_fainted():
			_execute_action(state, player, enemy, player_move)


func _goes_first(a: MonsterInstance, b: MonsterInstance) -> bool:
	var spd_a: int = a.effective_speed()
	var spd_b: int = b.effective_speed()
	if spd_a != spd_b:
		return spd_a > spd_b
	return _rng.randi_range(0, 1) == 0


func _resolve_move(actor: MonsterInstance, move_idx: int) -> MoveConfig:
	if move_idx < 0 or actor.config.move_ids.is_empty():
		return null
	var move_id: String = actor.config.move_ids[move_idx]
	return _move_library.get(move_id, null) as MoveConfig


func _execute_action(
	state: BattleState,
	user: MonsterInstance,
	target: MonsterInstance,
	move: MoveConfig
) -> void:
	if move == null:
		_log(state, "  %s has no move available!" % user.config.display_name)
		return

	move_used.emit(user.config.display_name, move.display_name, target.config.display_name)

	# Accuracy check
	if _rng.randf() > move.accuracy:
		_log(state, "  %s used %s — but it missed!" % [user.config.display_name, move.display_name])
		return

	match move.effect:
		MoveConfig.Effect.NONE:
			if move.power > 0:
				_apply_damage(state, user, target, move)
			else:
				_log(state, "  %s used %s (no effect)" % [user.config.display_name, move.display_name])
		MoveConfig.Effect.HEAL:
			_apply_heal(state, user, move)
		MoveConfig.Effect.BUFF_SPEED_SELF:
			_apply_stat_change(state, user.config.display_name, user, "speed", 1, move.display_name)
		MoveConfig.Effect.DEBUFF_SPEED_TARGET:
			_apply_stat_change(state, user.config.display_name, target, "speed", -1, move.display_name)


func _apply_damage(
	state: BattleState,
	attacker: MonsterInstance,
	defender: MonsterInstance,
	move: MoveConfig
) -> void:
	var dmg: int = _calculate_damage(attacker, move, defender)
	defender.apply_damage(dmg)
	_log(state, "  %s used %s → %d damage to %s (%d/%d HP left)" % [
		attacker.config.display_name, move.display_name, dmg,
		defender.config.display_name, defender.current_hp, defender.max_hp(),
	])
	damage_dealt.emit(defender.config.display_name, dmg, defender.current_hp, defender.max_hp())
	if defender.is_fainted():
		_log(state, "  %s fainted!" % defender.config.display_name)
		monster_fainted.emit(defender.config.display_name)


func _apply_heal(state: BattleState, user: MonsterInstance, move: MoveConfig) -> void:
	var before: int = user.current_hp
	user.restore_hp(move.power)
	var healed: int = user.current_hp - before
	_log(state, "  %s used %s → restored %d HP (%d/%d HP)" % [
		user.config.display_name, move.display_name, healed,
		user.current_hp, user.max_hp(),
	])
	hp_restored.emit(user.config.display_name, healed, user.current_hp, user.max_hp())


func _apply_stat_change(
	state: BattleState,
	user_name: String,
	target: MonsterInstance,
	stat: String,
	delta: int,
	move_name: String
) -> void:
	target.modify_stat_stage(stat, delta)
	var total: int = target.get_stat_stage(stat)
	var direction: String = "rose" if delta > 0 else "fell"
	_log(state, "  %s used %s → %s's %s %s! (stage %+d)" % [
		user_name, move_name, target.config.display_name, stat, direction, total,
	])
	stat_changed.emit(target.config.display_name, stat, delta, total)


## Damage formula: max(1, (power * atk) / (20 + def))
static func _calculate_damage(
	attacker: MonsterInstance,
	move: MoveConfig,
	defender: MonsterInstance
) -> int:
	var numerator: int = move.power * attacker.attack()
	var denominator: int = 20 + defender.defense()
	return max(1, numerator / denominator)


func _log(state: BattleState, message: String) -> void:
	state.combat_log.append(message)
