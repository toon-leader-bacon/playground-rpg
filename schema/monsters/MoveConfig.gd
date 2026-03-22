class_name MoveConfig
extends Resource

## TargetType declares who a move is allowed to target.
## Used by PlayerController and AI to resolve valid targets before submission.
enum TargetType {
	SINGLE_ENEMY,  # Targets one opponent (default).
	SINGLE_ALLY,   # Targets one teammate.
	SELF,          # Always targets the caster; no targeting UI shown.
}

@export var id: String = ""
@export var display_name: String = ""
@export var type_tag: int = TypeTag.Type.NORMAL    # TypeTag.Type value
@export var move_power: int = 0                    # base power fed into damage/heal formulas
@export var accuracy: float = 1.0                  # 0.0–1.0; -1 = always hits (skip roll)
@export var pp: int = 10                           # max PP
@export var target_mode: int = TargetType.SINGLE_ENEMY

# --- Formula fields (Tier 1 / Tier 2) ---
@export var damage_formula: String = ""            # Expression; variables: move_power, caster.*, target.*
@export var heal_formula: String = ""              # Expression; heals actor/self
@export var crit_rate_formula: String = ""         # Expression override; default = 1/16

# --- Node override fields (Tier 3 escape hatches) ---
@export var accuracy_node: String = ""             # Tag in NodeRegistry; replaces ACCURACY_CHECK
@export var accuracy_node_arguments: Array = []    # Arguments passed to accuracy node

@export var damage_node: String = ""               # Tag in NodeRegistry; replaces default damage calc
@export var damage_args: Dictionary = {}           # Arguments for damage_node

# --- Effect arrays ---
@export var pre_effects: Array[EffectEntry] = []
@export var post_effects: Array[EffectEntry] = []


func serialize() -> Dictionary:
	var pre_arr: Array = []
	for e: EffectEntry in pre_effects:
		pre_arr.append(e.serialize())
	var post_arr: Array = []
	for e: EffectEntry in post_effects:
		post_arr.append(e.serialize())
	return {
		"id": id,
		"display_name": display_name,
		"type_tag": type_tag,
		"move_power": move_power,
		"accuracy": accuracy,
		"pp": pp,
		"target_mode": target_mode,
		"damage_formula": damage_formula,
		"heal_formula": heal_formula,
		"crit_rate_formula": crit_rate_formula,
		"accuracy_node": accuracy_node,
		"accuracy_node_arguments": accuracy_node_arguments.duplicate(),
		"damage_node": damage_node,
		"damage_args": damage_args.duplicate(),
		"pre_effects": pre_arr,
		"post_effects": post_arr,
	}


static func deserialize(data: Dictionary) -> MoveConfig:
	var m := MoveConfig.new()
	m.id = data.get("id", "")
	m.display_name = data.get("display_name", "")
	m.type_tag = data.get("type_tag", TypeTag.Type.NORMAL)
	m.move_power = data.get("move_power", 0)
	m.accuracy = data.get("accuracy", 1.0)
	m.pp = data.get("pp", 10)
	m.target_mode = data.get("target_mode", TargetType.SINGLE_ENEMY)
	m.damage_formula = data.get("damage_formula", "")
	m.heal_formula = data.get("heal_formula", "")
	m.crit_rate_formula = data.get("crit_rate_formula", "")
	m.accuracy_node = data.get("accuracy_node", "")
	var raw_acc_args: Array = data.get("accuracy_node_arguments", []) as Array
	m.accuracy_node_arguments.assign(raw_acc_args)
	m.damage_node = data.get("damage_node", "")
	m.damage_args = (data.get("damage_args", {}) as Dictionary).duplicate()
	var raw_pre: Array = data.get("pre_effects", []) as Array
	for d: Dictionary in raw_pre:
		m.pre_effects.append(EffectEntry.deserialize(d))
	var raw_post: Array = data.get("post_effects", []) as Array
	for d: Dictionary in raw_post:
		m.post_effects.append(EffectEntry.deserialize(d))
	return m


func deserialize_update(data: Dictionary) -> void:
	id = data.get("id", id)
	display_name = data.get("display_name", display_name)
	type_tag = data.get("type_tag", type_tag)
	move_power = data.get("move_power", move_power)
	accuracy = data.get("accuracy", accuracy)
	pp = data.get("pp", pp)
	target_mode = data.get("target_mode", target_mode)
	damage_formula = data.get("damage_formula", damage_formula)
	heal_formula = data.get("heal_formula", heal_formula)
	crit_rate_formula = data.get("crit_rate_formula", crit_rate_formula)
	accuracy_node = data.get("accuracy_node", accuracy_node)
	damage_node = data.get("damage_node", damage_node)


func deep_copy() -> MoveConfig:
	return MoveConfig.deserialize(serialize())
