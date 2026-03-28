class_name MoveResult
extends RefCounted
## Value object returned by ZoneController.try_move / try_move_entity.
## On success: success = true and new_pos holds the destination.
## On failure: success = false and blocked_reason describes why.

var success: bool = false
var new_pos: Vector2i = Vector2i.ZERO
var blocked_reason: String = ""


static func ok(pos: Vector2i) -> MoveResult:
	var r := MoveResult.new()
	r.success = true
	r.new_pos = pos
	return r


static func fail(reason: String) -> MoveResult:
	var r := MoveResult.new()
	r.blocked_reason = reason
	return r
