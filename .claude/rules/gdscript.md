---
paths:
  - "**/*.gd"
---

# GDScript Code Style

## Typing

Every variable, parameter, and return type must be explicitly typed. No exceptions.

```gdscript
# Correct
var speed: float = 5.0
func calculate_damage(base: int, modifier: float) -> int:

# Wrong
var speed = 5.0
func calculate_damage(base, modifier):
```

Static typing is preferred over `var` with inferred type when the type is not immediately obvious from the right-hand side.

## Naming

| Symbol | Convention | Example |
|---|---|---|
| Files | PascalCase | `BattleManager.gd` |
| Classes | PascalCase | `class_name BattleManager` |
| Variables | snake_case | `current_health` |
| Constants | ALL_CAPS_SNAKE | `MAX_PARTY_SIZE` |
| Functions | snake_case | `calculate_damage()` |
| Private functions | _leading_underscore | `_apply_status_effect()` |
| Signals | past_tense_snake_case | `battle_started`, `entity_fainted` |
| Enums | PascalCase, values ALL_CAPS | `enum CombatPhase { PLAYER_TURN, ENEMY_TURN }` |

## Function Design

- One responsibility per function. If a function needs a comment to explain what it does, it should probably be two functions.
- Public functions are the interface. Private functions (`_leading_underscore`) are implementation details. Callers outside the class use public functions only.
- Early returns over nested conditionals.

```gdscript
# Correct
func apply_damage(target: Entity, amount: int) -> void:
    if target.is_dead():
        return
    target.current_hp -= amount

# Wrong
func apply_damage(target: Entity, amount: int) -> void:
    if not target.is_dead():
        target.current_hp -= amount
```

## Signals and Node References

- Declare all signals at the top of the file, before variables.
- Use `@onready var` with relative paths for node references. Never use `get_node()` with absolute paths.
- Prefer connecting signals in `_ready()` over connecting in the editor for anything that involves game logic.

## What Not to Do

- Do not use `match` with raw strings — use enums.
- Avoid using `Dictionary` for large structured data — create a typed Resource class instead.
- Do not call `load()` or `ResourceLoader.load()` directly — use `ConfigLoader`.
- Do not put game logic in `_ready()` or `_process()`.
