extends TileCollidable
class_name BonkCounterCollidable

var _count: int = 0

func on_player_collide(_player: Node2D) -> void:
	_count += 1
	print("Bonk #%d" % _count)
