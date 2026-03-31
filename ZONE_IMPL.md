# Zone Implementation Plan

> **Scope of this document:** Engineering companion to `ZONE_DESIGN.md`. Where the design document defines *what* to build and *why*, this document defines *how* to build it. It specifies the class architecture, Godot subsystems to use, critical interfaces, data flow, and build order for the zone system. This document is intended to be handed to an implementing engineer (or Claude Code instance) as the authoritative implementation guide.
>
> This document does not repeat design requirements. Read `ZONE_DESIGN.md` first.

---

## 1. Architecture Overview

The zone system is composed of four distinct layers:

```
┌─────────────────────────────────────────────────────┐
│                  CONTENT LAYER                      │
│   .tres files in content/world/ — authored by       │
│   generator or by hand. Never mutated at runtime.   │
└────────────────────────┬────────────────────────────┘
                         │ loaded by
┌────────────────────────▼────────────────────────────┐
│                  SCHEMA LAYER                       │
│   Resource class definitions in schema/world/       │
│   ZoneResource, TileDefinitionResource, etc.        │
└────────────────────────┬────────────────────────────┘
                         │ consumed by
┌────────────────────────▼────────────────────────────┐
│                  ENGINE LAYER                       │
│   Runtime nodes and autoloads in engine/world/      │
│   ZoneLoader, ZoneScene, MovementController, etc.   │
└────────────────────────┬────────────────────────────┘
                         │ signals via
┌────────────────────────▼────────────────────────────┐
│               CROSS-CUTTING AUTOLOADS               │
│   WorldClock, EventBus, Blackboard                  │
│   Owned by no single system. Globally accessible.   │
└─────────────────────────────────────────────────────┘
```

The engine layer has zero awareness of the generator. The only coupling between generator and engine is the `.tres` files in `content/world/`.

---

## 2. Directory Structure

```
res://
├── schema/
│   └── world/
│       ├── ZoneResource.gd
│       ├── TileDefinitionResource.gd
│       ├── TileEffectResource.gd
│       ├── PassabilityConditionResource.gd
│       ├── EntityDefinitionResource.gd
│       └── EncounterTableResource.gd
│
├── engine/
│   └── world/
│       ├── ZoneScene.tscn              # the runtime scene for any zone
│       ├── ZoneScene.gd
│       ├── ZoneLoader.gd               # autoload
│       ├── MovementController.gd       # shared component
│       ├── TileEffectRegistry.gd       # autoload
│       ├── EntityNode.tscn             # base entity scene
│       ├── EntityNode.gd
│       └── PlayerNode.tscn
│           └── PlayerNode.gd
│
├── engine/
│   └── core/
│       ├── WorldClock.gd               # autoload
│       ├── EventBus.gd                 # autoload
│       └── Blackboard.gd               # autoload
│
└── content/
    └── world/
        ├── zones/
        │   └── route_01.tres           # example ZoneResource instance
        └── tiles/
            └── global_tile_registry.tres
```

---

## 3. Schema Layer — Resource Classes

All classes live in `schema/world/`. They are pure data — no game logic, no node references. Engine and generator may both import from here.

### 3.1 `TileEffectResource`

The atomic unit of behavior. Used by tiles (on-enter/exit) and entities (on-interact). Never contains logic — only a tag and arguments that the `TileEffectRegistry` resolves at runtime.

```gdscript
# schema/world/TileEffectResource.gd
class_name TileEffectResource
extends Resource

@export var effect_tag: String        # e.g. "encounter_check", "warp", "set_flag"
@export var args: Dictionary          # e.g. { "zone_id": "town_01", "spawn": "south" }
```

### 3.2 `PassabilityConditionResource`

Encodes a single conditional passability rule. A tile may have zero or more of these evaluated before the base passability bitmask.

```gdscript
# schema/world/PassabilityConditionResource.gd
class_name PassabilityConditionResource
extends Resource

@export var direction_mask: int       # bitmask: which directions this condition guards
@export var condition_tag: String     # e.g. "has_item", "blackboard_flag"
@export var condition_args: Dictionary # e.g. { "item": "surf" }
```

**Direction bitmask encoding:**

```
Bit 0 = can enter from North
Bit 1 = can enter from South
Bit 2 = can enter from East
Bit 3 = can enter from West
Bit 4 = can exit to North
Bit 5 = can exit to South
Bit 6 = can exit to East
Bit 7 = can exit to West

All bits set (0b11111111 = 255) = fully passable
No bits set  (0b00000000 = 0)   = fully blocked
South-exit only (ledge) = 0b00100000 = 32
```

