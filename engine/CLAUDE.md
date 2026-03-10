# JRPG Project: Engine

This file describes the game engine architecture, and instructions for inter-file design and development.

---

## Coding Standards

- **No game logic in `_ready()` or `_process()`.** These are for initialization and per-frame visual updates only. Gameplay logic belongs in dedicated methods called by the appropriate Manager autoload. However, these may be used for test/integration scenes.
- **All inter-system communication goes through `EventBus`.** Never hold a direct reference to another system's node if that communication can be expressed as a signal. Direct references are acceptable within the same scene/subsystem.
- **Do not call `load()` or `ResourceLoader.load()` directly anywhere.** All resource loading goes through `ConfigLoader`.
- **Do not use `get_node()` with long absolute paths.** Use `@onready var` with relative paths or signals.

---

## Project Structure

- The `engine/` dir contains folders for major mechanic/ features.
- Each mechanic has a model, view & controller directory. There may be several different models or controllers with specific implementations (Battle1v1.gd vs BattleATB.gd for example)
- A `.tscn` scene and its primary `.gd` script always live in the same folder.
- Pure logic scripts with no associated scene belong in the `engine/shared` directory

An example directory structure is as follows (this example is for illustration, and may not be the actual current implementation)

```
res://
└── engine/
    ├── core/                  # Autoloads: GameState, EventBus, ConfigLoader, etc.
    ├── shared/                # Common scripts, especially data model objects, used across multiple components
    │   ├── model/
    │   ├── controller/
    │   └── view/
    ├── battle/
    │   ├── model/             # BattleState.gd, CombatResult.gd (pure data, serializable)
    │   ├── controller/        # BattleManager.gd, combat system implementations
    │   └── view/              # BattleUI.tscn + BattleUI.gd, animations
    ├── world/
    │   ├── model/             # ZoneData.gd, EncounterTable.gd
    │   ├── controller/        # WorldManager.gd
    │   └── view/              # WorldMap.tscn, TileMapController.gd
    ├── entities/
    │   ├── model/             # Entity.gd, Move.gd, StatBlock.gd (the base resource classes)
    │   ├── controller/        # EntityController.gd
    │   └── view/              # EntitySprite.tscn
    ├── etc...
    └── ui/
        └── view/              # HUD.tscn, Menus, etc.

```

---

## Architecture Rules

### The Config-Driven Rule

Adding new *content* (monsters, moves, zones) must never require code changes, just new `.tres` configuration files.
Adding new *mechanic types* requires engine code, structured as an enum + match statement. Never modify existing match branches when adding new mechanics (options in the match statement). Specifying a mechanic type/ tuning hyper-parameters typically requires a different `.tres` configuration file.

### MVC Discipline

- **Model scripts** (`models/`): Pure data. No Node inheritance unless strictly required by Godot. Must be serializable to/from `.tres`.
- **View scenes** (`views/`): Display only. No game state mutations. No direct calls to Manager autoloads — listen to EventBus signals instead.
- **Controller scripts** (`controllers/` and `core/`): Mediate between model and view. Own the game loop logic. The only layer allowed to mutate GameState.

### Autoloads

The five core autoloads are registered in Godot's Project Settings. Do not create new autoloads without explicit instruction. All five live in `engine/core/`.

### EventBus

Declares signals only. No logic, no state.

- **EventBus signals are append-only.** Never remove or rename an existing signal — this breaks all listeners silently. Only add new signals.
- All inter-system events route through EventBus. If two systems need to communicate, it goes here.

### GameState

Single source of truth for all mutable game data. If you are tempted to store game state on a scene node, it goes in GameState instead.

- Only Controller-layer scripts may write to GameState properties.
- View scripts may read GameState but never write to it.

### ConfigLoader

The only place in the codebase that touches the filesystem or calls `load()`. All other scripts request resources through ConfigLoader.

### BattleManager

Owns the battle loop entirely. No scene or other autoload may mutate battle state directly — all battle state changes go through BattleManager's methods or via EventBus signals.

### WorldManager

Owns zone transitions, encounter triggering, and world map state. Same rules as BattleManager — no external script mutates world state directly

---

## Config Files

- All game content is defined in `.tres` Godot Resource files in `content/`.
- Resource class definitions (the GDScript that defines the schema) live in the relevant `models/` folder.
- `ConfigLoader` is responsible for all loading and validation.
- When creating a new Resource class, all properties must use `@export` with full type annotations.

---

## What NOT to Do

- Do not hardcode monster stats, move data, or zone layouts in GDScript.
- Do not let `engine/` reference `generator/` in any way.
- Do not call `load()` directly — use `ConfigLoader`.
- Do not store game state on scene nodes — use `GameState`.
- Do not mutate battle or world state outside of their respective Manager autoloads.
- Do not remove or rename existing EventBus signals — append only.
