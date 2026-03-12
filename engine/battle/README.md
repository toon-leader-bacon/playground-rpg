# Battle Engine Architecture

This document describes the intended architecture for the battle system. It is a design-first document — the implementation is in progress and may not yet match all sections here.

---

## Design Goals

- Support multiple distinct combat styles (1v1 turn-based, ATB, N-vs-M phase-based, etc.) within a single shared architecture.
- Maximize reuse of combat logic across styles. Only what truly differs per style should be in a separate implementation.
- All mechanics are configurable and data-driven via `.tres` content files.
- The battle system must be pausable mid-execution to wait for human input, without blocking the Godot main loop.

---

## Core Concept: The Battle Loop

Every combat style, regardless of complexity, follows the same macro-level loop:

```
1. TurnScheduler produces a DecisionCollector for the current round/phase
2. BattleController issues prompts to actors (human or AI)
3. Actors submit their decisions into the DecisionCollector
4. DecisionCollector fires `committed` once its completion condition is met
5. ActionRunner takes the committed decisions, reorders and runs them
6. TurnScheduler advances state; loop repeats until battle ends
```

The BattleController owns this loop. It is a coroutine (`await`-based) so it can park at Step 3 waiting for human input without freezing the game.

---

## Components

### BattleController

The top-level orchestrator. Runs the battle loop, holds references to all other components. One implementation per combat style (e.g. `TurnBased1v1Controller`, `ATBController`).

- Calls `TurnScheduler.next_collector(battle_state)` to get the DecisionCollector for each round
- Issues prompts to actors via signals (`waiting_for_input`) for human players, or calls AI controllers synchronously
- `await`s `DecisionCollector.committed` before handing off to the ActionRunner
- After ActionRunner completes, calls `TurnScheduler.advance(battle_state)` and loops

The BattleController's loop is intentionally rigid — the sequence is always the same. Flexibility lives inside the pluggable components, not in the loop itself.

**Public API (called by UI):**
- `run()` — starts the battle coroutine
- `submit_player_action(actor_id, move_index)` — called by the UI when a player makes a choice

**Signals (consumed by UI and EventBus):**
- `waiting_for_input(actor_id, available_moves)` — battle is paused, human must act
- `battle_started`, `battle_ended(winner_id)`
- Action-level signals delegated to EventBus (see EventBus.gd)

---

### TurnScheduler

Answers: **"Who needs to act, and when?"**

Produces a `DecisionCollector` configured for the current round. Also tracks and advances macro-level turn state (whose phase it is, ATB timer values, etc.).

Pluggable — swap the scheduler to change the fundamental rhythm of combat:

| Implementation | Behavior |
|---|---|
| `SpeedBasedScheduler` | Both actors submit simultaneously each round; faster actor's action resolves first |
| `ATBScheduler` | N independent timers; entity acts as soon as its bar fills |
| `PhaseScheduler` | Full player phase, then full enemy phase (Fire Emblem style) |

The scheduler's current state (projected turn order, ATB bar values, etc.) can be snapshotted into `BattleState` — useful for displaying a turn order UI and for AI agents reasoning about future turns.

---

### DecisionCollector

Answers: **"Have all required decisions been submitted for this round?"**

Accepts action submissions from actors. Fires `committed` exactly once when its completion condition is met. That completion condition varies by style:

| Completion Mode | Used By |
|---|---|
| `ALL_SUBMITTED` | All required actors have submitted (Pokemon 1v1, ATB single-entity) |
| `EXPLICIT_END` | An external signal ends the phase (Fire Emblem player phase ending) |

**Invariants (enforced by assert):**
- Only actors listed in `required_actors` may submit
- Each actor may submit exactly once per collector instance
- `committed` fires exactly once, never more

This strictness is intentional: if the battle soft-locks, the collector is the unambiguous place to diagnose why (either a required actor never submitted, or `end_phase()` was never called).

**Key interface:**
```gdscript
signal committed(queue: Array[Action])

func submit(actor_id: String, action: Action) -> void
func end_phase() -> void  # EXPLICIT_END mode only
var is_committed: bool    # safe to check before awaiting
```

---

### ActionRunner

Answers: **"Given a committed set of decisions, in what order and how do they actually execute?"**

Takes the queue from `DecisionCollector.committed`, handles:
- **Reordering**: speed-based, priority tiers (e.g. Quick Attack always goes first), random tiebreaking
- **Move interactions**: moves that cancel or modify other moves in the same round (e.g. a move that counters the opponent's move if it's of a certain type)
- **Per-action execution**: calls `ActionResolver.apply()` for each action, emits signals after each, optionally `await`s between actions for UI animation pacing

