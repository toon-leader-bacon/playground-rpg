# Battle Engine Architecture

This document describes the battle system architecture as implemented. It is kept up to date after each major development effort.

---

## Directory Structure

```
engine/battle/
├── model/          # Pure data — battle state, actions, results
├── controller/     # Top-level battle orchestrators (one per combat style)
├── resolver/       # Move execution pipeline — what happens when a move fires
├── scheduler/      # Turn order and timing — who acts next and when
└── view/           # BattleScene + CombatantHUD
```

### `model/`

Pure data objects. No logic that mutates game state outside of the model itself.
`Action`, `ActionResult`, `BattleState` variants, `PipelineContext`, `MoveOption`.

### `controller/`

Top-level battle orchestrators — the only layer `BattleManager` directly instantiates.
Each file is one full combat style implementation plus `ATBTickDriver` (the frame-tick bridge). These files own the battle loop: they call into `scheduler/` to know whose turn it is, collect decisions, then hand off to `scheduler/SpeedOrderedActionRunner` to execute. Adding a new combat style means adding a new file here and extending `BattleManager.CombatStyle`.

### `resolver/`

A closed subsystem for computing what happens when a single move fires. Nothing outside this folder needs to understand how these three files relate — the only public API is `ActionResolver.apply()`.

- **`ActionResolver`** — 8-node FSM pipeline: DECLARE → TARGET_RESOLVE → ACCURACY_CHECK → CRIT_CHECK → APPLY_PRE_EFFECTS → DAMAGE_CALC → APPLY_DAMAGE → APPLY_POST_EFFECTS → RESOLVE
- **`StatResolver`** — feeds the pipeline stat values, applying level scale, stat stages, and active condition modifiers
- **`NodeRegistry`** — Tier 3 callable registry for pluggable accuracy/damage overrides (e.g. `"always_hit"`, `"weather_accuracy"`)

### `scheduler/`

Everything about *turn structure* — when actors act and in what order. These files collectively answer "whose turn is it?" and then bridge the answer back to a concrete `Action`.

- **`SpeedBasedScheduler`** + **`ATBScheduler`** — the two scheduling strategies (round-based speed order vs. independent float gauges)
- **`SpeedOrderedActionRunner`** — executes a pre-collected action queue, sorted by speed, via `ActionResolver`
- **`DecisionCollector`** — waits for all required actors to commit decisions before handing off to the runner
- **`PlayerController`** — input adapter: translates a human player's `select_move` / `select_target` calls into a submitted `Action`

### `view/`

Display only. `BattleScene` drives the whole visual layer from a `BattleConfig` resource. `CombatantHUD` is the reusable per-combatant panel (HP bar, optional ATB gauge). No game state mutations happen here; all updates arrive via EventBus signals.

---

## Design Goals

- Support multiple distinct combat styles (turn-based NvM, ATB NvM, etc.) within a single shared architecture.
- Maximize reuse of combat logic across styles. Only what truly differs per style should be in a separate implementation.
- All mechanics are configurable and data-driven via `.tres` content files.
- The battle system must be pausable mid-execution to wait for human input, without blocking the Godot main loop.

---

## Core Concept: The Battle Loop

Every combat style follows the same macro-level loop:

```
1. Scheduler determines which actor(s) act next and produces a DecisionCollector
2. BattleController prompts actors (human or AI)
3. Actors submit their decisions into the DecisionCollector
4. DecisionCollector fires `committed` once its completion condition is met
5. ActionRunner executes the committed decisions
6. Scheduler advances; loop repeats until battle ends
```

The BattleController owns this loop as an `await`-based coroutine so it can park at Step 3 waiting for human input without freezing the game.

---

## Components

### BattleController

Top-level orchestrator. Runs the battle loop; holds references to all other components. One implementation per combat style.

**Implementations:**

- `TurnBased1v1Controller` — interactive 1v1 coroutine
- `TurnBased2v2Controller` — interactive 2v2 coroutine
- `TurnBasedNvMController` — interactive NvM coroutine (arbitrary team sizes)
- `ATBNvMController` — FF-style ATB NvM coroutine; time is driven externally via `tick(delta)`

**Public API (all controllers):**

- `run(player_team, enemy_team, move_library, rng)` — starts the battle coroutine (fire-and-forget)
- `submit_player_action(actor_id, move_index)` — called by UI when a player makes a move choice
- `submit_player_target(actor_id, target_id)` — called by UI when a player selects a target
- `tick(delta)` — **ATB only**: must be called each frame by `ATBTickDriver`

---

### TurnScheduler / ATBScheduler

Answers: **"Who acts next, and when?"**

