class_name Persona
extends RefCounted
## Persona-style move family generator.
##
## Generates a series of moves from a single FamilyParams definition by
## linearly interpolating power, PP, and accuracy across tiers. Per-tier
## overrides let you pin exact values when LERP alone isn't precise enough.
##
## Usage:
##   var p := Persona.FamilyParams.new()
##   p.set_names_from_affixes("Zio", ["", "nga", "dyne"])
##   p.type_tag = TypeTag.Type.ELECTRIC
##   p.damage_formula = MoveFactory.SPECIAL_FORMULA
##   p.start_power = 40;  p.end_power = 160
##   p.start_pp = 15;     p.end_pp = 5
##   var zio: MoveConfig = Persona.build(p, 0)    # "Zio"
##   var ziodyne: MoveConfig = Persona.build(p, 2) # "Ziodyne"

const _MoveFactory = preload("res://generator/moves/MoveFactory.gd")


## ── Typed parameter object ────────────────────────────────────────────────────

class FamilyParams:
	extends RefCounted
	## Typed configuration for one move family.
	## Set required fields, then call Persona.build(params, tier).

	## Display names for each tier, in order (required).
	## Set directly, or use set_names_from_affixes().
	var tier_names: Array[String] = []

	## Content IDs for each tier.
	## If shorter than tier_names, remaining IDs are derived from display names
	## (lowercase, spaces replaced with underscores).
	var tier_ids: Array[String] = []

	## Move type, damage formula, and targeting.
	var type_tag: int = TypeTag.Type.NORMAL
	var damage_formula: String = ""
	var target_mode: int = MoveConfig.TargetType.SINGLE_ENEMY

	## LERP bounds — values are interpolated linearly from start to end across tiers.
	var start_power: int = 40
	var end_power: int = 160
	var start_pp: int = 15
	var end_pp: int = 5
	var start_accuracy: float = 1.0
	var end_accuracy: float = 1.0

	## Optional per-tier overrides — take precedence over LERP when set.
	## Useful for exact values LERP cannot reproduce precisely.
	var tier_powers: Array[int] = []
	var tier_pps: Array[int] = []
	var tier_accuracies: Array[float] = []

	## Per-tier crit rate formula strings. "" = use engine default.
	## Indexed by tier; tiers beyond the array end use the default.
	var crit_rate_formulas: Array[String] = []

	## Per-tier post effects. Each element must be an Array[EffectEntry].
	## Tiers beyond the array end receive no post effects.
	var post_effects_by_tier: Array = []

	## Populates tier_names from a shared prefix + per-tier suffix strings.
	## e.g. set_names_from_affixes("Zio", ["", "nga", "dyne"])
	##      → tier_names = ["Zio", "Zionga", "Ziodyne"]
	func set_names_from_affixes(prefix: String, suffixes: Array[String]) -> void:
		tier_names.clear()
		for suffix: String in suffixes:
			tier_names.append(prefix + suffix)

	func tier_count() -> int:
		return tier_names.size()


## ── Builder ───────────────────────────────────────────────────────────────────

## Builds one MoveConfig for the given tier index.
## tier must be in [0, params.tier_count() - 1].
static func build(params: FamilyParams, tier: int) -> MoveConfig:
	var n: int = params.tier_count()
	assert(n > 0, "Persona.FamilyParams: tier_names is empty")
	assert(tier >= 0 and tier < n,
		"Persona.build: tier %d out of range [0, %d)" % [tier, n])

	var t: float = float(tier) / float(maxi(n - 1, 1))

	var display_name: String = params.tier_names[tier]
	var id: String          = _resolve_id(params, tier, display_name)
	var power: int          = _resolve_int(params.tier_powers, tier,
								roundi(lerpf(params.start_power, params.end_power, t)))
	var pp: int             = _resolve_int(params.tier_pps, tier,
								roundi(lerpf(params.start_pp, params.end_pp, t)))
	var accuracy: float     = _resolve_float(params.tier_accuracies, tier,
								lerpf(params.start_accuracy, params.end_accuracy, t))
	var crit: String        = _resolve_string(params.crit_rate_formulas, tier, "")
	var post_fx: Array[EffectEntry] = _resolve_effects(params.post_effects_by_tier, tier)

	var factory := _MoveFactory.new()
	return factory.build_from_formula(
		id, display_name, params.damage_formula,
		power, accuracy, pp, params.type_tag, post_fx, crit
	)


## ── Private helpers ───────────────────────────────────────────────────────────

static func _resolve_id(params: FamilyParams, tier: int, display_name: String) -> String:
	if tier < params.tier_ids.size() and not params.tier_ids[tier].is_empty():
		return params.tier_ids[tier]
	return display_name.to_lower().replace(" ", "_")


static func _resolve_int(overrides: Array[int], tier: int, default_val: int) -> int:
	if tier < overrides.size():
		return overrides[tier]
	return default_val


static func _resolve_float(overrides: Array[float], tier: int, default_val: float) -> float:
	if tier < overrides.size():
		return overrides[tier]
	return default_val


static func _resolve_string(overrides: Array[String], tier: int, default_val: String) -> String:
	if tier < overrides.size():
		return overrides[tier]
	return default_val


static func _resolve_effects(by_tier: Array, tier: int) -> Array[EffectEntry]:
	var result: Array[EffectEntry] = []
	if tier < by_tier.size():
		for entry: Variant in by_tier[tier]:
			result.append(entry as EffectEntry)
	return result
