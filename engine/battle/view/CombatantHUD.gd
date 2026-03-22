class_name CombatantHUD
extends VBoxContainer
## Reusable HUD panel for a single combatant: name, HP bar, and optional ATB gauge.
## Instantiated dynamically by BattleScene for each team member.

@onready var _name_label: Label = $NameLabel
@onready var _hp_bar: ProgressBar = $HPBar
@onready var _hp_text: Label = $HPText
@onready var _atb_container: VBoxContainer = $ATBContainer
@onready var _atb_bar: ProgressBar = $ATBContainer/ATBBar

## The actor_id this HUD tracks (e.g. "player_0", "enemy_2").
var actor_id: String = ""


## Initialize this HUD for a combatant. Call once after adding to the scene tree.
func setup(p_actor_id: String, display_name: String, max_hp: int, show_atb: bool) -> void:
	actor_id = p_actor_id
	_name_label.text = display_name
	_hp_bar.max_value = max_hp
	_hp_bar.value = max_hp
	_hp_text.text = "%d / %d" % [max_hp, max_hp]
	_atb_container.visible = show_atb


## Update the HP bar and text. Call on damage_dealt_keyed / hp_restored_keyed.
func update_hp(hp: int, max_hp: int) -> void:
	_hp_bar.value = hp
	_hp_text.text = "%d / %d" % [hp, max_hp]


## Update the ATB gauge fill (0–100). Only visible when show_atb was true in setup().
func update_atb(value: float) -> void:
	_atb_bar.value = value


## Highlight this panel when it is the active actor (gauge full / waiting for input).
func set_active(active: bool) -> void:
	modulate = Color(1.0, 0.95, 0.4) if active else Color.WHITE