| Implementation | Behavior |
|---|---|
| `SpeedBasedScheduler` | One collector per round requiring all actors simultaneously |
| `ATBScheduler` | Independent float gauges per actor (0–100); actor enters ready queue when full |

#### ATBScheduler specifics

- `tick(delta)` advances gauges: `fill += effective_speed() * FILL_RATE_CONSTANT * delta`
- Fainted actors are skipped during tick
- When gauge reaches 100: actor appended to FIFO ready queue, gauge resets to 0, `actor_ready` signal emitted
- `set_paused(true/false)` freezes all gauge advancement — used for Wait mode (see below)
- `get_gauge(id) / set_gauge(id, value)` allow external effects to inspect or modify gauges

**FILL_RATE_CONSTANT = 10.0** — a monster with speed 10 fills its gauge in 1 second at 60fps. Tune this constant to change overall ATB pacing.

---

### ATBTickDriver

A thin `Node` whose only job is to call `controller.tick(delta)` in `_process`. BattleManager adds it as a child when starting an ATB battle and frees it on `battle_ended`. The controller itself is a `RefCounted` (no scene tree dependency) and remains fully unit-testable without this node.

---

### Wait Mode (ATB)

When any actor's gauge fills, **all gauges freeze** until that actor's action is resolved:

1. `pop_next_ready()` dequeues the actor
2. `_scheduler.set_paused(true)` — freezes all gauges immediately
3. Player input is awaited (or enemy AI resolves synchronously)
4. `_runner.run(single_action_queue, state, rng)` executes the action
5. `_scheduler.set_paused(false)` — gauges resume

If multiple actors fill in the same `tick()` call, they are all queued in FIFO order. The outer coroutine loop drains them one at a time before returning to `await _ticked`.

---

### Why `_ticked` signal, not `await actor_ready`

The ATB coroutine loop uses an internal `_ticked` signal (emitted at the end of each `tick()` call) to wake up when no actors are ready:

```gdscript
while not _scheduler.has_ready():
    await _ticked
```

An alternative — `await _scheduler.actor_ready` — was considered and rejected. If two actors fill their gauges in the same `tick()` call, the scheduler emits `actor_ready` twice synchronously. The second emission fires before the coroutine has resumed from the first `await`, so it is lost. The `_ticked` approach never loses readiness events because readiness is checked via `has_ready()` after every tick, not via signal delivery.

---

### DecisionCollector

Answers: **"Have all required decisions been submitted for this round?"**

Fires `committed` exactly once when its condition is met.

| Mode | Used by |
|---|---|
| `ALL_SUBMITTED([actor_ids])` | All required actors have submitted — used by both turn-based (all actors per round) and ATB (single actor per action) |
| `EXPLICIT_END` | An external signal ends the phase (future: Fire Emblem style) |

For ATB single-actor actions: `DecisionCollector.create_all_submitted([actor_id])` commits immediately on the first and only submit. No separate "ATB collector" class is needed.

---

### ActionRunner (`SpeedOrderedActionRunner`)

Takes the committed action queue, sorts by `effective_speed()` with RNG tiebreaking, and executes each action via `ActionResolver`. Emits per-action signals (`move_used`, `damage_dealt`, etc.). Handles mid-queue faints gracefully (skips the action, does not abort the queue).

Shared across all combat styles. For ATB, the queue always has exactly one element — the sort step is a no-op but adds no measurable overhead.

---

### ActionResolver (`resolver/`)

**Stateless.** `static func apply(action, state, rng) -> ActionResult`. Runs the 8-node FSM pipeline. Mutates `action.actor` and `action.target` directly (MonsterInstance references). Compatible with any `BattleState` subclass.

The move pipeline is **3-tier data-driven**:

- **Tier 1** — `move.accuracy`, `move.move_power`, `move.target_mode` (pure config, no code)
- **Tier 2** — `move.damage_formula`, `move.heal_formula`, `move.crit_rate_formula` (GDScript `Expression` strings)
- **Tier 3** — `move.accuracy_node`, `move.damage_node` (registered `Callable` overrides via `NodeRegistry`)

Pre/post effects are declared as `Array[EffectEntry]` on the move. Each entry specifies a condition to apply, recoil fraction, or weather change — evaluated inside `APPLY_PRE_EFFECTS` / `APPLY_POST_EFFECTS` pipeline nodes.

`init_registry()` must be called once at startup (BattleManager._ready()) to register the default Tier 3 nodes (`"always_hit"`, `"weather_accuracy"`).

---

### PlayerController

Bridges UI input to `DecisionCollector`. Two-step flow: `select_move(index)` → optionally `needs_target` signal → `select_target(id)` → submits to collector. Reused identically across all battle modes.

