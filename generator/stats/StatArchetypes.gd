class_name StatArchetypes
extends RefCounted
## Pre-built bias dictionaries for common JRPG monster archetypes.
## Each static method returns a Dictionary ready for StatBlockFactory.build_authored().
## Keys are StatName string constants; values are StatBiasEntry instances.
##
## These are starting points, not final answers. Compose them with
## add_random_accent() to add per-creature variation, or merge them manually
## to create zone-specific hybrids (e.g. a fast tank for a mid-game swamp boss).
##
## --- Simple usage ---
##
##   var block: GenericStatBlock = factory.build_authored(
##       StatProfiles.POKEMON, 300.0, StatArchetypes.tank()
##   )
##
## --- Zone composition pattern ---
##
##   Every monster in a zone shares a base archetype; each creature gets one
##   random secondary accent drawn from a curated pool. This gives the zone a
##   consistent identity while keeping individual creatures distinct.
##
##   # Swamp zone: all creatures are defense-heavy and slow.
##   # Each creature also randomly excels at HP, ATTACK, or MAGIC.
##   var swamp_base: Dictionary[String, StatBiasEntry] = {
##       StatName.DEFENSE: StatArchetypes._b(2.5, 1),   # always highest stat
##       StatName.SPEED:   StatArchetypes._b(0.3, -1),  # always lowest stat
##   }
##   var biases: Dictionary[String, StatBiasEntry] = factory.add_random_accent(
##       swamp_base, [StatName.HP, StatName.ATTACK, StatName.MAGIC], 1.5
##   )
##   var stats: GenericStatBlock = factory.build_authored(StatProfiles.POKEMON, 300.0, biases)
##
##   # Swamp boss twist: unusually fast for the zone, defense still dominant,
##   # tighter variance so the boss stats feel more intentional.
##   var boss_biases: Dictionary[String, StatBiasEntry] = {
##       StatName.DEFENSE: StatArchetypes._b(3.0, 1),
##       StatName.SPEED:   StatArchetypes._b(2.0, 2),  # fast, but not the highest stat
##   }
##   var boss: GenericStatBlock = factory.build_authored(
##       StatProfiles.POKEMON, 500.0, boss_biases, 0.05  # std_dev_factor=0.05 = tight
##   )


## Tough, slow creature: highest HP, second-highest defense, lowest speed.
static func tank() -> Dictionary[String, StatBiasEntry]:
	return {
		StatName.HP: _b(2.0, 1),
		StatName.DEFENSE: _b(2.0, 2),
		StatName.SPEED: _b(0.4, -1),
	}


## Fragile, powerful attacker: highest attack, lowest defense, below-average HP.
static func glass_cannon() -> Dictionary[String, StatBiasEntry]:
	return {
		StatName.ATTACK: _b(3.0, 1),
		StatName.DEFENSE: _b(0.3, -1),
		StatName.HP: _b(0.5),
	}


## Fast damage dealer: highest speed, second-highest attack, lowest defense.
static func speedster() -> Dictionary[String, StatBiasEntry]:
	return {
		StatName.SPEED: _b(2.5, 1),
		StatName.ATTACK: _b(1.2, 2),
		StatName.DEFENSE: _b(0.4, -1),
	}


## Magical support: highest magic defense, second-highest spirit, lowest attack.
static func support() -> Dictionary[String, StatBiasEntry]:
	return {
		StatName.MAGIC_DEFENSE: _b(2.0, 1),
		StatName.SPIRIT: _b(1.8, 2),
		StatName.ATTACK: _b(0.3, -1),
	}


## No bias — purely Gaussian distribution. Equivalent to build_gaussian_total.
static func balanced() -> Dictionary[String, StatBiasEntry]:
	return {}


static func _b(
	weight: float, rank: int = 0, min_val: float = -INF, max_val: float = INF
) -> StatBiasEntry:
	return StatBiasEntry.new(weight, rank, min_val, max_val)
