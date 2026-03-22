extends RefCounted
## Runtime instance of a ConditionConfig applied to a specific monster.
## Connects to EventBus on apply(), disconnects on remove().

const _StatResolver = preload("res://engine/battle/resolver/StatResolver.gd")

var config: ConditionConfig
var carrier: MonsterInstance
var carrier_id: String
var remaining_duration: int = -1  # -1 = permanent

var _rng: RandomNumberGenerator


static func create(
	p_config: ConditionConfig,
	p_carrier: MonsterInstance,
	p_carrier_id: String
) -> Object:
	var inst: Object = load("res://engine/entities/model/ConditionInstance.gd").new()
	inst.config = p_config
	inst.carrier = p_carrier
	inst.carrier_id = p_carrier_id
	inst._rng = RandomNumberGenerator.new()
	inst._rng.randomize()

	# Set duration based on DurationType
	match p_config.duration_type:
		ConditionConfig.DurationType.PERMANENT:
			inst.remaining_duration = -1
		ConditionConfig.DurationType.COUNTDOWN:
			inst.remaining_duration = p_config.duration
		ConditionConfig.DurationType.RANDOM_RANGE:
			inst.remaining_duration = inst._rng.randi_range(p_config.duration_min, p_config.duration_max)

	return inst


func apply() -> void:
	# Register stat modifiers on carrier
	for mod_entry: Dictionary in config.stat_modifiers:
		var stat: String = mod_entry.get("stat", "") as String
		var mult: float = mod_entry.get("multiplier", 1.0) as float
		if stat != "":
			carrier.add_condition_modifier(stat, mult, config.id)

	# Subscribe to trigger event
	if config.trigger_event != "":
		var signal_obj: Signal = _get_event_signal(config.trigger_event)
		if signal_obj.get_name() != "":
			signal_obj.connect(_on_trigger_event)

	# Subscribe to removal event
	if config.removal_trigger_event != "":
		var removal_signal_obj: Signal = _get_event_signal(config.removal_trigger_event)
		if removal_signal_obj.get_name() != "":
			removal_signal_obj.connect(_on_removal_event)


func remove() -> void:
	# Unregister stat modifiers
	for mod_entry: Dictionary in config.stat_modifiers:
		var stat: String = mod_entry.get("stat", "") as String
		if stat != "":
			carrier.remove_condition_modifier(stat, config.id)

	# Disconnect from trigger event
	if config.trigger_event != "":
		var signal_obj: Signal = _get_event_signal(config.trigger_event)
		if signal_obj.get_name() != "" and signal_obj.is_connected(_on_trigger_event):
			signal_obj.disconnect(_on_trigger_event)

	# Disconnect from removal event
	if config.removal_trigger_event != "":
		var removal_signal_obj: Signal = _get_event_signal(config.removal_trigger_event)
		if removal_signal_obj.get_name() != "" and removal_signal_obj.is_connected(_on_removal_event):
			removal_signal_obj.disconnect(_on_removal_event)

	# Remove from carrier's active_conditions
	carrier.active_conditions.erase(self)

	EventBus.battle_condition_expired.emit(carrier_id, config.id)


## Called when the subscribed trigger event fires.
## Works for both "actor_turn_started" (takes actor_id) and "move_hit" (takes target_id, move_type).
func _on_trigger_event(arg1: Variant = null, arg2: Variant = null) -> void:
	# Filter: only react when the event involves this carrier
	var event_actor_id: String = str(arg1) if arg1 != null else ""
	if event_actor_id != carrier_id:
		return

	# Turn denial
	if config.turn_denial_chance > 0.0:
		if _rng.randf() < config.turn_denial_chance:
			carrier.deny_turn()

	# Periodic damage
	if config.periodic_damage_formula != "":
		var target_ctx: Dictionary = _StatResolver.build_context(carrier.config, carrier, null)
		var expr := Expression.new()
		var err: int = expr.parse(config.periodic_damage_formula, PackedStringArray(["target"]))
		if err == OK:
			var val = expr.execute([target_ctx])
			if not expr.has_execute_failed():
				var dmg: int = maxi(0, int(float(val)))
				if dmg > 0:
					carrier.apply_damage(dmg)
					EventBus.battle_damage_dealt_keyed.emit(
						carrier_id, dmg, carrier.current_hp, carrier.max_hp()
					)

	# Duration countdown
	if config.duration_type == ConditionConfig.DurationType.COUNTDOWN or \
	   config.duration_type == ConditionConfig.DurationType.RANDOM_RANGE:
		if remaining_duration > 0:
			remaining_duration -= 1
			if remaining_duration <= 0:
				remove()


## Called when the removal trigger event fires (e.g. move_hit for Freeze removal).
func _on_removal_event(arg1: Variant = null, arg2: Variant = null) -> void:
	var event_target_id: String = str(arg1) if arg1 != null else ""
	if event_target_id != carrier_id:
		return

	# Check move type condition (e.g. only fire moves remove Freeze)
	if config.removal_move_type >= 0:
		var move_type: int = int(arg2) if arg2 != null else -1
		if move_type != config.removal_move_type:
			return

	remove()


func _get_event_signal(event_name: String) -> Signal:
	match event_name:
		"battle_actor_turn_started":
			return EventBus.battle_actor_turn_started
		"battle_move_hit":
			return EventBus.battle_move_hit
		_:
			push_error("ConditionInstance: unknown event signal '%s'" % event_name)
			return Signal()