### 3.3 `TileDefinitionResource`

Defines a single tile *type*. Not a placed tile — a reusable definition that the tile palette references. Think of this as a tile class, not a tile instance.

```gdscript
# schema/world/TileDefinitionResource.gd
class_name TileDefinitionResource
extends Resource

@export var id: String                                  # e.g. "grass_standard"
@export var tags: PackedStringArray                     # e.g. ["grass", "outdoor"]
@export var texture: Texture2D                          # placeholder color rect is fine
@export var atlas_coords: Vector2i                      # which cell in the spritesheet

# Passability
@export var passability_mask: int = 255                 # default: fully passable
@export var conditions: Array[PassabilityConditionResource] = []

# Effects
@export var on_enter: TileEffectResource                # null = no effect
@export var on_exit: TileEffectResource                 # null = no effect

# Encounters
@export var encounter_table_override: EncounterTableResource  # null = inherit zone default

# Physics
# Which Godot physics layer this tile's collision shape lives on.
# 0 = no collision (decoration, floor). 1 = world_static. 2 = water. etc.
@export var physics_layer: int = 0
```

### 3.4 `EncounterTableResource`

```gdscript
# schema/world/EncounterTableResource.gd
class_name EncounterTableResource
extends Resource

@export var encounter_chance: float = 0.1               # per-step probability (0.0-1.0)
@export var entries: Array[EncounterEntryResource] = []

# EncounterEntryResource is a small inline resource:
# { monster_id: String, weight: int, level_min: int, level_max: int }
```

### 3.5 `EntityDefinitionResource`

Defines a placed entity in a zone. Composition-based — behavior is expressed through effect tags, not subclasses. Common archetypes (see §6) are convenience constructors over this base resource.

```gdscript
# schema/world/EntityDefinitionResource.gd
class_name EntityDefinitionResource
extends Resource

@export var id: String
@export var display_name: String
@export var position: Vector2i                          # cell coordinates in zone grid

# Visual
@export var sprite: Texture2D                          # null = invisible entity
@export var z_index: int = 2                           # default: entity layer

# Physics
@export var has_collision: bool = true
@export var physics_layer: int = 3                     # default: entities layer

# Behavior (tag + args pattern throughout)
@export var on_interact: TileEffectResource            # null = not interactable
@export var on_enter: TileEffectResource               # player steps onto same cell
@export var on_load: TileEffectResource                # fires when zone loads
@export var movement_behavior: TileEffectResource      # null = static; "wander", "patrol"

# State
@export var tags: PackedStringArray                    # e.g. ["npc", "blocking"]
@export var persistence_scope: String = ""             # "": none, "zone": ephemeral, "save": persistent
@export var flag_open_condition: String = ""           # blackboard flag that controls active state
```

### 3.6 `ZoneResource`

The top-level zone definition. One `.tres` file per zone in `content/world/zones/`.

```gdscript
# schema/world/ZoneResource.gd
class_name ZoneResource
extends Resource

# Metadata
@export var id: String
@export var display_name: String
@export var width: int
@export var height: int
@export var spawn_points: Dictionary                   # String -> Vector2i; Must contain "default"

# Tile palette (hybrid global + local)
# Global tile IDs are strings referencing the global tile registry.
# Local overrides are TileDefinitionResources defined inline.
@export var local_tile_palette: Array[TileDefinitionResource] = []

# Layers: each is a flat PackedInt32Array of length (width * height).
# Values are indices into the resolved tile palette (global + local combined).
# -1 = void cell (absent tile).
@export var layer_ground: PackedInt32Array
@export var layer_decoration: PackedInt32Array

# Entities
@export var entities: Array[EntityDefinitionResource] = []

# Encounters
@export var default_encounter_table: EncounterTableResource  # null = no encounters
```

---

## 4. Global Tile Registry

Common tile types (grass, path, water, wall) are defined once and shared across all zones. This prevents the generator from re-defining identical tile behaviors in every zone config.

The registry is a single resource file at `content/world/tiles/global_tile_registry.tres`, loaded once by the engine on startup.

```gdscript
# schema/world/GlobalTileRegistry.gd
class_name GlobalTileRegistry
extends Resource

@export var tiles: Array[TileDefinitionResource] = []
```

