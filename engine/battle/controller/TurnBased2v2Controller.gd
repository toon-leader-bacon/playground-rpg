extends RefCounted
## Async coroutine controller for interactive 2v2 turn-based combat.
## No class_name: BattleManager uses preload.
##
## 4 actors: player_0, player_1, enemy_0, enemy_1.
## All 4 submit simultaneously each turn; actions resolved in speed order.
## Player monsters submit sequentially (player_0 first, then player_1).
## AI handles enemy monsters synchronously.

const _BattleState2v2 = preload("res://engine/battle/model/BattleState2v2.gd")
const _DecisionCollector = preload("res://engine/battle/controller/DecisionCollector.gd")
const _SpeedBasedScheduler = preload("res://engine/battle/controller/SpeedBasedScheduler.gd")
const _SpeedOrderedActionRunner = preload("res://engine/battle/controller/SpeedOrderedActionRunner.gd")
const _PlayerController = preload("res://engine/battle/controller/PlayerController.gd")
const _Action = preload("res://engine/battle/model/Action.gd")
const _RandomAI = preload("res://engine/entities/controller/ai/RandomAI.gd")

const MAX_TURNS := 100

# --- Signals ---
signal combatants_initialized(p0_name: String, p0_max_hp: int, p1_name: String, p1_max_hp: int, e0_name: String, e0_max_hp: int, e1_name: String, e1_max_hp: int)
signal turn_started(turn_num: int)
signal waiting_for_input(actor_id: String, available_moves: Array[MoveOption])
signal needs_target(actor_id: String, valid_target_ids: Array[String])
signal battle_ended(winner_id: String, turn_count: int)

# Forwarded from runner
signal move_used(user_name: String, move_name: String, target_name: String)
signal damage_dealt(target_name: String, amount: int, remaining_hp: int, max_hp: int)
signal hp_restored(target_name: String, amount: int, new_hp: int, max_hp: int)
signal stat_changed(target_name: String, stat: String, delta: int, total_stage: int)
signal monster_fainted(monster_name: String)
signal damage_dealt_keyed(actor_id: String, amount: int, remaining_hp: int, max_hp: int)
signal hp_restored_keyed(actor_id: String, amount: int, new_hp: int, max_hp: int)

var _state: BattleState2v2
var _move_library: Dictionary[String, MoveConfig]
var _rng: RandomNumberGenerator
var _scheduler: SpeedBasedScheduler
var _runner: SpeedOrderedActionRunner
var _pc0: PlayerController
var _pc1: PlayerController
var _enemy_ai: MonsterAI


