extends TileCollidable
class_name WaterBonkCollidable

## Demonstrates both blackboard scopes via WorldBoard autoload:
##   zone scope  — resets every time this zone is loaded
##   save scope  — persists across zone transitions for the lifetime of the save

func on_player_collide(_player: Node2D) -> void:
	var zone_count: int = WorldBoard.get_zone("number_of_water_bonks", 0) + 1
	WorldBoard.set_zone("number_of_water_bonks", zone_count)

	var lifetime_count: int = WorldBoard.get_save("total_water_bonks_lifetime", 0) + 1
	WorldBoard.set_save("total_water_bonks_lifetime", lifetime_count)

	print("Water bonks this zone: %d | Lifetime: %d" % [zone_count, lifetime_count])
