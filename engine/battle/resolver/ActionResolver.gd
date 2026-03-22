class_name ActionResolver
extends RefCounted
## 8-node FSM for resolving a single move action.
## DECLARE → TARGET_RESOLVE → ACCURACY_CHECK → CRIT_CHECK →
##   APPLY_PRE_EFFECTS → DAMAGE_CALC → APPLY_DAMAGE → APPLY_POST_EFFECTS → RESOLVE

const _Action = preload("res://engine/battle/model/Action.gd")
const _BattleState = preload("res://engine/battle/model/BattleState.gd")
const _ActionResult = preload("res://engine/battle/model/ActionResult.gd")
const _PipelineContext = preload("res://engine/battle/model/PipelineContext.gd")
const _StatResolver = preload("res://engine/battle/resolver/StatResolver.gd")
const _NodeRegistry = preload("res://engine/battle/resolver/NodeRegistry.gd")
const _ConditionInstance = preload("res://engine/entities/model/ConditionInstance.gd")

const DEFAULT_CRIT_RATE: float = 1.0 / 16.0
const CRIT_MULTIPLIER: float = 1.5

## Shared registry — populated once via init_registry() or lazily on first use.
static var _registry: NodeRegistry = null


## Call once at startup (e.g. from BattleManager._ready()) to register default nodes.
static func init_registry() -> void:
	_registry = NodeRegistry.create_default()


static func _get_registry() -> NodeRegistry:
	if _registry == null:
		_registry = NodeRegistry.create_default()
	return _registry


## Apply a single action through the 8-node FSM.
## state may be a BattleStateNvM (preferred) or a plain BattleState.
static func apply(
	action: Action,
	state: BattleState,
	rng: RandomNumberGenerator
) -> ActionResult:
	var result := ActionResult.new()

	var move: MoveConfig = action.move
	if move == null:
		return result

	# Build PipelineContext
	var ctx := _PipelineContext.new()
	ctx.actor_id = action.actor_id
	ctx.target_id = action.target_id
	ctx.actor = action.actor
	ctx.target = action.target
	ctx.move = move
	ctx.battle_state = state as BattleStateNvM
	ctx.rng = rng

	# --- DECLARE ---
	EventBus.battle_actor_turn_started.emit(action.actor_id)
	if action.actor.is_turn_denied():
		action.actor.clear_turn_denied()
		EventBus.battle_turn_denied.emit(action.actor_id, "")
		result.turn_denied = true
		return result
	action.actor.deduct_pp(move.id, move.pp)

	# --- TARGET_RESOLVE ---
	# Confirm target alive; no-op if dead (handled by caller skipping fainted actors)

	# --- ACCURACY_CHECK ---
	_node_accuracy_check(ctx)
	if not ctx.hit:
		return result

	# --- CRIT_CHECK ---
	_node_crit_check(ctx)

	# --- APPLY_PRE_EFFECTS ---
	_node_apply_effects(ctx, move.pre_effects)

	# --- DAMAGE_CALC ---
	_node_damage_calc(ctx)

	# --- APPLY_DAMAGE ---
	_node_apply_damage(ctx)

	# --- APPLY_POST_EFFECTS ---
	_node_apply_effects(ctx, move.post_effects)
	_node_apply_heal(ctx)

	# --- RESOLVE ---
	result.hit = ctx.hit
	result.damage = ctx.damage_value
	result.healed = ctx.healed_value
	result.crit = ctx.crit
	result.fainted = ctx.fainted
	result.turn_denied = ctx.turn_denied
	return result


# ---- Node implementations ----

static func _node_accuracy_check(ctx: Object) -> void:
	var move: MoveConfig = ctx.move
	var reg: NodeRegistry = _get_registry()

	if move.accuracy_node != "":
		var fn: Callable = reg.get_accuracy_node(move.accuracy_node)
		if fn.is_valid():
			fn.call(ctx, move.accuracy_node_arguments)
			return
		push_error("ActionResolver: unknown accuracy_node tag '%s'" % move.accuracy_node)

	# Default: accuracy = -1 means always hit
	if move.accuracy < 0.0:
		ctx.hit = true
		return

	ctx.hit = ctx.rng.randf() < move.accuracy


static func _node_crit_check(ctx: Object) -> void:
	var move: MoveConfig = ctx.move
	var crit_rate: float = DEFAULT_CRIT_RATE

	if move.crit_rate_formula != "":
		var caster_ctx: Dictionary = _StatResolver.build_context(
			ctx.actor.config, ctx.actor, ctx.battle_state
		)
		var val = _eval_formula(move.crit_rate_formula, ctx.move.move_power, caster_ctx, {}, ctx.battle_state)
		if val != null:
			crit_rate = float(val)

	ctx.crit = ctx.rng.randf() < crit_rate


