extends GdUnitTestSuite


# --- build_empty ---

func test_build_empty_creates_all_keys_at_zero() -> void:
	# Step 1: set up inputs
	var factory := StatBlockFactory.new()

	# Step 2: run code under test
	var block: GenericStatBlock = factory.build_empty(StatProfiles.POKEMON)

	# Step 3: validate output
	assert_int(block.stat_names().size()).is_equal(StatProfiles.POKEMON.size())
	for stat_name: String in StatProfiles.POKEMON:
		assert_float(block.get_stat(stat_name)).is_equal_approx(0.0, 0.001)


func test_build_empty_with_custom_names() -> void:
	var factory := StatBlockFactory.new()
	var names: Array[String] = [StatName.HP, StatName.ATTACK]

	var block: GenericStatBlock = factory.build_empty(names)

	assert_bool(block.has_stat(StatName.HP)).is_true()
	assert_bool(block.has_stat(StatName.ATTACK)).is_true()
	assert_bool(block.has_stat(StatName.DEFENSE)).is_false()


# --- build_from_values ---

func test_build_from_values_sets_correct_values() -> void:
	var factory := StatBlockFactory.new()
	var names: Array[String] = [StatName.HP, StatName.ATTACK, StatName.DEFENSE]
	var values: Array[float] = [80.0, 55.0, 40.0]

	var block: GenericStatBlock = factory.build_from_values(names, values)

	assert_float(block.get_stat(StatName.HP)).is_equal_approx(80.0, 0.001)
	assert_float(block.get_stat(StatName.ATTACK)).is_equal_approx(55.0, 0.001)
	assert_float(block.get_stat(StatName.DEFENSE)).is_equal_approx(40.0, 0.001)


func test_build_from_values_preserves_order() -> void:
	var factory := StatBlockFactory.new()
	var names: Array[String] = StatProfiles.POKEMON.duplicate()
	var values: Array[float] = [45.0, 49.0, 49.0, 45.0, 65.0, 45.0]

	var block: GenericStatBlock = factory.build_from_values(names, values)

	assert_float(block.get_stat(StatName.HP)).is_equal_approx(45.0, 0.001)
	assert_float(block.get_stat(StatName.SPECIAL_DEFENSE)).is_equal_approx(65.0, 0.001)


# --- build_from_dict ---

func test_build_from_dict_sets_all_entries() -> void:
	var factory := StatBlockFactory.new()
	var values: Dictionary = {
		StatName.STRENGTH: 30.0,
		StatName.MAGIC: 15.0,
		StatName.SPEED: 25.0,
	}

	var block: GenericStatBlock = factory.build_from_dict(values)

	assert_float(block.get_stat(StatName.STRENGTH)).is_equal_approx(30.0, 0.001)
	assert_float(block.get_stat(StatName.MAGIC)).is_equal_approx(15.0, 0.001)
	assert_float(block.get_stat(StatName.SPEED)).is_equal_approx(25.0, 0.001)


# --- build_random ---

func test_build_random_produces_values_in_range() -> void:
	# Step 1: set up mocks
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999

	# Step 2: set up inputs
	var factory := StatBlockFactory.new(rng)

	# Step 3: run code under test
	var block: GenericStatBlock = factory.build_random(StatProfiles.FF_SIMPLE, 10.0, 100.0)

	# Step 4: validate output
	for stat_name: String in StatProfiles.FF_SIMPLE:
		var val: float = block.get_stat(stat_name)
		assert_float(val).is_greater_equal(10.0)
		assert_float(val).is_less_equal(100.0)

	# Step 5: validate mocks
	assert_object(factory.rng).is_same(rng)


func test_build_random_sets_all_stat_names() -> void:
	var factory := StatBlockFactory.new()
	var block: GenericStatBlock = factory.build_random(StatProfiles.CHRONO_TRIGGER, 1.0, 50.0)

	assert_int(block.stat_names().size()).is_equal(StatProfiles.CHRONO_TRIGGER.size())


# --- build_random_ranged ---

func test_build_random_ranged_respects_per_stat_ranges() -> void:
	# Step 1: set up mocks
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Step 2: set up inputs
	var factory := StatBlockFactory.new(rng)
	var ranges: Dictionary = {
		StatName.HP: [100.0, 200.0],
		StatName.ATTACK: [5.0, 10.0],
	}

	# Step 3: run code under test
	var block: GenericStatBlock = factory.build_random_ranged(ranges)

	# Step 4: validate output
	assert_float(block.get_stat(StatName.HP)).is_greater_equal(100.0)
	assert_float(block.get_stat(StatName.HP)).is_less_equal(200.0)
	assert_float(block.get_stat(StatName.ATTACK)).is_greater_equal(5.0)
	assert_float(block.get_stat(StatName.ATTACK)).is_less_equal(10.0)

	# Step 5: validate mocks
	assert_object(factory.rng).is_same(rng)


# --- build_gaussian_total ---

func test_gaussian_total_sum_equals_total_points() -> void:
	# Step 1: set up mocks
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Step 2: set up inputs
	var factory := StatBlockFactory.new(rng)

	# Step 3: run code under test
	var block: GenericStatBlock = factory.build_gaussian_total(StatProfiles.POKEMON, 300.0)

	# Step 4: validate output — sum must equal total_points exactly (within float epsilon)
	var total: float = 0.0
	for stat_name: String in StatProfiles.POKEMON:
		total += block.get_stat(stat_name)
	assert_float(total).is_equal_approx(300.0, 0.001)


