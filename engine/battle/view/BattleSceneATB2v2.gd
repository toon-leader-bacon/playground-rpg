extends Control
## Interactive ATB 2v2 battle UI.
## Starts an ATB_NVM_INTERACTIVE battle (2 player vs 2 enemy).
## Shows HP bars and live ATB gauge bars for all four combatants.
## Action menu pops up when a player's ATB gauge fills.
## Player team: player_0 (bottom-left), player_1 (bottom-right).
## Enemy team:  enemy_0 (top-left),   enemy_1 (top-right).

@onready var _enemy0_name: Label = $EnemyPanel/Enemy0Panel/Enemy0NameLabel
@onready var _enemy0_hp_bar: ProgressBar = $EnemyPanel/Enemy0Panel/Enemy0HPBar
@onready var _enemy0_hp_text: Label = $EnemyPanel/Enemy0Panel/Enemy0HPText
@onready var _enemy0_atb_bar: ProgressBar = $EnemyPanel/Enemy0Panel/Enemy0ATBBar

@onready var _enemy1_name: Label = $EnemyPanel/Enemy1Panel/Enemy1NameLabel
@onready var _enemy1_hp_bar: ProgressBar = $EnemyPanel/Enemy1Panel/Enemy1HPBar
@onready var _enemy1_hp_text: Label = $EnemyPanel/Enemy1Panel/Enemy1HPText
@onready var _enemy1_atb_bar: ProgressBar = $EnemyPanel/Enemy1Panel/Enemy1ATBBar

@onready var _player0_name: Label = $PlayerPanel/Player0Panel/Player0NameLabel
@onready var _player0_hp_bar: ProgressBar = $PlayerPanel/Player0Panel/Player0HPBar
@onready var _player0_hp_text: Label = $PlayerPanel/Player0Panel/Player0HPText
@onready var _player0_atb_bar: ProgressBar = $PlayerPanel/Player0Panel/Player0ATBBar

@onready var _player1_name: Label = $PlayerPanel/Player1Panel/Player1NameLabel
@onready var _player1_hp_bar: ProgressBar = $PlayerPanel/Player1Panel/Player1HPBar
@onready var _player1_hp_text: Label = $PlayerPanel/Player1Panel/Player1HPText
@onready var _player1_atb_bar: ProgressBar = $PlayerPanel/Player1Panel/Player1ATBBar

@onready var _message_box: RichTextLabel = $MessageBox
@onready var _action_menu: VBoxContainer = $ActionMenu
@onready var _current_actor_label: Label = $ActionMenu/CurrentActorLabel
@onready var _move_buttons: Array[Button] = [
	$ActionMenu/MoveButton0,
	$ActionMenu/MoveButton1,
	$ActionMenu/MoveButton2,
	$ActionMenu/MoveButton3,
]
@onready var _target_menu: VBoxContainer = $TargetMenu
@onready var _target_buttons: Array[Button] = [
	$TargetMenu/TargetButton0,
	$TargetMenu/TargetButton1,
]

# actor_id -> display_name cache
var _actor_names: Dictionary = {}
# actor_id -> [hp_bar, hp_text, max_hp, atb_bar]
var _widgets: Dictionary = {}

var _current_actor_id: String = ""
var _pending_target_ids: Array[String] = []


func _ready() -> void:
	_action_menu.hide()
	_target_menu.hide()

	EventBus.battle_nvm_initialized.connect(_on_battle_nvm_initialized)
	EventBus.battle_gauge_updated.connect(_on_gauge_updated)
	EventBus.battle_action_started.connect(_on_action_started)
	EventBus.battle_move_used.connect(_on_move_used)
	EventBus.battle_damage_dealt_keyed.connect(_on_damage_dealt_keyed)
	EventBus.battle_hp_restored_keyed.connect(_on_hp_restored_keyed)
	EventBus.battle_stat_changed.connect(_on_stat_changed)
	EventBus.battle_monster_fainted.connect(_on_monster_fainted)
	EventBus.battle_waiting_for_input.connect(_on_waiting_for_input)
	EventBus.battle_needs_target.connect(_on_needs_target)
	EventBus.battle_ended.connect(_on_battle_ended)

	for i: int in range(_move_buttons.size()):
		_move_buttons[i].pressed.connect(_on_move_button_pressed.bind(i))
	for i: int in range(_target_buttons.size()):
		_target_buttons[i].pressed.connect(_on_target_button_pressed.bind(i))

	_start_demo_battle()