At runtime, the engine resolves a zone's effective palette by merging:

1. All tiles from the global registry (indices 0..N-1)
2. All tiles from `ZoneResource.local_tile_palette` (indices N..M)

Layer arrays reference into this merged palette. The generator must be aware of global registry indices when authoring zones, or use string IDs resolved at load time (see §5.1).

---

## 5. Engine Layer — Runtime Systems

### 5.1 `ZoneLoader` (Autoload)

Responsible for loading a `ZoneResource` `.tres` file and constructing the live `ZoneScene`. Nothing else in the engine loads zones — all zone transitions go through `ZoneLoader`.

**Interface:**

```gdscript
# engine/world/ZoneLoader.gd (autoload as "ZoneLoader")

func load_zone(zone_id: String, spawn_point: String) -> void
# Loads content/world/zones/{zone_id}.tres
# Constructs ZoneScene, places player at named spawn point
# Tears down previous zone scene

func get_current_zone() -> ZoneResource
```

**Responsibilities:**

- Resolve `zone_id` to a `.tres` path
- Instantiate `ZoneScene.tscn` and populate it from the `ZoneResource`
- Initialize `Blackboard` ephemeral scope for the new zone
- Place the `PlayerNode` at the named spawn point
- Stub interface to world graph: emit `EventBus.zone_load_requested(zone_id, spawn_point)` and let the world graph (future) handle routing. For prototype, `ZoneLoader` handles it directly.

### 5.2 `ZoneScene` (Node2D)

The live runtime scene for a zone. Constructed by `ZoneLoader` from a `ZoneResource`. Owns all TileMapLayers and the entity container.

**Scene tree:**

```
ZoneScene (Node2D)
├── TileMapLayer: "ground"       z_index=0
├── TileMapLayer: "decoration"   z_index=1
├── Entities (Node2D)            z_index=2, y_sort_enabled=true
│   └── [EntityNode instances spawned at runtime]
├── Overlay (TileMapLayer)       z_index=3  (tree canopies, bridge tops)
└── Camera2D                     follows PlayerNode, clamped to zone bounds
```

**Responsibilities:**

- On `_ready()`: populate TileMapLayers from `ZoneResource` layer arrays + resolved palette
- Spawn `EntityNode` instances for each `EntityDefinitionResource` in the zone
- Register zone bounds with `Camera2D`
- On zone teardown: free all entity nodes, clear ephemeral blackboard scope

**TileMap population (pseudocode):**

```gdscript
func _populate_layer(layer: TileMapLayer, data: PackedInt32Array, palette: Array):
    for i in data.size():
        var cell = Vector2i(i % zone.width, i / zone.width)
        var tile_idx = data[i]
        if tile_idx == -1: continue  # void cell
        var tile_def = palette[tile_idx]
        # Set tile visuals via Godot TileSet atlas coords
        layer.set_cell(cell, tile_def.atlas_source_id, tile_def.atlas_coords)
```

Godot's TileMap handles merging collision shapes from all painted tiles automatically. Per-tile collision shapes are defined in the TileSet asset (editor-side), keyed by atlas coords.

### 5.3 `MovementController` (Shared Component Script)

The core movement resolution logic. Used by both `PlayerNode` (input-driven) and `EntityNode` (AI-driven). Implemented as a standalone script that is attached to or called by both. Not a node — a pure logic class.

**Interface:**

```gdscript
# engine/world/MovementController.gd

static func try_move(
    actor,                    # PlayerNode or EntityNode
    direction: Vector2i,      # unit vector: N=Vector2i(0,-1), S=(0,1), etc.
    zone: ZoneScene
) -> bool:                    # true = move committed, false = bonked
```

**Resolution phases (sequential):**

