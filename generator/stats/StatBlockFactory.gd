class_name StatBlockFactory
extends RefCounted
## Factory for producing GenericStatBlock resources.
##
## All build methods accept stat name arrays from StatProfiles (or custom arrays).
## Always inject a seeded RNG via _init() when you need deterministic output —
## for tests, procedural generation with a reproducible seed, or saving a monster
## such that it can be regenerated identically later.
##
## Method overview (simplest to most expressive):
##   build_empty()          — zeroed block; fill by hand
##   build_from_values()    — parallel name/value arrays; deterministic
##   build_from_dict()      — dict literal; deterministic
##   build_random()         — uniform random per stat; no sum guarantee
##   build_random_ranged()  — per-stat uniform ranges; no sum guarantee
##   build_gaussian_total() — Gaussian spread with exact total_points sum
##   build_authored()       — Gaussian + weight/rank/bound constraints; exact sum

var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator = null) -> void:
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()


## Returns a GenericStatBlock with every stat in stat_names initialised to 0.0.
## Use as a starting point before assigning values by hand or with build_from_dict().
func build_empty(stat_names: Array[String]) -> GenericStatBlock:
	var block := GenericStatBlock.new()
	for stat_name: String in stat_names:
		block.stats[stat_name] = 0.0
	return block


## Returns a GenericStatBlock from parallel arrays of names and values.
## stat_names[i] is paired with values[i]. Arrays must be the same length.
## Prefer this over build_from_dict() when you already have ordered value arrays
## (e.g. the output of a generation step).
func build_from_values(stat_names: Array[String], values: Array[float]) -> GenericStatBlock:
	assert(stat_names.size() == values.size(), "stat_names and values must have the same length")
	var block := GenericStatBlock.new()
	for i: int in range(stat_names.size()):
		block.stats[stat_names[i]] = values[i]
	return block


## Returns a GenericStatBlock from an explicit { stat_name: value } dictionary.
## Convenient for hand-authored blocks with named keys (e.g. boss stat overrides).
func build_from_dict(values: Dictionary) -> GenericStatBlock:
	var block := GenericStatBlock.new()
	for key in values.keys():
		block.stats[str(key)] = float(values[key])
	return block


## Returns a GenericStatBlock with every stat sampled uniformly from [min_val, max_val].
## No sum guarantee — totals will vary each call. Use build_gaussian_total() if
## a fixed budget matters (e.g. balanced encounter design).
func build_random(stat_names: Array[String], min_val: float, max_val: float) -> GenericStatBlock:
	var block := GenericStatBlock.new()
	for stat_name: String in stat_names:
		block.stats[stat_name] = rng.randf_range(min_val, max_val)
	return block


## Returns a GenericStatBlock with independent per-stat uniform ranges.
## ranges_dict maps stat_name (String) -> [min_val, max_val] (Array of two floats).
## No sum guarantee. Useful for fixed-range loot tables or hand-tuned stat
## bands where each stat is designed independently.
func build_random_ranged(ranges_dict: Dictionary) -> GenericStatBlock:
	var block := GenericStatBlock.new()
	for stat_name in ranges_dict.keys():
		var range_arr: Array = ranges_dict[stat_name]
		block.stats[str(stat_name)] = rng.randf_range(float(range_arr[0]), float(range_arr[1]))
	return block


