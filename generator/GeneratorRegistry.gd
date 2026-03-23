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
const _MoveRecipes = preload("res://generator/recipes/MoveRecipes.gd")
const _MoveExamplesRecipes = preload("res://generator/recipes/MoveExamplesRecipes.gd")


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

		# ── Move recipes: scratch series (physical, NORMAL) ───────────────────
		"move_scratch_i": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveRecipes.scratch_i(rng),
			"description": "Scratch — Tier I physical attack (40 power, 35 PP, default crit).",
		},
		"move_scratch_ii": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveRecipes.scratch_ii(rng),
			"description": "Rake — Tier II physical attack (65 power, 20 PP, elevated crit).",
		},
		"move_scratch_iii": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveRecipes.scratch_iii(rng),
			"description": "Rend — Tier III physical attack (100 power, 10 PP, high crit, defense-down).",
		},

		# ── Move recipes: Zio series (special, ELECTRIC, single target) ────────
		"move_zio": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveRecipes.zio(rng),
			"description": "Zio — Tier I electric spell (40 power, 15 PP, single target).",
		},
		"move_zionga": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveRecipes.zionga(rng),
			"description": "Zionga — Tier II electric spell (100 power, 10 PP, single target).",
		},
		"move_ziodyne": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveRecipes.ziodyne(rng),
			"description": "Ziodyne — Tier III electric spell (160 power, 5 PP, single target).",
		},

		# ── Move examples: one recipe per supported design pattern ────────────
		"move_ex_physical_damage": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.physical_damage(rng),
			"description": "Rock Slam — 65 power physical NORMAL (pattern: baseline physical).",
		},
		"move_ex_special_damage": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.special_damage(rng),
			"description": "Fire Blast — 90 power special FIRE, 85% acc, 10% burn (pattern: special + chance effect).",
		},
		"move_ex_self_heal": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.self_heal(rng),
			"description": "Heal — restores 50% max HP; always hits; self target (pattern: self-heal).",
		},
		"move_ex_recoil": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.recoil_move(rng),
			"description": "Brave Bird — 120 power physical AIR; 33% recoil (pattern: recoil damage).",
		},
		"move_ex_always_hit": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.always_hit_move(rng),
			"description": "Swift — 60 power physical; always_hit node (pattern: guaranteed hit).",
		},
		"move_ex_blizzard": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.weather_accuracy_move(rng),
			"description": "Blizzard — 110 power special ICE; 100% in HAIL, 70% default (pattern: weather accuracy).",
		},
		"move_ex_accuracy_down": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.accuracy_down_move(rng),
			"description": "Sand Attack — applies accuracy_down_1 to target (pattern: accuracy debuff).",
		},
		"move_ex_paralysis": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.paralysis_move(rng),
			"description": "Thunder Wave — always hits; applies paralysis (pattern: guaranteed status).",
		},
		"move_ex_sleep": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.sleep_move(rng),
			"description": "Hypnosis — 60% accuracy; applies sleep (pattern: partial-chance status).",
		},
		"move_ex_burn_install": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.burn_install_move(rng),
			"description": "Will-O-Wisp — 85% accuracy; applies burn (pattern: direct burn install).",
		},
		"move_ex_elevated_crit": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.elevated_crit_move(rng),
			"description": "Slash — 70 power; crit_rate_formula = 0.125 (pattern: elevated crit).",
		},
		"move_ex_crit_branch": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.crit_branch_move(rng),
			"description": "Frost Nova — 85 power special ICE; freeze on crit, slow otherwise (pattern: crit branch).",
		},
		"move_ex_reversal": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.hp_inverse_move(rng),
			"description": "Reversal — damage scales inversely with caster HP (pattern: HP-inverse damage).",
		},
		"move_ex_stored_power": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.buff_scale_move(rng),
			"description": "Stored Power — damage scales with caster buff count (pattern: buff scaling).",
		},
		"move_ex_rain_dance": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.weather_set_move(rng),
			"description": "Rain Dance — sets RAIN weather for 5 turns (pattern: weather setter).",
		},
		"move_ex_scald": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.damage_burn_move(rng),
			"description": "Scald — 80 power special WATER; 30% burn (pattern: damage + burn chance).",
		},
		"move_ex_close_combat": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.damage_self_debuff_move(rng),
			"description": "Close Combat — 120 power physical; defense_down + sp_def_down to caster (pattern: self-debuff).",
		},
		"move_ex_speed_up": {
			"func": func(rng: RandomNumberGenerator) -> Resource:
				return _MoveExamplesRecipes.speed_up_move(rng),
			"description": "Quick Step — always hits; speed_up_1 to caster (pattern: self speed buff).",
		},
	}
