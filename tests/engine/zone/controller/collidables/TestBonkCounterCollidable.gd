extends GdUnitTestSuite


func test_count_increments_on_each_collide() -> void:
	var bonk := BonkCounterCollidable.new()
	var player := Node2D.new()

	bonk.on_player_collide(player)
	bonk.on_player_collide(player)
	bonk.on_player_collide(player)

	assert_int(bonk._count).is_equal(3)


func test_two_instances_have_independent_counts() -> void:
	var bonk_a := BonkCounterCollidable.new()
	var bonk_b := BonkCounterCollidable.new()
	var player := Node2D.new()

	bonk_a.on_player_collide(player)
	bonk_a.on_player_collide(player)
	bonk_b.on_player_collide(player)

	assert_int(bonk_a._count).is_equal(2)
	assert_int(bonk_b._count).is_equal(1)
