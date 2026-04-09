extends GdUnitTestSuite

# WorldBoard is a global autoload — we test relative increments rather than
# absolute values so tests are order-independent and require no cleanup.


func test_zone_count_increments_on_collide() -> void:
	var before: int = WorldBoard.get_zone("number_of_water_bonks", 0) as int
	var bonk := WaterBonkCollidable.new()

	bonk.on_player_collide(Node2D.new())

	assert_int(WorldBoard.get_zone("number_of_water_bonks", 0) as int).is_equal(before + 1)


func test_save_count_increments_on_collide() -> void:
	var before: int = WorldBoard.get_save("total_water_bonks_lifetime", 0) as int
	var bonk := WaterBonkCollidable.new()

	bonk.on_player_collide(Node2D.new())

	assert_int(WorldBoard.get_save("total_water_bonks_lifetime", 0) as int).is_equal(before + 1)


func test_multiple_instances_share_zone_count() -> void:
	# Each WaterBonkCollidable writes to the same zone key — two collides on
	# separate instances should increment the shared counter by 2, not 1 each.
	var before: int = WorldBoard.get_zone("number_of_water_bonks", 0) as int
	var bonk_a := WaterBonkCollidable.new()
	var bonk_b := WaterBonkCollidable.new()
	var player := Node2D.new()

	bonk_a.on_player_collide(player)
	bonk_b.on_player_collide(player)

	assert_int(WorldBoard.get_zone("number_of_water_bonks", 0) as int).is_equal(before + 2)