```
Phase 1 — Geometry check (Godot physics):
  Owns: "Is there a physical object in the way?"
  Cast a ray from actor.global_position toward target world position.
  Collision mask = actor's current collision mask.
  If ray hits → bonk, return false.
  This catches solid terrain (layer 1), other entity bodies (layer 3), and water when surf is not unlocked (layer 2).
  Phase 1 Ownership rule: 
    Physics layers are the sole mechanism for geometry-level blocking. Toggling a physics layer on the actor's collision mask (e.g. removing layer 2 when surf is unlocked) is the correct way to make a tile class passable/impassable globally. Phase 2 never duplicates this — it does not re-check geometry.

Phase 2 — Custom passability check:
  Owns: "Does the game's rule system allow this move?"
  Resolve target cell = actor.logical_cell + direction
  Fetch TileDefinitionResource at target cell from ground + collision layers
  Evaluate passability_mask for the entry direction
  If blocked → bonk, return false.
  Evaluate each PassabilityConditionResource:
    This catches some directional rules (ledges, one-way corridors) and condition gates (flags, story progression)
    Query condition_tag against Blackboard / player inventory
    If condition fails → bonk, return false.
  Also evaluate exit conditions on current cell for the exit direction.
  Phase 2 Ownership rule: 
    Phase 2 never controls what geometry exists — only whether the game's logic permits traversal given that geometry is already clear. A ledge tile's south-only bitmask is a logic rule, not a geometry rule; the tile has no physics collision shape on layer 1.


Phase 3 — Commit:
  Fire on_exit effect for current tile (if any)
  Update actor.logical_cell = target_cell
  Update EntityRegistry if actor is an entity
  Fire on_enter effect for target tile (if any)
  Animate: tween actor's visual position to map_to_local(target_cell)
  return true
```

**Direction encoding:**

```gdscript
const NORTH = Vector2i(0, -1)
const SOUTH = Vector2i(0,  1)
const EAST  = Vector2i(1,  0)
const WEST  = Vector2i(-1, 0)

# Direction → entry bit mapping (for passability_mask)
const ENTRY_BIT = { NORTH: 0, SOUTH: 1, EAST: 2, WEST: 3 }
const EXIT_BIT  = { NORTH: 4, SOUTH: 5, EAST: 6, WEST: 7 }
```

### 5.4 `TileEffectRegistry` (Autoload)

A registry of all named effects the engine knows how to execute. This is the only place effect logic lives — tiles and entities reference effects by tag, never by code.

```gdscript
# engine/world/TileEffectRegistry.gd (autoload as "TileEffectRegistry")

var _registry: Dictionary = {}  # String -> Callable

func register(tag: String, handler: Callable) -> void:
    _registry[tag] = handler

func execute(effect: TileEffectResource, context: Dictionary) -> void:
    if effect == null: return
    if not _registry.has(effect.effect_tag):
        push_error("Unknown effect tag: %s" % effect.effect_tag)
        return
    _registry[effect.effect_tag].call(effect.args, context)
```

**Context dictionary** passed to every effect handler:

```gdscript
{
    "actor": PlayerNode or EntityNode,
    "zone": ZoneScene,
    "cell": Vector2i
}
```

**Built-in effects registered at engine startup:**

| Tag | Handler behavior |
|---|---|
| `encounter_check` | Roll against encounter table, emit `EventBus.encounter_triggered` if hit |
| `warp` | Emit `EventBus.warp_requested(zone_id, spawn_point)` — ZoneLoader handles it |
| `set_flag` | Write to Blackboard at specified scope |
| `damage` | Apply damage to player party (stub for prototype) |
| `apply_status` | Apply status tag to player (stub for prototype) |
| `forced_exit` | Queue a forced move in specified direction on next tick |
| `show_text` | Emit `EventBus.show_text_requested(text)` — UI handles it |
| `give_item` | Add item to player inventory, mark entity collected in save BB |
| `remove_self` | Check condition, remove entity from zone and registry if passes |

New effects are added by calling `TileEffectRegistry.register()` — never by modifying existing handlers.

### 5.5 `EntityRegistry` (Autoload or Zone-scoped)

A spatial index mapping grid cells to live entity nodes. The authoritative answer to "what entity is at cell X,Y?"

```gdscript
# engine/world/EntityRegistry.gd (autoload as "EntityRegistry")

var _map: Dictionary = {}  # Vector2i -> EntityNode

func register(cell: Vector2i, entity: EntityNode) -> void
func unregister(cell: Vector2i) -> void
func get_entity_at(cell: Vector2i) -> EntityNode  # null if empty
func move_entity(from: Vector2i, to: Vector2i) -> void

func clear() -> void  # called by ZoneLoader on zone teardown
```

Entities call `register()` in `_ready()` and `unregister()` in `_exit_tree()`. Movement calls `move_entity()` atomically. This is the Phase 3 conflict check source.

---

## 6. Entity System

### 6.1 `EntityNode` (Node2D)

