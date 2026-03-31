# Zone System — Software Architecture

This document captures the medium-level implementation decisions for the zone/world system,
the lessons learned from the initial prototype, and the architectural direction going forward.

---

## Prior Implementation (Prototype)

### What was built

The zone system is entirely hand-rolled, using Godot only for `Camera2D` and input events.

**Schema layer** (`schema/world/`)
Eight `Resource` subclasses define the data contract: `ZoneResource`, `TileLayerResource`
(palette + flat `PackedStringArray` of tile keys), `TileDefinitionResource` (tags +
8-bit directional passability bitmask), `TileEffectResource`, `PassabilityConditionEntry`,
`EncounterTableResource`, `EncounterEntryResource`, `EntityDefinitionResource`.

**Engine model** (`engine/world/model/`)
`ZoneState` holds mutable runtime state (player position, entity positions, removed entities).
`ZoneEffectContext` is the execution context passed to tile effect handlers.
`MoveResult` is a value object returned from every movement attempt.

**Engine controller** (`engine/world/controller/`)
`ZoneController` — static methods for `try_move`, `try_move_entity`, `try_interact`.
Passability is enforced by checking the 8-bit `passability_mask` on source and destination
tiles. Directional encoding: South `(0,+1)` checks ENTER_N + EXIT_S; North `(0,-1)` checks
ENTER_S + EXIT_N; etc.
`TileEffectRegistry` — tag-dispatched effect handlers (`encounter_check`, `warp`,
`show_text`, `set_flag`, `remove_self`; others are warning stubs).
`EntityBehaviorHandler` — wander (random direction each tick) and patrol (waypoint
following via zone blackboard).

**Engine view** (`engine/world/view/`)
`ZoneTileRenderer` — extends `Node2D`, overrides `_draw()` to paint solid-colour
rectangles for each visible tile. `PlayerEntityNode` and `EntityNode` are also `Node2D`
nodes that draw themselves with `_draw()`. `ZoneScene` owns zone loading, player input
routing, entity management, and EventBus wiring.

**Generator** (`generator/world/`)
`ZoneFactory.build_simple_route()` procedurally builds a `ZoneResource` in memory.
`ZoneRecipes` wraps it for the CLI. `ResourceSaver` writes the final `.tres` — this is
the only reliable way to produce valid `.tres` files for complex nested resources (see
Lessons Learned below).

### What works well

- The **schema + bitmask passability model** is a good fit for grid-based JRPGs.
  8-directional one-way ledges, conditional gates, and directional blockers are all
  expressible without special-casing.
- The **generator-first workflow** (code builds data → `ResourceSaver` writes `.tres`)
  is consistent with the rest of the project and works cleanly headlessly.
- The **TileEffectRegistry tag-dispatch** pattern (from `NodeRegistry` in the battle
  system) composes well: new effects are one Callable added to the registry, zero schema
  changes.
- The **ZoneState / ZoneController separation** is clean. Controllers are stateless static
  functions; all mutable world state lives in `ZoneState`.
- **41 tests, all passing**, covering schema round-trips, state construction, and
  controller passability logic.

---

## Lessons Learned

### 1. Custom rendering has a hard ceiling

`ZoneTileRenderer._draw()` is CPU-bound and redraws the entire map each time
`queue_redraw()` is called. Every tile is a separate `draw_rect` call. This does not
scale to large maps, animated tiles, or layered transparency effects.
Godot's `TileMapLayer` batches draw calls to the GPU and is the correct primitive for any
non-trivial tile map.

### 2. The passability bitmask is a feature, not a problem

Godot's built-in `TileMap` physics (collision shapes per tile + `CharacterBody2D`) is
axis-aligned and continuous. It handles "can I enter this tile?" but not "can I enter this
tile *from the north only*?". The directional bitmask gives one-way ledges, entry-only
gates, and conditional bridges that standard TileMap physics cannot express without
significant custom work.
The bitmask approach in `ZoneController` should be kept. Physics bodies are not the right
tool for grid-based discrete JRPG movement.

