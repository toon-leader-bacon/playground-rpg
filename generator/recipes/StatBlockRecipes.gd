extends RefCounted
## Stat block recipe functions for the generator CLI.
##
## Each function is a recipe: takes an RNG instance and returns a GenericStatBlock.
## Hard-coded parameters are intentional — the recipe captures a specific,
## repeatable configuration. To add variation, create a new recipe.
##
## ─── HOW TO ADD A NEW STAT BLOCK RECIPE ─────────────────────────────────────
##
##  1. Add a static function below following this exact signature:
##
##       static func my_recipe(rng: RandomNumberGenerator) -> Resource:
##           var factory := _StatBlockFactory.new(rng)
##           return factory.build_something(SomeProfile, ...)
##
##  2. Register it in GeneratorRegistry.gd (see the comment block there).
##
## Useful building blocks:
##   _StatProfiles   — stat name arrays for different JRPG game styles
##   _StatArchetypes — pre-built bias dicts (tank, glass_cannon, speedster, etc.)
##   _StatName       — string constants for individual stat names
##   _StatBlockFactory methods:
##     build_gaussian_total(names, total, std_dev_factor, min_per_stat)
##       → Gaussian spread with exact total sum. Good for generic monsters.
##     build_authored(names, total, biases, std_dev_factor, min_per_stat)
##       → Gaussian + weight/rank/bound constraints. Good for archetyped monsters.
##     add_random_accent(base_biases, candidate_stats, accent_weight)
##       → Copies a bias dict and adds one randomly chosen secondary strength.
##         Use this to give each creature in a zone a unique twist.
##
## ─────────────────────────────────────────────────────────────────────────────

const _StatBlockFactory = preload("res://generator/stats/StatBlockFactory.gd")
const _StatProfiles = preload("res://generator/stats/StatProfiles.gd")
const _StatArchetypes = preload("res://generator/stats/StatArchetypes.gd")
const _StatName = preload("res://schema/stats/StatName.gd")


# ── Pokemon profile (HP / ATK / DEF / SP.ATK / SP.DEF / SPD) ─────────────────

static func pokemon_balanced(rng: RandomNumberGenerator) -> Resource:
	var factory := _StatBlockFactory.new(rng)
	return factory.build_gaussian_total(_StatProfiles.POKEMON, 500.0, 0.10, 5.0)


static func pokemon_tank(rng: RandomNumberGenerator) -> Resource:
	var factory := _StatBlockFactory.new(rng)
	return factory.build_authored(
		_StatProfiles.POKEMON, 500.0, _StatArchetypes.tank(), 0.10, 5.0
	)


static func pokemon_glass_cannon(rng: RandomNumberGenerator) -> Resource:
	var factory := _StatBlockFactory.new(rng)
	return factory.build_authored(
		_StatProfiles.POKEMON, 500.0, _StatArchetypes.glass_cannon(), 0.10, 5.0
	)


static func pokemon_speedster(rng: RandomNumberGenerator) -> Resource:
	var factory := _StatBlockFactory.new(rng)
	return factory.build_authored(
		_StatProfiles.POKEMON, 500.0, _StatArchetypes.speedster(), 0.10, 5.0
	)


static func pokemon_support(rng: RandomNumberGenerator) -> Resource:
	var factory := _StatBlockFactory.new(rng)
	return factory.build_authored(
		_StatProfiles.POKEMON, 500.0, _StatArchetypes.support(), 0.10, 5.0
	)


## Tank base with one randomly chosen secondary strength drawn from
## HP, ATTACK, or SPECIAL_ATTACK. Demonstrates the add_random_accent pattern
## for giving each creature in a zone a unique secondary identity.
static func pokemon_accented(rng: RandomNumberGenerator) -> Resource:
	var factory := _StatBlockFactory.new(rng)
	var biases: Dictionary[String, StatBiasEntry] = factory.add_random_accent(
		_StatArchetypes.tank(),
		[_StatName.HP, _StatName.ATTACK, _StatName.SPECIAL_ATTACK],
		1.5
	)
	return factory.build_authored(_StatProfiles.POKEMON, 500.0, biases, 0.10, 5.0)


# ── Final Fantasy simplified profile (HP / MP / STR / AGI / VIT / MAG / SPI / LCK) ──

static func ff_balanced(rng: RandomNumberGenerator) -> Resource:
	var factory := _StatBlockFactory.new(rng)
	return factory.build_gaussian_total(_StatProfiles.FF_SIMPLE, 600.0, 0.15, 5.0)


static func ff_tank(rng: RandomNumberGenerator) -> Resource:
	var factory := _StatBlockFactory.new(rng)
	return factory.build_authored(
		_StatProfiles.FF_SIMPLE, 600.0, _StatArchetypes.tank(), 0.12, 5.0
	)


# ── Fire Emblem profile (HP / STR / MAG / DEX / SPD / LCK / DEF / RES) ───────

static func fire_emblem_balanced(rng: RandomNumberGenerator) -> Resource:
	var factory := _StatBlockFactory.new(rng)
	return factory.build_gaussian_total(_StatProfiles.FIRE_EMBLEM, 350.0, 0.12, 3.0)


# ── Diablo primary stats (STR / DEX / VIT / INT) ──────────────────────────────

static func diablo_balanced(rng: RandomNumberGenerator) -> Resource:
	var factory := _StatBlockFactory.new(rng)
	return factory.build_gaussian_total(_StatProfiles.DIABLO_PRIMARY, 100.0, 0.10, 5.0)
