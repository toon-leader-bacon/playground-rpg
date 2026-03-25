class_name BattleFsm
extends RefCounted
## Directed graph FSM for battle move resolution.
##
## Nodes: named Callables — func(ctx: PipelineContext) -> void
## Edges: ordered FsmEdge list — first matching edge out of the current node is followed.
##
## START and END are always present no-op nodes. The runner begins at START and
## halts when it reaches END. Neither node is ever replaced by move overrides,
## but moves may add edges out of START or edges targeting END.

const START: String = "START"
const END: String = "END"

var _nodes: Dictionary[String, Callable] = {}
var _edges: Array[FsmEdge] = []


func _init() -> void:
	var noop := func(_ctx: PipelineContext) -> void: pass
	_nodes[START] = noop
	_nodes[END] = noop


## Add or replace a node by id.
func add_node(id: String, fn: Callable) -> void:
	_nodes[id] = fn


## Return the current callable for a node id, or an invalid Callable if not found.
func get_node(id: String) -> Callable:
	return _nodes.get(id, Callable())


## Append an edge. Edges from the same node are evaluated in the order they were added.
func add_edge(edge: FsmEdge) -> void:
	_edges.append(edge)


## Insert edge before the first existing edge from the same source node.
## If no existing edge shares the source, appends to end.
## Use this when a conditional back-edge must be checked before the default
## unconditional forward-edge from the same node (first-match-wins).
func insert_edge_before_source(edge: FsmEdge) -> void:
	for i: int in range(_edges.size()):
		if _edges[i].from == edge.from:
			_edges.insert(i, edge)
			return
	_edges.append(edge)


## Execute the FSM from START to END, mutating ctx at each node.
func run(ctx: PipelineContext) -> void:
	var current: String = START
	while current != END:
		if not _nodes.has(current):
			push_error("BattleFsm: unknown node '%s'" % current)
			return
		_nodes[current].call(ctx)
		current = _resolve_next(current, ctx)


func _resolve_next(from: String, ctx: PipelineContext) -> String:
	for edge: FsmEdge in _edges:
		if edge.from != from:
			continue
		if not edge.condition.is_valid() or edge.condition.call(ctx):
			return edge.to
	push_error("BattleFsm: no valid edge out of node '%s'" % from)
	return END
