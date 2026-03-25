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
# Each entry targets one FSM node and may supply an override, pre-hook, post-hook, and args.
# Moves with no exotic behavior leave this array empty.
@export var node_overrides: Array[NodeOverrideEntry] = []

# --- Edge override fields (Tier 3 loop/branch injection) ---
# Each entry injects a custom FSM edge (conditional or unconditional).
# Used for multi-hit loops and other non-linear pipeline structures.
@export var edge_overrides: Array[EdgeOverrideEntry] = []

# --- Effect arrays ---
@export var pre_effects: Array[EffectEntry] = []
@export var post_effects: Array[EffectEntry] = []

# --- Action-space tags ---
## Designer-assigned string tags (e.g. "magic", "physical") used for move denial matching.
## Marked Array (untyped) for .tres compatibility — treat as Array[String].
@export var move_tags: Array = []


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
		"node_overrides": _serialize_overrides(),
		"edge_overrides": _serialize_edge_overrides(),
		"pre_effects": pre_arr,
		"post_effects": post_arr,
		"move_tags": move_tags.duplicate(),
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
	var raw_overrides: Array = data.get("node_overrides", []) as Array
	for d: Dictionary in raw_overrides:
		m.node_overrides.append(NodeOverrideEntry.deserialize(d))
	var raw_edge_overrides: Array = data.get("edge_overrides", []) as Array
	for d: Dictionary in raw_edge_overrides:
		m.edge_overrides.append(EdgeOverrideEntry.deserialize(d))
	var raw_pre: Array = data.get("pre_effects", []) as Array
	for d: Dictionary in raw_pre:
		m.pre_effects.append(EffectEntry.deserialize(d))
	var raw_post: Array = data.get("post_effects", []) as Array
	for d: Dictionary in raw_post:
		m.post_effects.append(EffectEntry.deserialize(d))
	m.move_tags = data.get("move_tags", []).duplicate()
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
	move_tags = data.get("move_tags", move_tags)


func deep_copy() -> MoveConfig:
	return MoveConfig.deserialize(serialize())


func _serialize_overrides() -> Array:
	var arr: Array = []
	for e: NodeOverrideEntry in node_overrides:
		arr.append(e.serialize())
	return arr


func _serialize_edge_overrides() -> Array:
	var arr: Array = []
	for e: EdgeOverrideEntry in edge_overrides:
		arr.append(e.serialize())
	return arr
