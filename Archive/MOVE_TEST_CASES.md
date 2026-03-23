# Move Test Cases — Architecture Validation Suite

This document defines a set of concrete moves as **test cases** for the configurable move system. Each entry describes the move in terms of the architecture defined in the design brief: which FSM nodes it uses, what tier it occupies, what its `.tres` config looks like, and what the expected pipeline walkthrough is.

These moves serve two purposes:

1. **Illustrative examples** for Claude Code to understand how the architecture is meant to work in practice
2. **Acceptance criteria** — the system is considered working when all non-deferred cases pass

Moves marked **DEFERRED** require condition or FSM features not in the initial implementation scope. They are included to document intent and guide future work, but are not part of the initial acceptance criteria.

---

## How to Read These Entries

Each entry includes:

- **Tier** — which of the three expressiveness tiers this move occupies
- **Config** — the `.tres` field sketch
- **Pipeline walkthrough** — what happens at each FSM node
- **What this tests** — the specific architectural capability being validated
- **Status** — IN SCOPE or DEFERRED

### FSM Node Override Convention

Each FSM node has a corresponding pair of optional config fields:

| Field | Meaning |
|---|---|
| `<node>_formula` or `<node>_args` | Pass arguments into the **default** node implementation |
| `<node>_node` | Replace the default node with a **named engine function** (Tier 3 tag) |

Both can be specified together — `<node>_node` says *what runs*, `<node>_args` says *how it runs*. Specifying both `<node>_node` and `<node>_formula` on the same node is invalid and the engine should error. When neither is present, the engine default runs with no arguments.

Examples:

```
# Default node, with a formula argument
damage_formula = "move_power * caster.attack / target.defense"

# Custom node replacing the default, no args
accuracy_node = "always_hit"

# Custom node with args passed in
damage_node = "life_drain"
damage_args = { drain_fraction: 0.5 }
```

---

## Group 1 — Baseline Cases

These must work first. They establish that the foundational pipeline is functioning correctly before any complex features are tested.

---

### TEST-01: Scratch

*Simple physical damage. No secondary effects. The absolute baseline.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = NORMAL
move_power = 40
accuracy = 100
damage_formula = "move_power * caster.attack / target.defense"
post_effects = []
```

**Pipeline walkthrough:**

- **DECLARE** — 1 PP deducted. No interrupts.
- **TARGET_RESOLVE** — Single enemy target confirmed.
- **ACCURACY_CHECK** — Base 100 accuracy. Rolls against target evasion. Passes under normal conditions.
- **CRIT_CHECK** — Standard crit rate. Crit flag set true or false.
- **APPLY_PRE_EFFECTS** — No pre-effects. Pass-through.
- **DAMAGE_CALC** — Formula evaluated: `40 * caster.attack / target.defense`. If crit flag is true, multiplier applied (e.g. 1.5x).
- **APPLY_DAMAGE** — Computed damage written to target current HP.
- **APPLY_POST_EFFECTS** — Empty post_effects array. Pass-through.
- **RESOLVE** — Turn handed off.

**What this tests:** The full default pipeline executes end to end. StatResolver produces correct post-modification stat values. Expression compiles and evaluates correctly. Damage is applied to the target.

**Status:** IN SCOPE

---

### TEST-02: Heal

*Restores 50% of the target's max HP. Self-targeted. Never misses. No damage.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = NORMAL
move_power = 0
accuracy_node = "always_hit"
target_mode = SELF
heal_formula = "target.max_hp * 0.5"
post_effects = []
```

**Pipeline walkthrough:**

- **DECLARE** — 1 PP deducted.
- **TARGET_RESOLVE** — Target is self (caster). No re-evaluation needed.
- **ACCURACY_CHECK** — `accuracy_node = "always_hit"` replaces the default node. The registered `always_hit` function forces hit flag true and skips all accuracy and evasion math entirely.
- **CRIT_CHECK** — No-op. Crits are meaningless on a heal. Crit flag ignored downstream.
- **APPLY_PRE_EFFECTS** — Pass-through.
- **DAMAGE_CALC** — No-op. `move_power == 0` and no damage formula present.
- **APPLY_DAMAGE** — No-op. No damage value in context.
- **APPLY_POST_EFFECTS** — `heal_formula` evaluated: `target.max_hp * 0.5`. Result applied as positive HP change to caster. `StatResolver.resolve_max("hp", ...)` is called here — this validates the `max_` stat convention.
- **RESOLVE** — Turn handed off.

