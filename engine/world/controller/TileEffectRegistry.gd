## Registry mapping effect_tag strings to handler Callables.
## No class_name — always preloaded. Follows NodeRegistry.gd pattern.
##
## Call init_registry() once at startup (ZoneScene._ready).
## Call dispatch(effect, ctx, rng) to execute an effect.

const _ZoneState := preload("res://engine/world/model/ZoneState.gd")
const _ZoneEffectContext := preload("res://engine/world/model/ZoneEffectContext.gd")

static var _initialized: bool = false
static var _handlers: Dictionary = {}   # { tag: String → Callable }


static func init_registry() -> void:
	if _initialized:
		return
	_initialized = true
	_handlers["encounter_check"] = _handle_encounter_check
	_handlers["warp"] = _handle_warp
	_handlers["damage"] = _handle_damage
	_handlers["apply_status"] = _handle_apply_status
	_handlers["forced_exit"] = _handle_forced_exit
	_handlers["set_flag"] = _handle_set_flag
	_handlers["show_text"] = _handle_show_text
	_handlers["give_item"] = _handle_give_item
	_handlers["remove_self"] = _handle_remove_self


static func dispatch(effect: TileEffectResource, ctx: ZoneEffectContext, rng: RandomNumberGenerator) -> void:
	if effect == null:
		return
	if _handlers.has(effect.effect_tag):
		_handlers[effect.effect_tag].call(effect.args, ctx, rng)
		EventBus.zone_tile_effect_triggered.emit(effect.effect_tag, ctx.actor_id)
	else:
		push_warning("TileEffectRegistry: unknown effect tag '%s'" % effect.effect_tag)


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

static func _handle_encounter_check(args: Dictionary, ctx: ZoneEffectContext, rng: RandomNumberGenerator) -> void:
	var table: EncounterTableResource = ctx.zone_state.zone_config.default_encounter_table
	if table == null:
		return
	if rng.randf() >= table.encounter_probability:
		return
	var entry: EncounterEntryResource = table.weighted_pick(rng)
	if entry == null:
		return
	var level: int = rng.randi_range(entry.level_min, entry.level_max)
	EventBus.zone_encounter_triggered.emit(entry.monster_id, level)


static func _handle_warp(args: Dictionary, _ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	var zone_id: String = args.get("zone_id", "")
	var spawn_id: String = args.get("spawn_point_id", "default")
	if zone_id == "":
		push_warning("TileEffectRegistry: warp effect missing 'zone_id' in args")
		return
	EventBus.zone_warp_requested.emit(zone_id, spawn_id)


static func _handle_damage(args: Dictionary, ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	push_warning("TileEffectRegistry: 'damage' effect not yet implemented (actor=%s)" % ctx.actor_id)


static func _handle_apply_status(args: Dictionary, ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	push_warning("TileEffectRegistry: 'apply_status' effect not yet implemented (actor=%s)" % ctx.actor_id)


static func _handle_forced_exit(args: Dictionary, ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	push_warning("TileEffectRegistry: 'forced_exit' effect not yet implemented (actor=%s)" % ctx.actor_id)


static func _handle_set_flag(args: Dictionary, ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	var key: String = args.get("key", "")
	var value: Variant = args.get("value", true)
	var scope: String = args.get("scope", "zone")
	if key == "":
		push_warning("TileEffectRegistry: set_flag effect missing 'key' in args")
		return
	if scope == "global":
		GameState.flags[key] = value
	else:
		ctx.zone_state.zone_bb.write(key, value)
	EventBus.zone_flag_set.emit(key, value)


static func _handle_show_text(args: Dictionary, _ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	var text: String = args.get("text", "")
	EventBus.zone_message_shown.emit(text)


static func _handle_give_item(args: Dictionary, ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	push_warning("TileEffectRegistry: 'give_item' effect not yet implemented (actor=%s)" % ctx.actor_id)


static func _handle_remove_self(args: Dictionary, ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	var entity_id: String = ctx.entity_id
	if entity_id == "":
		push_warning("TileEffectRegistry: remove_self called without entity_id in context")
		return
	if entity_id not in ctx.zone_state.removed_entities:
		ctx.zone_state.removed_entities.append(entity_id)
	EventBus.zone_entity_removed.emit(entity_id)
