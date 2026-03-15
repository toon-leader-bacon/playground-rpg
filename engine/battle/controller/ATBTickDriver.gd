extends Node
## Thin Node wrapper that drives ATBNvMController.tick() each _process frame.
## BattleManager creates this, adds it as a child, and frees it when the battle ends.
## The controller itself is a RefCounted — this Node is the only thing that owns the frame loop.

var _controller: Object


func setup(controller: Object) -> void:
	_controller = controller


func _process(delta: float) -> void:
	if _controller != null:
		_controller.call("tick", delta)
