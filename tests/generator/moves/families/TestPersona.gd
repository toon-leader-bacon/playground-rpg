extends GdUnitTestSuite
## Tests for Persona.build() — verifies LERP scaling, naming, overrides,
## and per-tier optional fields.

const _MoveFactory = preload("res://generator/moves/MoveFactory.gd")


# ── LERP scaling ──────────────────────────────────────────────────────────────

func test_lerp_power_first_tier_equals_start() -> void:
	var p := _make_simple_params(3)
	p.start_power = 40
	p.end_power = 160
	var move: MoveConfig = Persona.build(p, 0) as MoveConfig
	assert_int(move.move_power).is_equal(40)


func test_lerp_power_last_tier_equals_end() -> void:
	var p := _make_simple_params(3)
	p.start_power = 40
	p.end_power = 160
	var move: MoveConfig = Persona.build(p, 2) as MoveConfig
	assert_int(move.move_power).is_equal(160)


func test_lerp_power_middle_tier_is_interpolated() -> void:
	var p := _make_simple_params(3)
	p.start_power = 40
	p.end_power = 160
	var move: MoveConfig = Persona.build(p, 1) as MoveConfig
	assert_int(move.move_power).is_equal(100)


func test_lerp_pp_decreases_across_tiers() -> void:
	var p := _make_simple_params(3)
	p.start_pp = 15
	p.end_pp = 5
	var t0: MoveConfig = Persona.build(p, 0) as MoveConfig
	var t1: MoveConfig = Persona.build(p, 1) as MoveConfig
	var t2: MoveConfig = Persona.build(p, 2) as MoveConfig
	assert_int(t0.pp).is_equal(15)
	assert_int(t1.pp).is_equal(10)
	assert_int(t2.pp).is_equal(5)


func test_lerp_accuracy_interpolates_correctly() -> void:
	var p := _make_simple_params(3)
	p.start_accuracy = 1.0
	p.end_accuracy = 0.7
	var t0: MoveConfig = Persona.build(p, 0) as MoveConfig
	var t2: MoveConfig = Persona.build(p, 2) as MoveConfig
	assert_float(t0.accuracy).is_equal_approx(1.0, 0.001)
	assert_float(t2.accuracy).is_equal_approx(0.7, 0.001)


func test_single_tier_family_uses_start_values() -> void:
	var p := _make_simple_params(1)
	p.start_power = 80
	p.end_power = 200
	var move: MoveConfig = Persona.build(p, 0) as MoveConfig
	assert_int(move.move_power).is_equal(80)


# ── Naming ────────────────────────────────────────────────────────────────────

func test_set_names_from_affixes_concatenates_correctly() -> void:
	var p := Persona.FamilyParams.new()
	p.set_names_from_affixes("Zio", ["", "nga", "dyne"])
	assert_int(p.tier_names.size()).is_equal(3)
	assert_str(p.tier_names[0]).is_equal("Zio")
	assert_str(p.tier_names[1]).is_equal("Zionga")
	assert_str(p.tier_names[2]).is_equal("Ziodyne")


func test_id_derived_from_display_name_lowercase() -> void:
	var p := _make_simple_params(1)
	p.tier_names = ["Thunder Storm"]
	var move: MoveConfig = Persona.build(p, 0) as MoveConfig
	assert_str(move.id).is_equal("thunder_storm")
	assert_str(move.display_name).is_equal("Thunder Storm")


func test_explicit_id_overrides_derived_id() -> void:
	var p := _make_simple_params(1)
	p.tier_names = ["Scratch"]
	p.tier_ids   = ["scratch_i"]
	var move: MoveConfig = Persona.build(p, 0) as MoveConfig
	assert_str(move.id).is_equal("scratch_i")
	assert_str(move.display_name).is_equal("Scratch")


func test_partial_tier_ids_uses_derived_for_remaining() -> void:
	var p := _make_simple_params(3)
	p.tier_names = ["Alpha", "Beta", "Gamma"]
	p.tier_ids   = ["explicit_a"]   # only tier 0 has an explicit ID
	assert_str((Persona.build(p, 0) as MoveConfig).id).is_equal("explicit_a")
	assert_str((Persona.build(p, 1) as MoveConfig).id).is_equal("beta")
	assert_str((Persona.build(p, 2) as MoveConfig).id).is_equal("gamma")


# ── Per-tier overrides ────────────────────────────────────────────────────────

