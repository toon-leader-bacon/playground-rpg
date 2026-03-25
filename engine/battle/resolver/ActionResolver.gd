class_name ActionResolver
extends RefCounted
## Two-stage FSM-based move resolution.
##
## Stage 1 — _build_default_fsm(): constructs the directed graph of named nodes
##   and ordered edges that describes the standard move pipeline.
## Stage 2 — fsm.run(ctx): walks the graph from START to END, executing each
##   node's Callable against a shared PipelineContext.
##
## Default pipeline (node traversal order for a typical damaging move):
##   START → DECLARE → ACCURACY_CHECK → CRIT_CHECK →
##   APPLY_PRE_EFFECTS → DAMAGE_CALC → APPLY_DAMAGE →
##   APPLY_POST_EFFECTS → APPLY_HEAL → END
##
## Conditional short-circuits (edges that skip ahead to END):
##   DECLARE      → END  when turn is denied
##   ACCURACY_CHECK → END  when the move misses

const _ConditionInstance = preload("res://engine/entities/model/ConditionInstance.gd")

const DEFAULT_CRIT_RATE: float = 1.0 / 16.0
const CRIT_MULTIPLIER: float = 1.5

## Stable node-name constants for use when patching the default FSM from MoveConfig.
const NODE_DECLARE: String = "DECLARE"
const NODE_ACCURACY_CHECK: String = "ACCURACY_CHECK"
const NODE_CRIT_CHECK: String = "CRIT_CHECK"
const NODE_APPLY_PRE_EFFECTS: String = "APPLY_PRE_EFFECTS"
const NODE_DAMAGE_CALC: String = "DAMAGE_CALC"
const NODE_APPLY_DAMAGE: String = "APPLY_DAMAGE"
const NODE_APPLY_POST_EFFECTS: String = "APPLY_POST_EFFECTS"
const NODE_APPLY_HEAL: String = "APPLY_HEAL"

## Shared registries — populated once via init_registry() or lazily on first use.
static var _registry: NodeRegistry = null
static var _edge_registry: EdgeRegistry = null


## Call once at startup (e.g. from BattleManager._ready()) to register default nodes.
static func init_registry() -> void:
	_registry = NodeRegistry.create_default()
	_edge_registry = EdgeRegistry.create_default()


static func _get_registry() -> NodeRegistry:
	if _registry == null:
		_registry = NodeRegistry.create_default()
	return _registry


static func _get_edge_registry() -> EdgeRegistry:
	if _edge_registry == null:
		_edge_registry = EdgeRegistry.create_default()
	return _edge_registry


## Resolve a single action through the move pipeline.
## state may be a BattleStateNvM (preferred) or a plain BattleState.
static func apply(
	action: Action,
	state: BattleState,
	rng: RandomNumberGenerator
) -> ActionResult:
	var result := ActionResult.new()
	if action.move == null:
		return result

	# Build PipelineContext
	var ctx := PipelineContext.new()
	ctx.actor_id = action.actor_id
	ctx.target_id = action.target_id
	ctx.actor = action.actor
	ctx.target = action.target
	ctx.move = action.move
	ctx.battle_state = state as BattleStateNvM
	ctx.rng = rng

	# Stage 1: Build FSM and apply per-move overrides
	var fsm: BattleFsm = _build_default_fsm()
	_apply_move_overrides(fsm, action.move)

	# Stage 2: Run FSM
	fsm.run(ctx)

	# Pack final context state into ActionResult
	result.hit = ctx.hit
	result.damage = ctx.damage_value
	result.healed = ctx.healed_value
	result.crit = ctx.crit
	result.fainted = ctx.fainted
	result.turn_denied = ctx.turn_denied
	return result


# ---- FSM construction ----

