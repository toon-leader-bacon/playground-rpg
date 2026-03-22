extends GdUnitTestSuite
## FSM pipeline tests + 17 move acceptance criteria (TEST-01 through TEST-17).

const _BattleState = preload("res://engine/battle/model/BattleState.gd")
const _Action = preload("res://engine/battle/model/Action.gd")
const _ActionResolver = preload("res://engine/battle/resolver/ActionResolver.gd")
const _BattleStateNvM = preload("res://engine/battle/model/BattleStateNvM.gd")


func before() -> void:
	_ActionResolver.init_registry()


# ============================================================
# Group 1 — Baseline pipeline
# ============================================================

## TEST-01: Scratch — full default pipeline, physical damage formula.
func test_01_scratch_full_pipeline() -> void:
	var attacker := _make_monster("a", 100, 50, 20, 30, 50, 20)
	var defender := _make_monster("b", 100, 20, 40, 30, 20, 40)
	var move := _make_damage_move("scratch", "move_power * caster.attack / target.defense", 40)
	var action: Action = _Action.create("a", "b", attacker, defender, move)
	var state := BattleState.new()
	var rng := _seeded_rng(1)

	var result: ActionResult = _ActionResolver.apply(action, state, rng)

	assert_bool(result.hit).is_true()
	assert_int(result.damage).is_greater(0)
	# damage = 40 * 50 / 40 = 50 (no crit)
	assert_int(defender.current_hp).is_less(100)


## TEST-02: Heal — self-target, always_hit, heals 50% max HP.
func test_02_heal_self_target_always_hit() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 10, 10)
	actor.apply_damage(60)  # 40 HP remaining
	var move := MoveConfig.new()
	move.id = "heal"
	move.accuracy_node = "always_hit"
	move.target_mode = MoveConfig.TargetType.SELF
	move.heal_formula = "target.max_hp * 0.5"
	var action: Action = _Action.create("a", "a", actor, actor, move)
	var state := BattleState.new()

	var result: ActionResult = _ActionResolver.apply(action, state, _seeded_rng(0))

	assert_bool(result.hit).is_true()
	assert_int(result.damage).is_equal(0)
	# Healed ~50 HP (max_hp=100+0=100, 50% = 50)
	assert_int(result.healed).is_equal(50)
	assert_int(actor.current_hp).is_equal(90)  # 40 + 50


## TEST-03: Sand Attack — status-only move, accuracy_down_1 applied to target.
func test_03_sand_attack_applies_accuracy_down() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 10, 10)
	var target := _make_monster("b", 100, 10, 10, 10, 10, 10)
	var move := MoveConfig.new()
	move.id = "sand_attack"
	move.accuracy = 1.0
	var entry := EffectEntry.new()
	entry.chance = 1.0
	entry.target = "target"
	entry.condition_id = "accuracy_down_1"
	move.post_effects = [entry]
	var action: Action = _Action.create("a", "b", actor, target, move)
	var state := BattleState.new()

	var result: ActionResult = _ActionResolver.apply(action, state, _seeded_rng(0))

	assert_bool(result.hit).is_true()
	assert_int(result.damage).is_equal(0)
	assert_int(target.active_conditions.size()).is_equal(1)


# ============================================================
# Group 2 — Accuracy variants
# ============================================================

## TEST-04: Swift — always_hit node bypasses accuracy entirely.
func test_04_swift_always_hit_node() -> void:
	var actor := _make_monster("a", 100, 50, 10, 10, 50, 10)
	var target := _make_monster("b", 100, 10, 10, 10, 10, 10)
	var move := _make_damage_move("swift", "move_power * caster.attack / target.defense", 60)
	move.accuracy_node = "always_hit"
	move.accuracy = 0.0  # would always miss without node override
	var action: Action = _Action.create("a", "b", actor, target, move)
	var state := BattleState.new()

	var result: ActionResult = _ActionResolver.apply(action, state, _seeded_rng(0))

	assert_bool(result.hit).is_true()
	assert_int(result.damage).is_greater(0)


