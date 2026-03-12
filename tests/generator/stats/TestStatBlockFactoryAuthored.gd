extends GdUnitTestSuite


# --- build_authored: sum guarantee ---

func test_sum_equals_total_points_with_weight_biases() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var factory := StatBlockFactory.new(rng)
	var biases: Dictionary[String, StatBiasEntry] = {
		StatName.ATTACK: StatBiasEntry.new(3.0),
		StatName.SPEED: StatBiasEntry.new(0.5),
	}

	var block: GenericStatBlock = factory.build_authored(StatProfiles.POKEMON, 300.0, biases)

	var total: float = 0.0
	for stat_name in StatProfiles.POKEMON:
		total += block.get_stat(stat_name)
	assert_float(total).is_equal_approx(300.0, 0.001)


func test_sum_equals_total_points_with_rank_biases() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var factory := StatBlockFactory.new(rng)
	var biases: Dictionary[String, StatBiasEntry] = {
		StatName.HP: StatBiasEntry.new(1.0, 1),
		StatName.SPEED: StatBiasEntry.new(1.0, -1),
	}

	var block: GenericStatBlock = factory.build_authored(StatProfiles.POKEMON, 400.0, biases)

	var total: float = 0.0
	for stat_name in StatProfiles.POKEMON:
		total += block.get_stat(stat_name)
	assert_float(total).is_equal_approx(400.0, 0.001)


# --- build_authored: weight influence ---

func test_high_weight_stat_larger_than_low_weight_stat() -> void:
	# Use very low std_dev so weight dominates the result reliably.
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var factory := StatBlockFactory.new(rng)
	var biases: Dictionary[String, StatBiasEntry] = {
		StatName.ATTACK: StatBiasEntry.new(4.0),   # heavily weighted
		StatName.SPEED: StatBiasEntry.new(0.25),    # very lightly weighted
	}

	var block: GenericStatBlock = factory.build_authored(
		StatProfiles.POKEMON, 300.0, biases, 0.02  # very tight std_dev
	)

	assert_float(block.get_stat(StatName.ATTACK)).is_greater(block.get_stat(StatName.SPEED))


# --- build_authored: rank=1 is highest ---

func test_rank_1_stat_is_highest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var factory := StatBlockFactory.new(rng)
	var biases: Dictionary[String, StatBiasEntry] = {StatName.ATTACK: StatBiasEntry.new(1.0, 1)}

	var block: GenericStatBlock = factory.build_authored(StatProfiles.POKEMON, 300.0, biases)

	var attack: float = block.get_stat(StatName.ATTACK)
	for stat_name in StatProfiles.POKEMON:
		assert_float(attack).is_greater_equal(block.get_stat(stat_name) - 0.0001)


# --- build_authored: rank=-1 is lowest ---

func test_rank_neg1_stat_is_lowest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9999
	var factory := StatBlockFactory.new(rng)
	var biases: Dictionary[String, StatBiasEntry] = {StatName.SPEED: StatBiasEntry.new(1.0, -1)}

	var block: GenericStatBlock = factory.build_authored(StatProfiles.POKEMON, 300.0, biases)

	var speed: float = block.get_stat(StatName.SPEED)
	for stat_name in StatProfiles.POKEMON:
		assert_float(speed).is_less_equal(block.get_stat(stat_name) + 0.0001)


# --- build_authored: absolute bounds ---

func test_min_val_respected_before_scaling() -> void:
	# Give the stat a high weight so its mean is large; min_val stays below natural value.
	# This tests the bound is applied without artificially capping a normally-large stat.
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	var factory := StatBlockFactory.new(rng)
	# HP weight=5 → mean ≈ (5/10)*300=150; min_val=20 should never bind here,
	# but we verify the final value stays >= 20 regardless of scaling.
	var biases: Dictionary[String, StatBiasEntry] = {StatName.HP: StatBiasEntry.new(5.0, 0, 20.0)}

	var block: GenericStatBlock = factory.build_authored(
		StatProfiles.POKEMON, 300.0, biases, 0.05
	)

	assert_float(block.get_stat(StatName.HP)).is_greater_equal(20.0)


func test_max_val_respected_in_final_output() -> void:
	# ATTACK gets very high weight so it would dominate without the cap.
	var rng := RandomNumberGenerator.new()
	rng.seed = 567
	var factory := StatBlockFactory.new(rng)
	# cap ATTACK at 30; with total=300 and 6 stats, natural ATTACK would be ~120+.
	var biases: Dictionary[String, StatBiasEntry] = {StatName.ATTACK: StatBiasEntry.new(5.0, 0, -INF, 30.0)}

	var block: GenericStatBlock = factory.build_authored(
		StatProfiles.POKEMON, 300.0, biases, 0.02
	)

	assert_float(block.get_stat(StatName.ATTACK)).is_less_equal(30.0 + 0.0001)


