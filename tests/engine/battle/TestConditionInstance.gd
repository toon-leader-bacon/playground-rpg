extends GdUnitTestSuite

const _ConditionInstance = preload("res://engine/entities/model/ConditionInstance.gd")


func test_burn_registers_attack_modifier_on_apply() -> void:
	var config := _make_burn_config()
	var carrier := _make_monster("carrier", 100, 60, 20, 10, 10, 10)
	var inst: Object = _ConditionInstance.create(config, carrier, "carrier")
	inst.apply()

	assert_bool(carrier.condition_modifiers.has("attack")).is_true()
	var mods: Array = carrier.condition_modifiers["attack"] as Array
	assert_int(mods.size()).is_equal(1)
	assert_float(mods[0]["multiplier"] as float).is_equal_approx(0.5, 0.001)


func test_burn_periodic_damage_on_turn_start() -> void:
	var config := _make_burn_config()
	var carrier := _make_monster("carrier", 100, 60, 20, 10, 10, 10)
	carrier.active_conditions = []
	var inst: Object = _ConditionInstance.create(config, carrier, "carrier")
	inst.apply()
	var hp_before: int = carrier.current_hp

	# Simulate turn start for the carrier
	EventBus.battle_actor_turn_started.emit("carrier")

	# Damage = 100 * 0.0625 = 6
	assert_int(carrier.current_hp).is_less(hp_before)


func test_burn_removes_attack_modifier_on_remove() -> void:
	var config := _make_burn_config()
	var carrier := _make_monster("carrier", 100, 60, 20, 10, 10, 10)
	carrier.active_conditions = []
	var inst: Object = _ConditionInstance.create(config, carrier, "carrier")
	inst.apply()
	inst.remove()

	assert_bool(carrier.condition_modifiers.has("attack")).is_false()


func test_paralysis_can_deny_turn() -> void:
	var config := _make_paralysis_config()
	var carrier := _make_monster("carrier", 100, 10, 10, 60, 10, 10)
	carrier.active_conditions = []
	var inst: Object = _ConditionInstance.create(config, carrier, "carrier")
	inst.apply()

	# Fire turn_started many times to get at least one denial with 25% chance
	var denied: bool = false
	for i: int in range(50):
		carrier.clear_turn_denied()
		EventBus.battle_actor_turn_started.emit("carrier")
		if carrier.is_turn_denied():
			denied = true
			break
	assert_bool(denied).is_true()


func test_sleep_denies_turn_and_counts_down() -> void:
	var config := ConditionConfig.new()
	config.id = "sleep"
	config.display_name = "Sleep"
	config.trigger_event = "battle_actor_turn_started"
	config.turn_denial_chance = 1.0
	config.duration_type = ConditionConfig.DurationType.COUNTDOWN
	config.duration = 2

	var carrier := _make_monster("carrier", 100, 10, 10, 10, 10, 10)
	carrier.active_conditions = []
	var inst: Object = _ConditionInstance.create(config, carrier, "carrier")
	inst.apply()

	assert_int(inst.remaining_duration).is_equal(2)

	# Turn 1
	EventBus.battle_actor_turn_started.emit("carrier")
	assert_bool(carrier.is_turn_denied()).is_true()
	assert_int(inst.remaining_duration).is_equal(1)

	carrier.clear_turn_denied()

	# Turn 2 — should expire and remove itself
	EventBus.battle_actor_turn_started.emit("carrier")
	assert_int(carrier.active_conditions.size()).is_equal(0)


func test_freeze_removed_by_fire_hit() -> void:
	var config := _make_freeze_config()
	var carrier := _make_monster("carrier", 100, 10, 10, 10, 10, 10)
	carrier.active_conditions = []
	var inst: Object = _ConditionInstance.create(config, carrier, "carrier")
	inst.apply()
	carrier.active_conditions.append(inst)  # ActionResolver normally does this

	assert_int(carrier.active_conditions.size()).is_equal(1)

	# Fire hit on carrier — should remove freeze (removal_move_type = FIRE = 2)
	EventBus.battle_move_hit.emit("carrier", TypeTag.Type.FIRE)

	assert_int(carrier.active_conditions.size()).is_equal(0)