## TEST-05: Blizzard — weather_accuracy: always hits in HAIL, 30% in SUN, 70% otherwise.
func test_05_blizzard_always_hits_in_hail() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 80, 10)
	var target := _make_monster("b", 100, 10, 10, 10, 10, 30)
	var move := MoveConfig.new()
	move.id = "blizzard"
	move.move_power = 110
	move.accuracy_node = "weather_accuracy"
	move.accuracy_node_arguments = [
		{"weather": WeatherType.Type.HAIL, "accuracy_formula": "100.0"},
		{"weather": WeatherType.Type.SUN, "accuracy_formula": "30.0"},
		{"weather": -1, "accuracy_formula": "70.0"},
	]
	move.damage_formula = "move_power * caster.special_attack / target.special_defense"
	var action: Action = _Action.create("a", "b", actor, target, move)
	var state: BattleStateNvM = _BattleStateNvM.new()
	state.weather = WeatherType.Type.HAIL

	# All 20 trials must hit in HAIL
	for i: int in range(20):
		var r: ActionResult = _ActionResolver.apply(action, state, RandomNumberGenerator.new())
		assert_bool(r.hit).is_true()


func test_05_blizzard_misses_often_in_sun() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 80, 10)
	var target := _make_monster("b", 100, 10, 10, 10, 10, 30)
	var move := MoveConfig.new()
	move.id = "blizzard"
	move.move_power = 110
	move.accuracy_node = "weather_accuracy"
	move.accuracy_node_arguments = [
		{"weather": WeatherType.Type.HAIL, "accuracy_formula": "100.0"},
		{"weather": WeatherType.Type.SUN, "accuracy_formula": "30.0"},
		{"weather": -1, "accuracy_formula": "70.0"},
	]
	move.damage_formula = "move_power * caster.special_attack / target.special_defense"
	var action: Action = _Action.create("a", "b", actor, target, move)
	var state: BattleStateNvM = _BattleStateNvM.new()
	state.weather = WeatherType.Type.SUN

	# Over 50 trials with 30% hit rate, should miss at least once
	var hits: int = 0
	for i: int in range(50):
		var r: ActionResult = _ActionResolver.apply(action, state, RandomNumberGenerator.new())
		if r.hit:
			hits += 1
	assert_int(hits).is_less(50)


# ============================================================
# Group 3 — Critical hit variants
# ============================================================

## TEST-06: Slash — elevated crit rate; weak condition applied only on crit.
func test_06_slash_weak_applied_only_on_crit() -> void:
	var actor := _make_monster("a", 100, 50, 10, 10, 50, 10)
	var target := _make_monster("b", 100, 10, 30, 10, 10, 30)
	var move := _make_damage_move("slash", "move_power * caster.attack / target.defense", 70)
	move.crit_rate_formula = "caster.crit_rate + 0.25"
	var entry := EffectEntry.new()
	entry.chance = 1.0
	entry.target = "target"
	entry.condition_id = "weak"
	entry.if_crit = true
	move.pre_effects = [entry]

	# Find a seed that produces a crit
	var found_crit: bool = false
	for seed_val: int in range(100):
		var a := _make_monster("a", 100, 50, 10, 10, 50, 10)
		var t := _make_monster("b", 100, 10, 30, 10, 10, 30)
		var m := _make_damage_move("slash", "move_power * caster.attack / target.defense", 70)
		m.crit_rate_formula = "caster.crit_rate + 0.25"
		var e := EffectEntry.new()
		e.chance = 1.0
		e.target = "target"
		e.condition_id = "weak"
		e.if_crit = true
		m.pre_effects = [e]
		var act: Action = _Action.create("a", "b", a, t, m)
		var result: ActionResult = _ActionResolver.apply(act, BattleState.new(), _seeded_rng(seed_val))
		if result.crit:
			assert_int(t.active_conditions.size()).is_equal(1)
			found_crit = true
			break
	assert_bool(found_crit).is_true()


func test_06_slash_weak_not_applied_on_normal_hit() -> void:
	# With crit_rate_formula forcing 0%, weak should never apply
	var actor := _make_monster("a", 100, 50, 10, 10, 50, 10)
	var target := _make_monster("b", 100, 10, 30, 10, 10, 30)
	var move := _make_damage_move("slash", "move_power * caster.attack / target.defense", 70)
	move.crit_rate_formula = "0.0"  # force no crit
	var entry := EffectEntry.new()
	entry.chance = 1.0
	entry.target = "target"
	entry.condition_id = "weak"
	entry.if_crit = true
	move.pre_effects = [entry]
	var action: Action = _Action.create("a", "b", actor, target, move)

	var result: ActionResult = _ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_bool(result.crit).is_false()
	assert_int(target.active_conditions.size()).is_equal(0)


