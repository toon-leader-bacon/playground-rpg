# Tile Collidables

Defines what happens when the player interacts with a tile — whether blocked by it, steps onto it,
or steps off it.

---

## How it works

When the player tries to move and a `RayCast2D` detects a `StaticBody2D` in the way, `movement.gd`
emits `movement_blocked(collider)`. `tile_placer.gd` handles this signal by finding a
`TileCollidable` child on the collider and calling `on_player_collide(player)`.

When the player moves successfully, `movement.gd` emits `tile_changed(from_tile, to_tile)`.
`tile_placer.gd` handles this signal by looking up the `StaticBody2D` for each tile in its
`_tile_body_map` and calling `on_player_exit(player)` on the old tile and `on_player_enter(player)`
on the new tile.

All three event types are driven by signals — `movement.gd` has no knowledge of `TileCollidable`
or the effect system.

Most tiles have no event entries at all and simply block or pass silently.

---

## Serialization format

In a tile definition dictionary, add optional `"on_collision"`, `"on_enter"`, and/or `"on_exit"`
fields:

```gdscript
# Bare tag — no config values needed
"on_collision": "my_tag"

# Tag with config values passed to the factory at tile creation time
"on_collision": {"function": "my_tag", "config": ["value1", "value2"]}

# Same format applies to on_enter and on_exit
"on_enter": {"function": "call_print_enter", "config": ["stepped onto tile"]}
"on_exit":  {"function": "call_print_exit",  "config": ["stepped off tile"]}
```

`config` values are baked into the component at creation time. They are not passed again at
event time. Think of them as constructor arguments, not event arguments.

---

## The two kinds of collidable

### 1. Stateless — register a lambda

Use this when the behaviour is a one-liner and needs no memory between events.
The factory captures `config` in a closure and wraps it in a generic `TileCollidable`.

```gdscript
CollisionRegistry.register("call_print", func(config: Array) -> TileCollidable:
    var c := TileCollidable.new()
    c.set_handler(func(_player: Node2D) -> void:
        print(config[0] if config.size() > 0 else "")
    )
    return c
)
```

The same pattern works for enter/exit via `set_enter_handler` and `set_exit_handler`:

```gdscript
CollisionRegistry.register("call_print_enter", func(config: Array) -> TileCollidable:
    var c := TileCollidable.new()
    c.set_enter_handler(func(_player: Node2D) -> void:
        print(config[0] if config.size() > 0 else "entered tile")
    )
    return c
)
```

Tile definition: `"on_collision": {"function": "call_print", "config": ["ouch"]}`

### 2. Stateful — subclass TileCollidable

Use this when the component needs to remember something between events (a counter, a cooldown,
a flag). Create a new `.gd` file that extends `TileCollidable` and override whichever of
`on_player_collide`, `on_player_enter`, `on_player_exit` you need.
The factory returns a fresh instance — each tile gets its own independent state.

```gdscript
# BonkCounterCollidable.gd
extends TileCollidable
class_name BonkCounterCollidable

var _count: int = 0

func on_player_collide(_player: Node2D) -> void:
    _count += 1
    print("Bonk #%d" % _count)
```

```gdscript
CollisionRegistry.register("bonk_counter", func(_config: Array) -> TileCollidable:
    return BonkCounterCollidable.new()
)
```

Tile definition: `"on_collision": {"function": "bonk_counter"}`

---

## 3. Shared state — blackboard

Use this when multiple tiles of the same type should contribute to a single shared counter or
flag — e.g. "total water bonks this zone" rather than "bonks on this specific water tile".

State lives in the `WorldBoard` autoload, which exposes two scopes:

| Scope | Method | Lifetime |
|---|---|---|
| Zone | `WorldBoard.set_zone` / `get_zone` | Cleared on every zone load |
| Save | `WorldBoard.set_save` / `get_save` | Persists across zone transitions |

The preferred form is a subclass so the dependency on `WorldBoard` is explicit and contained:

```gdscript
# WaterBonkCollidable.gd
extends TileCollidable
class_name WaterBonkCollidable

func on_player_collide(_player: Node2D) -> void:
    var zone_count: int = WorldBoard.get_zone("number_of_water_bonks", 0) + 1
    WorldBoard.set_zone("number_of_water_bonks", zone_count)

    var lifetime_count: int = WorldBoard.get_save("total_water_bonks_lifetime", 0) + 1
    WorldBoard.set_save("total_water_bonks_lifetime", lifetime_count)

    print("Water bonks this zone: %d | Lifetime: %d" % [zone_count, lifetime_count])
```

Tile definition: `"on_collision": {"function": "water_bonk_counter"}`

**Contrast with `bonk_counter`:** `BonkCounterCollidable` stores state on the component
instance — each wall tile has its own independent count. The blackboard approach stores state
in a single shared space — every water tile increments the same key. Both patterns are useful;
the choice depends on whether the state belongs to *a tile* or *the zone*.

**Note on naming:** The autoload is registered as `WorldBoard`, not `Blackboard`. `Blackboard`
refers to the battle system's `engine/shared/model/Blackboard.gd` — a different class entirely.

---

## Adding a new collidable type — checklist

1. Decide which state model fits:
   - No state → lambda in `_register_collision_handlers()`
   - Per-tile state → subclass `TileCollidable`, override the relevant method(s)
   - Zone-shared state → subclass `TileCollidable`, read/write `WorldBoard` directly
2. If subclassing: create `MyCollidable.gd` in this directory, extend `TileCollidable`.
   Override `on_player_collide`, `on_player_enter`, and/or `on_player_exit` as needed.
   Run `godot --headless --import` to register the class name.
3. Register the factory in `tile_placer.gd` → `_register_collision_handlers()`.
4. Reference it in a tile definition:
   - `"on_collision": {"function": "your_tag"}` — fires when movement is blocked by this tile
   - `"on_enter": {"function": "your_tag"}` — fires when the player steps onto this tile
   - `"on_exit": {"function": "your_tag"}` — fires when the player steps off this tile

---

## Files

| File | Role |
|---|---|
| `TileCollidable.gd` | Base component. Three optional handler callables (`_handler`, `_enter_handler`, `_exit_handler`). Subclass to add state. |
| `CollisionRegistry.gd` | Static factory registry. Maps tag strings to factory callables that produce `TileCollidable` instances. |
| `BonkCounterCollidable.gd` | Example stateful collidable. Counts collisions per tile instance. |
| `WaterBonkCollidable.gd` | Example stateful collidable using `WorldBoard` for zone- and save-scoped shared state. |
| `WallCollidable.gd` | Deprecated demo. Kept as a reference for the subclass pattern. |
