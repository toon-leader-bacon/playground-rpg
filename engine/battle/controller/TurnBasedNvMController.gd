extends RefCounted
## Async coroutine controller for interactive NvM turn-based combat.
## No class_name: BattleManager uses preload.
##
## Generalizes TurnBased2v2Controller to arbitrary team sizes.
## Actor IDs: "player_0".."player_N-1", "enemy_0".."enemy_M-1".
## All actors submit simultaneously each turn; actions resolved in speed order.
## Player monsters submit sequentially (player_0 first, then player_N-1).
## AI handles all enemy monsters synchronously.

const _BattleStateNvM = preload("res://engine/battle/model/BattleStateNvM.gd")
const _DecisionCollector = preload("res://engine/battle/controller/DecisionCollector.gd")
const _SpeedBasedScheduler = preload("res://engine/battle/controller/SpeedBasedScheduler.gd")
const _SpeedOrderedActionRunner = preload("res://engine/battle/controller/SpeedOrderedActionRunner.gd")
const _PlayerController = preload("res://engine/battle/controller/PlayerController.gd")
const _Action = preload("res://engine/battle/model/Action.gd")
const _RandomAI = preload("res://engine/entities/controller/ai/RandomAI.gd")

const MAX_TURNS := 100

# --- Signals ---
## Fires once at battle start. Parallel arrays: index i = team member i.
signal combatants_initialized(
	player_names: Array[String], player_max_hps: Array[int],
	enemy_names: Array[String], enemy_max_hps: Array[int]
)
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

var _state: BattleStateNvM
var _move_library: Dictionary[String, MoveConfig]
var _rng: RandomNumberGenerator
var _scheduler: SpeedBasedScheduler
var _runner: SpeedOrderedActionRunner
var _player_controllers: Array[PlayerController] = []
var _enemy_ai: MonsterAI


## Start the NvM battle coroutine. Fire-and-forget — do not await from an autoload.
func run(
	player_team: Array[MonsterInstance],
	enemy_team: Array[MonsterInstance],
	move_library: Dictionary[String, MoveConfig],
	rng: RandomNumberGenerator = null
) -> void:
	_move_library = move_library
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_enemy_ai = _RandomAI.new()

	# Build actor ID list (players first, then enemies)
	var actor_ids: Array[String] = []
	for i: int in range(player_team.size()):
		actor_ids.append("player_" + str(i))
	for i: int in range(enemy_team.size()):
		actor_ids.append("enemy_" + str(i))

	_scheduler = _SpeedBasedScheduler.new(actor_ids)
	_runner = _SpeedOrderedActionRunner.new()

	# Build one PlayerController per player slot; connect needs_target permanently
	_player_controllers.clear()
	for i: int in range(player_team.size()):
		var pc: PlayerController = _PlayerController.new()
		_player_controllers.append(pc)
		pc.needs_target.connect(func(actor_id: String, target_ids: Array[String]) -> void:
			needs_target.emit(actor_id, target_ids)
		)

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

	# Build state
	_state = _BattleStateNvM.new()
	_state.player_team = player_team
	_state.enemy_team = enemy_team

	for m: MonsterInstance in player_team + enemy_team:
		m.reset_stat_stages()

	# Emit initialization signal with parallel arrays
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

	# Main battle loop
	while not _state.is_team_wiped("player") and not _state.is_team_wiped("enemy") and _state.turn < MAX_TURNS:
		turn_started.emit(_state.turn + 1)
		var collector: DecisionCollector = _scheduler.next_collector()
		_scheduler.advance(_state)

		# Enemies submit synchronously
		for i: int in range(enemy_team.size()):
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

		# Players submit sequentially
		for i: int in range(player_team.size()):
			var actor_id: String = "player_" + str(i)
			var player: MonsterInstance = _state.player_team[i]
			if player.is_fainted():
				collector.submit(actor_id, _make_pass(actor_id, player))
				continue
			var pc: PlayerController = _player_controllers[i]
			pc.bind(actor_id, player, collector, _move_library, _make_enemy_target_resolver())
			waiting_for_input.emit(actor_id, _build_move_list(player))
			if not collector.has_submitted(actor_id):
				await pc.submitted

		# Execute turn
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


## Called by BattleManager to forward a player's move choice.
func submit_player_action(actor_id: String, move_index: int) -> void:
	var idx: int = _player_index_from_id(actor_id)
	if idx >= 0 and idx < _player_controllers.size():
		_player_controllers[idx].select_move(move_index)


## Called by BattleManager after player selects a target.
func submit_player_target(actor_id: String, target_id: String) -> void:
	var idx: int = _player_index_from_id(actor_id)
	if idx >= 0 and idx < _player_controllers.size():
		_player_controllers[idx].select_target(target_id)


# --- Private helpers ---

func _player_index_from_id(actor_id: String) -> int:
	if actor_id.begins_with("player_"):
		return actor_id.substr(7).to_int()
	return -1


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
