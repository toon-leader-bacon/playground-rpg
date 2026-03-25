extends GdUnitTestSuite
## Tests for move examples recipes and their existing .tres config files.
##
## Recipe tests verify the MoveConfig values produced by each recipe function.
## Config loading tests verify that the existing .tres files load through
## ConfigLoader with correct typed values — the integration gate for generator → engine.

const _MoveExamplesRecipes = preload("res://generator/recipes/MoveExamplesRecipes.gd")


# ── Recipe output tests ───────────────────────────────────────────────────────

func test_physical_damage_uses_physical_formula() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.physical_damage(RandomNumberGenerator.new()) as MoveConfig
	assert_bool(move.damage_formula.contains("caster.attack")).is_true()
	assert_bool(move.damage_formula.contains("target.defense")).is_true()


func test_special_damage_type_tag_is_fire() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.special_damage(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.type_tag).is_equal(TypeTag.Type.FIRE)


func test_special_damage_has_burn_post_effect() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.special_damage(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.condition_id).is_equal("burn")
	assert_float(fx.chance).is_greater(0.0)
	assert_float(fx.chance).is_less(1.0)


func test_self_heal_target_mode_is_self() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.self_heal(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.target_mode).is_equal(MoveConfig.TargetType.SELF)


func test_self_heal_formula_proportional_to_max_hp() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.self_heal(RandomNumberGenerator.new()) as MoveConfig
	assert_bool(move.heal_formula.contains("max_hp")).is_true()


func test_recoil_move_post_effect_is_recoil_type() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.recoil_move(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.effect_type).is_equal("recoil")
	assert_str(fx.target).is_equal("caster")


func test_recoil_move_fraction() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.recoil_move(RandomNumberGenerator.new()) as MoveConfig
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_float(fx.recoil_fraction).is_greater(0.0)
	assert_float(fx.recoil_fraction).is_less(1.0)


func test_always_hit_uses_accuracy_node() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.always_hit_move(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.node_overrides.size()).is_greater_equal(1)
	assert_str(move.node_overrides[0].override_tag).is_equal("always_hit")


func test_weather_accuracy_node_arguments_include_hail() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.weather_accuracy_move(RandomNumberGenerator.new()) as MoveConfig
	assert_str(move.node_overrides[0].override_tag).is_equal("weather_accuracy")
	assert_bool(move.node_overrides[0].args.has("entries")).is_true()
	var found_hail: bool = false
	for entry: Dictionary in move.node_overrides[0].args.get("entries", []) as Array:
		if entry.get("weather", -1) == WeatherType.Type.HAIL:
			found_hail = true
			break
	assert_bool(found_hail).is_true()


func test_accuracy_down_applies_accuracy_down_1_condition() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.accuracy_down_move(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.condition_id).is_equal("accuracy_down_1")
	assert_str(fx.target).is_equal("target")


func test_paralysis_move_condition_and_type_tag() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.paralysis_move(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.type_tag).is_equal(TypeTag.Type.ELECTRIC)
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.condition_id).is_equal("paralysis")
	assert_int(move.node_overrides.size()).is_greater_equal(1)
	assert_str(move.node_overrides[0].override_tag).is_equal("always_hit")


func test_sleep_move_has_reduced_accuracy() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.sleep_move(RandomNumberGenerator.new()) as MoveConfig
	assert_float(move.accuracy).is_less(1.0)
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.condition_id).is_equal("sleep")


func test_burn_install_applies_burn() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.burn_install_move(RandomNumberGenerator.new()) as MoveConfig
	assert_float(move.accuracy).is_less(1.0)
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.condition_id).is_equal("burn")
	assert_float(fx.chance).is_equal_approx(1.0, 0.001)


func test_elevated_crit_above_default_rate() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.elevated_crit_move(RandomNumberGenerator.new()) as MoveConfig
	assert_str(move.crit_rate_formula).is_not_empty()
	var crit: float = float(move.crit_rate_formula)
	assert_float(crit).is_greater(0.0625)


func test_crit_branch_has_if_crit_effect() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.crit_branch_move(RandomNumberGenerator.new()) as MoveConfig
	var has_if_crit: bool = false
	for effect: EffectEntry in move.post_effects:
		if effect.if_crit:
			has_if_crit = true
			break
	assert_bool(has_if_crit).is_true()


func test_crit_branch_has_unless_crit_effect() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.crit_branch_move(RandomNumberGenerator.new()) as MoveConfig
	var has_unless_crit: bool = false
	for effect: EffectEntry in move.post_effects:
		if effect.unless_crit:
			has_unless_crit = true
			break
	assert_bool(has_unless_crit).is_true()


