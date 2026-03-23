extends GdUnitTestSuite
## Tests for the scratch move series recipes and their generated .tres configs.
##
## Recipe tests verify the MoveConfig values produced by each recipe function.
## Config loading tests verify that the generator output can be loaded through
## ConfigLoader with correct typed values — the integration gate for generator → engine.

const _MoveRecipes = preload("res://generator/recipes/MoveRecipes.gd")


# ── Tier consistency ──────────────────────────────────────────────────────────

func test_scratch_series_power_increases_each_tier() -> void:
	var rng := RandomNumberGenerator.new()
	var i: MoveConfig = _MoveRecipes.scratch_i(rng) as MoveConfig
	var ii: MoveConfig = _MoveRecipes.scratch_ii(rng) as MoveConfig
	var iii: MoveConfig = _MoveRecipes.scratch_iii(rng) as MoveConfig
	assert_int(ii.move_power).is_greater(i.move_power)
	assert_int(iii.move_power).is_greater(ii.move_power)


func test_scratch_series_pp_decreases_each_tier() -> void:
	var rng := RandomNumberGenerator.new()
	var i: MoveConfig = _MoveRecipes.scratch_i(rng) as MoveConfig
	var ii: MoveConfig = _MoveRecipes.scratch_ii(rng) as MoveConfig
	var iii: MoveConfig = _MoveRecipes.scratch_iii(rng) as MoveConfig
	assert_int(ii.pp).is_less(i.pp)
	assert_int(iii.pp).is_less(ii.pp)


# ── Tier I: Scratch ───────────────────────────────────────────────────────────

func test_scratch_i_id_and_name() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_i(RandomNumberGenerator.new()) as MoveConfig
	assert_str(move.id).is_equal("scratch_i")
	assert_str(move.display_name).is_equal("Scratch")


func test_scratch_i_power_and_pp() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_i(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.move_power).is_equal(40)
	assert_int(move.pp).is_equal(35)


func test_scratch_i_full_accuracy() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_i(RandomNumberGenerator.new()) as MoveConfig
	assert_float(move.accuracy).is_equal_approx(1.0, 0.001)


func test_scratch_i_no_crit_override() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_i(RandomNumberGenerator.new()) as MoveConfig
	assert_str(move.crit_rate_formula).is_equal("")


func test_scratch_i_no_post_effects() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_i(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.post_effects.size()).is_equal(0)


# ── Tier II: Rake ─────────────────────────────────────────────────────────────

func test_scratch_ii_id_and_name() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_ii(RandomNumberGenerator.new()) as MoveConfig
	assert_str(move.id).is_equal("scratch_ii")
	assert_str(move.display_name).is_equal("Rake")


func test_scratch_ii_power_and_pp() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_ii(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.move_power).is_equal(65)
	assert_int(move.pp).is_equal(20)


func test_scratch_ii_has_elevated_crit_rate() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_ii(RandomNumberGenerator.new()) as MoveConfig
	assert_str(move.crit_rate_formula).is_not_empty()
	var crit: float = float(move.crit_rate_formula)
	# Must be strictly higher than the default 1/16 = 0.0625
	assert_float(crit).is_greater(0.0625)


func test_scratch_ii_no_post_effects() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_ii(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.post_effects.size()).is_equal(0)


# ── Tier III: Rend ────────────────────────────────────────────────────────────

func test_scratch_iii_id_and_name() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_iii(RandomNumberGenerator.new()) as MoveConfig
	assert_str(move.id).is_equal("scratch_iii")
	assert_str(move.display_name).is_equal("Rend")


func test_scratch_iii_power_and_pp() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_iii(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.move_power).is_equal(100)
	assert_int(move.pp).is_equal(10)


func test_scratch_iii_reduced_accuracy() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_iii(RandomNumberGenerator.new()) as MoveConfig
	assert_float(move.accuracy).is_less(1.0)


func test_scratch_iii_has_highest_crit_rate() -> void:
	var rng := RandomNumberGenerator.new()
	var ii: MoveConfig = _MoveRecipes.scratch_ii(rng) as MoveConfig
	var iii: MoveConfig = _MoveRecipes.scratch_iii(rng) as MoveConfig
	assert_float(float(iii.crit_rate_formula)).is_greater(float(ii.crit_rate_formula))


func test_scratch_iii_has_defense_down_post_effect() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_iii(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.condition_id).is_equal("defense_down_1")
	assert_str(fx.target).is_equal("target")


func test_scratch_iii_defense_down_is_partial_chance() -> void:
	var move: MoveConfig = _MoveRecipes.scratch_iii(RandomNumberGenerator.new()) as MoveConfig
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	# Should be a partial chance — risky but not guaranteed
	assert_float(fx.chance).is_greater(0.0)
	assert_float(fx.chance).is_less(1.0)


# ── Config loading (generator → engine integration) ───────────────────────────

func test_config_loading_scratch_i() -> void:
	var move: MoveConfig = ConfigLoader.load_move("scratch_i")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("scratch_i")
	assert_int(move.move_power).is_equal(40)
	assert_bool(move.damage_formula.contains("caster.attack")).is_true()


func test_config_loading_scratch_ii() -> void:
	var move: MoveConfig = ConfigLoader.load_move("scratch_ii")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("scratch_ii")
	assert_int(move.move_power).is_equal(65)
	assert_str(move.crit_rate_formula).is_not_empty()


func test_config_loading_scratch_iii() -> void:
	var move: MoveConfig = ConfigLoader.load_move("scratch_iii")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("scratch_iii")
	assert_int(move.move_power).is_equal(100)
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.condition_id).is_equal("defense_down_1")


func test_config_loading_claw_beast() -> void:
	var monster: MonsterConfig = ConfigLoader.load_monster("claw_beast")
	assert_object(monster).is_not_null()
	assert_str(monster.id).is_equal("claw_beast")
	assert_bool(monster.move_ids.has("scratch_i")).is_true()
	assert_bool(monster.move_ids.has("scratch_ii")).is_true()
	assert_bool(monster.move_ids.has("scratch_iii")).is_true()


func test_config_loading_zio() -> void:
	var move: MoveConfig = ConfigLoader.load_move("zio")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("zio")
	assert_int(move.move_power).is_equal(40)
	assert_int(move.type_tag).is_equal(TypeTag.Type.ELECTRIC)


func test_config_loading_zionga() -> void:
	var move: MoveConfig = ConfigLoader.load_move("zionga")
	assert_object(move).is_not_null()
	assert_int(move.move_power).is_equal(100)


func test_config_loading_ziodyne() -> void:
	var move: MoveConfig = ConfigLoader.load_move("ziodyne")
	assert_object(move).is_not_null()
	assert_int(move.move_power).is_equal(160)
	assert_int(move.pp).is_equal(5)


func test_config_loading_scratch_showcase_battle() -> void:
	var battle: BattleConfig = ConfigLoader.load_battle_config("scratch_showcase")
	assert_object(battle).is_not_null()
	assert_int(battle.style).is_equal(BattleConfig.CombatStyle.TURN_BASED_NVM)
	assert_bool(battle.player_monster_ids.has("claw_beast")).is_true()
	assert_bool(battle.enemy_monster_ids.has("claw_beast")).is_true()