func test_freeze_not_removed_by_non_fire_hit() -> void:
	var config := _make_freeze_config()
	var carrier := _make_monster("carrier", 100, 10, 10, 10, 10, 10)
	carrier.active_conditions = []
	var inst: Object = _ConditionInstance.create(config, carrier, "carrier")
	inst.apply()
	carrier.active_conditions.append(inst)  # ActionResolver normally does this

	# Water hit — should NOT remove freeze
	EventBus.battle_move_hit.emit("carrier", TypeTag.Type.WATER)

	assert_int(carrier.active_conditions.size()).is_equal(1)

	# Cleanup
	inst.remove()


func test_condition_expired_signal_emitted_on_remove() -> void:
	var config := ConditionConfig.new()
	config.id = "test_cond"
	config.duration_type = ConditionConfig.DurationType.PERMANENT

	var carrier := _make_monster("carrier", 100, 10, 10, 10, 10, 10)
	carrier.active_conditions = []
	var inst: Object = _ConditionInstance.create(config, carrier, "carrier")
	inst.apply()

	var expired_fired: Array = [false]
	var check_fn := func(actor_id: String, _cid: String) -> void:
		if actor_id == "carrier":
			expired_fired[0] = true
	EventBus.battle_condition_expired.connect(check_fn)
	inst.remove()

	assert_bool(expired_fired[0]).is_true()
	EventBus.battle_condition_expired.disconnect(check_fn)


func test_sleep_random_duration_in_range() -> void:
	var config := ConditionConfig.new()
	config.id = "sleep"
	config.duration_type = ConditionConfig.DurationType.RANDOM_RANGE
	config.duration_min = 1
	config.duration_max = 3

	var carrier := _make_monster("c", 100, 10, 10, 10, 10, 10)
	carrier.active_conditions = []

	for i: int in range(20):
		var inst: Object = _ConditionInstance.create(config, carrier, "c")
		var dur: int = inst.remaining_duration
		assert_int(dur).is_greater_equal(1)
		assert_int(dur).is_less_equal(3)


# --- Helpers ---

func _make_burn_config() -> ConditionConfig:
	var c := ConditionConfig.new()
	c.id = "burn"
	c.display_name = "Burn"
	c.trigger_event = "battle_actor_turn_started"
	c.periodic_damage_formula = "target.max_hp * 0.0625"
	c.stat_modifiers = [{"stat": "attack", "multiplier": 0.5}]
	c.duration_type = ConditionConfig.DurationType.PERMANENT
	return c


func _make_paralysis_config() -> ConditionConfig:
	var c := ConditionConfig.new()
	c.id = "paralysis"
	c.display_name = "Paralysis"
	c.trigger_event = "battle_actor_turn_started"
	c.stat_modifiers = [{"stat": "speed", "multiplier": 0.5}]
	c.turn_denial_chance = 0.25
	c.duration_type = ConditionConfig.DurationType.PERMANENT
	return c


func _make_freeze_config() -> ConditionConfig:
	var c := ConditionConfig.new()
	c.id = "freeze"
	c.display_name = "Freeze"
	c.trigger_event = "battle_actor_turn_started"
	c.turn_denial_chance = 1.0
	c.duration_type = ConditionConfig.DurationType.PERMANENT
	c.removal_trigger_event = "battle_move_hit"
	c.removal_move_type = TypeTag.Type.FIRE
	return c


func _make_monster(id: String, hp: int, atk: int, def_val: int, spd: int, sp_atk: int, sp_def: int) -> MonsterInstance:
	var config := MonsterConfig.new()
	config.id = id
	config.display_name = id.capitalize()
	var stats := StatBlock.new()
	stats.max_hp = hp
	stats.attack = atk
	stats.defense = def_val
	stats.speed = spd
	stats.special_attack = sp_atk
	stats.special_defense = sp_def
	config.base_stats = stats
	config.type_tags = [TypeTag.Type.NORMAL]
	config.ai_style = MonsterConfig.AIStyle.RANDOM
	return MonsterInstance.create(config, 1)