---

## BattleConfig: Data-Driven Mode Selection

`schema/battle/BattleConfig.gd` is the content-layer configuration resource. A `.tres` instance describes a complete battle scenario:

```
style               — TURN_BASED_NVM or ATB_NVM
player_monster_ids  — Array of monster IDs to load
enemy_monster_ids   — Array of monster IDs to load
monster_level       — level applied to all combatants
atb_speed_multiplier — future tuning knob (not yet wired to scheduler)
```

`BattleConfig.CombatStyle` is the user-facing enum. `BattleManager.CombatStyle` is the internal dispatch enum. `BattleScene._start_battle()` maps between them.

Demo configs live in `content/battles/`. To run a different battle, change `config_id` in the `BattleScene` Inspector.

---

## CombatantHUD Component

`engine/battle/view/CombatantHUD.tscn` is a reusable panel (VBoxContainer) for a single combatant. Spawned dynamically by `BattleScene` based on team sizes read from `BattleConfig`.

```gdscript
hud.setup(actor_id, display_name, max_hp, show_atb_bar)
hud.update_hp(hp, max_hp)
hud.update_atb(value)   # only meaningful when show_atb_bar=true
hud.set_active(bool)    # highlight when it's this actor's turn
```

ATB gauge bars are hidden by default; `show_atb` enables them. This means the same component works for both turn-based and ATB modes with no branching in the component itself.

---

## How Different Combat Styles Map to This Architecture

| Style | Scheduler | Collector | Runner |
|---|---|---|---|
| Pokemon NvM | `SpeedBasedScheduler` | `ALL_SUBMITTED`, N=all actors | `SpeedOrderedActionRunner` (full queue) |
| FF ATB NvM Wait | `ATBScheduler` | `ALL_SUBMITTED`, N=1 | `SpeedOrderedActionRunner` (1-element queue) |
| Fire Emblem *(future)* | `PhaseScheduler` | `EXPLICIT_END` | per-action immediate |

---

## Data Flow Diagram

```
[Turn-based]                          [ATB]
SpeedBasedScheduler                   ATBScheduler.tick(delta)
    │                                     │ gauge fills
    └─► DecisionCollector(all actors)     └─► DecisionCollector(1 actor)
              │                                       │
              │ ◄─ MonsterAI (sync)                   │ ◄─ MonsterAI (sync)
              │ ◄─ PlayerController (await input)     │ ◄─ PlayerController (await input)
              │                                       │   [scheduler paused during input]
              ▼ committed                             ▼ committed
         SpeedOrderedActionRunner               SpeedOrderedActionRunner
              │                                       │
              └─► ActionResolver.apply() × N          └─► ActionResolver.apply() × 1
                        │                                       │
                        └─► signals → EventBus → UI            └─► signals → EventBus → UI
```

---

## Current Implementation Status

| Component | Location | Status |
|---|---|---|
| `BattleState`, `BattleState2v2`, `BattleStateNvM` | `model/` | Implemented |
| `Action`, `ActionResult`, `PipelineContext` | `model/` | Implemented |
| `ActionResolver` (8-node FSM) | `resolver/` | Implemented |
| `StatResolver` | `resolver/` | Implemented |
| `NodeRegistry` | `resolver/` | Implemented |
| `SpeedBasedScheduler` | `scheduler/` | Implemented |
| `ATBScheduler` | `scheduler/` | Implemented |
| `SpeedOrderedActionRunner` | `scheduler/` | Implemented |
| `DecisionCollector` | `scheduler/` | Implemented (ALL_SUBMITTED + EXPLICIT_END) |
| `PlayerController` | `scheduler/` | Implemented |
| `TurnBased1v1` (sync prototype) | `controller/` | Implemented |
| `TurnBased1v1Controller` | `controller/` | Implemented |
| `TurnBased2v2Controller` | `controller/` | Implemented |
| `TurnBasedNvMController` | `controller/` | Implemented |
| `ATBNvMController` | `controller/` | Implemented |
| `ATBTickDriver` | `controller/` | Implemented |
| `MonsterAI` / `RandomAI` | `engine/entities/` | Implemented |
| `BattleConfig` schema | `schema/battle/` | Implemented |
| `BattleScene` (generic, config-driven) | `view/` | Implemented |
| `CombatantHUD` component | `view/` | Implemented |
| `PhaseScheduler` (Fire Emblem style) | `scheduler/` | Not yet implemented |
| Type effectiveness system | — | Not yet implemented |
| Move PP exhaustion / Struggle | `resolver/` | Tracked, not enforced |
