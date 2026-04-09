extends TileCollidable
class_name WallCollidable

# WARNING: This is a demo implementation and is not currently being used as of Apr 2026.
# One can use this via `CollisionRegistry.register("wall_collide", on_player_collide)` if 
# they want to use it.

func on_player_collide(_player: Node2D) -> void:
	print("bonk")