**What this tests:** Self-targeting. Always-hit (accuracy no-op). Heal formula using `target.max_hp`. DAMAGE_CALC and APPLY_DAMAGE no-ops do not break the pipeline. The `max_` stat prefix convention works correctly in expressions.

**Status:** IN SCOPE

---

### TEST-03: Sand Attack

*Reduces target accuracy. No damage. Goes through normal accuracy check.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = NORMAL
move_power = 0
accuracy = 100
post_effects = [
  { chance: 1.0, condition: "accuracy_down_1", target: "target" }
]
```

**Pipeline walkthrough:**

- **DECLARE** — 1 PP deducted.
- **TARGET_RESOLVE** — Single enemy confirmed.
- **ACCURACY_CHECK** — Base 100 accuracy. Rolls normally. Can miss.
- **CRIT_CHECK** — No-op (no damage).
- **APPLY_PRE_EFFECTS** — Pass-through.
- **DAMAGE_CALC** — No-op.
- **APPLY_DAMAGE** — No-op.
- **APPLY_POST_EFFECTS** — `chance: 1.0` rolls succeed. `accuracy_down_1` condition applied to target. This condition registers a stat modifier on the target's active condition list that reduces their effective accuracy stat.
- **RESOLVE** — Turn handed off.

**What this tests:** A pure status move (no damage) that installs a condition. Confirms DAMAGE_CALC and APPLY_DAMAGE no-ops work cleanly for non-damaging moves. Confirms a condition applied here is visible to StatResolver on subsequent turns.

**Status:** IN SCOPE — requires `accuracy_down_1` condition to be implemented as a simple stat modifier condition

---

## Group 2 — Accuracy Variants

---

### TEST-04: Swift

*Always hits. Bypasses accuracy and evasion entirely.*

**Tier:** 3 — Config + tagged node override (this is the canonical Tier 3 example)

**Config:**

```
type_tag = NORMAL
move_power = 60
accuracy_node = "always_hit"
damage_formula = "move_power * caster.attack / target.defense"
post_effects = []
```

**Pipeline walkthrough:**

- **ACCURACY_CHECK** — `accuracy_node = "always_hit"` is present. The engine looks up `"always_hit"` in the node registry and calls that function instead of the default accuracy check. The registered function forces hit flag true and bypasses all accuracy and evasion math — including evasion-raising conditions on the target.

**What this tests:** The node override mechanism end to end — a tag in the config is resolved to a registered engine function at runtime, and that function replaces the default node. This is the simplest possible Tier 3 move: one node overridden, everything else default. Validates that the node registry lookup works and that the overriding function's result flows correctly into the rest of the pipeline.

**Status:** IN SCOPE

---

### TEST-05: Blizzard

*Normally 70% accuracy. In hail weather, always hits. If the weather is Sunny, it has 30% accuracy*

**Tier:** 2 — Config + formula string

**Config:**

```
type_tag = ICE
move_power = 110
accuracy_node = "weather_accuracy"
accuracy_node_arguments = [
  { "weather": HAIL, "accuracy_formula": "100.0"},
  { "weather": SUNNY_DAY, "accuracy_formula": "30.0"},
  { "weather": any, "accuracy_formula": "70.0"}
]
damage_formula = "move_power * caster.special_attack / target.special_defense"
post_effects = [
  { chance: 0.10, condition: "freeze", target: "target" }
]
```

**Pipeline walkthrough:**

- **ACCURACY_CHECK** — A custom accuracy check node is specified by `accuracy_node`. The engine uses the function mapped to this tag, and also passes in the arguments. In this case, a mapping of weather types to formula. These formula are simple, flat accuracy percentages depending on what weather the battle currently has. However, because this is requires if-else statements then it's most elegantly implemented as a custom node (function) in the engine.
- **APPLY_POST_EFFECTS** — 10% chance to apply freeze condition to target.

**What this tests:** State-conditional accuracy. The accuracy node is different always, and it produces different behavior depending on the battle state (weather).

**Status:** IN SCOPE — requires `battle.weather` to be exposed in the Expression context and WEATHER_HAIL to be a defined constant

---

## Group 3 — Critical Hit Variants

---

### TEST-06: Slash

*Physical damage with elevated critical hit rate.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = NORMAL
move_power = 70
accuracy = 100
crit_rate_formula = "caster.crit_rate + 0.25"
pre_effects = [
  { chance: 1.0, condition: "weak", target: "target", if_crit: true },
]
damage_formula = "move_power * caster.attack / target.defense"
post_effects = []
```

