# engine/battle/resolver/

This directory owns move resolution — the process of taking a declared `Action` and producing an `ActionResult`. It is stateless: every call to `ActionResolver.apply()` builds a fresh FSM, runs it against a `PipelineContext`, and returns.

---

## Files


| File                | Role                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------- |
| `ActionResolver.gd` | Entry point. Builds the default FSM, applies per-move overrides, runs it.                    |
| `BattleFsm.gd`      | Directed graph FSM: named nodes (Callables) + ordered edges (FsmEdge).                       |
| `FsmEdge.gd`        | A single directed edge with an optional condition predicate.                                 |
| `NodeRegistry.gd`   | String-tag → Callable registry for custom node/hook implementations (void return).           |
| `EdgeRegistry.gd`   | String-tag → Callable registry for custom edge conditions (bool return).                     |
| `StatResolver.gd`   | Stateless utility for resolving effective stat values from config + instance + battle state. |


---

## How a Move Resolves (two-stage)

`ActionResolver.apply(action, state, rng)` runs in two stages:

### Stage 1 — Build the FSM

`_build_default_fsm()` constructs the standard directed graph:

```
START → DECLARE → ACCURACY_CHECK → CRIT_CHECK →
APPLY_PRE_EFFECTS → DAMAGE_CALC → APPLY_DAMAGE →
APPLY_POST_EFFECTS → APPLY_HEAL → END
```

Conditional short-circuits (edges that skip to END):

- `DECLARE → END` when the actor's turn is denied
- `ACCURACY_CHECK → END` when the move misses

After the default FSM is built, `_apply_move_overrides(fsm, move)` iterates the move's `node_overrides: Array[NodeOverrideEntry]` and patches the graph (see below).

### Stage 2 — Run the FSM

`BattleFsm.run(ctx)` walks the graph from `START` to `END`. At each node it calls the node's Callable with the shared `PipelineContext`, then evaluates outgoing edges in declaration order to find the next node.

---

## The Node Override System

Each `NodeOverrideEntry` in `MoveConfig.node_overrides` targets one named FSM node and may specify:


| Field              | Effect                                |
| ------------------ | ------------------------------------- |
| `override_tag`     | Replaces the node's Callable entirely |
| `pre_hook_tag`     | Runs before the node's Callable       |
| `post_hook_tag`    | Runs after the node's Callable        |
| `args: Dictionary` | Passed to whichever tags are set      |


All tags resolve to Callables registered in `NodeRegistry`. Custom callables have the signature:

```gdscript
func(ctx: PipelineContext, args: Dictionary) -> void
```

Edge conditions (from `EdgeOverrideEntry.condition_tag`) are registered separately in `EdgeRegistry` — see the Edge Override System section below.

`args` are bound into the Callable at FSM-build time using `Callable.bind(entry.args)`, so the FSM always sees the simpler `func(ctx: PipelineContext) -> void` interface. Default node implementations take only `ctx` and read their configuration from `ctx.move` (formula strings, accuracy value, etc.).

### Example — Magnitude

```
node_overrides = [
    NodeOverrideEntry { node_id="DECLARE",     post_hook_tag="magnitude_declare" },
    NodeOverrideEntry { node_id="DAMAGE_CALC", override_tag="magnitude_damage"  },
]
```

`magnitude_declare` runs after standard DECLARE logic (turn denial, PP deduction) and rolls the magnitude level, writing it to `ctx.bb`. `magnitude_damage` replaces the standard damage formula and reads from `ctx.bb`.

### Adding a new custom node

1. Register the Callable in `NodeRegistry.create_default()`:
  ```gdscript
   reg.register_node("my_tag", func(ctx: PipelineContext, args: Dictionary) -> void:
       # read from ctx, args; write results back to ctx
   )
  ```
2. Reference it from the move's `.tres`:
  ```
   [sub_resource type="Resource" id="NodeOverride_1"]
   script = ExtResource("NodeOverrideEntry_script")
   node_id = "DAMAGE_CALC"
   override_tag = "my_tag"
   args = {"key": "value"}
  ```

The FSM and ActionResolver require no changes.

---