static func _build_default_fsm() -> BattleFsm:
	var fsm := BattleFsm.new()

	# Nodes
	fsm.add_node(NODE_DECLARE,            Callable(ActionResolver, "_node_declare"))
	fsm.add_node(NODE_ACCURACY_CHECK,     Callable(ActionResolver, "_node_accuracy_check"))
	fsm.add_node(NODE_CRIT_CHECK,         Callable(ActionResolver, "_node_crit_check"))
	fsm.add_node(NODE_APPLY_PRE_EFFECTS,  Callable(ActionResolver, "_node_apply_pre_effects"))
	fsm.add_node(NODE_DAMAGE_CALC,        Callable(ActionResolver, "_node_damage_calc"))
	fsm.add_node(NODE_APPLY_DAMAGE,       Callable(ActionResolver, "_node_apply_damage"))
	fsm.add_node(NODE_APPLY_POST_EFFECTS, Callable(ActionResolver, "_node_apply_post_effects"))
	fsm.add_node(NODE_APPLY_HEAL,         Callable(ActionResolver, "_node_apply_heal"))

	# Edges (evaluated in declaration order; first matching edge is followed)
	fsm.add_edge(FsmEdge.always(BattleFsm.START, NODE_DECLARE))

	fsm.add_edge(FsmEdge.when(NODE_DECLARE, BattleFsm.END,
		func(c: PipelineContext) -> bool: return c.turn_denied))
	fsm.add_edge(FsmEdge.always(NODE_DECLARE, NODE_ACCURACY_CHECK))

	fsm.add_edge(FsmEdge.when(NODE_ACCURACY_CHECK, BattleFsm.END,
		func(c: PipelineContext) -> bool: return not c.hit))
	fsm.add_edge(FsmEdge.always(NODE_ACCURACY_CHECK, NODE_CRIT_CHECK))

	fsm.add_edge(FsmEdge.always(NODE_CRIT_CHECK,         NODE_APPLY_PRE_EFFECTS))
	fsm.add_edge(FsmEdge.always(NODE_APPLY_PRE_EFFECTS,  NODE_DAMAGE_CALC))
	fsm.add_edge(FsmEdge.always(NODE_DAMAGE_CALC,        NODE_APPLY_DAMAGE))
	fsm.add_edge(FsmEdge.always(NODE_APPLY_DAMAGE,       NODE_APPLY_POST_EFFECTS))
	fsm.add_edge(FsmEdge.always(NODE_APPLY_POST_EFFECTS, NODE_APPLY_HEAL))
	fsm.add_edge(FsmEdge.always(NODE_APPLY_HEAL,         BattleFsm.END))

	return fsm


## Apply per-move node overrides from MoveConfig to the FSM built in Stage 1.
## For each NodeOverrideEntry: override replaces the callable; pre/post hooks wrap it.
## All custom callables have signature func(ctx, args) and are bound with entry.args
## so the FSM always sees func(ctx) -> void.
static func _apply_move_overrides(fsm: BattleFsm, move: MoveConfig) -> void:
	var reg: NodeRegistry = _get_registry()
	for entry: NodeOverrideEntry in move.node_overrides:
		# Determine base callable (override or keep existing default)
		var base_fn: Callable = fsm.get_node(entry.node_id)
		if entry.override_tag != "":
			var fn: Callable = reg.get_node(entry.override_tag)
			if fn.is_valid():
				base_fn = fn.bind(entry.args)
			else:
				push_error("ActionResolver: unknown override_tag '%s'" % entry.override_tag)
				continue

		# Resolve pre/post hooks
		var pre_fn: Callable
		if entry.pre_hook_tag != "":
			var fn: Callable = reg.get_node(entry.pre_hook_tag)
			if fn.is_valid():
				pre_fn = fn.bind(entry.args)
			else:
				push_error("ActionResolver: unknown pre_hook_tag '%s'" % entry.pre_hook_tag)

		var post_fn: Callable
		if entry.post_hook_tag != "":
			var fn: Callable = reg.get_node(entry.post_hook_tag)
			if fn.is_valid():
				post_fn = fn.bind(entry.args)
			else:
				push_error("ActionResolver: unknown post_hook_tag '%s'" % entry.post_hook_tag)

		# Wrap and install
		if pre_fn.is_valid() or post_fn.is_valid():
			fsm.add_node(entry.node_id, _wrap_with_hooks(base_fn, pre_fn, post_fn))
		elif entry.override_tag != "":
			fsm.add_node(entry.node_id, base_fn)

	var edge_reg: EdgeRegistry = _get_edge_registry()
	for edge_entry: EdgeOverrideEntry in move.edge_overrides:
		var condition: Callable
		if edge_entry.condition_tag != "":
			var fn: Callable = edge_reg.get_condition(edge_entry.condition_tag)
			if fn.is_valid():
				condition = fn.bind(edge_entry.args)
			else:
				push_error("ActionResolver: unknown condition_tag '%s'" % edge_entry.condition_tag)
				continue
		if condition.is_valid():
			fsm.insert_edge_before_source(FsmEdge.when(edge_entry.from_node, edge_entry.to_node, condition))
		else:
			fsm.insert_edge_before_source(FsmEdge.always(edge_entry.from_node, edge_entry.to_node))


