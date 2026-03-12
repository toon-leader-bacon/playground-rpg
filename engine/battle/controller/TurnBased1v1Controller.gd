extends RefCounted
## Async battle controller for interactive 1v1 turn-based combat.
## Runs as a coroutine — parks at `await` until player submits a move.
## No class_name: BattleManager uses preload to reference this.
##
## Usage:
##   var ctrl = TurnBased1v1Controller.new()
##   ctrl.waiting_for_input.connect(my_ui_handler)
##   ctrl.run(player, enemy, move_library)        # fire-and-forget coroutine
##   # Later, when player picks a move:
##   ctrl.submit_player_action(move_index)

const _BattleState = preload("res://engine/battle/model/BattleState.gd")
const _DecisionCollector = preload("res://engine/battle/controller/DecisionCollector.gd")
const _SpeedBasedScheduler = preload("res://engine/battle/controller/SpeedBasedScheduler.gd")
const _SpeedOrderedActionRunner = preload("res://engine/battle/controller/SpeedOrderedActionRunner.gd")
const _PlayerController = preload("res://engine/battle/controller/PlayerController.gd")
const _Action = preload("res://engine/battle/model/Action.gd")

const MAX_TURNS := 100

# --- Signals ---
signal battle_started(player_name: String, enemy_name: String)
signal combatants_initialized(player_name: String, player_max_hp: int, enemy_name: String, enemy_max_hp: int)
signal turn_started(turn_num: int, player_name: String, player_hp: int, enemy_name: String, enemy_hp: int)
signal waiting_for_input(actor_id: String, available_moves: Array[MoveOption])
signal battle_ended(winner_id: String, turn_count: int)

# Forwarded from runner
signal move_used(user_name: String, move_name: String, target_name: String)
signal damage_dealt(target_name: String, amount: int, remaining_hp: int, max_hp: int)
signal hp_restored(target_name: String, amount: int, new_hp: int, max_hp: int)
signal stat_changed(target_name: String, stat: String, delta: int, total_stage: int)
signal monster_fainted(monster_name: String)

var _state: BattleState
var _player: MonsterInstance
var _enemy: MonsterInstance
var _move_library: Dictionary[String, MoveConfig]
var _rng: RandomNumberGenerator
var _scheduler: SpeedBasedScheduler
var _runner: SpeedOrderedActionRunner
var _player_controller: PlayerController


## Start the battle coroutine. Fire-and-forget — do not await this from an autoload.
func run(
	player: MonsterInstance,
	enemy: MonsterInstance,
	move_library: Dictionary[String, MoveConfig],
	rng: RandomNumberGenerator = null
) -> void:
	_player = player
	_enemy = enemy
	_move_library = move_library
	_rng = rng if rng != null else RandomNumberGenerator.new()

	_scheduler = _SpeedBasedScheduler.new()
	_runner = _SpeedOrderedActionRunner.new()
	_player_controller = _PlayerController.new()

	# Forward runner signals
	_runner.move_used.connect(func(u: String, m: String, t: String) -> void:
		move_used.emit(u, m, t)
	)
	_runner.damage_dealt.connect(func(tgt: String, amt: int, hp: int, max_hp: int) -> void:
		damage_dealt.emit(tgt, amt, hp, max_hp)
	)
	_runner.hp_restored.connect(func(tgt: String, amt: int, hp: int, max_hp: int) -> void:
		hp_restored.emit(tgt, amt, hp, max_hp)
	)
	_runner.stat_changed.connect(func(tgt: String, stat: String, delta: int, stage: int) -> void:
		stat_changed.emit(tgt, stat, delta, stage)
	)
	_runner.monster_fainted.connect(func(name: String) -> void:
		monster_fainted.emit(name)
	)

	_state = BattleState.new()
	_state.player = _player
	_state.enemy = _enemy

	_player.reset_stat_stages()
	_enemy.reset_stat_stages()

	combatants_initialized.emit(
		_player.config.display_name, _player.max_hp(),
		_enemy.config.display_name, _enemy.max_hp()
	)
	battle_started.emit(_player.config.display_name, _enemy.config.display_name)

	while not _player.is_fainted() and not _enemy.is_fainted() and _state.turn < MAX_TURNS:
		# 1. Emit turn_started with current HP
		turn_started.emit(
			_state.turn + 1,
			_player.config.display_name, _player.current_hp,
			_enemy.config.display_name, _enemy.current_hp
		)

		# 2. Get collector; advance turn counter
		var collector: DecisionCollector = _scheduler.next_collector(_state)
		_scheduler.advance(_state)

		# 3. AI submits synchronously
		var enemy_move_idx: int = MonsterAI.choose_action(_enemy, _player, _rng)
		var enemy_move_id: String = _enemy.config.move_ids[enemy_move_idx] if enemy_move_idx >= 0 else ""
		var enemy_move: MoveConfig = _move_library.get(enemy_move_id, null) as MoveConfig
		var enemy_action: Action = _Action.create("enemy", "player", _enemy, _player, enemy_move)
		collector.submit("enemy", enemy_action)

		# 4. Bind player controller
		_player_controller.bind("player", _player, _enemy, collector, _move_library)

		# 5. Signal UI to present choices
		waiting_for_input.emit("player", _build_move_list(_player))

		# 6. Await human submission if not already committed
		if not collector.is_committed:
			await collector.committed

		# 7. Run the action queue (populated by DecisionCollector on commit)
		_runner.run(collector.queue, _state, _rng)

		# 8. Check end conditions
		if _player.is_fainted() or _enemy.is_fainted():
			break

	_state.is_active = false

	var winner_id: String = ""
	if _player.is_fainted() and _enemy.is_fainted():
		winner_id = "draw"
	elif _player.is_fainted():
		winner_id = _enemy.config.id
	elif _enemy.is_fainted():
		winner_id = _player.config.id

	_state.winner_id = winner_id
	battle_ended.emit(winner_id, _state.turn)


## Called by UI or scene to forward the player's move choice into the active battle.
func submit_player_action(move_index: int) -> void:
	_player_controller.set_decision(move_index)


func _build_move_list(monster: MonsterInstance) -> Array[MoveOption]:
	var moves: Array[MoveOption] = []
	for i: int in range(monster.config.move_ids.size()):
		var move_id: String = monster.config.move_ids[i]
		var move: MoveConfig = _move_library.get(move_id, null) as MoveConfig
		var display: String = move.display_name if move != null else move_id
		moves.append(MoveOption.new(i, display))
	return moves