**Pipeline walkthrough:**

- **CRIT_CHECK** — Uses the elevated crit rate formula from `crit_rate_formula`. Higher probability of crit flag being set true.
- **PRE_EFFECTS** - Applies a weakened effect to the target before computing damage if it was a crit, dealing even more bonus damage.
- **DAMAGE_CALC** — If crit flag true, damage multiplier applied on top of base formula result.

**What this tests:** Per-move crit rate as a configurable field. Crit rate staging system. Crit multiplier applied correctly in DAMAGE_CALC.

**Status:** IN SCOPE

---

### TEST-07: Frost Nova

*Ice damage. On normal hit: applies Slow. On critical hit: applies Freeze instead of Slow.*

**Tier:** 2 — Config + formula string (crit-conditional effect selection)

**Config:**

```
type_tag = ICE
move_power = 60
accuracy = 100
damage_formula = "move_power * caster.special_attack / target.special_defense"
post_effects = [
  { chance: 1.0, condition: "slow", target: "target", unless_crit: true },
  { chance: 1.0, condition: "freeze", target: "target", if_crit: true }
]
```

**Pipeline walkthrough:**

- **CRIT_CHECK** — Crit flag set.
- **APPLY_POST_EFFECTS** — Iterates post_effects. First entry: `unless_crit: true` — skipped if crit flag is set. Second entry: `if_crit: true` — only applied if crit flag is set. On a normal hit: Slow applied, Freeze skipped. On a crit: Freeze applied, Slow skipped.

**What this tests:** Crit flag as a condition on post_effect entries. The `if_crit` and `unless_crit` modifiers on effect entries. Validates that crits can change *which* effect fires, not just scale damage.

**Status:** IN SCOPE — requires `if_crit` and `unless_crit` fields to be supported in the post_effects entry schema

---

## Group 4 — Recoil and Self-Targeting Effects

---

### TEST-08: Brave Bird

*Physical damage. Caster takes recoil equal to 33% of damage dealt.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = FLYING
move_power = 120
accuracy = 100
damage_formula = "move_power * caster.attack / target.defense"
post_effects = [
  { chance: 1.0, effect: "recoil", target: "caster", recoil_fraction: 0.33 }
]
```

**Pipeline walkthrough:**

- **APPLY_DAMAGE** — Damage value written to target HP. Damage value also retained in pipeline context.
- **APPLY_POST_EFFECTS** — `recoil` effect entry reads `damage_value` from pipeline context, computes `damage_value * 0.33`, applies that as damage to caster HP.

**What this tests:** Recoil as a self-targeting post_effect that reads the pipeline context's `damage_value`. Confirms pipeline context is accessible in APPLY_POST_EFFECTS. Caster takes damage from their own move.

**Status:** IN SCOPE — requires `recoil` as a supported effect type in the post_effects schema, and `damage_value` available in context at APPLY_POST_EFFECTS

---

### TEST-09: Close Combat

*Physical damage. After resolving, drops caster's defense and special defense by one stage each.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = FIGHTING
move_power = 120
accuracy = 100
damage_formula = "move_power * caster.attack / target.defense"
post_effects = [
  { chance: 1.0, condition: "defense_down_1", target: "caster" },
  { chance: 1.0, condition: "special_defense_down_1", target: "caster" }
]
```

