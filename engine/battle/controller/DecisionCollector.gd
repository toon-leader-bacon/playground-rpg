class_name DecisionCollector
extends RefCounted
## Collects action decisions from required actors, fires `committed` exactly once
## when the completion condition is met.

signal committed(queue: Array[Action])

enum Mode { ALL_SUBMITTED, EXPLICIT_END }

var is_committed: bool = false
## The ordered action queue, populated when committed fires. Read after is_committed is true.
var queue: Array[Action] = []

var _mode: Mode = Mode.ALL_SUBMITTED
var _required_actors: Array[String] = []
var _submissions: Dictionary[String, Action] = {}


## Create a collector that commits when all listed actors have submitted.
static func create_all_submitted(actors: Array[String]) -> DecisionCollector:
	var c := DecisionCollector.new()
	c._mode = Mode.ALL_SUBMITTED
	for actor_id: String in actors:
		c._required_actors.append(actor_id)
	return c


## Submit an action for an actor. Asserts no double-submit and that actor is required.
func submit(actor_id: String, action: Action) -> void:
	assert(actor_id in _required_actors,
		"DecisionCollector: actor '%s' is not in required list" % actor_id)
	assert(not _submissions.has(actor_id),
		"DecisionCollector: actor '%s' already submitted" % actor_id)
	_submissions[actor_id] = action
	_try_commit()


## Signal the end of a phase (EXPLICIT_END mode only).
func end_phase() -> void:
	assert(_mode == Mode.EXPLICIT_END, "end_phase() called on ALL_SUBMITTED collector")
	_try_commit()


func _try_commit() -> void:
	if is_committed:
		return
	var should_commit: bool = false
	match _mode:
		Mode.ALL_SUBMITTED:
			should_commit = _submissions.size() == _required_actors.size()
		Mode.EXPLICIT_END:
			should_commit = true
	if should_commit:
		is_committed = true
		for actor_id: String in _required_actors:
			if _submissions.has(actor_id):
				queue.append(_submissions[actor_id])
		committed.emit(queue)
