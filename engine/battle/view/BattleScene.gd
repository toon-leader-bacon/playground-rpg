extends Control
## Interactive battle UI. Listens to EventBus signals, presents move choices,
## forwards player input to BattleManager.

@onready var _enemy_name_label: Label = $EnemyPanel/EnemyNameLabel
@onready var _enemy_hp_bar: ProgressBar = $EnemyPanel/EnemyHPBar
@onready var _enemy_hp_text: Label = $EnemyPanel/EnemyHPText
@onready var _player_name_label: Label = $PlayerPanel/PlayerNameLabel
@onready var _player_hp_bar: ProgressBar = $PlayerPanel/PlayerHPBar
@onready var _player_hp_text: Label = $PlayerPanel/PlayerHPText
@onready var _message_box: RichTextLabel = $MessageBox
@onready var _action_menu: VBoxContainer = $ActionMenu
@onready var _move_buttons: Array[Button] = [
	$ActionMenu/MoveButton0,
	$ActionMenu/MoveButton1,
	$ActionMenu/MoveButton2,
	$ActionMenu/MoveButton3,
]

var _current_actor_id: String = ""
var _player_max_hp: int = 1
var _enemy_max_hp: int = 1


func _ready() -> void:
	_action_menu.hide()

	EventBus.battle_combatants_initialized.connect(_on_battle_combatants_initialized)
	EventBus.battle_turn_started.connect(_on_turn_started)
	EventBus.battle_damage_dealt.connect(_on_damage_dealt)
	EventBus.battle_hp_restored.connect(_on_hp_restored)
	EventBus.battle_stat_changed.connect(_on_stat_changed)
	EventBus.battle_monster_fainted.connect(_on_monster_fainted)
	EventBus.battle_waiting_for_input.connect(_on_waiting_for_input)
	EventBus.battle_ended.connect(_on_battle_ended)

	for i: int in range(_move_buttons.size()):
		_move_buttons[i].pressed.connect(_on_move_button_pressed.bind(i))

	_start_demo_battle()


func _start_demo_battle() -> void:
	var player_config: MonsterConfig = ConfigLoader.load_monster("fire_lizard")
	var enemy_config: MonsterConfig = ConfigLoader.load_monster("stone_golem")
	if player_config == null or enemy_config == null:
		push_error("BattleScene: could not load demo monster configs")
		return
	var player: MonsterInstance = MonsterInstance.create(player_config, 5)
	var enemy: MonsterInstance = MonsterInstance.create(enemy_config, 5)
	BattleManager.start_battle(BattleManager.CombatStyle.TURN_BASED_1V1_INTERACTIVE, [player, enemy])


func _on_battle_combatants_initialized(
	player_name: String,
	player_max_hp: int,
	enemy_name: String,
	enemy_max_hp: int
) -> void:
	_player_max_hp = player_max_hp
	_enemy_max_hp = enemy_max_hp

	_player_name_label.text = player_name
	_player_hp_bar.max_value = player_max_hp
	_player_hp_bar.value = player_max_hp
	_player_hp_text.text = "%d / %d" % [player_max_hp, player_max_hp]

	_enemy_name_label.text = enemy_name
	_enemy_hp_bar.max_value = enemy_max_hp
	_enemy_hp_bar.value = enemy_max_hp
	_enemy_hp_text.text = "%d / %d" % [enemy_max_hp, enemy_max_hp]

	_message_box.text = ""
	_append_message("Battle started: %s vs %s!" % [player_name, enemy_name])


func _on_turn_started(
	turn_num: int,
	player_name: String,
	player_hp: int,
	enemy_name: String,
	enemy_hp: int
) -> void:
	_append_message("\n[Turn %d] %s HP:%d  vs  %s HP:%d" % [
		turn_num, player_name, player_hp, enemy_name, enemy_hp
	])
	_update_hp_bars(player_hp, enemy_hp)


func _on_damage_dealt(target_name: String, amount: int, remaining_hp: int, max_hp: int) -> void:
	_append_message("  %s took %d damage (%d/%d HP)" % [
		target_name, amount, remaining_hp, max_hp
	])
	_refresh_hp_bar_for(target_name, remaining_hp, max_hp)


func _on_hp_restored(target_name: String, amount: int, new_hp: int, max_hp: int) -> void:
	_append_message("  %s restored %d HP (%d/%d HP)" % [
		target_name, amount, new_hp, max_hp
	])
	_refresh_hp_bar_for(target_name, new_hp, max_hp)


func _on_stat_changed(target_name: String, stat: String, delta: int, total_stage: int) -> void:
	var dir: String = "rose" if delta > 0 else "fell"
	_append_message("  %s's %s %s! (stage %+d)" % [target_name, stat, dir, total_stage])


func _on_monster_fainted(monster_name: String) -> void:
	_append_message("*** %s FAINTED! ***" % monster_name)


func _on_waiting_for_input(actor_id: String, available_moves: Array[MoveOption]) -> void:
	_current_actor_id = actor_id
	# Label buttons and hide extras
	for i: int in range(_move_buttons.size()):
		if i < available_moves.size():
			_move_buttons[i].text = available_moves[i].display_name
			_move_buttons[i].show()
		else:
			_move_buttons[i].hide()
	_action_menu.show()


func _on_move_button_pressed(idx: int) -> void:
	_action_menu.hide()
	BattleManager.submit_player_action(_current_actor_id, idx)


func _on_battle_ended(winner_name: String, _loser_name: String, turn_count: int) -> void:
	_action_menu.hide()
	if winner_name.is_empty() or winner_name == "(draw)":
		_append_message("\n=== DRAW after %d turns ===" % turn_count)
	else:
		_append_message("\n=== %s WINS after %d turns ===" % [winner_name, turn_count])


func _append_message(text: String) -> void:
	_message_box.text += text + "\n"


func _update_hp_bars(player_hp: int, enemy_hp: int) -> void:
	_player_hp_bar.value = player_hp
	_player_hp_text.text = "%d / %d" % [player_hp, _player_max_hp]
	_enemy_hp_bar.value = enemy_hp
	_enemy_hp_text.text = "%d / %d" % [enemy_hp, _enemy_max_hp]


func _refresh_hp_bar_for(target_name: String, hp: int, max_hp: int) -> void:
	if target_name == _player_name_label.text:
		_player_hp_bar.value = hp
		_player_hp_text.text = "%d / %d" % [hp, max_hp]
	else:
		_enemy_hp_bar.value = hp
		_enemy_hp_text.text = "%d / %d" % [hp, max_hp]
