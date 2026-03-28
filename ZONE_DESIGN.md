# Zone Design Bible

> **Scope of this document:** Defines the design space for a Zone — the immediate, traversable area a player moves around in. This is distinct from the World Map, which is a higher-order structure linking zones together. This document is split into two sections: (1) the design space and feature requirements, and (2) early architectural discussion. The design space section is the authoritative product-owner perspective; the architecture section is exploratory and subject to change.

---

## Part 1: Design Space

---

### 1. What is a Zone?

A Zone is a single, self-contained traversable area. It is the immediate space the player inhabits at any given moment. A zone could be:

- An outdoor route between towns (primary design target)
- A town or city (with doors leading to building interiors)
- A building interior (a single room or small connected set of rooms)
- A dungeon floor

All of these are the same underlying concept: **a scrollable tile grid the player moves through, populated with tiles and entities.** The complexity varies by zone type, but the data model is the same. Outdoor routes represent the most complex edge of the design space and are the primary prototype target.

A zone is **not** the world map. Zone-to-zone connections are owned by the world graph, not by the zones themselves. A zone only knows about its own named exit points; it does not know where those exits lead.

---

### 2. Zone Structure

#### 2.1 Grid

- A zone is a **rectangular grid of 1x1 tiles**.
- Tiles may be marked as **void** — effectively absent — allowing irregular shapes (caves, coastlines, L-shaped rooms) to be expressed within a rectangular bounding box.
- Zones are **larger than the viewport** and require camera scrolling. There is no fixed size constraint.
- Zones (for now) are always flat. There is no native support things like a bridge passing over other parts of the map. (Note this still may be achieved via clever use of dynamic entity collision directions)

#### 2.2 Tile Layers

A zone's tile grid is composed of **multiple named layers**, stacked vertically. Each layer serves a distinct purpose. The layer stack (bottom to top) is:

| Layer | Purpose |
|---|---|
| **Ground** | Base terrain tiles (grass, dirt, water, stone). Always present. |
| **Decoration** | Overlaid visual details (flowers, shadows, overlapping tree tops). No gameplay logic. |
| **Collision / Logic** | Invisible or semi-visible tiles that define passability, effects, and directional rules. |
| **Entity** | Where zone entities are placed and tracked at runtime. Not a tile layer per se, but lives in the same spatial coordinate system. |

This mirrors Godot's native TileMap layer model and allows visual authoring to be decoupled from gameplay logic.

#### 2.3 Zone-Level Metadata

Every zone carries a small set of top-level properties:

- **`id: String`** — Unique identifier. Used by warps, spawn points, and the world graph to reference this zone.
- **`display_name: String`** — Human-readable name shown in the UI.
- **`spawn_points: Dictionary[String, Vector2i]`** — Named entry points (e.g. `"north_entrance"`, `"default"`). When the player enters a zone, they are placed at a named spawn point specified by the triggering warp or world event.
- **`default_encounter_table: EncounterTable`** — The zone-wide encounter table inherited by any tile that does not define its own. May be null (no random encounters in this zone).

> This list is intentionally minimal. Zone metadata will grow as new engine features are introduced. Avoid adding fields speculatively.

---

### 3. Tiles

#### 3.1 Core Tile Properties

Every tile in the ground/collision layers is an instance of a tile definition. A tile definition specifies:

- **Visual:** A reference to a tileset and atlas coordinates (Godot-native). Placeholder colors are acceptable for prototyping.
- **Tags:** An arbitrary array of string tags (e.g. `"water"`, `"tall_grass"`, `"ice"`, `"indoors"`). Tags are the primary mechanism for the engine to reason about tile identity without hardcoded type checks.
- **Passability:** Per-direction entry rules (see §3.2).
- **On-Enter Effect:** An optional effect triggered when the player steps onto this tile (see §3.3).
- **On-Exit Effect:** An optional effect triggered when the player steps off this tile (see §3.3).
- **Encounter Table Override:** An optional encounter table that overrides the zone-level default for this specific tile.

#### 3.2 Directional Passability

Passability is defined **per cardinal direction** — North, South, East, West — independently. This allows a rich set of traversal behaviors to be expressed:

| Pattern | How it's expressed |
|---|---|
| Solid wall | All four directions blocked |
| Normal floor | All four directions open |
| Pokemon ledge (jump south only) | N, E, W blocked; S open (exit only) |
| One-way corridor | Some combination of entry/exit blocked |
| Conveyor tile | All entry directions open; forced exit in one direction via on-exit effect |
| Water (requires Surf) | All directions blocked unless condition passes |

