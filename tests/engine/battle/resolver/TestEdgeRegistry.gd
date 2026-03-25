extends GdUnitTestSuite

const _EdgeRegistry = preload("res://engine/battle/resolver/EdgeRegistry.gd")
const _PipelineContext = preload("res://engine/battle/model/PipelineContext.gd")


func test_get_condition_returns_invalid_for_unknown_tag() -> void:
	var reg: EdgeRegistry = _EdgeRegistry.create_default()
	assert_bool(reg.get_condition("nonexistent").is_valid()).is_false()


func test_register_custom_condition_callable_is_retrievable() -> void:
	var reg: EdgeRegistry = _EdgeRegistry.create_default()
	reg.register_condition("my_cond", func(_ctx: PipelineContext, _args: Dictionary) -> bool:
		return true
	)
	assert_bool(reg.get_condition("my_cond").is_valid()).is_true()


# ============================================================
# Triple Kick loop — condition callable
# ============================================================

func test_triple_kick_loop_callable_is_registered() -> void:
	var reg: EdgeRegistry = _EdgeRegistry.create_default()
	assert_bool(reg.get_condition("triple_kick_loop").is_valid()).is_true()


func test_triple_kick_loop_returns_true_when_remaining_greater_than_zero() -> void:
	var reg: EdgeRegistry = _EdgeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.bb.write("triple_kick.hits_remaining", 2)

	var result: bool = reg.get_condition("triple_kick_loop").call(ctx, {}) as bool

	assert_bool(result).is_true()
	assert_int(ctx.bb.read("triple_kick.hits_remaining", -1) as int).is_equal(1)


func test_triple_kick_loop_decrements_on_true() -> void:
	var reg: EdgeRegistry = _EdgeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.bb.write("triple_kick.hits_remaining", 1)

	reg.get_condition("triple_kick_loop").call(ctx, {})

	assert_int(ctx.bb.read("triple_kick.hits_remaining", -1) as int).is_equal(0)


func test_triple_kick_loop_returns_false_when_remaining_is_zero() -> void:
	var reg: EdgeRegistry = _EdgeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.bb.write("triple_kick.hits_remaining", 0)

	var result: bool = reg.get_condition("triple_kick_loop").call(ctx, {}) as bool

	assert_bool(result).is_false()
	assert_int(ctx.bb.read("triple_kick.hits_remaining", -1) as int).is_equal(0)
