extends Node
## Drives the game world at a fixed tick rate, independent of frame rate.
## Emits pre_tick → tick → post_tick each cycle.
##
## Tick order contract:
##   PlayerEntityNode connects pre_tick (read input) and tick (resolve movement).
##   EntityNode instances connect tick after PlayerEntityNode (resolve after player).
##   TileEffectRegistry effects fire during post_tick.

signal pre_tick
signal tick
signal post_tick

@export var tick_duration: float = 0.3

var _accumulator: float = 0.0
var _active: bool = true


func _process(delta: float) -> void:
	if not _active:
		return
	_accumulator += delta
	if _accumulator >= tick_duration:
		_accumulator -= tick_duration
		pre_tick.emit()
		tick.emit()
		post_tick.emit()


func pause() -> void:
	_active = false


func resume() -> void:
	_active = true
