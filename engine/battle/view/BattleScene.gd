extends Control
## Generic battle scene driven entirely by a BattleConfig resource.
## Loads a BattleConfig by ID, spawns CombatantHUD panels for each team member,
## and routes all EventBus signals to the appropriate HUD or log.
##
## Supports both TURN_BASED_NVM and ATB_NVM styles.
## ATB gauge bars are shown only when the config style is ATB_NVM.
##
## To run a different battle: change config_id in the Inspector, or create a
## new .tres in content/battles/ and point config_id at it.

## ID of the BattleConfig .tres to load from content/battles/.
@export var config_id: String = "pokemon_3v3"

@onready var _enemy_row: HBoxContainer = $EnemyRow
@onready var _player_row: HBoxContainer = $PlayerRow
@onready var _message_box: RichTextLabel = $MessageBox
@onready var _action_menu: VBoxContainer = $ActionArea/ActionMenu
@onready var _actor_label: Label = $ActionArea/ActionMenu/ActorLabel
@onready var _move_buttons: Array[Button] = [
	$ActionArea/ActionMenu/MoveButton0,
	$ActionArea/ActionMenu/MoveButton1,
	$ActionArea/ActionMenu/MoveButton2,
	$ActionArea/ActionMenu/MoveButton3,
]
@onready var _target_menu: VBoxContainer = $ActionArea/TargetMenu
@onready var _target_actor_label: Label = $ActionArea/TargetMenu/TargetActorLabel


const _CombatantHUD := preload("res://engine/battle/view/CombatantHUD.tscn")

var _config: BattleConfig
var _huds: Dictionary = {}        # actor_id -> CombatantHUD
var _actor_names: Dictionary = {} # actor_id -> display_name String
var _current_actor_id: String = ""
var _pending_target_ids: Array[String] = []
var _current_available_moves: Array = []
var _is_atb: bool = false


func _ready() -> void:
	_action_menu.hide()
	_target_menu.hide()

	_config = ConfigLoader.load_battle_config(config_id)
	if _config == null:
		push_error("BattleScene: could not load battle config '%s'" % config_id)
		return

	_is_atb = _config.style == BattleConfig.CombatStyle.ATB_NVM

	_connect_signals()
	_start_battle()


func _connect_signals() -> void:
	EventBus.battle_nvm_initialized.connect(_on_battle_nvm_initialized)
	EventBus.battle_move_used.connect(_on_move_used)
	EventBus.battle_damage_dealt_keyed.connect(_on_damage_dealt_keyed)
	EventBus.battle_hp_restored_keyed.connect(_on_hp_restored_keyed)
	EventBus.battle_stat_changed.connect(_on_stat_changed)
	EventBus.battle_monster_fainted.connect(_on_monster_fainted)
	EventBus.battle_waiting_for_input.connect(_on_waiting_for_input)
	EventBus.battle_needs_target.connect(_on_needs_target)
	EventBus.battle_ended.connect(_on_battle_ended)
	if _is_atb:
		EventBus.battle_gauge_updated.connect(_on_gauge_updated)
		EventBus.battle_action_started.connect(_on_action_started)
	else:
		EventBus.battle_turn_advanced.connect(_on_turn_advanced)

	for i: int in range(_move_buttons.size()):
		_move_buttons[i].pressed.connect(_on_move_button_pressed.bind(i))


func _start_battle() -> void:
	var player_team: Array[MonsterInstance] = []
	for monster_id: String in _config.player_monster_ids:
		var cfg: MonsterConfig = ConfigLoader.load_monster(monster_id)
		if cfg == null:
			push_error("BattleScene: could not load monster '%s'" % monster_id)
			return
		player_team.append(MonsterInstance.create(cfg, _config.monster_level))

	var enemy_team: Array[MonsterInstance] = []
	for monster_id: String in _config.enemy_monster_ids:
		var cfg: MonsterConfig = ConfigLoader.load_monster(monster_id)
		if cfg == null:
			push_error("BattleScene: could not load monster '%s'" % monster_id)
			return
		enemy_team.append(MonsterInstance.create(cfg, _config.monster_level))

	var bm_style: BattleManager.CombatStyle
	match _config.style:
		BattleConfig.CombatStyle.TURN_BASED_NVM:
			bm_style = BattleManager.CombatStyle.TURN_BASED_NVM_INTERACTIVE
		BattleConfig.CombatStyle.ATB_NVM:
			bm_style = BattleManager.CombatStyle.ATB_NVM_INTERACTIVE
		_:
			push_error("BattleScene: unhandled CombatStyle %d" % _config.style)
			return

	BattleManager.start_battle(bm_style, [player_team, enemy_team])


# --- EventBus handlers ---