static func _node_apply_effects(ctx: Object, effects: Array[EffectEntry]) -> void:
	for entry: EffectEntry in effects:
		if entry.if_crit and not ctx.crit:
			continue
		if entry.unless_crit and ctx.crit:
			continue
		if ctx.rng.randf() > entry.chance:
			continue

		var resolved_target: MonsterInstance
		var resolved_target_id: String
		if entry.target == "caster":
			resolved_target = ctx.actor
			resolved_target_id = ctx.actor_id
		else:
			resolved_target = ctx.target
			resolved_target_id = ctx.target_id

		if entry.effect_type == "recoil":
			var recoil_dmg: int = int(float(ctx.damage_value) * entry.recoil_fraction)
			if recoil_dmg > 0:
				ctx.actor.apply_damage(recoil_dmg)

		elif entry.effect_type == "set_weather":
			if ctx.battle_state != null:
				ctx.battle_state.set_weather(entry.weather, entry.weather_duration)
				EventBus.battle_weather_changed.emit(entry.weather, entry.weather_duration)

		if entry.condition_id != "":
			var cond_config: ConditionConfig = ConfigLoader.load_condition(entry.condition_id)
			if cond_config != null:
				var inst: Object = _ConditionInstance.create(cond_config, resolved_target, resolved_target_id)
				inst.apply()
				resolved_target.active_conditions.append(inst)
				EventBus.battle_condition_applied.emit(resolved_target_id, entry.condition_id)



static func _node_apply_heal(ctx: Object) -> void:
	var heal_formula: String = ctx.move.heal_formula
	if heal_formula == "":
		return
	# For SELF moves, the actor IS the target. For others, use ctx.target as "target".
	var heal_target: MonsterInstance = ctx.actor
	var target_ctx: Dictionary = _StatResolver.build_context(
		heal_target.config, heal_target, ctx.battle_state
	)
	var caster_ctx: Dictionary = _StatResolver.build_context(
		ctx.actor.config, ctx.actor, ctx.battle_state
	)
	var val = _eval_formula(heal_formula, ctx.move.move_power, caster_ctx, target_ctx, ctx.battle_state)
	if val != null:
		var heal_amount: int = maxi(0, int(float(val)))
		heal_target.restore_hp(heal_amount)
		ctx.healed_value = heal_amount


static func _node_damage_calc(ctx: Object) -> void:
	var move: MoveConfig = ctx.move
	if move.damage_formula == "" and move.move_power == 0:
		return

	var caster_ctx: Dictionary = _StatResolver.build_context(
		ctx.actor.config, ctx.actor, ctx.battle_state
	)
	var target_ctx: Dictionary = _StatResolver.build_context(
		ctx.target.config, ctx.target, ctx.battle_state
	)
	var reg: NodeRegistry = _get_registry()

	var raw_damage: float = 0.0

	if move.damage_node != "":
		var fn: Callable = reg.get_damage_node(move.damage_node)
		if fn.is_valid():
			fn.call(ctx, move.damage_args)
			return
		push_error("ActionResolver: unknown damage_node tag '%s'" % move.damage_node)

	if move.damage_formula != "":
		var val = _eval_formula(move.damage_formula, move.move_power, caster_ctx, target_ctx, ctx.battle_state)
		if val != null:
			raw_damage = float(val)
	elif move.move_power > 0:
		# Legacy fallback: power * attack / defense
		var caster_atk: float = caster_ctx.get("attack", 1.0) as float
		var target_def: float = target_ctx.get("defense", 1.0) as float
		raw_damage = float(move.move_power) * caster_atk / target_def

	if ctx.crit:
		raw_damage *= CRIT_MULTIPLIER

	ctx.damage_value = maxi(1, int(raw_damage)) if raw_damage > 0.0 else 0


static func _node_apply_damage(ctx: Object) -> void:
	if ctx.damage_value <= 0:
		return
	ctx.target.apply_damage(ctx.damage_value)
	EventBus.battle_move_hit.emit(ctx.target_id, ctx.move.type_tag)
	ctx.fainted = ctx.target.is_fainted()


# ---- Formula helpers ----

static func _eval_formula(
	formula: String,
	move_power: int,
	caster_ctx: Dictionary,
	target_ctx: Dictionary,
	battle_state: BattleStateNvM
) -> Variant:
	var expr := Expression.new()
	var input_names: PackedStringArray = PackedStringArray(["move_power", "caster", "target", "battle"])
	var err: int = expr.parse(formula, input_names)
	if err != OK:
		push_error("ActionResolver: formula parse error in '%s': %s" % [formula, expr.get_error_text()])
		return null
	var battle_ctx: Dictionary = {}
	if battle_state != null:
		battle_ctx["weather"] = battle_state.weather
	var result = expr.execute([move_power, caster_ctx, target_ctx, battle_ctx])
	if expr.has_execute_failed():
		push_error("ActionResolver: formula execute failed for '%s'" % formula)
		return null
	return result