static func _wrap_with_hooks(base: Callable, pre: Callable, post: Callable) -> Callable:
	return func(ctx: PipelineContext) -> void:
		if pre.is_valid():
			pre.call(ctx)
		base.call(ctx)
		if post.is_valid():
			post.call(ctx)


# ---- Node implementations ----

static func _node_declare(ctx: PipelineContext) -> void:
	EventBus.battle_actor_turn_started.emit(ctx.actor_id)
	if ctx.actor.is_turn_denied():
		ctx.actor.clear_turn_denied()
		EventBus.battle_turn_denied.emit(ctx.actor_id, "")
		ctx.turn_denied = true
		return
	ctx.actor.deduct_pp(ctx.move.id, ctx.move.pp)


static func _node_accuracy_check(ctx: PipelineContext) -> void:
	# accuracy < 0 means always hit
	if ctx.move.accuracy < 0.0:
		ctx.hit = true
		return
	ctx.hit = ctx.rng.randf() < ctx.move.accuracy


static func _node_crit_check(ctx: PipelineContext) -> void:
	var crit_rate: float = DEFAULT_CRIT_RATE

	if ctx.move.crit_rate_formula != "":
		var caster_ctx: Dictionary = StatResolver.build_context(
			ctx.actor.config, ctx.actor, ctx.battle_state
		)
		var val = _eval_formula(ctx.move.crit_rate_formula, ctx.move.move_power, caster_ctx, {}, ctx.battle_state)
		if val != null:
			crit_rate = float(val)

	ctx.crit = ctx.rng.randf() < crit_rate


static func _node_apply_pre_effects(ctx: PipelineContext) -> void:
	_apply_effects_impl(ctx, ctx.move.pre_effects)


static func _node_apply_post_effects(ctx: PipelineContext) -> void:
	_apply_effects_impl(ctx, ctx.move.post_effects)


static func _apply_effects_impl(ctx: PipelineContext, effects: Array[EffectEntry]) -> void:
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


static func _node_damage_calc(ctx: PipelineContext) -> void:
	var move: MoveConfig = ctx.move
	if move.damage_formula == "" and move.move_power == 0:
		return

	var caster_ctx: Dictionary = StatResolver.build_context(
		ctx.actor.config, ctx.actor, ctx.battle_state
	)
	var target_ctx: Dictionary = StatResolver.build_context(
		ctx.target.config, ctx.target, ctx.battle_state
	)

	var raw_damage: float = 0.0
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


static func _node_apply_damage(ctx: PipelineContext) -> void:
	if ctx.damage_value <= 0:
		return
	ctx.target.apply_damage(ctx.damage_value)
	EventBus.battle_move_hit.emit(ctx.target_id, ctx.move.type_tag)
	ctx.fainted = ctx.target.is_fainted()


static func _node_apply_heal(ctx: PipelineContext) -> void:
	if ctx.move.heal_formula == "":
		return
	var heal_target: MonsterInstance = ctx.actor
	var caster_ctx: Dictionary = StatResolver.build_context(ctx.actor.config, ctx.actor, ctx.battle_state)
	var target_ctx: Dictionary = StatResolver.build_context(heal_target.config, heal_target, ctx.battle_state)
	var val = _eval_formula(ctx.move.heal_formula, ctx.move.move_power, caster_ctx, target_ctx, ctx.battle_state)
	if val != null:
		var heal_amount: int = maxi(0, int(float(val)))
		heal_target.restore_hp(heal_amount)
		ctx.healed_value = heal_amount


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