**Pipeline walkthrough:**

- **APPLY_POST_EFFECTS** — Both stat-drop conditions applied to caster. These register negative stat modifiers on caster's active condition list, visible to StatResolver on future turns.

**What this tests:** Multiple post_effects entries on a single move. Self-targeting post_effects (conditions applied to the caster, not the target). Confirms `target: "caster"` is a valid target value in post_effects.

**Status:** IN SCOPE — requires `defense_down_1` and `special_defense_down_1` as simple stat modifier conditions

---

## Group 5 — State-Conditional Damage Formulas

---

### TEST-10: Reversal

*Physical damage. Power scales inversely with user's remaining HP. More powerful the lower the user's HP.*

**Tier:** 2 — Config + formula string

**Config:**

```
type_tag = FIGHTING
move_power = 1  # base value, formula overrides effective power
accuracy = 100
damage_formula = "200 * (1.0 - caster.hp / caster.max_hp) * caster.attack / target.defense"
post_effects = []
```

**Note:** The formula above is simplified for clarity. The actual Pokémon implementation uses discrete power tiers based on HP percentage thresholds. Either a step-function via ternary chaining or the continuous version above is acceptable for this test.

**Pipeline walkthrough:**

- **DAMAGE_CALC** — Formula evaluated. `caster.hp` is post-modification current HP. `caster.max_hp` is the HP ceiling. At full health the ratio is 1.0 and effective power approaches 0. At very low health the ratio approaches 0 and effective power approaches 200.

**What this tests:** `caster.hp` and `caster.max_hp` both available in formula context. StatResolver correctly provides current vs. max HP as distinct values. Formula that uses a ratio of two stats from the same entity.

**Status:** IN SCOPE

---

### TEST-11: Stored Power

*Magic damage. Base power 20. Each positive stat stage on the caster adds 20 more power.*

**Tier:** 2 — Config + formula string

**Config:**

```
type_tag = PSYCHIC
move_power = 20
accuracy = 100
damage_formula = "(move_power + 20 * caster.buff_count) * caster.special_attack / target.special_defense"
post_effects = []
```

**Pipeline walkthrough:**

- **DAMAGE_CALC** — `caster.buff_count` resolved by StatResolver. This requires StatResolver to expose a non-stat derived value — the count of positive stat stage conditions on the caster. Formula scales multiplicatively with buffs accumulated.

**What this tests:** Formula context exposing derived values beyond raw stats (`buff_count`). StatResolver must compute this from the caster's active condition list. Validates that conditions installed by earlier moves are correctly counted here.

**Status:** IN SCOPE — requires `buff_count` to be a defined computed field exposed in the caster context, not just a raw stat from StatBlock

---

## Group 6 — Field State Interaction

---

### TEST-12: Rain Dance

*Installs a weather condition on the battle state. No damage. No accuracy check.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = WATER
move_power = 0
accuracy = -1
post_effects = [
  { chance: 1.0, effect: "set_weather", weather: WEATHER_RAIN, duration: 5 }
]
```

**Pipeline walkthrough:**

- **ACCURACY_CHECK** — No-op (always hits).
- **DAMAGE_CALC** — No-op.
- **APPLY_DAMAGE** — No-op.
- **APPLY_POST_EFFECTS** — `set_weather` effect writes `WEATHER_RAIN` to `battle_state.weather` for 5 turns.

**What this tests:** Moves that write to battle state rather than a combatant. `set_weather` as a supported effect type. `battle.weather` being readable in subsequent formula evaluations (tested in combination with TEST-05 Blizzard).

**Status:** IN SCOPE — requires `set_weather` as a supported effect type and battle state weather field properly exposed to Expression context

---

## Group 7 — Pokemon Status Conditions

These test the condition system specifically. Each move is simple — the complexity lives in the condition behavior.

---

### TEST-13: Ember (with Burn)

*Fire damage. 10% chance to inflict Burn.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = FIRE
move_power = 40
accuracy = 100
damage_formula = "move_power * caster.special_attack / target.special_defense"
post_effects = [
  { chance: 0.10, condition: "burn", target: "target" }
]
```

