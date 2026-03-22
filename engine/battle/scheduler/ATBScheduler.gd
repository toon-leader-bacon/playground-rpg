class_name ATBScheduler
extends RefCounted
## Manages per-combatant ATB gauges (0–GAUGE_MAX).
## tick(delta) fills gauges proportional to each actor's effective_speed().
## When a gauge crosses GAUGE_MAX the actor is added to a FIFO ready queue and gauge resets to 0.
## Pause/resume freezes all gauge advancement (Wait mode).
## Public get/set gauge allows status effects to modify gauges externally.

signal actor_ready(actor_id: String)

const GAUGE_MAX: float = 100.0
const FILL_RATE_CONSTANT: float = 10.0

var _gauges: Dictionary[String, float] = {}
var _instances: Dictionary[String, MonsterInstance] = {}
var _ready_queue: Array[String] = []
var _paused: bool = false


func _init(actor_instances: Dictionary) -> void:
	for actor_id: String in actor_instances:
		_instances[actor_id] = actor_instances[actor_id] as MonsterInstance
		_gauges[actor_id] = 0.0


## Advance all non-fainted actor gauges by speed-based amount.
## Emits actor_ready and enqueues actor when gauge crosses GAUGE_MAX.
func tick(delta: float) -> void:
	if _paused:
		return
	for actor_id: String in _gauges:
		var monster: MonsterInstance = _instances[actor_id]
		if monster.is_fainted():
			continue
		_gauges[actor_id] += monster.effective_speed() * FILL_RATE_CONSTANT * delta
		if _gauges[actor_id] >= GAUGE_MAX:
			_gauges[actor_id] = 0.0
			_ready_queue.append(actor_id)
			actor_ready.emit(actor_id)


## Returns true if at least one actor is in the ready queue.
func has_ready() -> bool:
	return not _ready_queue.is_empty()


## Removes and returns the front actor_id from the FIFO ready queue.
func pop_next_ready() -> String:
	assert(has_ready(), "ATBScheduler: pop_next_ready called with empty queue")
	return _ready_queue.pop_front()


func set_paused(paused: bool) -> void:
	_paused = paused


func is_paused() -> bool:
	return _paused


## Returns the current gauge value for an actor.
func get_gauge(actor_id: String) -> float:
	return _gauges.get(actor_id, 0.0)


## Sets the gauge for an actor. Clamped to [0, GAUGE_MAX).
## Does NOT emit actor_ready — only tick() triggers readiness.
func set_gauge(actor_id: String, value: float) -> void:
	if not _gauges.has(actor_id):
		return
	_gauges[actor_id] = clampf(value, 0.0, GAUGE_MAX - 0.001)


## Returns a copy of all current gauge values keyed by actor_id.
func get_all_gauges() -> Dictionary:
	return _gauges.duplicate()