Passability conditions may be **conditional** — a tile is passable only if a named condition is satisfied. Conditions are referenced by tag and resolved by the engine at runtime (e.g. `"has_item:surf"`, `"black_board_flag:bridge_repaired"`). This is the same tag+args pattern used elsewhere in the engine (Namely the battle system, move resolver).

#### 3.3 Tile Effects (On-Enter / On-Exit)

Tile effects follow the **tag + arguments** pattern established in the battle system. A tile effect is not arbitrary code — it is a reference to a named, well-known effect in the engine's effect registry, plus optional arguments.

Examples:

| Effect Tag | Arguments | Behavior |
|---|---|---|
| `encounter_check` | `encounter_table_id` | Roll for random encounter on enter |
| `warp` | `spawn_point_id` | Teleport player to named spawn point (within same or different zone — destination resolved by world graph) |
| `damage` | `amount, type` | Deal damage to party on enter |
| `apply_status` | `status_tag` | Apply a status (e.g. poison) to party on enter |
| `forced_exit` | `direction` | Push player out in a specific direction on enter (conveyor) |
| `set_flag` | `flag_name` | Set a global or zone-scoped blackboard flag |

> **Tiles do not have on-interact hooks.** If a tile needs to be interactable (e.g. a readable bookshelf tile), it should be represented as an invisible entity placed on top of that tile, not as a tile property. This keeps tile logic passive and entity logic interactive.

#### 3.4 Encounter Tables

Encounter tables follow a **two-level inheritance model**:

1. **Zone-level default:** Defined in zone metadata. All tiles that do not specify their own encounter table inherit this.
2. **Tile-level override:** An individual tile may specify its own encounter table, completely replacing the zone default for that tile.

An encounter table specifies a list of `(monster_id, weight, level_range)` tuples, plus a per-step encounter probability. This is sufficient to express tall grass (common, broad table), rare patches (low probability, different table), and encounter-free areas (null table).

---

### 4. Entities

Entities are objects placed **on top of the tile grid**. They exist in the same coordinate space as tiles but are not tiles — they are independent actors with their own position, sprite, collision, and behavior. Entities are the primary source of player interaction in a zone.

#### 4.1 In-Scope Entity Types (Prototype)

| Type | Description |
|---|---|
| **Static Interactable** | A fixed object the player presses interact on. Signs, bookshelves, examine spots. |
| **Collectible** | An item or treasure on the ground. Disappears after collection. Persists collected state across zone reloads. |
| **Warp Object** | An invisible or visible entity that triggers a zone transition when interacted with or stepped on. Doors are the canonical example. Represents the entity-side of warp logic (as opposed to warp tiles). |
| **Wandering NPC** | An entity with simple autonomous movement (patrol path or wander behavior). Collidable. Interactable when adjacent. |
| **Blocking Object** | A static or moving entity that acts as dynamic collision (a boulder, a sleeping NPC). No interaction, just occupies space. |
| **Destructible / Removable** | An entity that can be removed from the zone via player action and a condition (Cut tree, pushed boulder). Removal is persisted. |

#### 4.2 Entity Interaction Model (Prototype)

For the prototype, entity behavior follows the same **tag + arguments** pattern as tile effects. An entity's `on_interact` field specifies a known effect tag and arguments.

Examples:

| Effect Tag | Arguments | Behavior |
|---|---|---|
| `show_text` | `text` | Display a text box |
| `give_item` | `item_id` | Transfer item to player, mark entity as collected |
| `warp` | `zone_id, spawn_point_id` | Trigger zone transition |
| `remove_self` | `condition_tag` | Remove entity if condition passes (cut tree, etc.) |

> This is intentionally simple. The entity design space is large and will be addressed in a dedicated **Entity Design Bible**. The prototype deliberately avoids: dialogue trees, state machines, AI behavior beyond movement, animations, trade menus, and battle triggers. These are future concerns.

#### 4.3 Entity Movement (Prototype Requirement)

The prototype **must** include at least one moving, collidable entity to stress-test the zone architecture. This is not a full AI system — it is a minimal proof of concept sufficient to validate that the zone can support dynamic actors.

Required for prototype:

- An entity that moves autonomously (wander or fixed patrol path)
- That entity participates in tile-grid collision (cannot walk through walls)
- That entity is interactable when the player is adjacent

This deliberately surfaces the architectural questions around dynamic collision and entity update loops *before* the zone system is considered complete, preventing design lock-in.

