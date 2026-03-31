extends GdUnitTestSuite
## Tests for TileEffectRegistry dispatch and built-in handlers.

const _TileEffectRegistry = preload("res://engine/world/controller/TileEffectRegistry.gd")


func before_each() -> void:
	_TileEffectRegistry._initialized = false
	_TileEffectRegistry._handlers = {}
	_TileEffectRegistry.init_registry()


func _make_effect(tag: String, args: Dictionary) -> TileEffectResource:
	var eff := TileEffectResource.new()
	eff.effect_tag = tag
	eff.args = args
	return eff


func _make_ctx() -> ZoneEffectContext:
	return ZoneEffectContext.make("player", Vector2i(1, 1), null)


# ── init_registry is idempotent ───────────────────────────────────────────────

func test_init_registry_is_idempotent() -> void:
	_TileEffectRegistry.init_registry()
	_TileEffectRegistry.init_registry()
	assert_bool(_TileEffectRegistry._initialized).is_true()


# ── null effect is silently skipped ──────────────────────────────────────────

func test_dispatch_null_effect_is_noop() -> void:
	var rng := RandomNumberGenerator.new()
	_TileEffectRegistry.dispatch(null, _make_ctx(), rng)
	# Should not crash


# ── unknown tag produces warning, no crash ────────────────────────────────────

func test_dispatch_unknown_tag_no_crash() -> void:
	var eff := _make_effect("totally_unknown_tag_xyz", {})
	var rng := RandomNumberGenerator.new()
	_TileEffectRegistry.dispatch(eff, _make_ctx(), rng)
	# No crash — just a push_warning internally


# ── show_text handler emits signal ────────────────────────────────────────────

func test_show_text_emits_signal() -> void:
	var received: Array[String] = []
	var handler := func(text: String) -> void: received.append(text)
	EventBus.zone_show_text.connect(handler)

	var eff := _make_effect("show_text", {"text": "Hello from test"})
	var rng := RandomNumberGenerator.new()
	_TileEffectRegistry.dispatch(eff, _make_ctx(), rng)

	EventBus.zone_show_text.disconnect(handler)
	assert_int(received.size()).is_equal(1)
	assert_str(received[0]).is_equal("Hello from test")


# ── warp handler emits signal ─────────────────────────────────────────────────

func test_warp_emits_signal() -> void:
	var received_zone: Array[String] = []
	var received_spawn: Array[String] = []
	var handler := func(z: String, s: String) -> void:
		received_zone.append(z)
		received_spawn.append(s)
	EventBus.zone_warp_requested.connect(handler)

	var eff := _make_effect("warp", {"zone_id": "town_01", "spawn_point": "south"})
	var rng := RandomNumberGenerator.new()
	_TileEffectRegistry.dispatch(eff, _make_ctx(), rng)

	EventBus.zone_warp_requested.disconnect(handler)
	assert_int(received_zone.size()).is_equal(1)
	assert_str(received_zone[0]).is_equal("town_01")
	assert_str(received_spawn[0]).is_equal("south")


# ── custom handler registration ───────────────────────────────────────────────

func test_custom_handler_registered_and_called() -> void:
	var called: Array[bool] = [false]
	_TileEffectRegistry.register("custom_test",
		func(_args: Dictionary, _ctx: ZoneEffectContext, _rng: RandomNumberGenerator) -> void:
			called[0] = true)

	var eff := _make_effect("custom_test", {})
	var rng := RandomNumberGenerator.new()
	_TileEffectRegistry.dispatch(eff, _make_ctx(), rng)

	assert_bool(called[0]).is_true()


# ── remove_self emits entity_removed signal ───────────────────────────────────

func test_remove_self_emits_entity_removed() -> void:
	var received: Array[String] = []
	var handler := func(id: String) -> void: received.append(id)
	EventBus.zone_entity_removed.connect(handler)

	var ctx := ZoneEffectContext.make("player", Vector2i(1, 1), null)
	ctx.entity_id = "sign_01"

	var eff := _make_effect("remove_self", {})
	var rng := RandomNumberGenerator.new()
	_TileEffectRegistry.dispatch(eff, ctx, rng)

	EventBus.zone_entity_removed.disconnect(handler)
	assert_int(received.size()).is_equal(1)
	assert_str(received[0]).is_equal("sign_01")
