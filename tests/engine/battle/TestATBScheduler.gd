extends GdUnitTestSuite
## Unit tests for ATBScheduler.
## All tests are fully synchronous — no scene tree required.

const _ATBScheduler = preload("res://engine/battle/controller/ATBScheduler.gd")


# --- Helpers ---

func _make_actor(speed: int) -> MonsterInstance:
	var config := MonsterConfig.new()
	config.id = "test"
	config.display_name = "Test"
	var stats := StatBlock.new()
	stats.max_hp = 100
	stats.attack = 10
	stats.defense = 10
	stats.speed = speed
	config.base_stats = stats
	config.type_tags = [TypeTag.Type.NORMAL]
	config.ai_style = MonsterConfig.AIStyle.RANDOM
	return MonsterInstance.create(config, 1)


func _make_scheduler_1(speed: int) -> _ATBScheduler:
	var actor := _make_actor(speed)
	return _ATBScheduler.new({"a": actor})


# --- Tests ---

func test_has_ready_false_initially() -> void:
	var sched := _make_scheduler_1(10)
	assert_bool(sched.has_ready()).is_false()


func test_gauge_fills_and_emits_actor_ready() -> void:
	var sched := _make_scheduler_1(10)
	var fired: Array = [false]
	sched.actor_ready.connect(func(_id: String) -> void: fired[0] = true)

	# speed=10, FILL_RATE=10, delta=1.0 → fills 100 exactly → triggers
	sched.tick(1.0)

	assert_bool(sched.has_ready()).is_true()
	assert_bool(fired[0]).is_true()


func test_gauge_resets_to_zero_after_fill() -> void:
	var sched := _make_scheduler_1(10)
	sched.tick(1.0)
	sched.pop_next_ready()
	assert_float(sched.get_gauge("a")).is_equal(0.0)


func test_fill_rate_proportional_to_speed() -> void:
	var fast := _make_actor(20)
	var slow := _make_actor(10)
	var sched := _ATBScheduler.new({"fast": fast, "slow": slow})

	# delta small enough that neither fills completely
	sched.tick(0.3)

	var fast_gauge: float = sched.get_gauge("fast")
	var slow_gauge: float = sched.get_gauge("slow")
	# fast should be exactly 2× slow
	assert_float(fast_gauge).is_equal_approx(slow_gauge * 2.0, 0.001)


func test_fifo_ordering() -> void:
	# Give actor A a head start so it fills first, then B fills in same tick
	var a := _make_actor(10)
	var b := _make_actor(10)
	var sched := _ATBScheduler.new({"a": a, "b": b})

	# Pre-charge A to 90, B to 50
	sched.set_gauge("a", 90.0)
	sched.set_gauge("b", 50.0)

	# delta=1.0 → a gains 100 (overflows first at iteration order), b gains 50 (now 100, overflows second)
	# Both will overflow in this tick
	sched.tick(1.0)

	assert_bool(sched.has_ready()).is_true()
	var first: String = sched.pop_next_ready()
	var second: String = sched.pop_next_ready()
	assert_str(first).is_equal("a")
	assert_str(second).is_equal("b")


func test_pause_prevents_fill() -> void:
	var sched := _make_scheduler_1(10)
	var fired: Array = [false]
	sched.actor_ready.connect(func(_id: String) -> void: fired[0] = true)

	sched.set_paused(true)
	sched.tick(1.0)
	sched.tick(1.0)
	sched.tick(1.0)

	assert_bool(fired[0]).is_false()
	assert_bool(sched.has_ready()).is_false()
	assert_float(sched.get_gauge("a")).is_equal(0.0)


func test_resume_continues_filling() -> void:
	var sched := _make_scheduler_1(10)

	# Fill halfway, pause, try to fill more, resume, fill to completion
	sched.tick(0.5)  # gauge = 50
	assert_float(sched.get_gauge("a")).is_equal_approx(50.0, 0.001)

	sched.set_paused(true)
	sched.tick(1.0)  # should not advance
	assert_float(sched.get_gauge("a")).is_equal_approx(50.0, 0.001)

	sched.set_paused(false)
	sched.tick(0.5)  # fills remaining 50 → actor_ready
	assert_bool(sched.has_ready()).is_true()


func test_set_gauge_clamps_below_max() -> void:
	var sched := _make_scheduler_1(10)
	var fired: Array = [false]
	sched.actor_ready.connect(func(_id: String) -> void: fired[0] = true)

	sched.set_gauge("a", 200.0)  # should clamp to just below GAUGE_MAX

	assert_bool(fired[0]).is_false()
	assert_bool(sched.has_ready()).is_false()
	assert_float(sched.get_gauge("a")).is_less(ATBScheduler.GAUGE_MAX)


func test_fainted_actor_not_ticked() -> void:
	var actor := _make_actor(10)
	actor.apply_damage(actor.max_hp())  # faint it
	var sched := _ATBScheduler.new({"a": actor})

	assert_bool(actor.is_fainted()).is_true()

	var fired: Array = [false]
	sched.actor_ready.connect(func(_id: String) -> void: fired[0] = true)

	sched.tick(10.0)  # large delta, would fill many times if not fainted

	assert_bool(fired[0]).is_false()
	assert_bool(sched.has_ready()).is_false()


func test_is_paused_reflects_state() -> void:
	var sched := _make_scheduler_1(10)
	assert_bool(sched.is_paused()).is_false()
	sched.set_paused(true)
	assert_bool(sched.is_paused()).is_true()
	sched.set_paused(false)
	assert_bool(sched.is_paused()).is_false()


func test_get_all_gauges_returns_copy() -> void:
	var sched := _make_scheduler_1(10)
	sched.tick(0.5)
	var snapshot: Dictionary = sched.get_all_gauges()
	assert_bool(snapshot.has("a")).is_true()
	# Mutating the copy should not affect the scheduler
	snapshot["a"] = 0.0
	assert_float(sched.get_gauge("a")).is_greater(0.0)


func test_pop_next_ready_removes_from_queue() -> void:
	var sched := _make_scheduler_1(10)
	sched.tick(1.0)
	assert_bool(sched.has_ready()).is_true()
	sched.pop_next_ready()
	assert_bool(sched.has_ready()).is_false()
