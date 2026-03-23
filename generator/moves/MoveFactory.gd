class_name MoveFactory
extends RefCounted
## Factory for generating MoveConfig resources.
##
## Provides named build methods for each broad move category (physical, special,
## status, heal). Each method has reasonable defaults — override only what
## differs per move.
##
## Usage:
##   var factory := MoveFactory.new()
##   var m := factory.build_physical_attack("scratch_i", "Scratch")
##   # with overrides:
##   var m2 := factory.build_physical_attack("rake", "Rake", 65, 1.0, 20)

## Damage formula constants — referenced by build methods and usable by recipes
## when defining move families.
const PHYSICAL_FORMULA := "move_power * caster.attack / target.defense"
const SPECIAL_FORMULA  := "move_power * caster.special_attack / target.special_defense"

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


## Creates a single EffectEntry for applying a condition.
## Reduces the boilerplate of constructing an EffectEntry manually.
##
## p_condition_id — id of the ConditionConfig to apply (e.g. "burn", "defense_down_1")
## p_chance       — [0.0–1.0] probability the effect triggers (default 1.0)
## p_target       — "target" or "caster" (default "target")
static func make_condition_effect(
	p_condition_id: String,
	p_chance: float = 1.0,
	p_target: String = "target"
) -> EffectEntry:
	var fx := EffectEntry.new()
	fx.condition_id = p_condition_id
	fx.chance = p_chance
	fx.target = p_target
	return fx


## Physical attack — damage uses the attack / defense formula.
##
## p_move_power        — base power fed into the damage formula (default 40)
## p_accuracy          — [0.0–1.0] hit chance; 1.0 = always lands (default)
## p_pp                — max uses before PP is exhausted (default 20)
## p_type_tag          — TypeTag.Type enum value (default NORMAL)
## p_post_effects      — Array[EffectEntry] applied after damage resolves (default none)
## p_crit_rate_formula — Expression string overriding the default 1/16 crit rate;
##                       "" = use engine default (default none)
func build_physical_attack(
	p_id: String,
	p_display_name: String,
	p_move_power: int = 40,
	p_accuracy: float = 1.0,
	p_pp: int = 20,
	p_type_tag: int = TypeTag.Type.NORMAL,
	p_post_effects: Array[EffectEntry] = [],
	p_crit_rate_formula: String = ""
) -> MoveConfig:
	return build_from_formula(
		p_id, p_display_name, PHYSICAL_FORMULA,
		p_move_power, p_accuracy, p_pp, p_type_tag, p_post_effects, p_crit_rate_formula
	)


## Special attack — damage uses the special_attack / special_defense formula.
## Same parameters as build_physical_attack.
func build_special_attack(
	p_id: String,
	p_display_name: String,
	p_move_power: int = 40,
	p_accuracy: float = 1.0,
	p_pp: int = 20,
	p_type_tag: int = TypeTag.Type.NORMAL,
	p_post_effects: Array[EffectEntry] = [],
	p_crit_rate_formula: String = ""
) -> MoveConfig:
	return build_from_formula(
		p_id, p_display_name, SPECIAL_FORMULA,
		p_move_power, p_accuracy, p_pp, p_type_tag, p_post_effects, p_crit_rate_formula
	)


## Generic damage move with an explicit formula string.
## Use this when the formula is determined externally (e.g. by a family generator).
## Prefer build_physical_attack or build_special_attack for the standard cases.
func build_from_formula(
	p_id: String,
	p_display_name: String,
	p_formula: String,
	p_move_power: int = 40,
	p_accuracy: float = 1.0,
	p_pp: int = 20,
	p_type_tag: int = TypeTag.Type.NORMAL,
	p_post_effects: Array[EffectEntry] = [],
	p_crit_rate_formula: String = ""
) -> MoveConfig:
	var move := MoveConfig.new()
	move.id = p_id
	move.display_name = p_display_name
	move.move_power = p_move_power
	move.accuracy = p_accuracy
	move.pp = p_pp
	move.type_tag = p_type_tag
	move.target_mode = MoveConfig.TargetType.SINGLE_ENEMY
	move.damage_formula = p_formula
	move.post_effects = p_post_effects
	move.crit_rate_formula = p_crit_rate_formula
	return move


## Status move — no damage; applies conditions or field effects via post_effects.
##
## p_target_mode — TargetType enum value (default SINGLE_ENEMY)
## p_post_effects — Array[EffectEntry] defining what the move does (default none)
func build_status(
	p_id: String,
	p_display_name: String,
	p_accuracy: float = 1.0,
	p_pp: int = 20,
	p_type_tag: int = TypeTag.Type.NORMAL,
	p_target_mode: int = MoveConfig.TargetType.SINGLE_ENEMY,
	p_post_effects: Array[EffectEntry] = []
) -> MoveConfig:
	var move := MoveConfig.new()
	move.id = p_id
	move.display_name = p_display_name
	move.move_power = 0
	move.accuracy = p_accuracy
	move.pp = p_pp
	move.type_tag = p_type_tag
	move.target_mode = p_target_mode
	move.post_effects = p_post_effects
	return move


## Heal move — restores HP to self; always hits.
##
## p_heal_fraction — fraction of max_hp to restore, e.g. 0.5 = 50% (default)
## p_pp            — max uses (default 10)
func build_heal(
	p_id: String,
	p_display_name: String,
	p_heal_fraction: float = 0.5,
	p_pp: int = 10
) -> MoveConfig:
	var move := MoveConfig.new()
	move.id = p_id
	move.display_name = p_display_name
	move.move_power = 0
	move.accuracy = 1.0
	move.pp = p_pp
	move.type_tag = TypeTag.Type.NORMAL
	move.target_mode = MoveConfig.TargetType.SELF
	move.accuracy_node = "always_hit"
	move.heal_formula = "target.max_hp * %s" % str(p_heal_fraction)
	return move
