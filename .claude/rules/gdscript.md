---
paths:
  - "**/*.gd"
---

# GDScript Code Style

## Typing

Every variable, parameter, and return type must be explicitly typed. No exceptions.
Prefer to use full types over generic or un-templated hints for Array and collection types.

```gdscript
# Correct
var combat_log: Array[String] = ["Starting combat"]
var move_lib: Dictionary[String, MoveConfig] = { "Ember": move_factory.ember() }
var speed: float = 5.0
func calculate_damage(base: int, modifier: float, battle_tags: Array[ETags], battle_modifiers: Dictionary[String, Mod]) -> int:

# Wrong
var combat_log = ["Starting combat"]
var move_lib: Dictionary = { "Ember": move_factory.ember() }
var speed = 5.0
func calculate_damage(base, modifier, battle_tags: Array, battle_modifiers):
```

### Typing Dictionaries

Sometimes, a dictionary may have multiple different value types. Prefer to create a new custom data class instead of using raw dictionaries.
This improves readability, avoids bugs, self documents, and deduplicates.

```gdscript
# Correct
class_name BattleState

var player: MonsterInstance
var enemy: MonsterInstance
var turn: int = 0
var is_active: bool = true
var combat_log: Array[String] = []

# Wrong
var battle_state: Dictionary[String, Variant] = {
    "player": null,
    "enemy": null,
    turn: 0,
    is_active: true,
    combat_log: []
}
```

│ Situation │ Use │
|---|---|
│ All values same type │ Dictionary[String, ConcreteType] │
│ Values mixed types, lives inside one function │ Local dict is tolerable; named class if fields > 3 │
│ Values mixed types, crosses function/file boundary │ Always a named class │
│ Persisted to .tres │ Resource subclass │

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

## Lambda Gotchas

Lambda functions capture the local environment:

```gdscript
var x = 42
var lambda = func ():
 print(x) # Prints `42`.
lambda.call()
```

Local variables are captured by value once, when the lambda is created. So they won't be updated in the lambda if reassigned in the outer function:

```gdscript
var x = 42
var lambda = func (): print(x)
lambda.call() # Prints `42`.
x = "Hello"
lambda.call() # Prints `42`.
```

Also, a lambda cannot reassign an outer local variable. After exiting the lambda, the variable will be unchanged, because the lambda capture implicitly shadows it:

```gdscript
var x = 42
var lambda = func ():
 print(x) # Prints `42`.
 x = "Hello" # Produces the `CONFUSABLE_CAPTURE_REASSIGNMENT` warning.
 print(x) # Prints `Hello`.
lambda.call()
print(x) # Prints `42`.
```

However, if you use pass-by-reference data types (arrays, dictionaries, and objects), then the content changes are shared until you reassign the variable:

```gdscript
var a = []
var lambda = func ():
 a.append(1)
 print(a) # Prints `[1]`.
 a = [2] # Produces the `CONFUSABLE_CAPTURE_REASSIGNMENT` warning.
 print(a) # Prints `[2]`.
lambda.call()
print(a) # Prints `[1]`.
```

## Quick Reference

Official Godot Script reference found here: <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html>
