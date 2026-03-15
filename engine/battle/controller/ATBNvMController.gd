extends RefCounted
## Async coroutine controller for FF-style ATB NvM Wait-mode combat.
## No class_name: BattleManager uses preload.
##
## Each actor has an independent gauge (0–100) that fills proportional to effective_speed().
## When a gauge fills, that actor acts immediately (FF-style: no waiting for others).
## Wait mode: all gauges freeze while any actor (player or enemy) is resolving their action.
## Actor IDs: "player_0".."player_N-1", "enemy_0".."enemy_M-1".
##
## External driver calls tick(delta) each frame (via ATBTickDriver).
## The internal _ticked signal wakes the coroutine after each tick.

const _ATBScheduler = preload("res://engine/battle/controller/ATBScheduler.gd")
const _BattleStateNvM = preload("res://engine/battle/model/BattleStateNvM.gd")
const _DecisionCollector = preload("res://engine/battle/controller/DecisionCollector.gd")
const _SpeedOrderedActionRunner = preload("res://engine/battle/controller/SpeedOrderedActionRunner.gd")
const _PlayerController = preload("res://engine/battle/controller/PlayerController.gd")
const _Action = preload("res://engine/battle/model/Action.gd")
const _RandomAI = preload("res://engine/entities/controller/ai/RandomAI.gd")

const MAX_ACTIONS: int = 500

# --- Signals ---

## Fires once at battle start. Parallel arrays: index i = team member i.
signal combatants_initialized(
	player_names: Array[String], player_max_hps: Array[int],
	enemy_names: Array[String], enemy_max_hps: Array[int]
)
signal battle_started()

## Forwarded from scheduler — fires when an actor's gauge fills.
signal actor_ready(actor_id: String)

## Fires when a player actor needs to pick a move.
signal waiting_for_input(actor_id: String, available_moves: Array[MoveOption])

## Fires when PlayerController needs a target selection from UI.
signal needs_target(actor_id: String, valid_target_ids: Array[String])

## Forwarded from runner
signal move_used(user_name: String, move_name: String, target_name: String)
signal damage_dealt(target_name: String, amount: int, remaining_hp: int, max_hp: int)
signal hp_restored(target_name: String, amount: int, new_hp: int, max_hp: int)
signal stat_changed(target_name: String, stat: String, delta: int, total_stage: int)
signal monster_fainted(monster_name: String)
signal damage_dealt_keyed(actor_id: String, amount: int, remaining_hp: int, max_hp: int)
signal hp_restored_keyed(actor_id: String, amount: int, new_hp: int, max_hp: int)

## Emitted in tick() for every actor — drives real-time gauge UI.
signal gauge_updated(actor_id: String, value: float)

## action_count = number of individual actions resolved (not turns, ATB has none).
signal battle_ended(winner_id: String, action_count: int)

## Internal: emitted at end of tick() to wake the coroutine loop.
signal _ticked


# --- State ---

var _state: BattleStateNvM
var _scheduler: ATBScheduler
var _runner: SpeedOrderedActionRunner
var _player_controllers: Array[PlayerController] = []
var _enemy_ai: MonsterAI
var _move_library: Dictionary[String, MoveConfig]
var _rng: RandomNumberGenerator
var _action_count: int = 0