func test_gaussian_total_produces_all_stat_keys() -> void:
	var factory := StatBlockFactory.new()
	var block: GenericStatBlock = factory.build_gaussian_total(StatProfiles.FF_SIMPLE, 400.0)

	assert_int(block.stat_names().size()).is_equal(StatProfiles.FF_SIMPLE.size())
	for stat_name: String in StatProfiles.FF_SIMPLE:
		assert_bool(block.has_stat(stat_name)).is_true()


func test_gaussian_total_all_values_non_negative_by_default() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var factory := StatBlockFactory.new(rng)

	var block: GenericStatBlock = factory.build_gaussian_total(StatProfiles.FIRE_EMBLEM, 250.0)

	for stat_name: String in StatProfiles.FIRE_EMBLEM:
		assert_float(block.get_stat(stat_name)).is_greater_equal(0.0)


func test_gaussian_total_respects_min_per_stat_before_scaling() -> void:
	# With min_per_stat > 0, no raw sample falls below that floor before scaling.
	# After proportional scaling the values may differ, but all should be > 0.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var factory := StatBlockFactory.new(rng)

	var block: GenericStatBlock = factory.build_gaussian_total(
		StatProfiles.POKEMON, 360.0, 0.10, 1.0
	)

	var total: float = 0.0
	for stat_name: String in StatProfiles.POKEMON:
		total += block.get_stat(stat_name)
		assert_float(block.get_stat(stat_name)).is_greater(0.0)
	assert_float(total).is_equal_approx(360.0, 0.001)


func test_gaussian_total_seeded_rng_is_deterministic() -> void:
	# Step 1: set up mocks
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 55555
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 55555

	# Step 2: set up inputs
	var factory_a := StatBlockFactory.new(rng_a)
	var factory_b := StatBlockFactory.new(rng_b)

	# Step 3: run code under test
	var block_a: GenericStatBlock = factory_a.build_gaussian_total(StatProfiles.POKEMON, 300.0)
	var block_b: GenericStatBlock = factory_b.build_gaussian_total(StatProfiles.POKEMON, 300.0)

	# Step 4: validate output
	for stat_name: String in StatProfiles.POKEMON:
		assert_float(block_a.get_stat(stat_name)).is_equal_approx(
			block_b.get_stat(stat_name), 0.0001
		)


func test_gaussian_total_high_std_dev_produces_spread() -> void:
	# A very high std_dev_factor should produce a more skewed distribution
	# than a very low one. Verify by comparing variance of both outputs.
	var rng_low := RandomNumberGenerator.new()
	rng_low.seed = 9999
	var rng_high := RandomNumberGenerator.new()
	rng_high.seed = 9999

	var factory_low := StatBlockFactory.new(rng_low)
	var factory_high := StatBlockFactory.new(rng_high)

	var block_low: GenericStatBlock = factory_low.build_gaussian_total(
		StatProfiles.POKEMON, 300.0, 0.01
	)
	var block_high: GenericStatBlock = factory_high.build_gaussian_total(
		StatProfiles.POKEMON, 300.0, 0.50
	)

	# Compute range (max - min) as a simple spread measure
	var min_low: float = INF
	var max_low: float = -INF
	var min_high: float = INF
	var max_high: float = -INF
	for stat_name: String in StatProfiles.POKEMON:
		min_low = minf(min_low, block_low.get_stat(stat_name))
		max_low = maxf(max_low, block_low.get_stat(stat_name))
		min_high = minf(min_high, block_high.get_stat(stat_name))
		max_high = maxf(max_high, block_high.get_stat(stat_name))

	assert_float(max_high - min_high).is_greater(max_low - min_low)


func test_gaussian_total_single_stat_equals_total() -> void:
	var factory := StatBlockFactory.new()
	var names: Array[String] = [StatName.HP]

	var block: GenericStatBlock = factory.build_gaussian_total(names, 500.0)

	assert_float(block.get_stat(StatName.HP)).is_equal_approx(500.0, 0.001)


# --- config loading ---

func test_load_pokemon_style_from_config_loader() -> void:
	# Step 1: set up inputs
	# (none — loads from disk)

	# Step 2: run code under test
	var block: GenericStatBlock = ConfigLoader.load_stat_block("pokemon_style")

	# Step 3: validate output
	assert_object(block).is_not_null()
	assert_bool(block.has_stat(StatName.HP)).is_true()
	assert_bool(block.has_stat(StatName.SPECIAL_ATTACK)).is_true()
	assert_float(block.get_stat(StatName.HP)).is_equal_approx(45.0, 0.001)


func test_load_ff_simple_from_config_loader() -> void:
	var block: GenericStatBlock = ConfigLoader.load_stat_block("ff_simple")

	assert_object(block).is_not_null()
	assert_bool(block.has_stat(StatName.MP)).is_true()
	assert_bool(block.has_stat(StatName.SPIRIT)).is_true()
	assert_float(block.get_stat(StatName.HP)).is_equal_approx(60.0, 0.001)