**Condition behavior (Burn):**

- Subscribes to `actor_turn_started(self)` on EventBus
- On trigger: deals `target.max_hp * 0.0625` damage to carrier
- Registers stat modifier: `attack * 0.5` on carrier's condition list (visible to StatResolver)
- Duration: PERMANENT until removed

**What this tests:** Full condition application via post_effects. Burn's periodic damage fires at the correct moment (carrier's turn start, not the attacker's). Burn's stat modifier reduces the carrier's effective attack as seen by StatResolver. Condition persists across turns.

**Status:** IN SCOPE

---

### TEST-14: Thunder Wave (Paralysis)

*Applies Paralysis to target. No damage.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = ELECTRIC
move_power = 0
accuracy = 90
post_effects = [
  { chance: 1.0, condition: "paralysis", target: "target" }
]
```

**Condition behavior (Paralysis):**

- Subscribes to `actor_turn_started(self)` on EventBus
- On trigger: rolls 25% chance. If succeeds, sets `turn_denied = true` on pipeline context for this actor's turn, causing DECLARE to no-op
- Registers stat modifier: `speed * 0.5` on carrier's condition list (visible to StatResolver, affects ATB gauge fill rate)
- Duration: PERMANENT until removed

**What this tests:** Turn denial mechanic — the condition must intercept the pipeline at or before DECLARE on the carrier's turn. Speed reduction visible to StatResolver and affecting ATB scheduling. A status move that can itself miss (90% accuracy).

**Status:** IN SCOPE

---

### TEST-15: Hypnosis (Sleep)

*Applies Sleep to target. No damage.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = PSYCHIC
move_power = 0
accuracy = 60
post_effects = [
  { chance: 1.0, condition: "sleep", target: "target" }
]
```

**Condition behavior (Sleep):**

- On application: assigns random duration between 1 and 3 turns (stored privately on condition instance)
- Subscribes to `actor_turn_started(self)` on EventBus
- On trigger: forces turn denial (100% chance). Decrements duration counter.
- When duration counter reaches 0: condition unregisters itself and emits `condition_expired`
- Duration: countdown

**What this tests:** Condition with random duration assigned at application time. Countdown-based expiry. Turn denial at 100% rate. Condition self-removing when duration expires. `condition_expired` signal emitted correctly.

**Status:** IN SCOPE

---

### TEST-16: Will-O-Wisp (Burn, direct application)

