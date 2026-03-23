extends RefCounted
## Move recipes — one static function per move, registered in GeneratorRegistry.
##
## Each function is a thin wrapper: it picks one tier from a family definition.
## All design intent (power scaling, effects, naming) lives in the family
## params object, not spread across individual functions.
##
## Adding a new family:
##   1. Define a static _<family>_params() function returning a FamilyParams.
##   2. Add one recipe function per tier that calls Persona.build(params, tier).
##   3. Register each recipe in GeneratorRegistry.gd.
##
## Each function matches the registry signature:
##   static func <name>(rng: RandomNumberGenerator) -> Resource

const _Persona    = preload("res://generator/moves/families/Persona.gd")
const _MoveFactory = preload("res://generator/moves/MoveFactory.gd")


# ── Scratch series (physical, NORMAL) ─────────────────────────────────────────
# Persona-style tier progression: escalating power/crit, decreasing PP.
# Uses explicit tier overrides (tier_powers etc.) to pin the exact design values
# rather than relying purely on LERP.

static func _scratch_params() -> Persona.FamilyParams:
	var p := Persona.FamilyParams.new()
	p.tier_names = ["Scratch", "Rake", "Rend"]
	p.tier_ids   = ["scratch_i", "scratch_ii", "scratch_iii"]
	p.type_tag       = TypeTag.Type.NORMAL
	p.damage_formula = _MoveFactory.PHYSICAL_FORMULA
	p.tier_powers    = [40, 65, 100]
	p.tier_pps       = [35, 20, 10]
	p.tier_accuracies = [1.0, 1.0, 0.9]
	p.crit_rate_formulas = ["", "0.125", "0.25"]
	var rend_fx: Array[EffectEntry] = [
		_MoveFactory.make_condition_effect("defense_down_1", 0.2)
	]
	p.post_effects_by_tier = [[], [], rend_fx]
	return p


## Scratch — Tier I physical attack.
## 40 power · 35 PP · 100 % accuracy · default crit (1/16).
static func scratch_i(rng: RandomNumberGenerator) -> Resource:
	return _Persona.build(_scratch_params(), 0)


## Rake — Tier II physical attack.
## 65 power · 20 PP · 100 % accuracy · elevated crit (1/8).
static func scratch_ii(rng: RandomNumberGenerator) -> Resource:
	return _Persona.build(_scratch_params(), 1)


## Rend — Tier III physical attack.
## 100 power · 10 PP · 90 % accuracy · high crit (1/4) · 20 % defense-down.
static func scratch_iii(rng: RandomNumberGenerator) -> Resource:
	return _Persona.build(_scratch_params(), 2)


# ── Zio series (special, ELECTRIC, single target) ─────────────────────────────
# Pure Persona-style: prefix "Zio" + suffixes, full LERP, no overrides needed.
# Power: 40 → 160.  PP: 15 → 5.  Accuracy: constant 1.0.

static func _zio_params() -> Persona.FamilyParams:
	var p := Persona.FamilyParams.new()
	p.set_names_from_affixes("Zio", ["", "nga", "dyne"])
	p.type_tag       = TypeTag.Type.ELECTRIC
	p.damage_formula = _MoveFactory.SPECIAL_FORMULA
	p.start_power = 40;   p.end_power = 160
	p.start_pp    = 15;   p.end_pp    = 5
	return p


## Zio — Tier I electric spell. Light damage, single target.
static func zio(rng: RandomNumberGenerator) -> Resource:
	return _Persona.build(_zio_params(), 0)


## Zionga — Tier II electric spell. Medium damage, single target.
static func zionga(rng: RandomNumberGenerator) -> Resource:
	return _Persona.build(_zio_params(), 1)


## Ziodyne — Tier III electric spell. Heavy damage, single target.
static func ziodyne(rng: RandomNumberGenerator) -> Resource:
	return _Persona.build(_zio_params(), 2)