## TEST-07: Frost Nova — slow on normal hit, freeze on crit.
func test_07_frost_nova_slow_on_normal_hit() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 80, 10)
	var target := _make_monster("b", 100, 10, 10, 10, 10, 30)
	var move := _make_damage_move("frost_nova", "move_power * caster.special_attack / target.special_defense", 60)
	move.crit_rate_formula = "0.0"
	var e_slow := EffectEntry.new()
	e_slow.chance = 1.0
	e_slow.target = "target"
	e_slow.condition_id = "slow"
	e_slow.unless_crit = true
	var e_freeze := EffectEntry.new()
	e_freeze.chance = 1.0
	e_freeze.target = "target"
	e_freeze.condition_id = "freeze"
	e_freeze.if_crit = true
	move.post_effects = [e_slow, e_freeze]
	var action: Action = _Action.create("a", "b", actor, target, move)

	var result: ActionResult = _ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_bool(result.crit).is_false()
	assert_int(target.active_conditions.size()).is_equal(1)
	var cond_id: String = (target.active_conditions[0] as Object).config.id
	assert_str(cond_id).is_equal("slow")


func test_07_frost_nova_freeze_on_crit_not_slow() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 80, 10)
	var target := _make_monster("b", 100, 10, 10, 10, 10, 30)
	var move := _make_damage_move("frost_nova", "move_power * caster.special_attack / target.special_defense", 60)
	move.crit_rate_formula = "1.0"  # force crit
	var e_slow := EffectEntry.new()
	e_slow.chance = 1.0
	e_slow.target = "target"
	e_slow.condition_id = "slow"
	e_slow.unless_crit = true
	var e_freeze := EffectEntry.new()
	e_freeze.chance = 1.0
	e_freeze.target = "target"
	e_freeze.condition_id = "freeze"
	e_freeze.if_crit = true
	move.post_effects = [e_slow, e_freeze]
	var action: Action = _Action.create("a", "b", actor, target, move)

	var result: ActionResult = _ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_bool(result.crit).is_true()
	assert_int(target.active_conditions.size()).is_equal(1)
	var cond_id: String = (target.active_conditions[0] as Object).config.id
	assert_str(cond_id).is_equal("freeze")


# ============================================================
# Group 4 — Recoil and self-targeting effects
# ============================================================

## TEST-08: Brave Bird — caster takes 33% of damage as recoil.
func test_08_brave_bird_recoil() -> void:
	var actor := _make_monster("a", 100, 80, 10, 10, 10, 10)
	var target := _make_monster("b", 200, 10, 20, 10, 10, 20)
	var move := _make_damage_move("brave_bird", "move_power * caster.attack / target.defense", 120)
	move.crit_rate_formula = "0.0"
	var recoil := EffectEntry.new()
	recoil.chance = 1.0
	recoil.target = "caster"
	recoil.effect_type = "recoil"
	recoil.recoil_fraction = 0.33
	move.post_effects = [recoil]
	var hp_before: int = actor.current_hp
	var action: Action = _Action.create("a", "b", actor, target, move)

	var result: ActionResult = _ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_bool(result.hit).is_true()
	var expected_recoil: int = int(float(result.damage) * 0.33)
	assert_int(actor.current_hp).is_equal(maxi(0, hp_before - expected_recoil))


## TEST-09: Close Combat — drops caster defense and special_defense.
func test_09_close_combat_self_stat_drops() -> void:
	var actor := _make_monster("a", 100, 80, 30, 10, 10, 30)
	var target := _make_monster("b", 200, 10, 20, 10, 10, 20)
	var move := _make_damage_move("close_combat", "move_power * caster.attack / target.defense", 120)
	var e1 := EffectEntry.new()
	e1.chance = 1.0
	e1.target = "caster"
	e1.condition_id = "defense_down_1"
	var e2 := EffectEntry.new()
	e2.chance = 1.0
	e2.target = "caster"
	e2.condition_id = "special_defense_down_1"
	move.post_effects = [e1, e2]
	var action: Action = _Action.create("a", "b", actor, target, move)

	_ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_int(actor.active_conditions.size()).is_equal(2)


