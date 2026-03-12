extends RefCounted
## Central registry mapping recipe names to generator functions.
##
## This is the single file a developer edits to register a new recipe.
##
## ─── HOW TO ADD A NEW RECIPE ────────────────────────────────────────────────
##
##  1. Choose or create a Recipes file under generator/recipes/ that matches
##     the kind of content you are generating (e.g. StatBlockRecipes.gd,
##     MonsterRecipes.gd). The file should contain only static functions.
##
##  2. Add a static function to that file:
##
##       static func my_recipe(rng: RandomNumberGenerator) -> Resource:
##           var factory := _SomeFactory.new(rng)
##           return factory.build_something(...)
##
##     The signature must be exactly (rng: RandomNumberGenerator) -> Resource.
##     Hard-coded parameters are intentional — a recipe captures a specific,
##     repeatable configuration, not a general-purpose factory call.
##
##  3. Add a preload for the Recipes file at the top of get_all() if it is
##     not already there (see the existing _StatBlockRecipes example).
##
##  4. Add an entry to the returned dictionary in get_all():
##
##       "my_recipe_name": {
##           "func": func(rng: RandomNumberGenerator) -> Resource:
##               return _StatBlockRecipes.my_recipe(rng),
##           "description": "One-line description shown in --list-recipes.",
##       },
##
##     Recipe names should follow the pattern: <content_type>_<profile>_<archetype>
##     e.g. "stat_pokemon_tank", "monster_fire_zone_grunt".
##
## ─── DESIGN DIRECTION ───────────────────────────────────────────────────────
##
##  Recipes are currently hard-coded functions. The intended long-term direction
##  is to promote them to GeneratorRecipe .tres config files — a schema object
##  storing factory name, parameters, and defaults — loaded from content/.
##  Keep that future shape in mind: each recipe function should be a thin,
##  readable wrapper around factory calls, not a blob of logic.
##
## ────────────────────────────────────────────────────────────────────────────


## Returns the full recipe registry.
## Keys are recipe name strings. Each value is a Dictionary with:
##   "func":        Callable  — signature (rng: RandomNumberGenerator) -> Resource
##   "description": String    — one line, shown in --list-recipes output
const _StatBlockRecipes = preload("res://generator/recipes/StatBlockRecipes.gd")


static func get_all() -> Dictionary:
	return {
		# ── Stat blocks: Pokemon profile ──────────────────────────────────────
		"stat_pokemon_balanced": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _StatBlockRecipes.pokemon_balanced(rng),
			"description": "Pokemon stat block, Gaussian distribution (500 pts).",
		},
		"stat_pokemon_tank": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _StatBlockRecipes.pokemon_tank(rng),
			"description": "Pokemon stat block, tank archetype (high HP + DEF, low SPD).",
		},
		"stat_pokemon_glass_cannon": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _StatBlockRecipes.pokemon_glass_cannon(rng),
			"description": "Pokemon stat block, glass cannon (high ATK, low DEF and HP).",
		},
		"stat_pokemon_speedster": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _StatBlockRecipes.pokemon_speedster(rng),
			"description": "Pokemon stat block, speedster (high SPD + ATK, low DEF).",
		},
		"stat_pokemon_support": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _StatBlockRecipes.pokemon_support(rng),
			"description": "Pokemon stat block, support archetype (high MDEF + SPIRIT, low ATK).",
		},
		"stat_pokemon_accented": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _StatBlockRecipes.pokemon_accented(rng),
			"description": "Pokemon stat block, tank base with one random secondary strength.",
		},

		# ── Stat blocks: Final Fantasy simplified profile ──────────────────────
		"stat_ff_balanced": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _StatBlockRecipes.ff_balanced(rng),
			"description": "FF-simple stat block, Gaussian distribution (600 pts).",
		},
		"stat_ff_tank": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _StatBlockRecipes.ff_tank(rng),
			"description": "FF-simple stat block, tank archetype.",
		},

		# ── Stat blocks: other profiles ────────────────────────────────────────
		"stat_fire_emblem_balanced": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _StatBlockRecipes.fire_emblem_balanced(rng),
			"description": "Fire Emblem stat block, Gaussian distribution (350 pts).",
		},
		"stat_diablo_balanced": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _StatBlockRecipes.diablo_balanced(rng),
			"description": "Diablo primary stat block, Gaussian distribution (100 pts).",
		},
	}