The runtime Godot node for all zone entities. Instantiated from `EntityNode.tscn` by `ZoneScene` for each `EntityDefinitionResource`. Not subclassed per entity type — behavior is driven entirely by the `EntityDefinitionResource` data it is initialized with.

**Scene tree:**

```
EntityNode (CharacterBody2D or StaticBody2D, chosen at init)
├── Sprite2D
└── CollisionShape2D   (disabled if has_collision = false)
```

Use `CharacterBody2D` for moving entities (wandering NPC). Use `StaticBody2D` for static entities (sign, boulder). The scene uses `CharacterBody2D` by default; static entities disable their movement processing.

**Key interface:**

```gdscript
# engine/world/EntityNode.gd

var logical_cell: Vector2i
var definition: EntityDefinitionResource

func initialize(def: EntityDefinitionResource, zone: ZoneScene) -> void:
    # Set logical_cell, sprite, collision, register with EntityRegistry
    # Subscribe to EventBus.flag_changed if flag_open_condition is set
    # Subscribe to WorldClock signals based on movement_behavior

func interact() -> void:
    # Called by PlayerNode when player presses interact adjacent to this entity
    TileEffectRegistry.execute(definition.on_interact, context)

func take_step() -> void:
    # Called by WorldClock.ticked (for moving entities only)
    # Runs movement AI, calls MovementController.try_move()

func _on_flag_changed(flag_name: String, _value: Variant) -> void:
    if flag_name == definition.flag_open_condition:
        _re_evaluate_state()
```

### 6.2 Entity Archetypes

Archetypes are static factory functions (not subclasses) that construct pre-configured `EntityDefinitionResource` instances. They live in the generator, not the engine — the engine only knows `EntityDefinitionResource`.

The six prototype archetypes and their canonical field configurations:

| Archetype | has_collision | movement_behavior | on_interact | persistence_scope |
|---|---|---|---|---|
| `static_interactable` | false | null | `show_text` | "" |
| `collectible` | false | null | `give_item` | "save" |
| `warp_object` | false | null | `warp` | "" |
| `wandering_npc` | true | `"wander"` | `show_text` | "" |
| `blocking_object` | true | null | null | "" |
| `destructible` | true | null | `remove_self` | "save" |

### 6.3 Player Node

The player is **not** an `EntityDefinitionResource`. It is a persistent engine node that survives zone transitions. It is not managed by `EntityRegistry`.

However, `PlayerNode` shares `MovementController` with entity nodes — it calls `MovementController.try_move()` exactly as entities do, with input direction supplied by the input system rather than AI.

```gdscript
# engine/world/PlayerNode.gd

var logical_cell: Vector2i
var collision_mask: int     # modified at runtime (e.g. surf unlocked)

func _on_pre_tick() -> void:
    # Connected to WorldClock.pre_tick
    # Read input, store intended direction (do not move yet)

func _on_tick() -> void:
    # Connected to WorldClock.tick
    # Call MovementController.try_move() with stored direction
    # Player resolves before entities (pre_tick fires first)

func try_interact() -> void:
    # Check the cell the player is facing
    # Query EntityRegistry for entity at that cell
    # Call entity.interact() if found
```

---

## 7. Cross-Cutting Autoloads

### 7.1 `WorldClock` (Autoload)

Drives the game world at a fixed tick rate independent of player input. The world moves even when the player stands still.

```gdscript
# engine/core/WorldClock.gd (autoload as "WorldClock")

signal pre_tick     # input/AI collection phase — player and entities decide intent
signal tick         # commit phase — movement resolved sequentially (player first)
signal post_tick    # effects phase — on_enter/on_exit, encounter checks

@export var tick_duration: float = 0.3   # configurable; seconds per world step

var _accumulator: float = 0.0

func _process(delta: float) -> void:
    _accumulator += delta
    if _accumulator >= tick_duration:
        _accumulator -= tick_duration
        pre_tick.emit()
        tick.emit()
        post_tick.emit()
```

**Tick order contract:**

- `PlayerNode` connects to `pre_tick` to read input.
- `PlayerNode` connects to `tick` to resolve movement (player moves first).
- `EntityNode` instances connect to `tick` to resolve movement (entities move after player, in registration order).
- `TileEffectRegistry` on-enter/exit effects fire during `post_tick`.

This ordering ensures entities always see the player's committed position when they resolve, preventing same-cell conflicts without a deconfliction pass.

### 7.2 `EventBus` (Autoload)