func test_tier_powers_override_lerp() -> void:
	var p := _make_simple_params(3)
	p.start_power = 0
	p.end_power = 999
	p.tier_powers = [40, 65, 100]
	assert_int((Persona.build(p, 0) as MoveConfig).move_power).is_equal(40)
	assert_int((Persona.build(p, 1) as MoveConfig).move_power).is_equal(65)
	assert_int((Persona.build(p, 2) as MoveConfig).move_power).is_equal(100)


func test_tier_pps_override_lerp() -> void:
	var p := _make_simple_params(3)
	p.start_pp = 0
	p.end_pp = 999
	p.tier_pps = [35, 20, 10]
	assert_int((Persona.build(p, 0) as MoveConfig).pp).is_equal(35)
	assert_int((Persona.build(p, 1) as MoveConfig).pp).is_equal(20)
	assert_int((Persona.build(p, 2) as MoveConfig).pp).is_equal(10)


func test_tier_accuracies_override_lerp() -> void:
	var p := _make_simple_params(3)
	p.start_accuracy = 0.0
	p.end_accuracy = 0.0
	p.tier_accuracies = [1.0, 1.0, 0.9]
	assert_float((Persona.build(p, 0) as MoveConfig).accuracy).is_equal_approx(1.0, 0.001)
	assert_float((Persona.build(p, 2) as MoveConfig).accuracy).is_equal_approx(0.9, 0.001)


# ── Per-tier optional fields ──────────────────────────────────────────────────

func test_crit_rate_formula_applied_per_tier() -> void:
	var p := _make_simple_params(3)
	p.crit_rate_formulas = ["", "0.125", "0.25"]
	assert_str((Persona.build(p, 0) as MoveConfig).crit_rate_formula).is_equal("")
	assert_str((Persona.build(p, 1) as MoveConfig).crit_rate_formula).is_equal("0.125")
	assert_str((Persona.build(p, 2) as MoveConfig).crit_rate_formula).is_equal("0.25")


func test_tiers_beyond_crit_array_get_empty_formula() -> void:
	var p := _make_simple_params(3)
	p.crit_rate_formulas = ["0.5"]   # only tier 0 set
	assert_str((Persona.build(p, 1) as MoveConfig).crit_rate_formula).is_equal("")
	assert_str((Persona.build(p, 2) as MoveConfig).crit_rate_formula).is_equal("")


func test_post_effects_applied_per_tier() -> void:
	var p := _make_simple_params(3)
	var fx: Array[EffectEntry] = [_MoveFactory.make_condition_effect("burn", 0.3)]
	p.post_effects_by_tier = [[], [], fx]
	assert_int((Persona.build(p, 0) as MoveConfig).post_effects.size()).is_equal(0)
	assert_int((Persona.build(p, 1) as MoveConfig).post_effects.size()).is_equal(0)
	var tier2: MoveConfig = Persona.build(p, 2) as MoveConfig
	assert_int(tier2.post_effects.size()).is_equal(1)
	assert_str((tier2.post_effects[0] as EffectEntry).condition_id).is_equal("burn")


func test_tiers_beyond_post_effects_array_have_no_effects() -> void:
	var p := _make_simple_params(3)
	p.post_effects_by_tier = []  # empty — no tier has effects
	for i: int in range(3):
		assert_int((Persona.build(p, i) as MoveConfig).post_effects.size()).is_equal(0)


# ── Formula passthrough ───────────────────────────────────────────────────────

func test_physical_formula_set_on_move() -> void:
	var p := _make_simple_params(1)
	p.damage_formula = _MoveFactory.PHYSICAL_FORMULA
	var move: MoveConfig = Persona.build(p, 0) as MoveConfig
	assert_bool(move.damage_formula.contains("caster.attack")).is_true()


func test_special_formula_set_on_move() -> void:
	var p := _make_simple_params(1)
	p.damage_formula = _MoveFactory.SPECIAL_FORMULA
	var move: MoveConfig = Persona.build(p, 0) as MoveConfig
	assert_bool(move.damage_formula.contains("caster.special_attack")).is_true()


func test_type_tag_passed_through() -> void:
	var p := _make_simple_params(1)
	p.type_tag = TypeTag.Type.FIRE
	var move: MoveConfig = Persona.build(p, 0) as MoveConfig
	assert_int(move.type_tag).is_equal(TypeTag.Type.FIRE)


# ── Helper ────────────────────────────────────────────────────────────────────

func _make_simple_params(tier_count: int) -> Persona.FamilyParams:
	var p := Persona.FamilyParams.new()
	p.damage_formula = _MoveFactory.PHYSICAL_FORMULA
	for i: int in range(tier_count):
		p.tier_names.append("Move%d" % i)
	return p
