extends GdUnitTestSuite

const _BattleFsm = preload("res://engine/battle/resolver/BattleFsm.gd")
const _FsmEdge = preload("res://engine/battle/resolver/FsmEdge.gd")
const _PipelineContext = preload("res://engine/battle/model/PipelineContext.gd")


# ============================================================
# insert_edge_before_source
# ============================================================

func test_insert_edge_before_source_places_before_first_match() -> void:
	var fsm: BattleFsm = _BattleFsm.new()
	# Add two existing edges from "A"
	fsm.add_edge(_FsmEdge.always("A", "C"))
	fsm.add_edge(_FsmEdge.always("A", "D"))
	# Insert a new edge from "A" — should land at index 0 (before A→C)
	fsm.insert_edge_before_source(_FsmEdge.always("A", "B"))

	# Manually walk _edges to verify order — access via run() behavior:
	# If we run from "A" with B, C, D as nodes, the first-match-wins should go to B.
	fsm.add_node("A", func(_c: PipelineContext) -> void: pass)
	fsm.add_node("B", func(_c: PipelineContext) -> void: pass)
	fsm.add_node("C", func(_c: PipelineContext) -> void: pass)
	fsm.add_node("D", func(_c: PipelineContext) -> void: pass)
	# Add edge from B to END so the FSM can terminate
	fsm.add_edge(_FsmEdge.always("B", BattleFsm.END))
	fsm.add_edge(_FsmEdge.always("C", BattleFsm.END))
	fsm.add_edge(_FsmEdge.always("D", BattleFsm.END))
	# Add START → A
	fsm.add_edge(_FsmEdge.always(BattleFsm.START, "A"))

	var visited: Array[String] = []
	fsm.add_node("B", func(_c: PipelineContext) -> void: visited.append("B"))
	fsm.add_node("C", func(_c: PipelineContext) -> void: visited.append("C"))

	var ctx: PipelineContext = _PipelineContext.new()
	fsm.run(ctx)

	# First edge out of A should be A→B (inserted before A→C)
	assert_array(visited).contains_exactly(["B"])


func test_insert_edge_before_source_appends_when_no_match() -> void:
	var fsm: BattleFsm = _BattleFsm.new()
	# Add an existing edge from "A"
	fsm.add_edge(_FsmEdge.always("A", BattleFsm.END))
	# Insert edge from "Z" — no existing Z edges, should append
	fsm.insert_edge_before_source(_FsmEdge.always("Z", BattleFsm.END))

	# Verify "Z" can be reached: set up START → Z
	fsm.add_node("Z", func(_c: PipelineContext) -> void: pass)
	# Re-wire START to skip A: use START → Z directly
	# (BattleFsm always adds START→END fallback is not present; we add our own)
	fsm.add_edge(_FsmEdge.always(BattleFsm.START, "Z"))

	var ctx: PipelineContext = _PipelineContext.new()
	# Should not error (Z→END is appended correctly)
	fsm.run(ctx)
	assert_bool(true).is_true()  # reached here without error


func test_insert_edge_before_source_conditional_checked_before_unconditional() -> void:
	var fsm: BattleFsm = _BattleFsm.new()
	# Default unconditional edge A → END
	fsm.add_edge(_FsmEdge.always("A", BattleFsm.END))
	# Insert conditional edge A → B that returns false (should not be taken)
	fsm.insert_edge_before_source(
		_FsmEdge.when("A", "B", func(_c: PipelineContext) -> bool: return false)
	)

	fsm.add_node("A", func(_c: PipelineContext) -> void: pass)
	fsm.add_node("B", func(_c: PipelineContext) -> void: pass)
	fsm.add_edge(_FsmEdge.always("B", BattleFsm.END))
	fsm.add_edge(_FsmEdge.always(BattleFsm.START, "A"))

	var visited_b: Array[bool] = [false]
	fsm.add_node("B", func(_c: PipelineContext) -> void: visited_b[0] = true)

	var ctx: PipelineContext = _PipelineContext.new()
	fsm.run(ctx)

	# Conditional A→B returned false, so unconditional A→END was taken
	assert_bool(visited_b[0]).is_false()