# ============================================================
# Group 5 — State-conditional damage formulas
# ============================================================

## TEST-10: Reversal — damage scales inversely with caster HP.
func test_10_reversal_high_damage_at_low_hp() -> void:
	var actor := _make_monster("a", 100, 50, 10, 10, 10, 10)
	var target := _make_monster("b", 200, 10, 20, 10, 10, 20)
	var move := _make_damage_move("reversal",
		"200.0 * (1.0 - caster.hp / caster.max_hp) * caster.attack / target.defense", 1)
	move.crit_rate_formula = "0.0"

	# At full HP: caster.hp = 100, max_hp = 100, ratio = 0 → damage ≈ 0 (but min 1 if power>0)
	var action_full: Action = _Action.create("a", "b", actor, target, move)
	var result_full: ActionResult = _ActionResolver.apply(action_full, BattleState.new(), _seeded_rng(0))

	# At 25% HP: higher damage
	var actor_low := _make_monster("a", 100, 50, 10, 10, 10, 10)
	actor_low.apply_damage(75)  # 25 HP remaining
	var target2 := _make_monster("b", 200, 10, 20, 10, 10, 20)
	var action_low: Action = _Action.create("a", "b", actor_low, target2, move)
	var result_low: ActionResult = _ActionResolver.apply(action_low, BattleState.new(), _seeded_rng(0))

	assert_int(result_low.damage).is_greater(result_full.damage)


## TEST-11: Stored Power — scales with caster.buff_count.
func test_11_stored_power_scales_with_buffs() -> void:
	var actor_no_buff := _make_monster("a", 100, 10, 10, 10, 50, 10)
	var target1 := _make_monster("b", 200, 10, 10, 10, 10, 20)
	var move := _make_damage_move("stored_power",
		"(move_power + 20.0 * caster.buff_count) * caster.special_attack / target.special_defense", 20)
	move.crit_rate_formula = "0.0"

	var action1: Action = _Action.create("a", "b", actor_no_buff, target1, move)
	var result1: ActionResult = _ActionResolver.apply(action1, BattleState.new(), _seeded_rng(0))

	# Now give actor 3 positive stages
	var actor_buffed := _make_monster("a", 100, 10, 10, 10, 50, 10)
	actor_buffed.modify_stat_stage("attack", 1)
	actor_buffed.modify_stat_stage("defense", 1)
	actor_buffed.modify_stat_stage("speed", 1)
	var target2 := _make_monster("b", 200, 10, 10, 10, 10, 20)
	var action2: Action = _Action.create("a", "b", actor_buffed, target2, move)
	var result2: ActionResult = _ActionResolver.apply(action2, BattleState.new(), _seeded_rng(0))

	assert_int(result2.damage).is_greater(result1.damage)


# ============================================================
# Group 6 — Field state interaction
# ============================================================

## TEST-12: Rain Dance — set_weather writes RAIN to battle state.
func test_12_rain_dance_sets_weather() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 10, 10)
	var target := _make_monster("a", 100, 10, 10, 10, 10, 10)
	var move := MoveConfig.new()
	move.id = "rain_dance"
	move.accuracy = -1.0
	var entry := EffectEntry.new()
	entry.chance = 1.0
	entry.effect_type = "set_weather"
	entry.weather = WeatherType.Type.RAIN
	entry.weather_duration = 5
	move.post_effects = [entry]
	var state: BattleStateNvM = _BattleStateNvM.new()
	var action: Action = _Action.create("a", "a", actor, target, move)

	_ActionResolver.apply(action, state, _seeded_rng(0))

	assert_int(state.weather).is_equal(WeatherType.Type.RAIN)
	assert_int(state.weather_duration).is_equal(5)


# ============================================================
# Group 7 — Pokemon status conditions
# ============================================================