The ActionRunner is where "battle physics" live — all the non-trivial logic about how a set of simultaneous decisions collapse into a sequence of events.

Pluggable per combat style if needed, but many styles can share a `SpeedOrderedActionRunner`.

---

### ActionResolver

**Stateless**. Takes a single `Action` and applies its effects to `BattleState`.

- Damage calculation
- Healing
- Stat stage changes
- Any other single-action effect

Shared across all combat styles. No signals — just pure effect application. The ActionRunner emits signals after calling ActionResolver.

---

### PlayerController

A thin controller that acts as the bridge between the UI and the `DecisionCollector`. Holds no battle logic. When the player presses a move button, the UI calls `PlayerController.set_decision(move_index)`, which constructs the `Action` and calls `DecisionCollector.submit()`.

Parallel to `MonsterAI`, which is the AI equivalent: called synchronously by the BattleController, returns an `Action` immediately.

---

## Data Flow Diagram

```
TurnScheduler
    │
    └─► DecisionCollector (required_actors, completion_mode)
              │
              │  ◄── MonsterAI.choose_action() [synchronous, immediate]
              │  ◄── PlayerController.set_decision() [async, awaits human input]
              │
              │  committed fires when condition met
              ▼
         ActionRunner
              │
              │  for each action (ordered):
              └─► ActionResolver.apply(action, battle_state)
                        │
                        └─► emits signals → EventBus → UI updates
```

---

## How Different Combat Styles Map to This Architecture

### Pokemon 1v1
- **Scheduler**: `SpeedBasedScheduler` — opens one collector requiring both actors simultaneously
- **DecisionCollector**: `ALL_SUBMITTED`, N=2
- **ActionRunner**: sort by speed + priority tier, apply in order

### Pokemon 2v2
- **Scheduler**: same as 1v1 but required_actors = all 4 monsters
- **DecisionCollector**: `ALL_SUBMITTED`, N=4
- UI receives a prompt with context `actors: [my_a, my_b]` — player submits 2 decisions
- **ActionRunner**: sort all 4 by speed, apply in order

### Final Fantasy ATB (5v3)
- **Scheduler**: `ATBScheduler` — N independent timer coroutines; when one fires, opens a single-actor collector
- **DecisionCollector**: `ALL_SUBMITTED`, N=1 (one entity at a time)
- **ActionRunner**: immediate (queue has one item)

### Fire Emblem Phase-Based
- **Scheduler**: `PhaseScheduler` — player phase, then enemy phase
- **DecisionCollector**: `EXPLICIT_END` — player acts any number of units, confirms end of phase
- Each unit action within the phase resolves immediately (ActionRunner runs per-action)

---

## Soft Lock Prevention

The primary soft lock risk is the battle parking at `await DecisionCollector.committed` indefinitely.

Mitigations:
- `DecisionCollector` asserts on unexpected/double submissions — fail loudly, not silently
- `BattleScene._ready()` asserts all required signals are connected before calling `run()`
- Check `is_committed` before `await` — if all actors were AI, committed already fired synchronously
- In debug builds: a watchdog timer that prints a warning if the battle has been in the same collector for more than N seconds

```gdscript
# Safe await pattern in BattleController
if not _current_collector.is_committed:
    await _current_collector.committed
```

---

## What Varies vs What Is Shared

| Component | Shared across styles | Swapped per style |
|---|---|---|
| `BattleState` | ✓ | |
| `ActionResolver` | ✓ | |
| `MonsterAI` | ✓ | |
| `PlayerController` | ✓ | |
| `BattleController` | loop structure ✓ | implementation per style |
| `TurnScheduler` | interface ✓ | implementation per style |
| `DecisionCollector` | interface + modes ✓ | completion mode per style |
| `ActionRunner` | interface ✓ | implementation per style |

---

## Current Implementation Status

> This section should be kept up to date as development progresses.

| Component | Status |
|---|---|
| `BattleState` | Implemented (model only) |
| `TurnBased1v1` | Implemented (synchronous prototype — to be refactored) |
| `ActionResolver` | Not yet extracted (logic lives inside `TurnBased1v1`) |
| `TurnScheduler` | Not yet implemented |
| `DecisionCollector` | Not yet implemented |
| `ActionRunner` | Not yet implemented |
| `PlayerController` | Not yet implemented |
| Battle UI / Scene | Not yet implemented |
