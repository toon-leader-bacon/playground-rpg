extends GdUnitTestSuite

const _DecisionCollector = preload("res://engine/battle/controller/DecisionCollector.gd")
const _Action = preload("res://engine/battle/model/Action.gd")


func test_committed_fires_when_all_submitted() -> void:
	var collector: DecisionCollector = _DecisionCollector.create_all_submitted(["player", "enemy"])
	# Use array so lambda mutation is visible to outer scope (GDScript lambda rebinding limitation)
	var fired: Array = [false]
	collector.committed.connect(func(_q: Array[Action]) -> void: fired[0] = true)

	collector.submit("player", _dummy_action())
	assert_bool(fired[0]).is_false()
	collector.submit("enemy", _dummy_action())

	assert_bool(fired[0]).is_true()


func test_committed_fires_exactly_once() -> void:
	var collector: DecisionCollector = _DecisionCollector.create_all_submitted(["player"])
	var count: Array = [0]
	collector.committed.connect(func(_q: Array[Action]) -> void: count[0] += 1)

	collector.submit("player", _dummy_action())

	assert_int(count[0]).is_equal(1)


func test_is_committed_guard() -> void:
	var collector: DecisionCollector = _DecisionCollector.create_all_submitted(["player"])
	assert_bool(collector.is_committed).is_false()

	collector.submit("player", _dummy_action())

	assert_bool(collector.is_committed).is_true()


func test_queue_order_matches_required_actors() -> void:
	var collector: DecisionCollector = _DecisionCollector.create_all_submitted(["player", "enemy"])
	var action_p: Action = _dummy_action()
	var action_e: Action = _dummy_action()
	# Use array; replace contents via clear+append (mutation, not rebinding)
	var received_queue: Array = []
	collector.committed.connect(func(q: Array[Action]) -> void:
		received_queue.clear()
		for item: Action in q:
			received_queue.append(item)
	)

	collector.submit("enemy", action_e)
	collector.submit("player", action_p)

	# Queue order should match required_actors order: player first, then enemy
	assert_int(received_queue.size()).is_equal(2)
	assert_object(received_queue[0]).is_equal(action_p)
	assert_object(received_queue[1]).is_equal(action_e)


func test_explicit_end_commits_on_end_phase() -> void:
	var collector := DecisionCollector.new()
	collector._mode = DecisionCollector.Mode.EXPLICIT_END
	var fired: Array = [false]
	collector.committed.connect(func(_q: Array[Action]) -> void: fired[0] = true)

	collector.end_phase()

	assert_bool(fired[0]).is_true()


# --- Helpers ---

func _dummy_action() -> Action:
	return _Action.new()