## TEST-13: Ember — 10% burn chance; applied as post_effect.
func test_13_ember_applies_burn_with_10pct_chance() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 60, 10)
	var target := _make_monster("b", 100, 10, 10, 10, 10, 30)
	var move := _make_damage_move("ember", "move_power * caster.special_attack / target.special_defense", 40)
	move.crit_rate_formula = "0.0"
	var entry := EffectEntry.new()
	entry.chance = 1.0  # force 100% for determinism
	entry.condition_id = "burn"
	entry.target = "target"
	move.post_effects = [entry]
	var action: Action = _Action.create("a", "b", actor, target, move)

	_ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_int(target.active_conditions.size()).is_equal(1)
	var cond: Object = target.active_conditions[0] as Object
	assert_str(cond.config.id).is_equal("burn")


func test_13_burn_registers_attack_modifier_on_carrier() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 60, 10)
	var target := _make_monster("b", 100, 60, 10, 10, 10, 30)
	var move := MoveConfig.new()
	move.id = "ember_burn_only"
	move.accuracy = 1.0
	var entry := EffectEntry.new()
	entry.chance = 1.0
	entry.condition_id = "burn"
	entry.target = "target"
	move.post_effects = [entry]
	var action: Action = _Action.create("a", "b", actor, target, move)

	_ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	# Burn registers attack * 0.5 modifier
	assert_bool(target.condition_modifiers.has("attack")).is_true()


## TEST-14: Thunder Wave — paralysis applied, speed modifier registered.
func test_14_thunder_wave_applies_paralysis() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 10, 10)
	var target := _make_monster("b", 100, 10, 10, 60, 10, 10)
	var move := MoveConfig.new()
	move.id = "thunder_wave"
	move.accuracy = 0.9
	var entry := EffectEntry.new()
	entry.chance = 1.0
	entry.condition_id = "paralysis"
	entry.target = "target"
	move.post_effects = [entry]
	var action: Action = _Action.create("a", "b", actor, target, move)

	_ActionResolver.apply(action, BattleState.new(), _seeded_rng(42))

	# If it hit, paralysis should be applied
	if target.active_conditions.size() > 0:
		var cond_id: String = (target.active_conditions[0] as Object).config.id
		assert_str(cond_id).is_equal("paralysis")
		assert_bool(target.condition_modifiers.has("speed")).is_true()


## TEST-15: Hypnosis — sleep with random 1–3 turn duration.
func test_15_hypnosis_applies_sleep_with_random_duration() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 10, 10)
	var target := _make_monster("b", 100, 10, 10, 10, 10, 10)
	var move := MoveConfig.new()
	move.id = "hypnosis"
	move.accuracy = 1.0  # force hit for this test
	var entry := EffectEntry.new()
	entry.chance = 1.0
	entry.condition_id = "sleep"
	entry.target = "target"
	move.post_effects = [entry]
	var action: Action = _Action.create("a", "b", actor, target, move)

	_ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_int(target.active_conditions.size()).is_equal(1)
	var sleep_inst: Object = target.active_conditions[0] as Object
	assert_str(sleep_inst.config.id).is_equal("sleep")
	# Duration should be 1–3
	var dur: int = sleep_inst.remaining_duration
	assert_int(dur).is_greater_equal(1)
	assert_int(dur).is_less_equal(3)


## TEST-16: Will-O-Wisp — burn applied directly; can miss.
func test_16_will_o_wisp_can_miss() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 10, 10)
	var target := _make_monster("b", 100, 10, 10, 10, 10, 10)
	var move := MoveConfig.new()
	move.id = "will_o_wisp"
	move.accuracy = 0.0  # force miss
	var entry := EffectEntry.new()
	entry.chance = 1.0
	entry.condition_id = "burn"
	entry.target = "target"
	move.post_effects = [entry]
	var action: Action = _Action.create("a", "b", actor, target, move)

	var result: ActionResult = _ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_bool(result.hit).is_false()
	assert_int(target.active_conditions.size()).is_equal(0)


func test_16_will_o_wisp_applies_burn_on_hit() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 10, 10)
	var target := _make_monster("b", 100, 10, 10, 10, 10, 10)
	var move := MoveConfig.new()
	move.id = "will_o_wisp"
	move.accuracy = 1.0  # force hit
	var entry := EffectEntry.new()
	entry.chance = 1.0
	entry.condition_id = "burn"
	entry.target = "target"
	move.post_effects = [entry]
	var action: Action = _Action.create("a", "b", actor, target, move)

	_ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_int(target.active_conditions.size()).is_equal(1)


