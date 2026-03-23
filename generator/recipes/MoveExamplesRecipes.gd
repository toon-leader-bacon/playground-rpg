extends RefCounted
## Move examples recipes — one static function per supported design pattern.
##
## Unlike the Persona-based families in MoveRecipes.gd, these are standalone
## recipes that each demonstrate a distinct move mechanic in the engine.
##
## Patterns covered:
##   physical_damage, special_damage, self_heal, recoil_move, always_hit_move,
##   weather_accuracy_move, accuracy_down_move, paralysis_move, sleep_move,
##   burn_install_move, elevated_crit_move, crit_branch_move, hp_inverse_move,
##   buff_scale_move, weather_set_move, damage_burn_move, damage_self_debuff_move,
##   speed_up_move
##
## Each function matches the registry signature:
##   static func <name>(rng: RandomNumberGenerator) -> Resource

const _MoveFactory = preload("res://generator/moves/MoveFactory.gd")


## physical_damage — Rock Slam style: 65 power physical NORMAL, 15 PP, full accuracy.
static func physical_damage(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	return factory.build_physical_attack("rock_slam_ex", "Rock Slam", 65, 1.0, 15)


## special_damage — Fire Blast style: 90 power special FIRE, 85% accuracy, 10% burn.
static func special_damage(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var post_fx: Array[EffectEntry] = [
		_MoveFactory.make_condition_effect("burn", 0.1),
	]
	return factory.build_special_attack(
		"fire_blast_ex", "Fire Blast", 90, 0.85, 5, TypeTag.Type.FIRE, post_fx
	)


## self_heal — Heal/Recover style: restores 50% max HP; always hits; targets self.
static func self_heal(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	return factory.build_heal("heal_ex", "Heal", 0.5, 10)


## recoil_move — Brave Bird style: 120 power physical AIR; 33% recoil to caster.
static func recoil_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var fx := EffectEntry.new()
	fx.chance = 1.0
	fx.target = "caster"
	fx.effect_type = "recoil"
	fx.recoil_fraction = 0.33
	var post_fx: Array[EffectEntry] = [fx]
	return factory.build_physical_attack("brave_bird_ex", "Brave Bird", 120, 1.0, 15, TypeTag.Type.AIR, post_fx)


## always_hit_move — Swift style: 60 power physical; bypasses accuracy checks entirely.
static func always_hit_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var move: MoveConfig = factory.build_physical_attack("swift_ex", "Swift", 60, 1.0, 20)
	move.accuracy_node = "always_hit"
	return move


## weather_accuracy_move — Blizzard style: 110 power special ICE; 100% in HAIL, 70% default.
static func weather_accuracy_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var post_fx: Array[EffectEntry] = [
		_MoveFactory.make_condition_effect("freeze", 0.1),
	]
	var move: MoveConfig = factory.build_special_attack(
		"blizzard_ex", "Blizzard", 110, 0.7, 5, TypeTag.Type.ICE, post_fx
	)
	move.accuracy_node = "weather_accuracy"
	move.accuracy_node_arguments = [
		{"weather": WeatherType.Type.HAIL, "accuracy_formula": "100.0"},
		{"weather": WeatherType.Type.SUN, "accuracy_formula": "30.0"},
		{"weather": -1, "accuracy_formula": "70.0"},
	]
	return move


## accuracy_down_move — Sand Attack style: applies accuracy_down_1 to target.
static func accuracy_down_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var post_fx: Array[EffectEntry] = [
		_MoveFactory.make_condition_effect("accuracy_down_1", 1.0),
	]
	return factory.build_status(
		"sand_attack_ex", "Sand Attack", 1.0, 15, TypeTag.Type.NORMAL,
		MoveConfig.TargetType.SINGLE_ENEMY, post_fx
	)


## paralysis_move — Thunder Wave style: always hits; applies paralysis to target.
static func paralysis_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var post_fx: Array[EffectEntry] = [
		_MoveFactory.make_condition_effect("paralysis", 1.0),
	]
	var move: MoveConfig = factory.build_status(
		"thunder_wave_ex", "Thunder Wave", 1.0, 20, TypeTag.Type.ELECTRIC,
		MoveConfig.TargetType.SINGLE_ENEMY, post_fx
	)
	move.accuracy_node = "always_hit"
	return move


## sleep_move — Hypnosis style: 60% accuracy; applies sleep to target.
static func sleep_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var post_fx: Array[EffectEntry] = [
		_MoveFactory.make_condition_effect("sleep", 1.0),
	]
	return factory.build_status(
		"hypnosis_ex", "Hypnosis", 0.6, 20, TypeTag.Type.NORMAL,
		MoveConfig.TargetType.SINGLE_ENEMY, post_fx
	)


## burn_install_move — Will-O-Wisp style: 85% accuracy; applies burn to target.
static func burn_install_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var post_fx: Array[EffectEntry] = [
		_MoveFactory.make_condition_effect("burn", 1.0),
	]
	return factory.build_status(
		"will_o_wisp_ex", "Will-O-Wisp", 0.85, 15, TypeTag.Type.FIRE,
		MoveConfig.TargetType.SINGLE_ENEMY, post_fx
	)


## elevated_crit_move — Slash style: 70 power physical; crit_rate_formula = "0.125" (1/8 rate).
static func elevated_crit_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	return factory.build_physical_attack("slash_ex", "Slash", 70, 1.0, 20, TypeTag.Type.NORMAL, [], "0.125")


## crit_branch_move — Frost Nova style: 85 power special ICE; freeze on crit, slow otherwise.
static func crit_branch_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var slow_fx := EffectEntry.new()
	slow_fx.chance = 1.0
	slow_fx.target = "target"
	slow_fx.condition_id = "slow"
	slow_fx.unless_crit = true
	var freeze_fx := EffectEntry.new()
	freeze_fx.chance = 1.0
	freeze_fx.target = "target"
	freeze_fx.condition_id = "freeze"
	freeze_fx.if_crit = true
	var post_fx: Array[EffectEntry] = [slow_fx, freeze_fx]
	return factory.build_special_attack("frost_nova_ex", "Frost Nova", 85, 1.0, 10, TypeTag.Type.ICE, post_fx)


## hp_inverse_move — Reversal style: damage scales inversely with caster's remaining HP.
static func hp_inverse_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var formula := "200.0 * (1.0 - caster.hp / caster.max_hp) * caster.attack / target.defense"
	return factory.build_from_formula("reversal_ex", "Reversal", formula, 1, 1.0, 15)


## buff_scale_move — Stored Power style: damage grows with each active stat buff on caster.
static func buff_scale_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var formula := "(move_power + 20.0 * caster.buff_count) * caster.special_attack / target.special_defense"
	return factory.build_from_formula("stored_power_ex", "Stored Power", formula, 20, 1.0, 10, TypeTag.Type.PSYCHIC)


## weather_set_move — Rain Dance style: sets RAIN weather for 5 turns; targets self.
static func weather_set_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var fx := EffectEntry.new()
	fx.chance = 1.0
	fx.effect_type = "set_weather"
	fx.weather = WeatherType.Type.RAIN
	fx.weather_duration = 5
	var post_fx: Array[EffectEntry] = [fx]
	return factory.build_status(
		"rain_dance_ex", "Rain Dance", -1.0, 5, TypeTag.Type.WATER,
		MoveConfig.TargetType.SELF, post_fx
	)


## damage_burn_move — Scald style: 80 power special WATER; 30% burn on hit.
static func damage_burn_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var post_fx: Array[EffectEntry] = [
		_MoveFactory.make_condition_effect("burn", 0.3),
	]
	return factory.build_special_attack("scald_ex", "Scald", 80, 1.0, 15, TypeTag.Type.WATER, post_fx)


## damage_self_debuff_move — Close Combat style: 120 power physical; lowers caster's defenses.
static func damage_self_debuff_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var post_fx: Array[EffectEntry] = [
		_MoveFactory.make_condition_effect("defense_down_1", 1.0, "caster"),
		_MoveFactory.make_condition_effect("special_defense_down_1", 1.0, "caster"),
	]
	return factory.build_physical_attack("close_combat_ex", "Close Combat", 120, 1.0, 5, TypeTag.Type.NORMAL, post_fx)


## speed_up_move — Quick Step style: always hits; applies speed_up_1 to caster.
static func speed_up_move(rng: RandomNumberGenerator) -> Resource:
	var factory := _MoveFactory.new(rng)
	var post_fx: Array[EffectEntry] = [
		_MoveFactory.make_condition_effect("speed_up_1", 1.0, "caster"),
	]
	var move: MoveConfig = factory.build_status(
		"quick_step_ex", "Quick Step", 1.0, 20, TypeTag.Type.NORMAL,
		MoveConfig.TargetType.SELF, post_fx
	)
	move.accuracy_node = "always_hit"
	return move