## Returns a GenericStatBlock where the sum of all stats equals total_points exactly.
##
## Each stat is sampled from a Gaussian centred at (total_points / n) with
## std_dev = std_dev_factor * total_points. After sampling, values are clamped
## to min_per_stat, then proportionally scaled so the total is guaranteed.
##
## std_dev_factor guide:
##   0.02  — nearly even distribution; every stat within a few % of the mean
##   0.10  — mild variance; typical balanced creature (default)
##   0.20  — noticeable specialisation; one or two stats stand out
##   0.40+ — glass cannon / tank territory; extreme variance
##
## min_per_stat is a SOFT floor applied before scaling. Clamping many stats up
## increases the raw sum, which reduces the scale factor, which may push the
## final values below min_per_stat. Use it to avoid near-zero samples, not to
## guarantee a meaningful floor in the finished block.
##
## Use build_authored() instead if you need weight, rank, or per-stat bound control.
func build_gaussian_total(
	stat_names: Array[String],
	total_points: float,
	std_dev_factor: float = 0.10,
	min_per_stat: float = 0.0
) -> GenericStatBlock:
	var n: int = stat_names.size()
	assert(n > 0, "stat_names must not be empty")
	assert(total_points > 0.0, "total_points must be positive")

	var mean: float = total_points / float(n)
	var std_dev: float = std_dev_factor * total_points

	var raw: Array[float] = []
	for _i: int in range(n):
		raw.append(maxf(_sample_gaussian(mean, std_dev), min_per_stat))

	# Proportional scaling: preserves relative shape, guarantees sum == total_points.
	var raw_sum: float = 0.0
	for v: float in raw:
		raw_sum += v

	var values: Array[float] = []
	if raw_sum > 0.0:
		var scale: float = total_points / raw_sum
		for v: float in raw:
			values.append(v * scale)
	else:
		# Degenerate case: all samples were clamped to 0; fall back to even split.
		for _i: int in range(n):
			values.append(mean)

	return build_from_values(stat_names, values)