## The Edge Override System

`MoveConfig.edge_overrides: Array[EdgeOverrideEntry]` injects custom FSM edges at Stage 1, alongside node overrides. This is the primary mechanism for multi-hit loops and other non-linear pipeline structures.

### EdgeOverrideEntry fields


| Field              | Effect                                                                        |
| ------------------ | ----------------------------------------------------------------------------- |
| `from_node`        | Source node name (e.g. `"APPLY_POST_EFFECTS"`)                                |
| `to_node`          | Destination node name (e.g. `"APPLY_PRE_EFFECTS"`)                            |
| `condition_tag`    | NodeRegistry tag for a `bool`-returning callable. Empty = unconditional edge. |
| `args: Dictionary` | Bound to the condition callable at FSM-build time                             |


Condition callables are registered in `EdgeRegistry` (separate from `NodeRegistry`) and have the signature:

```gdscript
func(ctx: PipelineContext, args: Dictionary) -> bool
```

After `.bind(entry.args)`, the FSM sees `func(ctx: PipelineContext) -> bool`.

### `insert_edge_before_source` semantics

`BattleFsm.insert_edge_before_source(edge)` inserts the new edge **before** the first existing edge from the same source node. This implements first-match-wins: a conditional back-edge is evaluated before the unconditional default forward-edge from the same node. If the condition returns `true`, the loop iterates; if `false`, evaluation falls through to the default.

### Infinite-loop risk

`BattleFsm.run()` has no maximum-steps guard. An edge override whose condition never returns `false` will loop forever. Always ensure condition callables have a finite decrement/counter path.

### `result.damage` is the last hit only

`ctx.damage_value` is overwritten on each loop iteration. `ActionResult.damage` reflects only the **final** hit. Each `APPLY_DAMAGE` call does apply damage to the target's HP — the cumulative effect is correct. Tests that want total damage should check `initial_hp - target.current_hp`, not `result.damage`.

### Example — Triple Kick

Triple Kick hits 3 times: 10 base power, `attack / defense` formula, 0.9 accuracy.

```
node_overrides = [
    NodeOverrideEntry { node_id="DECLARE", post_hook_tag="triple_kick_init" },
]
edge_overrides = [
    EdgeOverrideEntry { from_node="APPLY_POST_EFFECTS", to_node="APPLY_PRE_EFFECTS",
                        condition_tag="triple_kick_loop" },
]
```

`triple_kick_init` (post-hook on DECLARE): writes `ctx.bb.write("triple_kick.hits_remaining", 2)`.

`triple_kick_loop` (condition): reads `hits_remaining`; if `> 0`, decrements and returns `true` (loop back); otherwise returns `false` (fall through to `APPLY_HEAL → END`).

Pipeline execution order:

```
START → DECLARE (init: hits_remaining=2)
      → ACCURACY_CHECK → CRIT_CHECK
      → APPLY_PRE_EFFECTS → DAMAGE_CALC → APPLY_DAMAGE
      → APPLY_POST_EFFECTS  [loop? hits_remaining=2→1: true]  → APPLY_PRE_EFFECTS
      → DAMAGE_CALC → APPLY_DAMAGE
      → APPLY_POST_EFFECTS  [loop? hits_remaining=1→0: true]  → APPLY_PRE_EFFECTS
      → DAMAGE_CALC → APPLY_DAMAGE
      → APPLY_POST_EFFECTS  [loop? hits_remaining=0: false]   → APPLY_HEAL → END
```

### Adding a new looping move

1. Register condition callable in `EdgeRegistry.create_default()`:
  ```gdscript
   reg.register_condition("my_loop_condition", func(ctx: PipelineContext, _args: Dictionary) -> bool:
       var remaining: int = ctx.bb.read("my_move.remaining", 0) as int
       if remaining > 0:
           ctx.bb.write("my_move.remaining", remaining - 1)
           return true
       return false
   )
  ```
2. Register an init hook (void) in `NodeRegistry.create_default()` to seed the counter.
3. Reference both from the move's `.tres` via `node_overrides` and `edge_overrides`.

No changes to `BattleFsm`, `ActionResolver`, or `NodeRegistry` structure are required.

