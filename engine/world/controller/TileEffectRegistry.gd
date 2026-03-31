## Registry of all named tile/entity effects the engine knows how to execute.
## Effects are referenced by tag from TileEffectResource; logic lives only here.
## No class_name — preloaded by scripts that need it.

static var _initialized: bool = false
static var _handlers: Dictionary = {}


## Register all built-in effect handlers. Guard: idempotent after first call.
static func init_registry() -> void:
	if _initialized:
		return
	_initialized = true

	_handlers["encounter_check"] = _handle_encounter_check
	_handlers["warp"] = _handle_warp
	_handlers["set_flag"] = _handle_set_flag
	_handlers["show_text"] = _handle_show_text
	_handlers["give_item"] = _handle_give_item
	_handlers["remove_self"] = _handle_remove_self
	# Stubs — battle system integration deferred
	_handlers["damage"] = _handle_damage_stub
	_handlers["apply_status"] = _handle_apply_status_stub
	_handlers["forced_exit"] = _handle_forced_exit_stub


## Register a custom effect handler. Callable signature: (args: Dictionary, ctx: ZoneEffectContext, rng: RandomNumberGenerator) -> void
static func register(tag: String, handler: Callable) -> void:
	_handlers[tag] = handler


## Dispatch an effect. Silently skips null effects; warns on unknown tags.
static func dispatch(effect: Resource, ctx: ZoneEffectContext, rng: RandomNumberGenerator) -> void:
	if effect == null:
		return
	var tag: String = effect.get("effect_tag") if effect.get("effect_tag") != null else ""
	if tag.is_empty():
		return
	if not _handlers.has(tag):
		push_warning("TileEffectRegistry: unknown effect tag '%s'" % tag)
		return
	var args: Dictionary = effect.get("args") if effect.get("args") != null else {}
	_handlers[tag].call(args, ctx, rng)


# ── Built-in handlers ────────────────────────────────────────────────────────

static func _handle_encounter_check(args: Dictionary, ctx: ZoneEffectContext, rng: RandomNumberGenerator) -> void:
	var zone_res: ZoneResource = ctx.zone_resource as ZoneResource
	if zone_res == null:
		return
	var table: EncounterTableResource = null
	if args.has("table_override") and args["table_override"] != null:
		table = args["table_override"] as EncounterTableResource
	if table == null:
		table = zone_res.default_encounter_table
	if table == null:
		return
	if rng.randf() < table.encounter_chance:
		EventBus.zone_encounter_triggered.emit(table)


static func _handle_warp(args: Dictionary, _ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	var zone_id: String = args.get("zone_id", "")
	var spawn_point: String = args.get("spawn_point", "default")
	if zone_id.is_empty():
		push_warning("TileEffectRegistry: warp effect missing zone_id")
		return
	EventBus.zone_warp_requested.emit(zone_id, spawn_point)


static func _handle_set_flag(args: Dictionary, _ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	var key: String = args.get("flag", "")
	var value: Variant = args.get("value", true)
	var scope: String = args.get("scope", "zone")
	if key.is_empty():
		push_warning("TileEffectRegistry: set_flag effect missing flag key")
		return
	if scope == "save":
		WorldManager.set_save_flag(key, value)
	else:
		WorldManager.set_zone_flag(key, value)


static func _handle_show_text(args: Dictionary, _ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	var text: String = args.get("text", "")
	EventBus.zone_show_text.emit(text)


static func _handle_give_item(args: Dictionary, ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	var item_id: String = args.get("item_id", "")
	if item_id.is_empty():
		push_warning("TileEffectRegistry: give_item effect missing item_id")
		return
	var collected_key: String = "collected_%s" % item_id
	WorldManager.set_save_flag(collected_key, true)
	EventBus.zone_item_collected.emit(item_id)
	if not ctx.entity_id.is_empty():
		EventBus.zone_entity_removed.emit(ctx.entity_id)


static func _handle_remove_self(_args: Dictionary, ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	if not ctx.entity_id.is_empty():
		EventBus.zone_entity_removed.emit(ctx.entity_id)


static func _handle_damage_stub(_args: Dictionary, _ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	push_warning("TileEffectRegistry: 'damage' effect not yet implemented")


static func _handle_apply_status_stub(_args: Dictionary, _ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	push_warning("TileEffectRegistry: 'apply_status' effect not yet implemented")


static func _handle_forced_exit_stub(_args: Dictionary, _ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
	push_warning("TileEffectRegistry: 'forced_exit' effect not yet implemented")
