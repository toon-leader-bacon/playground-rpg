class_name StatBiasEntry
extends RefCounted
## Per-stat authorship hints for StatBlockFactory.build_authored().
## Plain value object — not a Godot Resource, never serialized to .tres.
##
## --- Fields ---
##
## weight (default 1.0)
##   Share of the total point pool this stat is aimed at.
##   Proportional to all other stat weights in the block.
##   weight=2.0 means this stat targets twice the points of a weight=1.0 stat.
##   Does not guarantee an exact value — the Gaussian spread still applies.
##
## rank (default 0)
##   Ordering constraint relative to all other stats in the block.
##   rank=1  → this stat must be the highest value in the final block.
##   rank=2  → this stat must be the second-highest, etc.
##   rank=-1 → this stat must be the lowest (resolved at runtime to n + rank + 1).
##   rank=-2 → second-lowest, etc.
##   rank=0  → no ordering preference; stat gets a randomly assigned value from the pool.
##   Rank reordering swaps sampled values, not means — it does not guarantee the stat
##   reaches any specific absolute value, only its relative position.
##
## min_val (default -INF) — SOFT FLOOR
##   Applied to the raw Gaussian sample before proportional scaling.
##   IMPORTANT: this is a soft floor, not a final guarantee.
##   If many stats are clamped up by min_val, the raw sum grows, the scale factor
##   drops below 1.0, and the final value may end up below min_val.
##   Use min_val to prevent degenerate near-zero samples, not to guarantee a
##   meaningful floor in the finished block. If a hard floor is required in the
##   final output, post-process with build_from_dict after generation.
##
## max_val (default INF) — HARD CEILING
##   Unlike min_val, max_val is enforced in the final output.
##   After proportional scaling, any stat exceeding max_val is capped and the
##   excess (slack) is redistributed evenly to stats without an authored max_val.
##   The final value is guaranteed to be <= max_val.
##
## std_dev_factor (default -1.0)
##   Per-stat override for Gaussian spread. Expressed as a fraction of total_points,
##   same scale as the global std_dev_factor parameter on build_authored().
##   -1.0 means "use the global factor". Set to 0.02 for a nearly-deterministic
##   stat (useful for a stat that must be precise) or 0.30+ for high variance.

var weight: float = 1.0
var rank: int = 0
var min_val: float = -INF
var max_val: float = INF
var std_dev_factor: float = -1.0


func _init(
	p_weight: float = 1.0,
	p_rank: int = 0,
	p_min_val: float = -INF,
	p_max_val: float = INF,
	p_std_dev_factor: float = -1.0
) -> void:
	weight = p_weight
	rank = p_rank
	min_val = p_min_val
	max_val = p_max_val
	std_dev_factor = p_std_dev_factor