func _start_demo_battle() -> void:
	var lizard_config: MonsterConfig = ConfigLoader.load_monster("fire_lizard")
	var golem_config: MonsterConfig = ConfigLoader.load_monster("stone_golem")
	if lizard_config == null or golem_config == null:
		push_error("BattleSceneATB2v2: could not load demo monster configs")
		return
	var p0: MonsterInstance = MonsterInstance.create(lizard_config, 5)
	var p1: MonsterInstance = MonsterInstance.create(golem_config, 5)
	var e0: MonsterInstance = MonsterInstance.create(golem_config, 5)
	var e1: MonsterInstance = MonsterInstance.create(lizard_config, 5)
	BattleManager.start_battle(BattleManager.CombatStyle.ATB_NVM_INTERACTIVE, [[p0, p1], [e0, e1]])


func _on_battle_nvm_initialized(
	player_names: Array, player_max_hps: Array,
	enemy_names: Array, enemy_max_hps: Array
) -> void:
	# Build name and widget caches
	_actor_names.clear()
	_widgets.clear()

	var p0_name: String = player_names[0] if player_names.size() > 0 else "Player 0"
	var p1_name: String = player_names[1] if player_names.size() > 1 else "Player 1"
	var e0_name: String = enemy_names[0] if enemy_names.size() > 0 else "Enemy 0"
	var e1_name: String = enemy_names[1] if enemy_names.size() > 1 else "Enemy 1"
	var p0_max: int = player_max_hps[0] if player_max_hps.size() > 0 else 100
	var p1_max: int = player_max_hps[1] if player_max_hps.size() > 1 else 100
	var e0_max: int = enemy_max_hps[0] if enemy_max_hps.size() > 0 else 100
	var e1_max: int = enemy_max_hps[1] if enemy_max_hps.size() > 1 else 100

	_actor_names = {
		"player_0": p0_name, "player_1": p1_name,
		"enemy_0": e0_name,  "enemy_1": e1_name,
	}
	_widgets = {
		"player_0": [_player0_hp_bar, _player0_hp_text, p0_max, _player0_atb_bar],
		"player_1": [_player1_hp_bar, _player1_hp_text, p1_max, _player1_atb_bar],
		"enemy_0":  [_enemy0_hp_bar,  _enemy0_hp_text,  e0_max, _enemy0_atb_bar],
		"enemy_1":  [_enemy1_hp_bar,  _enemy1_hp_text,  e1_max, _enemy1_atb_bar],
	}

	# Initialize name labels and HP bars
	_enemy0_name.text = e0_name
	_enemy0_hp_bar.max_value = e0_max
	_enemy0_hp_bar.value = e0_max
	_enemy0_hp_text.text = "%d / %d" % [e0_max, e0_max]
	_enemy0_atb_bar.value = 0

	_enemy1_name.text = e1_name
	_enemy1_hp_bar.max_value = e1_max
	_enemy1_hp_bar.value = e1_max
	_enemy1_hp_text.text = "%d / %d" % [e1_max, e1_max]
	_enemy1_atb_bar.value = 0

	_player0_name.text = p0_name
	_player0_hp_bar.max_value = p0_max
	_player0_hp_bar.value = p0_max
	_player0_hp_text.text = "%d / %d" % [p0_max, p0_max]
	_player0_atb_bar.value = 0

	_player1_name.text = p1_name
	_player1_hp_bar.max_value = p1_max
	_player1_hp_bar.value = p1_max
	_player1_hp_text.text = "%d / %d" % [p1_max, p1_max]
	_player1_atb_bar.value = 0

	_message_box.text = ""
	_append_message("[ATB 2v2] %s & %s  vs  %s & %s" % [p0_name, p1_name, e0_name, e1_name])
	_append_message("Gauges filling — act when your bar is full!")