func test_hp_inverse_formula_references_caster_hp() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.hp_inverse_move(RandomNumberGenerator.new()) as MoveConfig
	assert_bool(move.damage_formula.contains("caster.hp")).is_true()
	assert_bool(move.damage_formula.contains("caster.max_hp")).is_true()


func test_buff_scale_formula_references_buff_count() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.buff_scale_move(RandomNumberGenerator.new()) as MoveConfig
	assert_bool(move.damage_formula.contains("buff_count")).is_true()


func test_weather_set_effect_type_and_weather_value() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.weather_set_move(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.effect_type).is_equal("set_weather")
	assert_int(fx.weather).is_equal(WeatherType.Type.RAIN)


func test_damage_burn_has_damage_formula_and_burn_post_effect() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.damage_burn_move(RandomNumberGenerator.new()) as MoveConfig
	assert_bool(move.damage_formula.contains("special_attack")).is_true()
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.condition_id).is_equal("burn")
	assert_float(fx.chance).is_equal_approx(0.3, 0.001)


func test_damage_self_debuff_effects_target_caster() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.damage_self_debuff_move(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.post_effects.size()).is_equal(2)
	for effect: EffectEntry in move.post_effects:
		assert_str(effect.target).is_equal("caster")


func test_speed_up_move_applies_speed_up_1_to_caster() -> void:
	var move: MoveConfig = _MoveExamplesRecipes.speed_up_move(RandomNumberGenerator.new()) as MoveConfig
	assert_int(move.node_overrides.size()).is_greater_equal(1)
	assert_str(move.node_overrides[0].override_tag).is_equal("always_hit")
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.condition_id).is_equal("speed_up_1")
	assert_str(fx.target).is_equal("caster")


# ── Config loading tests (generator → engine integration) ─────────────────────

func test_config_loading_brave_bird() -> void:
	var move: MoveConfig = ConfigLoader.load_move("brave_bird")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("brave_bird")
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.effect_type).is_equal("recoil")
	assert_float(fx.recoil_fraction).is_greater(0.0)


func test_config_loading_swift() -> void:
	var move: MoveConfig = ConfigLoader.load_move("swift")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("swift")
	assert_int(move.node_overrides.size()).is_greater_equal(1)
	assert_str(move.node_overrides[0].override_tag).is_equal("always_hit")


func test_config_loading_blizzard() -> void:
	var move: MoveConfig = ConfigLoader.load_move("blizzard")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("blizzard")
	assert_int(move.node_overrides.size()).is_greater_equal(1)
	assert_str(move.node_overrides[0].override_tag).is_equal("weather_accuracy")
	assert_bool(move.node_overrides[0].args.has("entries")).is_true()


func test_config_loading_slash() -> void:
	var move: MoveConfig = ConfigLoader.load_move("slash")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("slash")
	assert_str(move.crit_rate_formula).is_not_empty()


func test_config_loading_frost_nova() -> void:
	var move: MoveConfig = ConfigLoader.load_move("frost_nova")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("frost_nova")
	assert_int(move.post_effects.size()).is_equal(2)
	var has_if_crit: bool = false
	var has_unless_crit: bool = false
	for effect: EffectEntry in move.post_effects:
		if effect.if_crit:
			has_if_crit = true
		if effect.unless_crit:
			has_unless_crit = true
	assert_bool(has_if_crit).is_true()
	assert_bool(has_unless_crit).is_true()


func test_config_loading_reversal() -> void:
	var move: MoveConfig = ConfigLoader.load_move("reversal")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("reversal")
	assert_bool(move.damage_formula.contains("hp")).is_true()


func test_config_loading_stored_power() -> void:
	var move: MoveConfig = ConfigLoader.load_move("stored_power")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("stored_power")
	assert_bool(move.damage_formula.contains("buff_count")).is_true()


func test_config_loading_rain_dance() -> void:
	var move: MoveConfig = ConfigLoader.load_move("rain_dance")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("rain_dance")
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.effect_type).is_equal("set_weather")


func test_config_loading_thunder_wave() -> void:
	var move: MoveConfig = ConfigLoader.load_move("thunder_wave")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("thunder_wave")
	assert_int(move.node_overrides.size()).is_greater_equal(1)
	assert_str(move.node_overrides[0].override_tag).is_equal("always_hit")
	assert_int(move.post_effects.size()).is_greater(0)
	var fx: EffectEntry = move.post_effects[0] as EffectEntry
	assert_str(fx.condition_id).is_equal("paralysis")


func test_config_loading_close_combat() -> void:
	var move: MoveConfig = ConfigLoader.load_move("close_combat")
	assert_object(move).is_not_null()
	assert_str(move.id).is_equal("close_combat")
	assert_int(move.post_effects.size()).is_equal(2)
	for effect: EffectEntry in move.post_effects:
		assert_str(effect.target).is_equal("caster")