## Constraint-driven authored generation with Gaussian randomness for unspecified stats.
## This is the primary generation method for zone-aware monster design.
##
## biases: Dictionary mapping stat_name (String) → StatBiasEntry.
##   Absent stats get weight=1.0, rank=0, and the global std_dev_factor/min_per_stat.
##   See StatBiasEntry and StatArchetypes for helpers that build these dicts.
##
## --- Algorithm ---
##
##   1. Resolve negative ranks: rank=-1 → n + (-1) + 1 = n (lowest position),
##      rank=-2 → second-lowest, etc. Clamped to [1, n]. Duplicate resolved ranks
##      emit push_error and the later entry's rank constraint is dropped.
##   2. Compute per-stat means: mean_i = (weight_i / total_weight) * total_points.
##      Stats absent from biases use weight=1.0.
##   3. Sample each stat from Normal(mean_i, dev_i) where
##      dev_i = (bias.std_dev_factor if set, else global std_dev_factor) * total_points.
##   4. Clamp each raw sample: max(global_min_per_stat, bias.min_val) … bias.max_val.
##      NOTE: min_val is a SOFT floor — see below.
##   5. Rank ordering (only if any bias has rank > 0):
##      Sort all sampled values descending → the pool. Assign pool[rank-1] to each
##      ranked stat. Remaining pool positions are shuffled randomly among unranked stats.
##      Effect: rank=1 stat always receives the largest sampled value; rank=-1 stat
##      always receives the smallest. Bounds take priority over rank (applied first).
##   6. Proportionally scale the reordered values so sum == total_points exactly.
##   7. Re-clamp any authored max_val in the scaled output. Excess (slack) is
##      redistributed evenly among stats with no authored max_val.
##      max_val IS guaranteed in the final output. min_val is NOT — see below.
##
## --- min_val vs max_val behaviour after scaling ---
##
##   max_val is a HARD ceiling. It is enforced again after scaling (step 7) and
##   surplus is redistributed, so the final value is guaranteed <= max_val.
##
##   min_val is a SOFT floor. It clamps the raw Gaussian sample (step 4) but is
##   not re-applied after proportional scaling. If multiple stats are clamped
##   upward, the raw sum grows, the scale factor drops below 1.0, and any
##   min_val-constrained stat can end up below its floor in the final block.
##   Use min_val to guard against degenerate near-zero samples, not to express
##   a meaningful design floor. If a hard floor is required, post-process the
##   block manually after generation.
##
## --- Usage example: swamp zone ---
##
##   # Shared base: defense-heavy, always slowest.
##   var swamp_base: Dictionary = {
##       StatName.DEFENSE: StatBiasEntry.new(2.5, 1),   # always highest
##       StatName.SPEED:   StatBiasEntry.new(0.3, -1),  # always lowest
##   }
##
##   # Per-creature accent: one random secondary specialty per monster.
##   var biases: Dictionary = factory.add_random_accent(
##       swamp_base, [StatName.HP, StatName.ATTACK, StatName.MAGIC], 1.5
##   )
##   var stats: GenericStatBlock = factory.build_authored(StatProfiles.POKEMON, 300.0, biases)
##
##   # Zone boss: defense still dominant, unusually fast for the zone, tighter variance.
##   var boss_biases: Dictionary = {
##       StatName.DEFENSE: StatBiasEntry.new(3.0, 1),
##       StatName.SPEED:   StatBiasEntry.new(2.0, 2),   # rank=2: fast but not highest
##   }
##   var boss: GenericStatBlock = factory.build_authored(
##       StatProfiles.POKEMON, 500.0, boss_biases, 0.05
##   )
##
## Calling with biases={} reproduces build_gaussian_total() exactly (same RNG path,
## no extra calls — the rank-reorder step is skipped entirely when no ranks are set).
func build_authored(
	stat_names: Array[String],
	total_points: float,
	biases: Dictionary = {},
	std_dev_factor: float = 0.10,
	min_per_stat: float = 0.0
) -> GenericStatBlock:
	var n: int = stat_names.size()
	assert(n > 0, "stat_names must not be empty")
	assert(total_points > 0.0, "total_points must be positive")

	# Step 1: Validate and resolve ranks.
	# bias_data mirrors biases but with rank already resolved to an absolute position [1,n].
	var bias_data: Dictionary = {}  # stat_name -> {weight, rank, min_val, max_val, std_dev_factor}
	var seen_ranks: Dictionary = {}  # resolved_rank(int) -> stat_name(String)

	for key in biases.keys():
		var stat_name: String = str(key)
		var bias: StatBiasEntry = biases[key]
		var resolved_rank: int = bias.rank
		if bias.rank < 0:
			resolved_rank = clampi(n + bias.rank + 1, 1, n)
		bias_data[stat_name] = {
			"weight": bias.weight,
			"rank": resolved_rank,
			"min_val": bias.min_val,
			"max_val": bias.max_val,
			"std_dev_factor": bias.std_dev_factor,
		}
		if resolved_rank > 0:
			if seen_ranks.has(resolved_rank):
				push_error(
					"StatBlockFactory.build_authored: duplicate resolved rank %d for '%s' (conflicts with '%s'); dropping rank constraint" % [
						resolved_rank, stat_name, seen_ranks[resolved_rank]
					]
				)
				bias_data[stat_name]["rank"] = 0
			else:
				seen_ranks[resolved_rank] = stat_name

	# Step 2: Compute total weight for proportional mean assignment.
	var total_weight: float = 0.0
	for stat_name in stat_names:
		total_weight += float(bias_data[stat_name]["weight"]) if bias_data.has(stat_name) else 1.0

	# Step 3 & 4: Sample from Gaussian and apply per-stat absolute bounds.
	var raw: Array[float] = []
	for stat_name in stat_names:
		var b_weight: float = 1.0
		var b_sdf: float = std_dev_factor
		var eff_min: float = min_per_stat
		var eff_max: float = INF

		if bias_data.has(stat_name):
			var b: Dictionary = bias_data[stat_name]
			b_weight = float(b["weight"])
			if float(b["std_dev_factor"]) >= 0.0:
				b_sdf = float(b["std_dev_factor"])
			if is_finite(float(b["min_val"])):
				eff_min = maxf(min_per_stat, float(b["min_val"]))
			if is_finite(float(b["max_val"])):
				eff_max = float(b["max_val"])

		var mean: float = (b_weight / total_weight) * total_points
		var dev: float = b_sdf * total_points
		var val: float = _sample_gaussian(mean, dev)
		val = maxf(val, eff_min)
		if is_finite(eff_max):
			val = minf(val, eff_max)
		raw.append(val)

	# Step 5: Apply rank ordering.
	# Skip entirely when no rank constraints — preserves exact RNG parity with build_gaussian_total.
	var has_ranks: bool = false
	for stat_name in bias_data.keys():
		if int(bias_data[stat_name]["rank"]) > 0:
			has_ranks = true
			break

	var reordered: Array[float] = raw.duplicate()
	if has_ranks:
		var sorted_values: Array[float] = raw.duplicate()
		sorted_values.sort()
		sorted_values.reverse()  # descending: index 0 = highest

		# Map each ranked stat to its claimed sorted position.
		var claimed: Dictionary = {}     # position(int) -> stat_index(int)
		var stat_pos: Dictionary = {}    # stat_index(int) -> position(int)
		for i in range(n):
			var stat_name: String = stat_names[i]
			if bias_data.has(stat_name):
				var r: int = int(bias_data[stat_name]["rank"])
				if r > 0 and r <= n:
					var pos: int = r - 1
					claimed[pos] = i
					stat_pos[i] = pos

		# Collect free positions for random assignment to unranked stats.
		var free_positions: Array[int] = []
		for pos in range(n):
			if not claimed.has(pos):
				free_positions.append(pos)

		# Fisher-Yates shuffle of free positions.
		for i in range(free_positions.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: int = free_positions[i]
			free_positions[i] = free_positions[j]
			free_positions[j] = tmp

		reordered.resize(n)
		var free_idx: int = 0
		for i in range(n):
			if stat_pos.has(i):
				reordered[i] = sorted_values[int(stat_pos[i])]
			else:
				reordered[i] = sorted_values[free_positions[free_idx]]
				free_idx += 1

	# Step 6: Proportional scale to guarantee sum == total_points.
	var raw_sum: float = 0.0
	for v: float in reordered:
		raw_sum += v

	var final_values: Array[float] = []
	if raw_sum > 0.0:
		var scale: float = total_points / raw_sum
		for v: float in reordered:
			final_values.append(v * scale)
	else:
		for _i in range(n):
			final_values.append(total_points / float(n))

	# Post-scaling: re-clamp authored max_val; redistribute slack to unconstrained stats.
	var slack: float = 0.0
	var unconstrained_indices: Array[int] = []
	for i in range(n):
		var stat_name: String = stat_names[i]
		if bias_data.has(stat_name) and is_finite(float(bias_data[stat_name]["max_val"])):
			var cap: float = float(bias_data[stat_name]["max_val"])
			if final_values[i] > cap:
				slack += final_values[i] - cap
				final_values[i] = cap
		else:
			unconstrained_indices.append(i)

	if slack > 0.0 and unconstrained_indices.size() > 0:
		var per_stat: float = slack / float(unconstrained_indices.size())
		for i in unconstrained_indices:
			final_values[i] += per_stat

	return build_from_values(stat_names, final_values)


## Shallow-copies base_biases, picks one random stat from candidate_stats,
## and upserts a StatBiasEntry with the given accent_weight for that stat.
## Uses the factory's own RNG. Returns the modified copy; base_biases is unchanged.
##
## Intended use: apply a shared zone archetype to every monster in the zone,
## then call add_random_accent once per creature to give each one a unique secondary
## strength drawn from a curated pool. Combine with build_authored() immediately after:
##
##   var biases: Dictionary = factory.add_random_accent(
##       StatArchetypes.tank(), [StatName.MAGIC, StatName.ATTACK], 1.8
##   )
##   var block: GenericStatBlock = factory.build_authored(StatProfiles.POKEMON, 300.0, biases)
##
## If candidate_stats is empty, returns an unmodified copy of base_biases.
## If the chosen stat already exists in base_biases, its entry is replaced entirely
## (weight is set to accent_weight, all other fields reset to defaults).
func add_random_accent(
	base_biases: Dictionary,
	candidate_stats: Array[String],
	accent_weight: float = 1.5
) -> Dictionary:
	var result: Dictionary = base_biases.duplicate()
	if candidate_stats.is_empty():
		return result
	var idx: int = rng.randi_range(0, candidate_stats.size() - 1)
	result[candidate_stats[idx]] = StatBiasEntry.new(accent_weight)
	return result


## Box-Muller transform — samples one value from Normal(mean, std_dev).
## u1 is clamped away from 0 to avoid log(0). Consumes two RNG calls per invocation;
## callers that need RNG parity across methods must account for this.
func _sample_gaussian(mean: float, std_dev: float) -> float:
	var u1: float = maxf(rng.randf(), 1e-10)  # avoid log(0)
	var u2: float = rng.randf()
	var z: float = sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return mean + std_dev * z