A small set of engine-level signals for cross-system communication. Not a general purpose message bus — only signals that genuinely need to cross system boundaries live here.

```gdscript
# engine/core/EventBus.gd (autoload as "EventBus")

# World signals
signal zone_load_requested(zone_id: String, spawn_point: String)
signal warp_requested(zone_id: String, spawn_point: String)
signal encounter_triggered(encounter_table: EncounterTableResource)

# Entity / flag signals
signal flag_changed(flag_name: String, value: Variant)
signal entity_removed(entity_id: String)
signal item_collected(item_id: String)

# UI signals
signal show_text_requested(text: String)
```

**Pattern for entity-to-entity communication:** The emitting entity writes to `Blackboard` first, then emits `flag_changed`. Receiving entities subscribe to `flag_changed` and query the blackboard for their specific data. The event bus carries the notification; the blackboard carries the data.

### 7.3 `Blackboard` (Autoload)

Key-value store with two lifetime scopes. The authoritative state store for all runtime game state that needs to outlive a single effect call.

```gdscript
# engine/core/Blackboard.gd (autoload as "Blackboard")

var _zone: Dictionary = {}    # ephemeral — cleared on zone load
var _save: Dictionary = {}    # persistent — serialized to save file

func set_zone(key: String, value: Variant) -> void
func get_zone(key: String, default: Variant = null) -> Variant

func set_save(key: String, value: Variant) -> void
func get_save(key: String, default: Variant = null) -> Variant

func clear_zone_scope() -> void   # called by ZoneLoader on zone transition
func serialize_save() -> Dictionary    # called by save system
func deserialize_save(data: Dictionary) -> void
```

---

## 8. Godot Physics Layer Assignments

Reserved physics layer assignments for the zone system. These must be consistent across the entire engine.

| Layer # | Name | What lives here |
|---|---|---|
| 1 | `world_static` | Solid terrain tiles (walls, trees, cliffs) |
| 2 | `water` | Water tiles |
| 3 | `entities` | NPCs, boulders, blocking objects |
| 4 | `entity_triggers` | (Future) LoS cones, soft trigger volumes |

**Player collision mask** (which layers the player collides with):

- Default: layers 1 + 3 (solid terrain + entities)
- Surf unlocked: layers 1 + 3 only (water layer 2 removed from mask, not added)
- Water is blocked by default; surf removes the block.

```gdscript
# Toggling surf at runtime — one line
player.set_collision_mask_value(2, false)  # surf unlocked: water no longer blocks
player.set_collision_mask_value(2, true)   # surf not available: water blocks
```

---

## 9. Render Layer (Z-Index) Assignments

| Z-Index | Node | Contents |
|---|---|---|
| 0 | TileMapLayer "ground" | Base terrain |
| 1 | TileMapLayer "decoration" | Ground details, floor markings |
| 2 | Node2D "entities" (y_sort_enabled=true) | NPCs, player, collectibles |
| 3 | TileMapLayer "overlay" | Tree canopies, bridge tops, roofs |

Y-sorting within Z=2 is handled by Godot natively (`y_sort_enabled = true` on the entities container). No custom sorting code required.

---

## 10. Key Data Flows

### 10.1 Player Movement Flow

```
WorldClock.pre_tick →
  PlayerNode reads input → stores intended_direction

WorldClock.tick →
  PlayerNode calls MovementController.try_move(self, intended_direction, zone)
    Phase 1: raycast in direction — geometry blocked? → bonk
    Phase 2: query TileDefinitionResource at target cell
             check passability_mask for entry direction
             evaluate PassabilityConditionResources → condition fails? → bonk
    Phase 3: EntityRegistry.get_entity_at(target_cell) → occupied? → bonk
    Phase 4: commit
      fire current tile on_exit via TileEffectRegistry
      logical_cell = target_cell
      tween visual position (cosmetic only)
  Entities resolve movement (same flow, AI-driven direction)

WorldClock.post_tick →
  fire target tile on_enter via TileEffectRegistry
  encounter check if tile has encounter table
```

### 10.2 Interact Flow

```
Player presses interact key →
  PlayerNode.try_interact() →
    facing_cell = logical_cell + facing_direction
    entity = EntityRegistry.get_entity_at(facing_cell)
    if entity != null:
      entity.interact()
        TileEffectRegistry.execute(definition.on_interact, context)
          e.g. "show_text" → EventBus.show_text_requested.emit(text)
          e.g. "give_item" → add to inventory, Blackboard.set_save(collected_key, true)
                             EventBus.item_collected.emit(item_id)
                             entity.queue_free()
```

