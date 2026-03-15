extends GdUnitTestSuite

const _SpeedBasedScheduler = preload("res://engine/battle/controller/SpeedBasedScheduler.gd")
const _BattleState = preload("res://engine/battle/model/BattleState.gd")


func test_collector_requires_default_player_and_enemy() -> void:
	var scheduler: SpeedBasedScheduler = _SpeedBasedScheduler.new()
	var collector: DecisionCollector = scheduler.next_collector()

	assert_object(collector).is_not_null()
	var fired: Array = [false]
	collector.committed.connect(func(_q: Array[Action]) -> void: fired[0] = true)

	collector.submit("player", Action.new())
	assert_bool(fired[0]).is_false()
	collector.submit("enemy", Action.new())
	assert_bool(fired[0]).is_true()


func test_collector_requires_custom_actor_list() -> void:
	var scheduler: SpeedBasedScheduler = _SpeedBasedScheduler.new(["a", "b", "c"])
	var collector: DecisionCollector = scheduler.next_collector()

	var fired: Array = [false]
	collector.committed.connect(func(_q: Array[Action]) -> void: fired[0] = true)

	collector.submit("a", Action.new())
	assert_bool(fired[0]).is_false()
	collector.submit("b", Action.new())
	assert_bool(fired[0]).is_false()
	collector.submit("c", Action.new())
	assert_bool(fired[0]).is_true()


func test_advance_increments_turn() -> void:
	var scheduler: SpeedBasedScheduler = _SpeedBasedScheduler.new()
	var state := BattleState.new()
	assert_int(state.turn).is_equal(0)

	scheduler.advance(state)

	assert_int(state.turn).is_equal(1)


func test_advance_increments_turn_multiple_times() -> void:
	var scheduler: SpeedBasedScheduler = _SpeedBasedScheduler.new()
	var state := BattleState.new()

	scheduler.advance(state)
	scheduler.advance(state)
	scheduler.advance(state)

	assert_int(state.turn).is_equal(3)