func _on_gauge_updated(actor_id: String, value: float) -> void:
	if not _widgets.has(actor_id):
		return
	var atb_bar: ProgressBar = _widgets[actor_id][3] as ProgressBar
	atb_bar.value = value


func _on_action_started(actor_id: String) -> void:
	var name: String = _actor_names.get(actor_id, actor_id)
	_append_message("\n» %s's ATB gauge is full!" % name)


func _on_move_used(user_name: String, move_name: String, target_name: String) -> void:
	_append_message("  %s used %s on %s" % [user_name, move_name, target_name])


func _on_damage_dealt_keyed(actor_id: String, amount: int, remaining_hp: int, max_hp: int) -> void:
	_append_message("  → %d damage (%d/%d HP left)" % [amount, remaining_hp, max_hp])
	_refresh_hp(actor_id, remaining_hp, max_hp)


func _on_hp_restored_keyed(actor_id: String, amount: int, new_hp: int, max_hp: int) -> void:
	_append_message("  → restored %d HP (%d/%d HP)" % [amount, new_hp, max_hp])
	_refresh_hp(actor_id, new_hp, max_hp)


func _on_stat_changed(target_name: String, stat: String, delta: int, total_stage: int) -> void:
	var dir: String = "rose" if delta > 0 else "fell"
	_append_message("  %s's %s %s! (stage %+d)" % [target_name, stat, dir, total_stage])


func _on_monster_fainted(monster_name: String) -> void:
	_append_message("*** %s FAINTED! ***" % monster_name)


func _on_waiting_for_input(actor_id: String, available_moves: Array) -> void:
	_current_actor_id = actor_id
	var actor_display: String = _actor_names.get(actor_id, actor_id)
	_current_actor_label.text = "%s — choose a move:" % actor_display
	for i: int in range(_move_buttons.size()):
		if i < available_moves.size():
			_move_buttons[i].text = (available_moves[i] as MoveOption).display_name
			_move_buttons[i].show()
		else:
			_move_buttons[i].hide()
	_action_menu.show()
	_target_menu.hide()


func _on_needs_target(actor_id: String, valid_target_ids: Array[String]) -> void:
	_current_actor_id = actor_id
	_pending_target_ids = valid_target_ids
	var actor_display: String = _actor_names.get(actor_id, actor_id)
	_current_actor_label.text = "%s — choose a target:" % actor_display
	for i: int in range(_target_buttons.size()):
		if i < valid_target_ids.size():
			_target_buttons[i].text = _actor_names.get(valid_target_ids[i], valid_target_ids[i])
			_target_buttons[i].show()
		else:
			_target_buttons[i].hide()
	_action_menu.hide()
	_target_menu.show()


func _on_move_button_pressed(idx: int) -> void:
	_action_menu.hide()
	BattleManager.submit_player_action(_current_actor_id, idx)


func _on_target_button_pressed(idx: int) -> void:
	_target_menu.hide()
	if idx < _pending_target_ids.size():
		BattleManager.submit_player_target(_current_actor_id, _pending_target_ids[idx])


func _on_battle_ended(winner_name: String, _loser_name: String, action_count: int) -> void:
	_action_menu.hide()
	_target_menu.hide()
	if winner_name.is_empty() or winner_name == "(draw)":
		_append_message("\n=== DRAW after %d actions ===" % action_count)
	else:
		_append_message("\n=== %s WINS after %d actions ===" % [winner_name, action_count])


func _append_message(text: String) -> void:
	_message_box.text += text + "\n"


func _refresh_hp(actor_id: String, hp: int, max_hp: int) -> void:
	if not _widgets.has(actor_id):
		return
	var widgets: Array = _widgets[actor_id]
	(widgets[0] as ProgressBar).value = hp
	(widgets[1] as Label).text = "%d / %d" % [hp, max_hp]
