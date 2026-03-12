extends GdUnitTestSuite


# --- construction and field defaults ---

func test_default_fields() -> void:
	var entry := StatBiasEntry.new()

	assert_float(entry.weight).is_equal_approx(1.0, 0.0001)
	assert_int(entry.rank).is_equal(0)
	assert_bool(is_finite(entry.min_val)).is_false()  # -INF
	assert_bool(is_finite(entry.max_val)).is_false()  # INF
	assert_float(entry.std_dev_factor).is_equal_approx(-1.0, 0.0001)


func test_custom_weight() -> void:
	var entry := StatBiasEntry.new(2.5)

	assert_float(entry.weight).is_equal_approx(2.5, 0.0001)
	assert_int(entry.rank).is_equal(0)


func test_positive_rank() -> void:
	var entry := StatBiasEntry.new(1.0, 2)

	assert_int(entry.rank).is_equal(2)


func test_negative_rank_stored_as_is() -> void:
	# Negative ranks are stored verbatim; resolution happens inside build_authored.
	var entry_neg1 := StatBiasEntry.new(1.0, -1)
	var entry_neg2 := StatBiasEntry.new(1.0, -2)

	assert_int(entry_neg1.rank).is_equal(-1)
	assert_int(entry_neg2.rank).is_equal(-2)


func test_min_val_and_max_val() -> void:
	var entry := StatBiasEntry.new(1.0, 0, 10.0, 80.0)

	assert_float(entry.min_val).is_equal_approx(10.0, 0.0001)
	assert_float(entry.max_val).is_equal_approx(80.0, 0.0001)


func test_std_dev_factor_override() -> void:
	var entry := StatBiasEntry.new(1.0, 0, -INF, INF, 0.05)

	assert_float(entry.std_dev_factor).is_equal_approx(0.05, 0.0001)


func test_negative_rank_minus1_resolves_to_lowest_in_build_authored() -> void:
	# Verify that rank=-1 in a 6-stat block causes the stat to be the lowest value.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var factory := StatBlockFactory.new(rng)
	var biases: Dictionary[String, StatBiasEntry] = {StatName.SPEED: StatBiasEntry.new(1.0, -1)}

	var block: GenericStatBlock = factory.build_authored(StatProfiles.POKEMON, 300.0, biases, 0.10)

	var speed: float = block.get_stat(StatName.SPEED)
	for stat_name in StatProfiles.POKEMON:
		assert_float(speed).is_less_equal(block.get_stat(stat_name) + 0.0001)


func test_negative_rank_minus2_resolves_to_second_lowest_in_build_authored() -> void:
	# rank=-2 → second lowest; the stat must be <= all others except the actual lowest.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999
	var factory := StatBlockFactory.new(rng)
	# SPEED rank=-1 (lowest), DEFENSE rank=-2 (second lowest)
	var biases: Dictionary[String, StatBiasEntry] = {
		StatName.SPEED: StatBiasEntry.new(1.0, -1),
		StatName.DEFENSE: StatBiasEntry.new(1.0, -2),
	}

	var block: GenericStatBlock = factory.build_authored(StatProfiles.POKEMON, 300.0, biases, 0.05)

	var speed: float = block.get_stat(StatName.SPEED)
	var defense: float = block.get_stat(StatName.DEFENSE)
	# defense should be >= speed (speed is lowest)
	assert_float(defense).is_greater_equal(speed - 0.0001)
	# defense should be <= all unranked stats
	for stat_name in StatProfiles.POKEMON:
		if stat_name == StatName.SPEED or stat_name == StatName.DEFENSE:
			continue
		assert_float(defense).is_less_equal(block.get_stat(stat_name) + 0.0001)