func test_max_val_slack_redistributed_to_unconstrained_stats() -> void:
	# When max_val caps a high-weight stat, the slack goes to the others.
	# Total must still equal total_points.
	var rng := RandomNumberGenerator.new()
	rng.seed = 888
	var factory := StatBlockFactory.new(rng)
	var biases: Dictionary[String, StatBiasEntry] = {StatName.ATTACK: StatBiasEntry.new(5.0, 0, -INF, 25.0)}

	var block: GenericStatBlock = factory.build_authored(
		StatProfiles.POKEMON, 300.0, biases, 0.02
	)

	var total: float = 0.0
	for stat_name in StatProfiles.POKEMON:
		total += block.get_stat(stat_name)
	assert_float(total).is_equal_approx(300.0, 0.01)


# --- build_authored: determinism ---

func test_seeded_rng_is_deterministic() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 31415
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 31415
	var biases: Dictionary[String, StatBiasEntry] = {
		StatName.ATTACK: StatBiasEntry.new(2.0, 1),
		StatName.SPEED: StatBiasEntry.new(0.5, -1),
	}

	var block_a: GenericStatBlock = StatBlockFactory.new(rng_a).build_authored(
		StatProfiles.POKEMON, 300.0, biases
	)
	var block_b: GenericStatBlock = StatBlockFactory.new(rng_b).build_authored(
		StatProfiles.POKEMON, 300.0, biases
	)

	for stat_name in StatProfiles.POKEMON:
		assert_float(block_a.get_stat(stat_name)).is_equal_approx(
			block_b.get_stat(stat_name), 0.0001
		)


# --- build_authored: parity with build_gaussian_total ---

func test_empty_biases_matches_build_gaussian_total() -> void:
	# With biases={} the authored method must produce identical output to build_gaussian_total.
	# Both factories share the same seed and consume the same RNG calls.
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 11111
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 11111

	var block_gaussian: GenericStatBlock = StatBlockFactory.new(rng_a).build_gaussian_total(
		StatProfiles.POKEMON, 300.0, 0.10, 0.0
	)
	var block_authored: GenericStatBlock = StatBlockFactory.new(rng_b).build_authored(
		StatProfiles.POKEMON, 300.0, {}, 0.10, 0.0
	)

	for stat_name in StatProfiles.POKEMON:
		assert_float(block_authored.get_stat(stat_name)).is_equal_approx(
			block_gaussian.get_stat(stat_name), 0.0001
		)


# --- add_random_accent ---

func test_add_random_accent_adds_one_stat_from_candidates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var factory := StatBlockFactory.new(rng)
	var candidates: Array[String] = [StatName.HP, StatName.ATTACK, StatName.MAGIC]
	var base: Dictionary[String, StatBiasEntry] = {}

	var result: Dictionary[String, StatBiasEntry] = factory.add_random_accent(base, candidates, 1.8)

	# Exactly one candidate should appear in the result.
	var hits: int = 0
	for c in candidates:
		if result.has(c):
			hits += 1
	assert_int(hits).is_equal(1)
	# The added entry must have the specified weight.
	for c in candidates:
		if result.has(c):
			assert_float(result[c].weight).is_equal_approx(1.8, 0.0001)


func test_add_random_accent_does_not_modify_base_dict() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var factory := StatBlockFactory.new(rng)
	var base: Dictionary[String, StatBiasEntry] = {StatName.SPEED: StatBiasEntry.new(0.3, -1)}
	var base_size_before: int = base.size()

	factory.add_random_accent(base, [StatName.HP, StatName.ATTACK])

	assert_int(base.size()).is_equal(base_size_before)


func test_add_random_accent_empty_candidates_returns_copy() -> void:
	var factory := StatBlockFactory.new()
	var base: Dictionary[String, StatBiasEntry] = {StatName.HP: StatBiasEntry.new(2.0)}
	var candidates: Array[String] = []

	var result: Dictionary[String, StatBiasEntry] = factory.add_random_accent(base, candidates)

	assert_int(result.size()).is_equal(1)
	assert_bool(result.has(StatName.HP)).is_true()


func test_add_random_accent_accent_stat_used_in_build_authored() -> void:
	# Smoke test: the result of add_random_accent is valid input for build_authored.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2025
	var factory := StatBlockFactory.new(rng)
	var base: Dictionary[String, StatBiasEntry] = {StatName.SPEED: StatBiasEntry.new(0.3, -1)}
	var accented: Dictionary[String, StatBiasEntry] = factory.add_random_accent(
		base, [StatName.HP, StatName.ATTACK, StatName.SPECIAL_ATTACK], 2.0
	)

	var block: GenericStatBlock = factory.build_authored(StatProfiles.POKEMON, 300.0, accented)

	# Basic sanity: sum is correct, speed is lowest.
	var total: float = 0.0
	for stat_name in StatProfiles.POKEMON:
		total += block.get_stat(stat_name)
	assert_float(total).is_equal_approx(300.0, 0.001)
	var speed: float = block.get_stat(StatName.SPEED)
	for stat_name in StatProfiles.POKEMON:
		assert_float(speed).is_less_equal(block.get_stat(stat_name) + 0.0001)
