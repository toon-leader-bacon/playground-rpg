class_name FsmEdge
extends RefCounted
## A directed edge in a BattleFsm graph.
## Edges from the same node are evaluated in declaration order;
## the first edge whose condition passes is followed.
## An edge with no condition (invalid Callable) is always followed.

var from: String = ""
var to: String = ""
## func(ctx: PipelineContext) -> bool. If invalid, the edge is unconditional.
var condition: Callable


## Creates an unconditional edge from → to.
static func always(from_node: String, to_node: String) -> FsmEdge:
	var edge := FsmEdge.new()
	edge.from = from_node
	edge.to = to_node
	return edge


## Creates a conditional edge from → to, followed only when cond(ctx) returns true.
static func when(from_node: String, to_node: String, cond: Callable) -> FsmEdge:
	var edge := FsmEdge.new()
	edge.from = from_node
	edge.to = to_node
	edge.condition = cond
	return edge
