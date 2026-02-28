# CLAUDE.md — JRPG Engine Project

This file defines how Claude Code should work in this codebase. Read it before doing anything else.
This, and all other CLAUDE.md files are 'living' files. Suggest updates or creation of any such file to the developer for approval.
Refer to `DESIGN_BIBLE.md` for full design intent, inspiration, and open questions.

---

## Project Summary

This is a **configurable JRPG engine** built in Godot 4, with GDScript. The long-term goal is a content generator that produces playable JRPG configurations automatically.
The engine and generator are strictly separate systems; The engine has zero direct awareness of the generator, only indirectly coupling via the "content" `.tres` configuration files created by the generator (or other sources).

---

## Coding Standards

- **Always use typed GDScript.** Every variable, parameter, and return type must be explicitly typed. No untyped variables.

  ```gdscript
  # CORRECT
  var speed: float = 5.0
  func calculate_damage(base: int, modifier: float) -> int:

  # WRONG
  var speed = 5.0
  func calculate_damage(base, modifier):
  ```

- **Naming convention**:
  - Files: PascalCase.gd, snake_case.tscn
  - Signals: past_tense_snake_case (e.g., battle_started, not on_battle_start)
  - Constants: ALL_CAPS_SNAKE
  - Private methods: _leading_underscore

- **No game logic in `_ready()` or `_process()`.** These are for initialization and per-frame visual updates only. Gameplay logic belongs in dedicated methods called by the appropriate Manager autoload.
- **All inter-system communication goes through `EventBus`.** Never hold a direct reference to another system's node if that communication can be expressed as a signal. Direct references are acceptable within the same scene/subsystem.
- **Do not call `load()` or `ResourceLoader.load()` directly anywhere.** All resource loading goes through `ConfigLoader`.
- **Do not use `get_node()` with long absolute paths.** Use `@onready var` with relative paths or signals.

---

## Project Structure

- Engine and Generator are in separate top level directories.
- The `engine/` dir contains folders for major mechanic/ features. Each has a model, view & controller directory. There may be several different models or controllers with specific implementations (Battle1v1.gd vs BattleATB.gd for example)
- A `.tscn` scene and its primary `.gd` script always live in the same folder.
- Pure logic scripts with no associated scene belong in the `engine/shared` directory
- If a new file's home is ambiguous, ask rather than guess.

```
res://
├── engine/
│   ├── core/                  # Autoloads: GameState, EventBus, ConfigLoader, etc.
│   ├── shared/                # Common scripts, especially data model objects, used across multiple components
│   │   ├── model/
│   │   ├── controller/
│   │   ├── view/
│   │   └── tests/
│   ├── battle/
│   │   ├── model/             # BattleState.gd, CombatResult.gd (pure data, serializable)
│   │   ├── controller/        # BattleManager.gd, combat system implementations
│   │   ├── view/              # BattleUI.tscn + BattleUI.gd, animations
│   │   └── tests/
│   ├── world/
│   │   ├── model/             # ZoneData.gd, EncounterTable.gd
│   │   ├── controller/        # WorldManager.gd
│   │   ├── view/              # WorldMap.tscn, TileMapController.gd
│   │   └── tests/
│   ├── entities/
│   │   ├── model/             # Entity.gd, Move.gd, StatBlock.gd (the base resource classes)
│   │   ├── controller/        # EntityController.gd
│   │   ├── view/              # EntitySprite.tscn
│   │   └── tests/
│   ├── etc...
│   └── ui/
│       └── view/              # HUD.tscn, Menus, etc.
│
├── generator/                 # Entirely separate — engine has zero awareness of this
│   ├── world/
│   ├── monster/
│   ├── moves/
│   └── etc.../
│
├── content/                   # All .tres config files live here (output of generator, input to engine)
│   ├── monsters/
│   ├── moves/
│   ├── zones/
│   └── etc.../
│
└── assets/
 ├── sprites/
 ├── audio/
 └── fonts/
```

---

## Architecture Rules

### The Config-Driven Rule

Adding new *content* (monsters, moves, zones) must never require code changes. Adding new *mechanic types* requires engine code, structured as an enum + match statement. Never modify existing match branches when adding new options — only add new ones.

### MVC Discipline

- **Model scripts** (`models/`): Pure data. No Node inheritance unless strictly required by Godot. Must be serializable to/from `.tres`.
- **View scenes** (`views/`): Display only. No game state mutations. No direct calls to Manager autoloads — listen to EventBus signals instead.
- **Controller scripts** (`controllers/` and `core/`): Mediate between model and view. Own the game loop logic. The only layer allowed to mutate GameState.

### The Engine/Generator Boundary

The `engine/` directory must never import from or reference `generator/`. The generator produces `.tres` files into `content/`; the engine reads from `content/`. That is the only connection between them.

### Autoloads

The five core autoloads are registered in Godot's Project Settings. Do not create new autoloads without explicit instruction. All five live in `engine/core/`.

### EventBus

Declares signals only. No logic, no state.

- **EventBus signals are append-only.** Never remove or rename an existing signal — this breaks all listeners silently. Only add new signals.
- All inter-system events route through EventBus. If two systems need to communicate, it goes here.

Current signals (add to this list as the project grows, never remove):

```gdscript
signal battle_started(enemy_data: Resource)
signal battle_ended(result: String)       # "win", "lose", "flee"
signal entity_fainted(entity_id: String)
signal xp_gained(amount: int)
signal zone_transition_requested(zone_id: String)
signal save_requested()
signal load_requested()
```

### GameState

Single source of truth for all mutable game data. If you are tempted to store game state on a scene node, it goes in GameState instead.

- Only Controller-layer scripts may write to GameState properties.
- View scripts may read GameState but never write to it.

### ConfigLoader

The only place in the codebase that touches the filesystem or calls `load()`. All other scripts request resources through ConfigLoader.

### BattleManager

Owns the battle loop entirely. No scene or other autoload may mutate battle state directly — all battle state changes go through BattleManager's methods or via EventBus signals.

### WorldManager

Owns zone transitions, encounter triggering, and world map state. Same rules as BattleManager — no external script mutates world state directly.

---

## Config Files

- All game content is defined in `.tres` Godot Resource files in `content/`.
- Resource class definitions (the GDScript that defines the schema) live in `engine/entities/models/` or the relevant `models/` folder.
- `ConfigLoader` is responsible for all loading and validation.
- When creating a new Resource class, all properties must use `@export` with full type annotations.

---

## What NOT to Do

- Do not hardcode monster stats, move data, or zone layouts in GDScript.
- Do not add story, dialogue systems, or narrative content — out of scope.
- Do not use Unity-style patterns. Use Godot's node tree and signals.
- Do not let `engine/` reference `generator/` in any way.
- Do not call `load()` directly — use `ConfigLoader`.
- Do not store game state on scene nodes — use `GameState`.
- Do not mutate battle or world state outside of their respective Manager autoloads.
- Do not remove or rename existing EventBus signals — append only.

---

## Asking for Clarification

If a task is ambiguous about which combat system mode to use, assume **1v1 turn-based (Pokémon-style)** as the default unless told otherwise.

If a task would require resolving an open question from `DESIGN_BIBLE.md`, **stop and flag it** rather than making an assumption. Open questions are design decisions that the developer wants to make explicitly.
