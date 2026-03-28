extends Node2D
## Root controller for the zone view. Owns zone loading, player input routing,
## entity management, and EventBus wiring.
## @export var zone_id drives which zone is loaded on _ready().

@export var zone_id: String = "test_zone"
@export var spawn_point_id: String = "default"

@onready var _camera: Camera2D = $Camera2D
@onready var _renderer: ZoneTileRenderer = $ZoneTileRenderer
@onready var _entity_root: Node2D = $EntityRoot
@onready var _zone_name_label: Label = $ZoneHUD/ZoneName
@onready var _message_box: RichTextLabel = $ZoneHUD/MessageBox

const _ZoneController := preload("res://engine/world/controller/ZoneController.gd")
const _TileEffectRegistry := preload("res://engine/world/controller/TileEffectRegistry.gd")
const _EntityBehaviorHandler := preload("res://engine/world/controller/EntityBehaviorHandler.gd")

var _zone_state: ZoneState = null
var _player_node: PlayerEntityNode = null
var _entity_nodes: Dictionary = {}     # { entity_id: String → EntityNode }
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _message_timer: float = 0.0


func _ready() -> void:
	_TileEffectRegistry.init_registry()
	_load_zone(zone_id, spawn_point_id)
	EventBus.zone_warp_requested.connect(_on_zone_warp_requested)
	EventBus.zone_message_shown.connect(_on_zone_message_shown)
	EventBus.zone_entity_removed.connect(_on_zone_entity_removed)


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_box.text = ""


# ---------------------------------------------------------------------------
# Zone loading
# ---------------------------------------------------------------------------

func _load_zone(id: String, spawn: String) -> void:
	var config: Resource = ConfigLoader.load_zone(id)
	if config == null:
		push_error("ZoneScene: could not load zone '%s'" % id)
		return

	_zone_state = ZoneState.create(config, spawn, GameState.zone_bb as Blackboard)
	GameState.current_zone_id = id

	_renderer.setup(_zone_state)

	_clear_entities()
	_spawn_player(_zone_state.player_position)
	_spawn_entities(config)

	_zone_name_label.text = config.get("display_name")
	EventBus.zone_loaded.emit(id, config.get("display_name"))


func _clear_entities() -> void:
	for child: Node in _entity_root.get_children():
		child.queue_free()
	_entity_nodes.clear()
	_player_node = null


func _spawn_player(pos: Vector2i) -> void:
	var node := PlayerEntityNode.new()
	_entity_root.add_child(node)
	node.set_tile_position(pos)
	node.move_requested.connect(_on_player_move_requested)
	node.interact_requested.connect(_on_player_interact_requested)
	_player_node = node
	_camera.position = node.position


func _spawn_entities(config: Resource) -> void:
	for entity_def: EntityDefinitionResource in config.get("entities"):
		if entity_def.id in _zone_state.removed_entities:
			continue
		var node := EntityNode.new()
		_entity_root.add_child(node)
		node.setup(entity_def)
		node.update_requested.connect(_on_entity_update_requested)
		_entity_nodes[entity_def.id] = node


# ---------------------------------------------------------------------------
# Player input
# ---------------------------------------------------------------------------

func _on_player_move_requested(direction: Vector2i) -> void:
	if _zone_state == null:
		return
	_player_node.facing = direction
	_player_node.queue_redraw()
	var result: MoveResult = _ZoneController.try_move(_zone_state, "player", direction, _rng)
	if result.success:
		_player_node.set_tile_position(result.new_pos)
		_camera.position = _player_node.position
		EventBus.zone_player_moved.emit(result.new_pos)


func _on_player_interact_requested() -> void:
	if _zone_state == null or _player_node == null:
		return
	_ZoneController.try_interact(_zone_state, _zone_state.player_position, _player_node.facing)


# ---------------------------------------------------------------------------
# Entity behavior
# ---------------------------------------------------------------------------

func _on_entity_update_requested(entity_id: String) -> void:
	if _zone_state == null:
		return
	if entity_id in _zone_state.removed_entities:
		return
	var entity_def: EntityDefinitionResource = _find_entity_def(entity_id)
	if entity_def == null:
		return
	var result: MoveResult = _EntityBehaviorHandler.update(entity_def, entity_id, _zone_state, _rng)
	if result.success and _entity_nodes.has(entity_id):
		_entity_nodes[entity_id].set_tile_position(result.new_pos)


func _find_entity_def(entity_id: String) -> EntityDefinitionResource:
	for e: EntityDefinitionResource in _zone_state.zone_config.get("entities"):
		if e.id == entity_id:
			return e
	return null


# ---------------------------------------------------------------------------
# EventBus listeners
# ---------------------------------------------------------------------------

func _on_zone_warp_requested(new_zone_id: String, new_spawn_id: String) -> void:
	_load_zone(new_zone_id, new_spawn_id)


func _on_zone_message_shown(text: String) -> void:
	_message_box.text = text
	_message_timer = 2.0


func _on_zone_entity_removed(entity_id: String) -> void:
	if _entity_nodes.has(entity_id):
		_entity_nodes[entity_id].queue_free()
		_entity_nodes.erase(entity_id)