func _on_battle_nvm_initialized(
	player_names: Array, player_max_hps: Array,
	enemy_names: Array, enemy_max_hps: Array
) -> void:
	# Clear leftover HUDs from any previous battle
	for child: Node in _enemy_row.get_children():
		child.queue_free()
	for child: Node in _player_row.get_children():
		child.queue_free()
	_huds.clear()
	_actor_names.clear()

	for i: int in range(enemy_names.size()):
		var actor_id: String = "enemy_" + str(i)
		var hud: CombatantHUD = _CombatantHUD.instantiate() as CombatantHUD
		_enemy_row.add_child(hud)
		hud.setup(actor_id, str(enemy_names[i]), int(enemy_max_hps[i]), _is_atb)
		_huds[actor_id] = hud
		_actor_names[actor_id] = str(enemy_names[i])

	for i: int in range(player_names.size()):
		var actor_id: String = "player_" + str(i)
		var hud: CombatantHUD = _CombatantHUD.instantiate() as CombatantHUD
		_player_row.add_child(hud)
		hud.setup(actor_id, str(player_names[i]), int(player_max_hps[i]), _is_atb)
		_huds[actor_id] = hud
		_actor_names[actor_id] = str(player_names[i])

	_message_box.text = ""
	var style_label: String = "ATB" if _is_atb else "Turn-based"
	var p_parts: PackedStringArray = []
	for n: Variant in player_names:
		p_parts.append(str(n))
	var e_parts: PackedStringArray = []
	for n: Variant in enemy_names:
		e_parts.append(str(n))
	_append_message("[%s] %s  vs  %s" % [style_label, " & ".join(p_parts), " & ".join(e_parts)])
	if _is_atb:
		_append_message("Gauges filling — act when your bar is full!")


func _on_turn_advanced(turn_num: int) -> void:
	_append_message("\n[Turn %d]" % turn_num)


func _on_action_started(actor_id: String) -> void:
	var name: String = _actor_names.get(actor_id, actor_id)
	_append_message("\n» %s's ATB gauge is full!" % name)


func _on_gauge_updated(actor_id: String, value: float) -> void:
	var hud: CombatantHUD = _huds.get(actor_id, null) as CombatantHUD
	if hud != null:
		hud.update_atb(value)


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
	_current_available_moves = available_moves.duplicate()
	var actor_display: String = _actor_names.get(actor_id, actor_id)
	_actor_label.text = "%s — choose a move:" % actor_display

	for i: int in range(_move_buttons.size()):
		if i < available_moves.size():
			_move_buttons[i].text = (available_moves[i] as MoveOption).display_name
			_move_buttons[i].show()
		else:
			_move_buttons[i].hide()

	# Highlight the active combatant
	_set_active_hud(actor_id)
	_action_menu.show()
	_target_menu.hide()


func _on_needs_target(actor_id: String, valid_target_ids: Array[String]) -> void:
	_current_actor_id = actor_id
	_pending_target_ids = valid_target_ids
	var actor_display: String = _actor_names.get(actor_id, actor_id)
	_target_actor_label.text = "%s — choose a target:" % actor_display

	# Remove old dynamic target buttons
	for child: Node in _target_menu.get_children():
		if child != _target_actor_label:
			child.queue_free()

	# Create one button per valid target
	for i: int in range(valid_target_ids.size()):
		var target_id: String = valid_target_ids[i]
		var btn: Button = Button.new()
		btn.text = _actor_names.get(target_id, target_id)
		btn.pressed.connect(_on_target_button_pressed.bind(i))
		_target_menu.add_child(btn)

	_action_menu.hide()
	_target_menu.show()


func _on_move_button_pressed(idx: int) -> void:
	_action_menu.hide()
	if idx < _current_available_moves.size():
		BattleManager.submit_player_action(
			_current_actor_id,
			(_current_available_moves[idx] as MoveOption).move_id
		)


func _on_target_button_pressed(idx: int) -> void:
	_target_menu.hide()
	if idx < _pending_target_ids.size():
		BattleManager.submit_player_target(_current_actor_id, _pending_target_ids[idx])
	_set_active_hud("")


func _on_battle_ended(winner_name: String, _loser_name: String, count: int) -> void:
	_action_menu.hide()
	_target_menu.hide()
	_set_active_hud("")
	var label: String = "actions" if _is_atb else "turns"
	if winner_name.is_empty() or winner_name == "(draw)":
		_append_message("\n=== DRAW after %d %s ===" % [count, label])
	else:
		_append_message("\n=== %s WINS after %d %s ===" % [winner_name, count, label])


# --- Private helpers ---

func _append_message(text: String) -> void:
	_message_box.text += text + "\n"


func _refresh_hp(actor_id: String, hp: int, max_hp: int) -> void:
	var hud: CombatantHUD = _huds.get(actor_id, null) as CombatantHUD
	if hud != null:
		hud.update_hp(hp, max_hp)


func _set_active_hud(actor_id: String) -> void:
	for id: String in _huds:
		(_huds[id] as CombatantHUD).set_active(id == actor_id)
