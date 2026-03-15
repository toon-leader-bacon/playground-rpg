class_name MoveConfig
extends Resource

## Effect determines what action a move triggers beyond raw damage.
## Extend this enum as new move effects are implemented in the battle system.
enum Effect {
	NONE,                  # Default: no special effect. power > 0 = direct damage.
	HEAL,                  # Restores caster HP equal to power.
	BUFF_SPEED_SELF,       # +1 speed stage to caster.
	DEBUFF_SPEED_TARGET,   # -1 speed stage to target.
	# Future: POISON, BURN, SLEEP, PARALYSIS, FREEZE,
	# STAT_BUFF_ATK, STAT_BUFF_DEF,
	# STAT_DEBUFF_ATK, STAT_DEBUFF_DEF,
	# SELF_DESTRUCT, MULTI_HIT, CHARGING, COUNTER
}

## TargetType declares who a move is allowed to target.
## Used by PlayerController and AI to resolve valid targets before submission.
enum TargetType {
	SINGLE_ENEMY,  # Targets one opponent (default).
	SINGLE_ALLY,   # Targets one teammate.
	SELF,          # Always targets the caster; no targeting UI shown.
}

@export var id: String = ""
@export var display_name: String = ""
@export var type_tag: int = TypeTag.Type.NORMAL       # TypeTag.Type value
@export var power: int = 0                             # damage power (NONE), or HP restored (HEAL)
@export var accuracy: float = 1.0
@export var effect: Effect = Effect.NONE
@export var target_type: int = TargetType.SINGLE_ENEMY


func serialize() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"type_tag": type_tag,
		"power": power,
		"accuracy": accuracy,
		"effect": effect,
		"target_type": target_type,
	}


static func deserialize(data: Dictionary) -> MoveConfig:
	var m := MoveConfig.new()
	m.id = data.get("id", "")
	m.display_name = data.get("display_name", "")
	m.type_tag = data.get("type_tag", TypeTag.Type.NORMAL)
	m.power = data.get("power", 0)
	m.accuracy = data.get("accuracy", 1.0)
	m.effect = data.get("effect", Effect.NONE) as MoveConfig.Effect
	m.target_type = data.get("target_type", TargetType.SINGLE_ENEMY)
	return m


func deserialize_update(data: Dictionary) -> void:
	id = data.get("id", id)
	display_name = data.get("display_name", display_name)
	type_tag = data.get("type_tag", type_tag)
	power = data.get("power", power)
	accuracy = data.get("accuracy", accuracy)
	effect = data.get("effect", effect) as MoveConfig.Effect
	target_type = data.get("target_type", target_type)


func deep_copy() -> MoveConfig:
	return MoveConfig.deserialize(serialize())