## Start the 2v2 battle coroutine. Fire-and-forget — do not await from an autoload.
func run(
	player_team: Array[MonsterInstance],
	enemy_team: Array[MonsterInstance],
	move_library: Dictionary[String, MoveConfig],
	rng: RandomNumberGenerator = null
) -> void:
	_move_library = move_library
	_rng = rng if rng != null else RandomNumberGenerator.new()

	_scheduler = _SpeedBasedScheduler.new(["player_0", "player_1", "enemy_0", "enemy_1"])
	_runner = _SpeedOrderedActionRunner.new()
	_pc0 = _PlayerController.new()
	_pc1 = _PlayerController.new()
	_enemy_ai = _RandomAI.new()

	# Forward runner signals
	_runner.move_used.connect(func(u: String, m: String, t: String) -> void:
		move_used.emit(u, m, t))
	_runner.damage_dealt.connect(func(tgt: String, amt: int, hp: int, mhp: int) -> void:
		damage_dealt.emit(tgt, amt, hp, mhp))
	_runner.hp_restored.connect(func(tgt: String, amt: int, hp: int, mhp: int) -> void:
		hp_restored.emit(tgt, amt, hp, mhp))
	_runner.stat_changed.connect(func(tgt: String, s: String, d: int, st: int) -> void:
		stat_changed.emit(tgt, s, d, st))
	_runner.monster_fainted.connect(func(n: String) -> void:
		monster_fainted.emit(n))
	_runner.damage_dealt_keyed.connect(func(id: String, amt: int, hp: int, mhp: int) -> void:
		damage_dealt_keyed.emit(id, amt, hp, mhp))
	_runner.hp_restored_keyed.connect(func(id: String, amt: int, hp: int, mhp: int) -> void:
		hp_restored_keyed.emit(id, amt, hp, mhp))

	# Forward needs_target from both player controllers (no auto-select in 2v2)
	_pc0.needs_target.connect(func(actor_id: String, target_ids: Array[String]) -> void:
		needs_target.emit(actor_id, target_ids))
	_pc1.needs_target.connect(func(actor_id: String, target_ids: Array[String]) -> void:
		needs_target.emit(actor_id, target_ids))

	_state = _BattleState2v2.new()
	_state.player_team = player_team
	_state.enemy_team = enemy_team

	for m: MonsterInstance in player_team + enemy_team:
		m.reset_stat_stages()

	var pt: Array[MonsterInstance] = player_team
	var et: Array[MonsterInstance] = enemy_team
	combatants_initialized.emit(
		pt[0].config.display_name, pt[0].max_hp(),
		pt[1].config.display_name, pt[1].max_hp(),
		et[0].config.display_name, et[0].max_hp(),
		et[1].config.display_name, et[1].max_hp()
	)

	while not _state.is_team_wiped("player") and not _state.is_team_wiped("enemy") and _state.turn < MAX_TURNS:
		turn_started.emit(_state.turn + 1)
		var collector: DecisionCollector = _scheduler.next_collector()
		_scheduler.advance(_state)

		# Enemies submit synchronously
		for i: int in range(2):
			var enemy_id: String = "enemy_" + str(i)
			var monster: MonsterInstance = _state.enemy_team[i]
			if monster.is_fainted():
				collector.submit(enemy_id, _make_pass(enemy_id, monster))
				continue
			var action: Action = _enemy_ai.choose_action(
				enemy_id, monster, _move_library, _make_player_target_resolver(), _rng
			)
			if action == null:
				collector.submit(enemy_id, _make_pass(enemy_id, monster))
			else:
				collector.submit(enemy_id, action)

		# Player 0 submits
		var p0: MonsterInstance = _state.player_team[0]
		if p0.is_fainted():
			collector.submit("player_0", _make_pass("player_0", p0))
		else:
			_pc0.bind("player_0", p0, collector, _move_library, _make_enemy_target_resolver())
			waiting_for_input.emit("player_0", _build_move_list(p0))
			if not collector.has_submitted("player_0"):
				await _pc0.submitted

		# Player 1 submits
		var p1: MonsterInstance = _state.player_team[1]
		if p1.is_fainted():
			collector.submit("player_1", _make_pass("player_1", p1))
		else:
			_pc1.bind("player_1", p1, collector, _move_library, _make_enemy_target_resolver())
			waiting_for_input.emit("player_1", _build_move_list(p1))
			if not collector.has_submitted("player_1"):
				await _pc1.submitted

		# All 4 submitted — run the turn
		_runner.run(collector.queue, _state, _rng)

		if _state.is_team_wiped("player") or _state.is_team_wiped("enemy"):
			break

	_state.is_active = false

	var winner_id: String = ""
	if _state.is_team_wiped("player") and _state.is_team_wiped("enemy"):
		winner_id = "draw"
	elif _state.is_team_wiped("player"):
		winner_id = "enemy"
	elif _state.is_team_wiped("enemy"):
		winner_id = "player"

	_state.winner_id = winner_id
	battle_ended.emit(winner_id, _state.turn)


## Called by BattleManager to forward player move choice.
func submit_player_action(actor_id: String, move_index: int) -> void:
	match actor_id:
		"player_0":
			_pc0.select_move(move_index)
		"player_1":
			_pc1.select_move(move_index)


## Called by BattleManager after player selects a target.
func submit_player_target(actor_id: String, target_id: String) -> void:
	match actor_id:
		"player_0":
			_pc0.select_target(target_id)
		"player_1":
			_pc1.select_target(target_id)


# --- Private helpers ---

func _make_pass(actor_id: String, actor: MonsterInstance) -> Action:
	return _Action.create(actor_id, actor_id, actor, actor, null)


## target_resolver for enemy AI: returns all alive player-team members.
func _make_player_target_resolver() -> Callable:
	return func(_actor_id: String) -> Dictionary:
		var d: Dictionary = {}
		for i: int in range(_state.player_team.size()):
			var m: MonsterInstance = _state.player_team[i]
			if not m.is_fainted():
				d["player_" + str(i)] = m
		return d


## target_resolver for player controllers: returns all alive enemy-team members.
func _make_enemy_target_resolver() -> Callable:
	return func(_actor_id: String) -> Dictionary:
		var d: Dictionary = {}
		for i: int in range(_state.enemy_team.size()):
			var m: MonsterInstance = _state.enemy_team[i]
			if not m.is_fainted():
				d["enemy_" + str(i)] = m
		return d


func _build_move_list(monster: MonsterInstance) -> Array[MoveOption]:
	var moves: Array[MoveOption] = []
	for i: int in range(monster.config.move_ids.size()):
		var move_id: String = monster.config.move_ids[i]
		var move: MoveConfig = _move_library.get(move_id, null) as MoveConfig
		var display: String = move.display_name if move != null else move_id
		moves.append(MoveOption.new(i, display))
	return moves