## Start the ATB NvM battle coroutine. Fire-and-forget — do not await from an autoload.
## BattleManager drives time by calling tick(delta) each frame via ATBTickDriver.
func run(
	player_team: Array[MonsterInstance],
	enemy_team: Array[MonsterInstance],
	move_library: Dictionary[String, MoveConfig],
	rng: RandomNumberGenerator = null
) -> void:
	_move_library = move_library
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_enemy_ai = _RandomAI.new()

	# Build actor→instance map for scheduler
	var actor_map: Dictionary = {}
	for i: int in range(player_team.size()):
		actor_map["player_" + str(i)] = player_team[i]
	for i: int in range(enemy_team.size()):
		actor_map["enemy_" + str(i)] = enemy_team[i]

	_scheduler = _ATBScheduler.new(actor_map)
	_scheduler.actor_ready.connect(func(id: String) -> void: actor_ready.emit(id))

	_runner = _SpeedOrderedActionRunner.new()
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

	# Build one PlayerController per player slot
	_player_controllers.clear()
	for i: int in range(player_team.size()):
		var pc: PlayerController = _PlayerController.new()
		_player_controllers.append(pc)
		pc.needs_target.connect(func(actor_id: String, target_ids: Array[String]) -> void:
			needs_target.emit(actor_id, target_ids)
		)

	# Build state
	_state = _BattleStateNvM.new()
	_state.player_team = player_team
	_state.enemy_team = enemy_team

	for m: MonsterInstance in player_team + enemy_team:
		m.reset_stat_stages()

	# Emit initialization
	var p_names: Array[String] = []
	var p_hps: Array[int] = []
	for m: MonsterInstance in player_team:
		p_names.append(m.config.display_name)
		p_hps.append(m.max_hp())
	var e_names: Array[String] = []
	var e_hps: Array[int] = []
	for m: MonsterInstance in enemy_team:
		e_names.append(m.config.display_name)
		e_hps.append(m.max_hp())
	combatants_initialized.emit(p_names, p_hps, e_names, e_hps)
	battle_started.emit()

	# Main ATB loop
	while not _state.is_team_wiped("player") and not _state.is_team_wiped("enemy") and _action_count < MAX_ACTIONS:
		# Wait for the next ready actor
		while not _scheduler.has_ready():
			await _ticked

		var actor_id: String = _scheduler.pop_next_ready()
		var actor: MonsterInstance = _state.get_combatant(actor_id)

		# Actor may have fainted while waiting in the queue
		if actor == null or actor.is_fainted():
			continue

		# Wait mode: freeze all gauges until this action resolves
		_scheduler.set_paused(true)

		if actor_id.begins_with("player_"):
			await _handle_player_turn(actor_id, actor)
		else:
			_handle_enemy_turn(actor_id, actor)

		_action_count += 1

		if _state.is_team_wiped("player") or _state.is_team_wiped("enemy"):
			break

		_scheduler.set_paused(false)

	_state.is_active = false

	var winner_id: String = ""
	if _state.is_team_wiped("player") and _state.is_team_wiped("enemy"):
		winner_id = "draw"
	elif _state.is_team_wiped("player"):
		winner_id = "enemy"
	elif _state.is_team_wiped("enemy"):
		winner_id = "player"

	_state.winner_id = winner_id
	battle_ended.emit(winner_id, _action_count)


## Called by ATBTickDriver each _process frame to advance ATB gauges.
func tick(delta: float) -> void:
	_scheduler.tick(delta)
	var gauges: Dictionary = _scheduler.get_all_gauges()
	for actor_id: String in gauges:
		gauge_updated.emit(actor_id, gauges[actor_id])
	_ticked.emit()


## Called by BattleManager to forward the player's move choice.
func submit_player_action(actor_id: String, move_index: int) -> void:
	var idx: int = _player_index_from_id(actor_id)
	if idx >= 0 and idx < _player_controllers.size():
		_player_controllers[idx].select_move(move_index)


## Called by BattleManager after player selects a target.
func submit_player_target(actor_id: String, target_id: String) -> void:
	var idx: int = _player_index_from_id(actor_id)
	if idx >= 0 and idx < _player_controllers.size():
		_player_controllers[idx].select_target(target_id)


# --- Private ---

func _handle_player_turn(actor_id: String, actor: MonsterInstance) -> void:
	var idx: int = _player_index_from_id(actor_id)
	var pc: PlayerController = _player_controllers[idx]
	var collector: DecisionCollector = _DecisionCollector.create_all_submitted([actor_id])
	pc.bind(actor_id, actor, collector, _move_library, _make_enemy_target_resolver())
	waiting_for_input.emit(actor_id, _build_move_list(actor))
	if not collector.is_committed:
		await collector.committed
	_runner.run(collector.queue, _state, _rng)


func _handle_enemy_turn(actor_id: String, actor: MonsterInstance) -> void:
	var action: Action = _enemy_ai.choose_action(
		actor_id, actor, _move_library, _make_player_target_resolver(), _rng
	)
	var queue: Array[Action] = []
	if action != null:
		queue.append(action)
	else:
		queue.append(_make_pass(actor_id, actor))
	_runner.run(queue, _state, _rng)


func _player_index_from_id(actor_id: String) -> int:
	if actor_id.begins_with("player_"):
		return actor_id.substr(7).to_int()
	return -1


func _make_pass(actor_id: String, actor: MonsterInstance) -> Action:
	return _Action.create(actor_id, actor_id, actor, actor, null)


func _make_player_target_resolver() -> Callable:
	return func(_actor_id: String) -> Dictionary:
		var d: Dictionary = {}
		for i: int in range(_state.player_team.size()):
			var m: MonsterInstance = _state.player_team[i]
			if not m.is_fainted():
				d["player_" + str(i)] = m
		return d


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