*Applies Burn directly. No damage. Lower accuracy.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = FIRE
move_power = 0
accuracy = 85
post_effects = [
  { chance: 1.0, condition: "burn", target: "target" }
]
```

**What this tests:** Same Burn condition as TEST-13 but applied via a dedicated status move rather than as a secondary effect. Validates that conditions are reusable across moves — the Burn condition definition is shared, not per-move. A miss on this move means Burn is never applied (unlike TEST-13 where a hit was required for the 10% chance to even roll).

**Status:** IN SCOPE

---

### TEST-17: Scald (Burn on Water move)

*Water damage. 30% chance to Burn.*

**Tier:** 1 — Pure config

**Config:**

```
type_tag = WATER
move_power = 80
accuracy = 100
damage_formula = "move_power * caster.special_attack / target.special_defense"
post_effects = [
  { chance: 0.30, condition: "burn", target: "target" }
]
```

**What this tests:** A water-type move that inflicts a fire-adjacent status. Confirms conditions are not gated by move type — the condition tag is resolved independently. Higher secondary effect chance than Ember (30% vs 10%).

**Status:** IN SCOPE

---

## Group 8 — Deferred Cases

The following moves require features not in the initial implementation scope. They are documented here to define intent and serve as targets for future iterations.

---

### TEST-D01: Rollout

*Physical damage. Power doubles each consecutive use (up to 5 turns). Chain breaks if interrupted.*

**Why deferred:** Requires a "RolloutStreak" condition that tracks consecutive use count and provides a power multiplier to the damage formula. Conditions with internal mutable state (the streak counter) are not in the initial condition implementation scope.

**Intended architecture when implemented:**

- Rollout installs a `rollout_streak` condition on the caster at DECLARE
- The condition increments a private counter each time Rollout fires
- The damage formula reads `caster.rollout_multiplier` — a computed value exposed by the condition via StatResolver
- If the caster uses any other move or takes a hit that breaks the chain, the condition removes itself
- The condition subscribes to `move_declared(self, *)` to detect chain breaks

---

### TEST-D02: Future Sight

*Move is declared now but strikes the target two turns later, regardless of caster state.*

**Why deferred:** Requires a delayed-resolution mechanism — a condition on the battle state (not a combatant) that counts down and re-enters the FSM pipeline at DAMAGE_CALC independently of any actor's turn. This is a battle-scoped condition with a deferred pipeline re-entry, which is beyond the initial condition scope.

---

### TEST-D03: Counter

*Returns 2× the physical damage the caster received last turn.*

**Why deferred:** Requires context-derived targeting (target is whoever last hit the caster, not a player selection) and access to damage received history. The damage history as a formula input (`caster.last_physical_damage_received`) requires the pipeline context to persist values across turns — a form of cross-turn state not yet in scope.

---

### TEST-D04: Metronome

*Randomly selects any other move and executes it.*

**Why deferred:** Requires a Tier 3 tagged escape hatch at DECLARE (`metronome_declare`) that selects a random move from the full move library and re-enters the pipeline with a new MoveConfig. The tag registry and full pipeline re-entry are both in scope architecturally, but this specific move requires the move library to be queryable at battle runtime, which has not been designed yet.

---

### TEST-D05: Perish Song

*All combatants on the field gain a 3-turn countdown. Any combatant still carrying it after 3 turns faints.*

**Why deferred:** Requires a field-scoped condition applied to all current combatants simultaneously. The initial condition scope targets single-combatant conditions only. Multi-target condition application at move resolution time is a natural extension but is not the initial priority.

---

### TEST-D06: Fury Swipes

*Hits 2–5 times. Each hit is an independent accuracy and damage roll.*

**Why deferred:** Requires a loop transition at RESOLVE — the FSM edge from RESOLVE back to ACCURACY_CHECK repeats between 2 and 5 times (randomly determined at DECLARE). Custom FSM transitions are architecturally supported but the implementation of transition modification on a move is not in the initial build scope.

---

## Acceptance Criteria Summary

The move system is considered complete for the initial implementation when all IN SCOPE test cases pass end to end. Specifically:

| Test | Description | Key capability |
|------|-------------|----------------|
| TEST-01 | Scratch | Full default pipeline, basic damage formula |
| TEST-02 | Heal | Self-target, always-hit, max_hp in formula, heal application |
| TEST-03 | Sand Attack | Status-only move, condition applied via post_effects |
| TEST-04 | Swift | Tier 3 node override — `accuracy_node` tag resolves to registered engine function |
| TEST-05 | Blizzard | `battle.weather` in formula, state-conditional accuracy |
| TEST-06 | Slash | Per-move crit rate modifier |
| TEST-07 | Frost Nova | `if_crit` / `unless_crit` on post_effect entries |
| TEST-08 | Brave Bird | Recoil reads damage_value from pipeline context |
| TEST-09 | Close Combat | Multiple self-targeting post_effects |
| TEST-10 | Reversal | `caster.hp / caster.max_hp` ratio in formula |
| TEST-11 | Stored Power | `caster.buff_count` derived value in formula context |
| TEST-12 | Rain Dance | Writes to battle state weather field |
| TEST-13 | Ember | Burn condition: periodic damage + stat modifier |
| TEST-14 | Thunder Wave | Paralysis: turn denial + speed reduction |
| TEST-15 | Hypnosis | Sleep: random duration countdown, self-expiring |
| TEST-16 | Will-O-Wisp | Burn reused across moves, can miss |
| TEST-17 | Scald | Water move with fire-adjacent status effect |
