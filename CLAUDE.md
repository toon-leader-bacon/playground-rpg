# CLAUDE.md — JRPG Engine Project

This file defines how Claude Code should work in this codebase. Read it before doing anything else.

---

## Project Summary

This is a **configurable JRPG engine** built in Godot 4, with GDScript. The long-term goal is a content generator that produces playable JRPG configurations automatically. The engine and generator are strictly separate systems.

Refer to `DESIGN_BIBLE.md` for full design intent, inspiration, and open questions.

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
- **No game logic in `_ready()` or `_process()`.** These are for initialization and per-frame visual updates only. Gameplay logic belongs in dedicated methods called by the appropriate Manager autoload.
- **All inter-system communication goes through `EventBus`.** Never hold a direct reference to another system's node if that communication can be expressed as a signal. Direct references are acceptable within the same scene/subsystem.
- **Scenes and their primary script live together.** `scenes/battle/BattleUI.tscn` and `scenes/battle/BattleUI.gd` are siblings. Pure logic scripts with no scene go in `scripts/`.

---

## Architecture Rules

### The Config-Driven Rule
Adding new *content* (monsters, moves, zones) must never require code changes. Adding new *mechanic types* requires engine code, structured as an enum + match statement. Never modify existing match branches when adding new options — only add new ones.

### MVC Discipline
- **Model scripts** (`scripts/data/`): Pure data. No Node inheritance unless required. Must be serializable.
- **View scenes** (`scenes/`): Display only. No game state mutations.
- **Controller autoloads** (`scripts/core/`): Mediate between model and view. Own the game loop logic.

### Autoloads Are the Skeleton
The five core autoloads are `GameState`, `EventBus`, `ConfigLoader`, `BattleManager`, and `WorldManager`. All major game systems route through these. Do not create new autoloads without explicit instruction.

---

## Project Structure

```
res://
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
├── scenes/
│   ├── battle/
│   ├── world/
│   ├── ui/
│   └── characters/
├── scripts/
│   ├── core/         # Autoload scripts (GameState, EventBus, etc.)
│   ├── battle/       # Combat system implementations
│   └── data/         # Resource definitions, model classes
├── resources/        # .tres config files (monsters, moves, zones)
│   ├── monsters/
│   ├── moves/
│   └── zones/
└── data/             # Any supplemental data files
```

---

## How to Implement New Mechanics

When asked to implement a new mechanic or system:

1. **Check `DESIGN_BIBLE.md` first.** Understand where this mechanic fits in the overall design.
2. **Define the interface before implementing.** What signals does it emit on `EventBus`? What config schema does it consume?
3. **Add to the appropriate match statement.** Don't create a parallel system — extend the existing one.
4. **Produce a minimal example `.tres` config** that exercises the new mechanic. Place it in the appropriate `resources/` subdirectory.
5. **Do not change existing behavior.** New mechanic branches must not affect existing branches.

---

## Config Files

- All content is defined in `.tres` Godot Resource files.
- Resource classes are defined in `scripts/data/`.
- `ConfigLoader` autoload is responsible for reading and validating resources.
- When creating a new resource type, define the `@export` properties with full type annotations.

---

## What NOT to Do

- Do not hardcode monster stats, move data, or zone layouts in GDScript.
- Do not add story, dialogue systems, or narrative content — out of scope.
- Do not create Unity-style patterns (no `GetComponent`, no `FindObjectOfType` equivalents). Use Godot's node tree and signals.
- Do not use `get_node()` with long absolute paths. Use `@onready var` with relative paths or signals.
- Do not modify the engine to depend on the content generator in any way.

---

## Asking for Clarification

If a task is ambiguous about which combat system mode to use, assume **1v1 turn-based (Pokémon-style)** as the default unless told otherwise.

If a task would require resolving an open question from `DESIGN_BIBLE.md`, **stop and flag it** rather than making an assumption. Open questions are design decisions that the developer wants to make explicitly.