### 3. Never hand-author `.tres` files with complex nested resources

The `.tres` text format differs subtly from GDScript syntax in ways that cause silent
parse errors:

| Field type | GDScript look-alike (WRONG in .tres) | Correct .tres format |
|---|---|---|
| `PackedStringArray` | `PackedStringArray(["a","b"])` | `PackedStringArray("a","b")` |
| `Dictionary` with sub-resources | `{"k": SubResource("id")}` inline | multiline block, ResourceSaver output |

**Rule:** flat fields (int, String, Vector2i, enum) can be hand-authored. Any field that
is a `Resource`, `Array[Resource]`, or `PackedStringArray` should be written by
`ResourceSaver` via the generator CLI.

### 4. Collision layer invisibility is a UX problem

The `"collision"` layer tiles are intentionally skipped by `ZoneTileRenderer` (they are
data, not art). But this means impassable walls and one-way ledges are invisible at
runtime, making the world confusing to navigate and impossible to debug visually.
The renderer needs a debug overlay that visualises the collision layer — at minimum as a
semi-transparent tint over affected tiles.

### 5. The architecture naturally splits into two independent concerns

Rendering (what the tile *looks like*) and passability (what the tile *does to movement*)
are already separate in the data model (`tags` drive rendering; `passability_mask` drives
movement). The refactor should honour this by keeping them on independent code paths.

---

## New Architectural Plan

### Goal

Replace `ZoneTileRenderer._draw()` with a `TileMapLayer`-based renderer while leaving
`ZoneController`, `ZoneState`, the schema layer, all tests, and the generator untouched.

### Rendering: `ZoneTileRenderer` → `TileMapLayer`

For each renderable layer (`"ground"`, `"decoration"`):

1. Build a `TileSet` programmatically: one `TileSetAtlasSource` per palette entry, each
   backed by a solid-colour `ImageTexture` generated from the tile's tag colour.
2. Create a `TileMapLayer` node, assign the `TileSet`, call `set_cell()` for each
   non-void tile.
3. `add_child()` the `TileMapLayer` to `ZoneTileRenderer`.

This immediately provides GPU-batched rendering and a clear path to real sprites: the
`ImageTexture` swap becomes a one-line change per tile type when an artist provides atlas
files.

**No changes required in:** `ZoneController`, `ZoneState`, `ZoneScene`, schema,
generator, or tests.

### Passability: unchanged

`ZoneController` and the directional bitmask stay as-is. The case for replacing them with
`TileMap` physics is weak: Godot's physics is continuous and axis-aligned, which is
wrong for discrete grid movement with directional ledges.

### Debug overlay

A togglable `_draw()` overlay in `ZoneTileRenderer` (not a separate layer) draws a
semi-transparent tint over tiles whose collision-layer passability_mask is not
`PASSABLE_ALL`. Walls get a red tint; ledges get a yellow tint. Toggled via a flag
(`show_collision_debug: bool`).

### Sprites (future)

When tile sprites are available, the migration is:

1. Import sprite atlas into the project.
2. Replace `ImageTexture.create_from_image(solid_color_img)` with an atlas texture
   loaded via `ConfigLoader` (or a new `SpriteSheetConfig` resource).
3. Update `texture_region_size` and atlas coordinates to match the sprite sheet layout.

`TileLayerResource.tile_palette` keys become sprite IDs — no schema changes needed.

### Entity rendering (future)

`PlayerEntityNode` and `EntityNode` currently draw placeholder shapes with `_draw()`.
When sprites are available, replace with `AnimatedSprite2D` or `Sprite2D` nodes.
The tile-position logic (`position = Vector2(x * TILE_SIZE, y * TILE_SIZE)`) stays
identical.

---

## File Change Surface for the Refactor

| File | Change |
|---|---|
| `engine/world/view/ZoneTileRenderer.gd` | Full rewrite: remove `_draw()`, add `TileMapLayer` builder + optional debug overlay |
| Everything else | No changes |
