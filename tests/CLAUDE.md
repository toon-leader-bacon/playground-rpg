# tests/CLAUDE.md

Every mechanic ships with tests.
The test directory mirrors the structure of the system under test exactly (e.g. `tests/engine/battle/` mirrors `engine/battle/`).

## Framework

GDUnit4. Every test file extends `GdUnitTestSuite`. Test functions are prefixed with `test_`.
Run the full suite headlessly with:

```bash
godot --headless --path . -s addons/gdUnit4/bin/GdUnit4CmdTool.gd --add res://tests
```

## Required Tests Per Mechanic

- **Serialization:** Instantiate a Resource, populate all fields, save to a temp path, reload it, assert all values round-trip correctly.
- **Config loading:** Load each example `.tres` from `content/` through `ConfigLoader` and assert the returned Resource has correct typed values.
- **Controller unit tests:** Small, focused tests for pure logic — damage calculation, status effect application, stat lookups. One behavior per test.

## Test Structure

Standard three-step pattern for tests without mocks:

```gdscript
func test_damage_calculation() -> void:
    # Set up inputs
    var attacker := StatBlock.new()
    attacker.attack = 10

    # Run code under test
    var result: int = DamageCalculator.calculate(attacker, 1.0)

    # Validate outputs
    assert_int(result).is_equal(10)
```

Five-step pattern when mocks are involved:

```gdscript
func test_battle_manager_emits_signal() -> void:
    # Set up mocks
    var mock_event_bus := mock(EventBus)

    # Set up inputs
    var enemy := MonsterResource.new()
    enemy.id = "slime"

    # Run code under test
    BattleManager.start_battle(enemy)

    # Validate outputs
    assert_object(BattleManager.current_enemy).is_equal(enemy)

    # Validate mocks
    verify(mock_event_bus).battle_started(enemy)
```

## What Not to Test

- View scenes — do not instantiate `.tscn` files in unit tests.
- `EventBus` signal declarations — these are contracts, not logic.
- Autoload wiring — that is integration territory, not unit territory.

## Integration Tests

Integration tests that span multiple systems are scene-based.
Each lives in `tests/engine/integration/` as a `.tscn` with an attached test script that extends `GdUnitTestSuite`.
Use `GdUnitSceneRunner` to drive them.