## TEST-17: Scald — water damage move with 30% burn chance.
func test_17_scald_damage_and_burn_chance() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 60, 10)
	var target := _make_monster("b", 200, 10, 10, 10, 10, 30)
	var move := _make_damage_move("scald", "move_power * caster.special_attack / target.special_defense", 80)
	move.crit_rate_formula = "0.0"
	var entry := EffectEntry.new()
	entry.chance = 1.0  # force 100% for determinism
	entry.condition_id = "burn"
	entry.target = "target"
	move.post_effects = [entry]
	var action: Action = _Action.create("a", "b", actor, target, move)

	var result: ActionResult = _ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_bool(result.hit).is_true()
	assert_int(result.damage).is_greater(0)
	assert_int(target.active_conditions.size()).is_equal(1)
	assert_str((target.active_conditions[0] as Object).config.id).is_equal("burn")


# ============================================================
# Additional pipeline tests
# ============================================================

func test_miss_on_accuracy() -> void:
	var attacker := _make_monster("a", 100, 100, 1, 10, 10, 1)
	var defender := _make_monster("b", 100, 1, 1, 10, 1, 1)
	var move := _make_damage_move("miss", "move_power * caster.attack / target.defense", 100)
	move.accuracy = 0.0
	var action: Action = _Action.create("a", "b", attacker, defender, move)
	var hp_before: int = defender.current_hp

	var result: ActionResult = _ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_bool(result.hit).is_false()
	assert_int(result.damage).is_equal(0)
	assert_int(defender.current_hp).is_equal(hp_before)


func test_damage_minimum_one() -> void:
	var attacker := _make_monster("a", 100, 1, 1, 10, 1, 1)
	var defender := _make_monster("b", 100, 1, 999, 10, 1, 999)
	var move := _make_damage_move("hit", "move_power * caster.attack / target.defense", 1)
	var action: Action = _Action.create("a", "b", attacker, defender, move)

	var result: ActionResult = _ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	if result.hit:
		assert_int(result.damage).is_greater_equal(1)


func test_fainted_flag_when_target_dies() -> void:
	var attacker := _make_monster("a", 100, 999, 1, 10, 10, 1)
	var defender := _make_monster("b", 1, 1, 1, 10, 1, 1)
	var move := _make_damage_move("nuke", "move_power * caster.attack / target.defense", 200)
	var action: Action = _Action.create("a", "b", attacker, defender, move)

	var result: ActionResult = _ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	if result.hit:
		assert_bool(result.fainted).is_true()
		assert_bool(defender.is_fainted()).is_true()


func test_turn_denied_flag() -> void:
	var actor := _make_monster("a", 100, 10, 10, 10, 10, 10)
	actor.deny_turn()
	var target := _make_monster("b", 100, 10, 10, 10, 10, 10)
	var move := _make_damage_move("hit", "move_power * caster.attack / target.defense", 20)
	var action: Action = _Action.create("a", "b", actor, target, move)
	var hp_before: int = target.current_hp

	var result: ActionResult = _ActionResolver.apply(action, BattleState.new(), _seeded_rng(0))

	assert_bool(result.turn_denied).is_true()
	assert_int(target.current_hp).is_equal(hp_before)


# ============================================================
# Helpers
# ============================================================

func _make_monster(
	id: String, hp: int, atk: int, def_val: int, spd: int, sp_atk: int, sp_def: int
) -> MonsterInstance:
	var config := MonsterConfig.new()
	config.id = id
	config.display_name = id.capitalize()
	var stats := StatBlock.new()
	stats.max_hp = hp
	stats.attack = atk
	stats.defense = def_val
	stats.speed = spd
	stats.special_attack = sp_atk
	stats.special_defense = sp_def
	config.base_stats = stats
	config.type_tags = [TypeTag.Type.NORMAL]
	config.ai_style = MonsterConfig.AIStyle.RANDOM
	return MonsterInstance.create(config, 1)


func _make_damage_move(id: String, formula: String, power: int) -> MoveConfig:
	var move := MoveConfig.new()
	move.id = id
	move.display_name = id.capitalize()
	move.type_tag = TypeTag.Type.NORMAL
	move.move_power = power
	move.accuracy = 1.0
	move.damage_formula = formula
	return move


func _seeded_rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng
