extends GdUnitTestSuite
## Tests for StatArchetypes pre-built bias dictionaries.
## Each archetype is verified by running build_authored and asserting rank ordering.
## POKEMON profile is used because it contains HP, ATTACK, DEFENSE, SPEED, SPECIAL_ATTACK,
## SPECIAL_DEFENSE — enough stats to test all archetype constraints unambiguously.


func _build(archetype: Dictionary, seed: int = 42) -> GenericStatBlock:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var factory := StatBlockFactory.new(rng)
	return factory.build_authored(StatProfiles.POKEMON, 300.0, archetype, 0.05)


# --- tank ---

func test_tank_returns_non_empty_dict() -> void:
	assert_bool(StatArchetypes.tank().is_empty()).is_false()


func test_tank_hp_is_highest() -> void:
	var block: GenericStatBlock = _build(StatArchetypes.tank())
	var hp: float = block.get_stat(StatName.HP)

	for stat_name in StatProfiles.POKEMON:
		assert_float(hp).is_greater_equal(block.get_stat(stat_name) - 0.0001)


func test_tank_defense_is_second_highest() -> void:
	var block: GenericStatBlock = _build(StatArchetypes.tank(), 123)
	var defense: float = block.get_stat(StatName.DEFENSE)
	var hp: float = block.get_stat(StatName.HP)

	# defense is rank 2 → it gets the second-largest value from the sorted pool.
	# All unranked stats must be <= defense.
	assert_float(defense).is_less_equal(hp + 0.0001)
	for stat_name in StatProfiles.POKEMON:
		if stat_name == StatName.HP or stat_name == StatName.DEFENSE or stat_name == StatName.SPEED:
			continue
		assert_float(defense).is_greater_equal(block.get_stat(stat_name) - 0.0001)


func test_tank_speed_is_lowest() -> void:
	var block: GenericStatBlock = _build(StatArchetypes.tank(), 456)
	var speed: float = block.get_stat(StatName.SPEED)

	for stat_name in StatProfiles.POKEMON:
		assert_float(speed).is_less_equal(block.get_stat(stat_name) + 0.0001)


# --- glass_cannon ---

func test_glass_cannon_returns_non_empty_dict() -> void:
	assert_bool(StatArchetypes.glass_cannon().is_empty()).is_false()


func test_glass_cannon_attack_is_highest() -> void:
	var block: GenericStatBlock = _build(StatArchetypes.glass_cannon())
	var attack: float = block.get_stat(StatName.ATTACK)

	for stat_name in StatProfiles.POKEMON:
		assert_float(attack).is_greater_equal(block.get_stat(stat_name) - 0.0001)


func test_glass_cannon_defense_is_lowest() -> void:
	var block: GenericStatBlock = _build(StatArchetypes.glass_cannon(), 789)
	var defense: float = block.get_stat(StatName.DEFENSE)

	for stat_name in StatProfiles.POKEMON:
		assert_float(defense).is_less_equal(block.get_stat(stat_name) + 0.0001)


# --- speedster ---

func test_speedster_returns_non_empty_dict() -> void:
	assert_bool(StatArchetypes.speedster().is_empty()).is_false()


func test_speedster_speed_is_highest() -> void:
	var block: GenericStatBlock = _build(StatArchetypes.speedster())
	var speed: float = block.get_stat(StatName.SPEED)

	for stat_name in StatProfiles.POKEMON:
		assert_float(speed).is_greater_equal(block.get_stat(stat_name) - 0.0001)


func test_speedster_attack_is_second_highest() -> void:
	var block: GenericStatBlock = _build(StatArchetypes.speedster(), 314)
	var attack: float = block.get_stat(StatName.ATTACK)
	var speed: float = block.get_stat(StatName.SPEED)

	assert_float(attack).is_less_equal(speed + 0.0001)
	for stat_name in StatProfiles.POKEMON:
		if stat_name == StatName.SPEED or stat_name == StatName.ATTACK or stat_name == StatName.DEFENSE:
			continue
		assert_float(attack).is_greater_equal(block.get_stat(stat_name) - 0.0001)


func test_speedster_defense_is_lowest() -> void:
	var block: GenericStatBlock = _build(StatArchetypes.speedster(), 271)
	var defense: float = block.get_stat(StatName.DEFENSE)

	for stat_name in StatProfiles.POKEMON:
		assert_float(defense).is_less_equal(block.get_stat(stat_name) + 0.0001)


# --- balanced ---

func test_balanced_returns_empty_dict() -> void:
	assert_bool(StatArchetypes.balanced().is_empty()).is_true()


func test_balanced_sum_equals_total() -> void:
	# balanced() = {} which falls through to Gaussian; sum must still be exact.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var factory := StatBlockFactory.new(rng)
	var block: GenericStatBlock = factory.build_authored(
		StatProfiles.POKEMON, 300.0, StatArchetypes.balanced()
	)

	var total: float = 0.0
	for stat_name in StatProfiles.POKEMON:
		total += block.get_stat(stat_name)
	assert_float(total).is_equal_approx(300.0, 0.001)