---

## Blackboards

Three `Blackboard` objects (see `engine/shared/model/Blackboard.gd`) provide key-value scratch space at different lifetimes. Custom nodes read and write these; standard nodes do not.


| Blackboard              | Location                  | Lifetime               | Example use                                    |
| ----------------------- | ------------------------- | ---------------------- | ---------------------------------------------- |
| `ctx.bb`                | `PipelineContext.bb`      | Single move execution  | Magnitude's rolled power level                 |
| `monster.memory`        | `MonsterInstance.memory`  | Full battle, per actor | Rollout damage accumulator, Fury Cutter streak |
| `battle_state.field_bb` | `BattleStateNvM.field_bb` | Full battle, shared    | Reflect duration, entry hazard flags           |


**Key convention:** namespace blackboard keys by move to prevent collisions: `"rollout.accumulator"`, not `"accumulator"`.

`ctx.bb` is discarded when `fsm.run()` returns. `monster.memory` and `field_bb` persist until the battle ends; the battle controller is responsible for clearing them.

---

## StatResolver

`StatResolver` is a stateless helper used by damage and heal nodes. It is not part of the FSM itself.

- `build_context(config, instance, battle_state) -> Dictionary` — builds the flat `caster` / `target` dictionary used by formula expressions. Includes effective stat values (base + level scale + stat stages + condition modifiers), current HP, buff count, and base crit rate.
- `resolve(stat_name, config, instance, battle_state) -> float` — resolves a single stat.

Formula expressions (e.g. `"move_power * caster.attack / target.defense"`) are evaluated by Godot's `Expression` class inside `ActionResolver._eval_formula()`.

---

## Data Flow Through a Resolution

```
ActionResolver.apply()
  │
  ├─ builds PipelineContext (actor, target, move, battle_state, rng, bb)
  │
  ├─ Stage 1: _build_default_fsm() + _apply_move_overrides()
  │
  └─ Stage 2: BattleFsm.run(ctx)
       │
       ├─ DECLARE        → emits turn_started; checks turn denial; deducts PP; runs post_hook if set
       ├─ ACCURACY_CHECK → rolls hit (or delegates to override)
       ├─ CRIT_CHECK     → rolls crit (or evaluates crit_rate_formula)
       ├─ APPLY_PRE_EFFECTS  → applies pre_effects array (conditions, recoil, weather)
       ├─ DAMAGE_CALC    → evaluates damage_formula or legacy power formula (or override)
       ├─ APPLY_DAMAGE   → applies ctx.damage_value to target; sets ctx.fainted
       ├─ APPLY_POST_EFFECTS → applies post_effects array
       ├─ APPLY_HEAL     → evaluates heal_formula if set
       └─ END
```

Nodes communicate primarily through `PipelineContext` typed fields (`hit`, `crit`, `damage_value`, `fainted`, etc.). These are the load-bearing contract between standard nodes — for example, `APPLY_POST_EFFECTS` reads `ctx.damage_value` for recoil calculation, so `DAMAGE_CALC` must run first. Custom nodes that need to share additional data within a single resolution use `ctx.bb`.

---

## Node Name Constants

String constants for all default node names live on `ActionResolver`:

```gdscript
ActionResolver.NODE_DECLARE           # "DECLARE"
ActionResolver.NODE_ACCURACY_CHECK    # "ACCURACY_CHECK"
ActionResolver.NODE_CRIT_CHECK        # "CRIT_CHECK"
ActionResolver.NODE_APPLY_PRE_EFFECTS # "APPLY_PRE_EFFECTS"
ActionResolver.NODE_DAMAGE_CALC       # "DAMAGE_CALC"
ActionResolver.NODE_APPLY_DAMAGE      # "APPLY_DAMAGE"
ActionResolver.NODE_APPLY_POST_EFFECTS# "APPLY_POST_EFFECTS"
ActionResolver.NODE_APPLY_HEAL        # "APPLY_HEAL"
```

Use these constants (not raw strings) when authoring `NodeOverrideEntry.node_id` values in GDScript. In `.tres` files, string literals are required.