### 10.3 Flag-Driven Entity State Change (Button → Door)

```
Player interacts with button entity →
  on_interact: TileEffectResource { tag: "set_flag", args: { flag: "door_west_open", scope: "zone" } }
  TileEffectRegistry executes "set_flag" →
    Blackboard.set_zone("door_west_open", true)
    EventBus.flag_changed.emit("door_west_open", true)

Door entity (subscribed to EventBus.flag_changed) →
  _on_flag_changed("door_west_open", true) →
    _re_evaluate_state():
      var is_open = Blackboard.get_zone("door_west_open")
      collision_shape.disabled = is_open
      # sprite swap: future concern, deferred
```

### 10.4 Zone Transition Flow

```
Player steps onto warp tile →
  TileEffectRegistry executes "warp" { zone_id: "town_01", spawn_point: "south_entrance" } →
    EventBus.warp_requested.emit("town_01", "south_entrance")

ZoneLoader (listening to warp_requested) →
  Blackboard.clear_zone_scope()
  free current ZoneScene
  load content/world/zones/town_01.tres
  instantiate new ZoneScene, populate from resource
  place PlayerNode at spawn_points["south_entrance"]
```

---

## 11. Prototype Build Order

Build in this sequence. Each step is independently testable before the next begins.

**Step 1 — Schema only**
Write all resource classes in `schema/world/`. No engine code yet. Manually author a minimal `ZoneResource` `.tres` for one test zone (10×10 grid, 3 tile types, no entities). Verify it loads without errors.

**Step 2 — TileMap rendering**
Build `ZoneScene` with TileMapLayer population from the test `ZoneResource`. No movement, no entities. Verify tiles render correctly from the palette + layer arrays.

**Step 3 — Player movement**
Add `WorldClock` autoload. Add `PlayerNode` with `MovementController`. Implement Phase 1 (raycast) and Phase 4 (commit + tween) only — skip custom passability for now. Verify the player walks around and bonks on walls.

**Step 4 — Custom passability**
Add `PassabilityConditionResource` evaluation (Phase 2). Add a ledge tile (south-only passability mask) and a water tile (fully blocked by default) to the test zone. Verify ledge and water behave correctly.

**Step 5 — Autoloads: EventBus, Blackboard, EntityRegistry**
Wire up the three cross-cutting autoloads. No functionality yet — just verify they initialize and are accessible.

**Step 6 — Static entities**
Add `EntityNode`. Populate a sign and a collectible in the test zone. Implement `TileEffectRegistry` with `show_text` and `give_item`. Verify interact flow works end to end.

**Step 7 — Zone transitions**
Add `ZoneLoader`. Author a second minimal zone. Add a warp tile in zone 1 that transitions to zone 2. Verify transition, spawn placement, and blackboard scope reset.

**Step 8 — Wandering NPC**
Add movement AI (`wander` behavior tag) to `EntityNode`. Connect to `WorldClock.tick`. Verify NPC moves, respects terrain collision, and is interactable when adjacent. This is the final prototype requirement from the design doc.

**Step 9 — Encounter system**
Add `EncounterTableResource`. Register `encounter_check` effect. Wire up tall grass tile. Verify encounter rolls fire. Battle handoff is a stub (`encounter_triggered` signal emitted — battle system handles it separately).

---

## 12. Open Decisions & Deferred Items

| Item | Status | Notes |
|---|---|---|
| World graph interface | Stub for prototype | `ZoneLoader` handles transitions directly; world graph is a future system |
| Entity sprite state changes | Deferred | Single sprite per entity for prototype; multi-state sprites are additive later |
| Entity animations | Deferred | Out of scope for prototype |
| Camera bounds | Implement in Step 2 | `Camera2D` clamped to zone `width * tile_size`, `height * tile_size` |
| Tile atlas source IDs | Resolve at Step 2 | TileDefinitionResource needs an `atlas_source_id: int` field — the index of the texture source in the Godot TileSet asset |
| NPC wander AI specifics | Resolve at Step 8 | Simple random cardinal direction each tick is sufficient for prototype |
| Encounter trigger location | post_tick | Fires after movement committed, before next input read |
| Save/load serialization | Out of scope | `Blackboard.serialize_save()` interface is defined; implementation is a future milestone |