#### 4.4 Future Entity Design Space (Out of Scope for Zone Prototype)

The following are acknowledged as significant future design areas, captured here to avoid losing them:

- **Movement AI:** Wander, patrol, follow, flee, flocking, line-of-sight chasing
- **Trainer-style LoS triggers:** A directional collision volume that fires an event (battle start) when the player enters it. Effectively an autonomous collider behavior, not a passive tile property.
- **Entity blackboards:** Per-entity, per-zone, and per-save-state memory (e.g. "has this trainer been defeated?")
- **Animations:** Idle, walk, interact cycles
- **Rich interactions:** Dialogue trees, trade menus, battle initiation, item transfers

---

### 5. State & Persistence

Zones typically do not have state directly, and instead the entities on top of the zone may have state. However, the entities state may be attached to a zone. This follows the **Blackboard pattern** already established in the battle system. There may be many BB scopes with different lifetimes:

| Scope | Lifetime | Example Use |
|---|---|---|
| **Ephemeral (Zone BB)** | Cleared on zone load | Temporary flags, mid-zone events that reset on re-entry |
| **Persistent (Save BB)** | Intended to be included in save and load of the entire game state | Collected items, defeated trainers, removed destructibles |

The zone's static definition (the `.tres` file) is never mutated at runtime. Most changes to a zone can be expressed with entities (changing collision map for example) or loading a new zone entirely (underwater variants for example).

---

### 6. Design Principles & Constraints

- **Tiles are passive.** They define space and properties, but do not reach out and affect the world. Effects are triggered by the engine in response to player movement, not by tiles themselves.
- **Entities are active.** They are the primary locus of interaction and the thing players actually engage with.
- **No hardcoded tile types.** All tile behavior is driven by tags and effects. A new tile behavior is added by registering a new effect in the engine's registry, not by adding a new branch to zone traversal logic.
- **Zone knows its exits; world graph knows their destinations.** A zone exit is a named spawn point. The world graph resolves where that exit leads. This decouples zone authoring from world topology.
- **Content is data.** Everything described in this document must be fully expressible as a `.tres` config file authored by the generator (or by hand). No zone-specific logic lives in GDScript outside of the engine's effect registry.

---

## Part 2: Architectural Notes

> This section is exploratory. It is intended to illuminate key design decisions and flag architectural risks — not to be a final implementation spec. Implementation details will be developed in collaboration with the CLAUDE.md files and direct development work.

---

### A. Schema Shape (Sketch)

The zone schema will likely involve the following resource types in `schema/world/`:

- **`ZoneResource`** — Top-level zone definition. Holds metadata, layer data, entity list, spawn points, encounter table.
- **`TileDefinitionResource`** — Defines a single tile type: tags, passability mask, on-enter/exit effects, encounter table override, tileset reference.
- **`TileLayerResource`** — A 2D array (width × height) of tile definition references for a single layer.
- **`EntityDefinitionResource`** — Defines a placed entity: position, sprite, tags, on-interact effect, movement behavior tag.
- **`EncounterTableResource`** — A weighted list of monster entries with level ranges and encounter probability.
- **`TileEffectResource`** — A tag + args pair. Reusable across tile and entity definitions.

The zone `.tres` file is the `ZoneResource`, which composes all of the above.

### B. Directional Passability Encoding

Per-direction passability (N/S/E/W, enter/exit independently) can be encoded as a bitmask on the tile definition. 8 bits covers all combinations (4 directions × enter/exit). This is compact, fast to evaluate at runtime, and trivially serializable.

Conditional passability (requires Surf, requires flag) is a separate field — a list of `(direction_mask, condition_tag, condition_args)` tuples evaluated at runtime before the bitmask check.

### C. Entity Update Loop

Moving entities require an `_process` or `_physics_process` update loop in Godot. The zone scene will need to own or manage this loop for all entities. The key architectural question is whether entities are full Godot `Node` instances (rich, but heavy) or data-driven resources driven by a single system node (lighter, more consistent with the data-driven philosophy). This should be decided at implementation time, but the data-driven approach is preferred for consistency with the rest of the engine.

### D. Warp Resolution

Warp effects produce a `(zone_id, spawn_point_id)` payload. The engine passes this to the world graph, which is responsible for loading the destination zone and placing the player at the named spawn point. The zone itself never directly loads another zone — it fires an event and the world system handles the rest.

### E. Blackboard Integration

Individual entities are responsible for writing/ reading to the various BBs at the appropriate times.
