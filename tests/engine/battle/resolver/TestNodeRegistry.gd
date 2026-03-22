extends GdUnitTestSuite

const _NodeRegistry = preload("res://engine/battle/resolver/NodeRegistry.gd")
const _PipelineContext = preload("res://engine/battle/model/PipelineContext.gd")
const _BattleStateNvM = preload("res://engine/battle/model/BattleStateNvM.gd")


func test_always_hit_forces_hit_true() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var ctx := _PipelineContext.new()
	ctx.hit = false
	ctx.rng = RandomNumberGenerator.new()
	ctx.battle_state = null

	var fn: Callable = reg.get_accuracy_node("always_hit")
	assert_bool(fn.is_valid()).is_true()
	fn.call(ctx, [])

	assert_bool(ctx.hit).is_true()


func test_always_hit_bypasses_accuracy_regardless_of_rng() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()

	for seed_val: int in [0, 42, 999, 12345]:
		var ctx := _PipelineContext.new()
		ctx.hit = false
		ctx.rng = RandomNumberGenerator.new()
		ctx.rng.seed = seed_val
		ctx.battle_state = null
		var fn: Callable = reg.get_accuracy_node("always_hit")
		fn.call(ctx, [])
		assert_bool(ctx.hit).is_true()


func test_weather_accuracy_returns_invalid_for_unknown_tag() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var fn: Callable = reg.get_accuracy_node("nonexistent_tag")

	assert_bool(fn.is_valid()).is_false()


func test_weather_accuracy_always_hits_in_hail() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var state: BattleStateNvM = _BattleStateNvM.new()
	state.weather = WeatherType.Type.HAIL

	var args: Array = [
		{"weather": WeatherType.Type.HAIL, "accuracy_formula": "100.0"},
		{"weather": WeatherType.Type.SUN, "accuracy_formula": "30.0"},
		{"weather": -1, "accuracy_formula": "70.0"},
	]

	for i: int in range(20):
		var ctx := _PipelineContext.new()
		ctx.rng = RandomNumberGenerator.new()
		ctx.battle_state = state
		var fn: Callable = reg.get_accuracy_node("weather_accuracy")
		fn.call(ctx, args)
		assert_bool(ctx.hit).is_true()


func test_register_custom_accuracy_node() -> void:
	var reg: NodeRegistry = _NodeRegistry.create_default()
	var called: Array = [false]
	reg.register_accuracy_node("custom_node", func(ctx: Object, _args: Array) -> void:
		ctx.hit = true
		called[0] = true
	)

	var ctx := _PipelineContext.new()
	ctx.hit = false
	var fn: Callable = reg.get_accuracy_node("custom_node")
	fn.call(ctx, [])

	assert_bool(called[0]).is_true()
	assert_bool(ctx.hit).is_true()
