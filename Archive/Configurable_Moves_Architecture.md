Configurable Moves
Architecture & Design Brief
JRPG Engine — Generator Feature
Prepared for Claude Code Implementation

1. Core Philosophy
The guiding principle of this feature is: moves should be as data-driven as possible. The plurality of moves should be fully expressible as .tres config files with zero new engine code per move. Writing custom engine code for a move is an escape hatch reserved for genuinely exotic behavior — it is not the default development loop.

This philosophy shapes every decision in the architecture. When there is a choice between encoding behavior as data versus code, the data path is always preferred. The generator produces .tres files; the engine provides a powerful enough generic runtime that most moves need nothing else.

A secondary principle: the engine and generator remain strictly decoupled. The generator writes .tres files into content/. The engine reads from content/. They never import from each other. This feature adds no exceptions to that rule.

1. Three Tiers of Move Expressiveness
Every move falls into one of three tiers, ordered by how much engine code involvement is required:

Tier 1 — Pure Config (the plurality)
The move is fully expressed as a .tres file. No new engine code is required. The move provides values (move power, accuracy, type tag, effect chance) that the engine's default node implementations consume directly. A simple Scratch attack or a standard Fire Blast lives here.

Example — Ember (.tres sketch):
type_tag = FIRE
move_power = 40
accuracy = 100
damage_formula = "move_power * caster.special_attack / target.special_defense"
post_effects = [{ chance: 0.10, condition: "burn", target: "target" }]

Tier 2 — Config + Formula Strings (the majority)
Mostly data, but one or more fields contain an expression string that the engine evaluates at runtime. These strings are written by the move designer and can reference any stat on the caster, target, or battle state. The engine compiles and caches these expressions at load time using Godot's built-in Expression class. No new GDScript functions are needed in the engine per move.

Example moves in this tier: Reversal (damage scales with low HP), Stored Power (damage scales with buff count), any move whose accuracy changes based on weather.

Tier 3 — Config + Tagged Escape Hatches (the minority)
For exotic behavior that cannot be expressed as data or formula strings, a move can reference a named function registered in the engine via a string tag. The .tres file carries the tag; the engine maintains a registry mapping tags to callables. The move is still mostly config — the tag is a surgical override of one specific node in the resolution pipeline.

Example: Metronome overrides the DECLARE node with tag "metronome_declare", which picks a random move and re-enters the pipeline. The rest of the move is default.

⚠ Development loop for Tier 3: the designer writes a new function in the engine, registers it under a tag, then adds that tag to the generator's known vocabulary. The tag string must match exactly — this is intentionally simple and the designer is responsible for keeping them in sync.

1. Formula Strings and Expression Evaluation
3.1 The Expression Class
Formula strings are evaluated using Godot's built-in Expression class. This is a deliberate choice to avoid reinventing a custom parser. The Expression class supports arithmetic, comparisons, ternary operators, and function calls — giving move designers a powerful tool. Move designers take responsibility for what they write; the system imposes no artificial restrictions.

Expressions are compiled once at load time when the .tres resource is loaded:
var expr = Expression.new()
expr.parse(formula_string, ["caster", "target", "battle", "move"])

The compiled expression is cached on the move resource. At runtime execution is a single call with a freshly resolved context:
expr.execute([caster_ctx, target_ctx, battle_ctx, move_ctx])

3.2 Formula Evaluation Context
Four named objects are available inside any formula string:

Stats are always post-modification. When the formula reads caster.attack, it receives the effective attack value after all active buffs, debuffs, and condition modifiers have been applied. The StatResolver system (Section 5) is responsible for producing these values.

Multiple views of the same stat are available by convention:

3.3 Example Formulas

1. Move Resolution: Finite State Machine
4.1 Design Principles
Move resolution is modeled as a Finite State Machine. The battle system owns and provides a fixed default pipeline. Moves do not define their own FSM — they interact with it in three ways:

Providing arguments to default node implementations (move power, formula strings, effect arrays)
Replacing a specific node with a tagged engine function (Tier 3 escape hatch)
Modifying a transition condition at a specific edge (Fury Swipes loop, crit-overrides-miss)

Moves cannot add new nodes to the FSM. This is an intentional scope constraint for the current implementation. If a future move genuinely requires a new node type, the architecture will be revisited at that time.

The plurality of moves only do the first item — providing arguments. The FSM complexity only surfaces when a move actually needs it.

4.2 Default Pipeline
The default move resolution pipeline consists of eight nodes executed in sequence:

DECLARE → TARGET_RESOLVE → ACCURACY_CHECK → CRIT_CHECK →
APPLY_PRE_EFFECTS → DAMAGE_CALC → APPLY_DAMAGE → APPLY_POST_EFFECTS → RESOLVE

4.3 Node Responsibilities

4.4 Pipeline Context Object
A context object is created at DECLARE and passed through every node, accumulating state as resolution proceeds. Nodes read from and write to this object. Key fields:

4.5 No-Op Behavior
Moves that do not use a node (self-targeting moves skipping ACCURACY_CHECK, non-damaging moves skipping DAMAGE_CALC and APPLY_DAMAGE) pass through those nodes as no-ops. There is no need to explicitly mark nodes as skipped in the config — the engine default implementation for an unused node is a transparent pass-through that leaves the context unchanged.

4.6 Cross-Turn State Belongs in Conditions
Moves that appear to need complex FSM behavior across multiple turns — Rollout (escalating power), Solar Beam (charge then fire), Bide (accumulate damage) — are not modeled as complex FSMs. They are simple moves that install a condition on the caster at DECLARE or RESOLVE. The condition owns the cross-turn state and does the ongoing work. The move's FSM stays simple.

Example: Rollout installs a "RolloutStreak" condition at DECLARE that tracks consecutive uses and provides a power multiplier. When Rollout fires in subsequent turns, DAMAGE_CALC reads the multiplier from the condition via StatResolver. The FSM for each individual Rollout use is identical and trivial.

1. StatResolver — Effective Stat Computation
5.1 Motivation
A monster's effective stat value at any moment is not a single stored number. It is the result of applying a stack of modifications to a base value. A move formula that reads caster.attack needs the fully resolved value — base stat, scaled by level, modified by any active buffs or debuffs, clamped to valid range.

MonsterConfig and StatBlock are intentionally pure data models with no runtime context. They must not own stat resolution logic because they do not have access to battle state, equipment, or active conditions. This is the StatResolver's job.

5.2 Interface
StatResolver is a stateless utility class with static functions. It takes everything needed as arguments:

StatResolver.resolve(stat_name, monster_config, monster_instance, battle_state) -> float
StatResolver.resolve_max(stat_name, monster_config, monster_instance, battle_state) -> float

monster_config — the MonsterConfig resource, provides base StatBlock values
monster_instance — runtime object tracking current HP, active conditions, temporary modifiers
battle_state — weather, terrain, any global modifiers

5.3 Pipe Chain
Internally, StatResolver executes a pipe chain. Each pipe is a thin object with a single pump(value) -> value function that takes a value, applies a transformation, and returns the result. The chain is assembled from the monster's active conditions and relevant battle state:

base_value
  | level_scale_pipe
  | condition_modifier_pipe   # reads monster_instance.active_conditions
  | battle_state_modifier_pipe
  | floor_clamp_pipe
-> final_value

This pipe architecture is the same pattern used elsewhere in the engine for configurable computation. Each pipe is independently replaceable. The chain itself is configurable per battle setup.

5.4 Context Object Construction
When building the Expression evaluation context for a formula string, the engine calls StatResolver for each stat binding. The context is built by iterating the keys from StatBlock.serialize():

func build_context(config, instance, battle_state) -> Dictionary:
    var ctx = {}
    for stat_name in config.base_stats.serialize().keys():
        ctx[stat_name] = StatResolver.resolve(stat_name, config, instance, battle_state)
        ctx["max_" + stat_name] = StatResolver.resolve_max(stat_name, ...)
        ctx["base_" + stat_name] = config.base_stats.get(stat_name)
    return ctx

This is intentionally dynamic. A custom StatBlock subclass that adds new stats (magic, resistance, etc.) automatically makes those stats available in formula strings without any changes to StatResolver or the expression evaluation system.

⚠ Open question (deferred): whether StatBlock should explicitly declare which fields are stats vs. other metadata. For now, all exported fields from serialize() are treated as stats. Revisit once a working move resolver is in place.

1. Conditions
6.1 Conditions as the Core Primitive
Conditions are where most interesting move behavior actually lives. A move fires once and resolves; a condition does the ongoing work. The architecture deliberately keeps move FSM nodes simple by pushing cross-turn and reactive complexity into conditions.

The initial implementation targets the five standard Pokemon status conditions: Burn, Poison, Paralysis, Sleep, and Freeze. This set is intentionally constrained to prove the architecture before expanding to more complex condition types (Slay the Spire power cards, Solar Beam charge state, Rollout streak, etc.).

6.2 What a Condition Needs to Express
Analyzing the five target conditions reveals a small set of primitive behaviors:

6.3 Condition Config Sketches
The five conditions expressed as config data:

Burn:
trigger: { event: "actor_turn_started", filter: "self" }
periodic_damage_formula: "target.max_hp * 0.0625"
stat_modifiers: [{ stat: "attack", multiplier: 0.5 }]
duration: PERMANENT

Poison:
trigger: { event: "actor_turn_started", filter: "self" }
periodic_damage_formula: "target.max_hp * 0.0625"
duration: PERMANENT

Paralysis:
trigger: { event: "actor_turn_started", filter: "self" }
turn_denial_chance: 0.25
stat_modifiers: [{ stat: "speed", multiplier: 0.5 }]
duration: PERMANENT

Sleep:
trigger: { event: "actor_turn_started", filter: "self" }
turn_denial_chance: 1.0
duration_range: [1, 3]

Freeze:
trigger: { event: "actor_turn_started", filter: "self" }
turn_denial_chance: 1.0
duration: PERMANENT
removal_trigger: { event: "move_hit", filter: "self", condition: "move_type == FIRE" }

6.4 The EventBus
Conditions hook into the battle at specific moments via an EventBus — a central signal emitter that fires well-defined signals at key points in the battle flow. This is an extension of the existing EventBus in the engine (currently used for UI updates) to also serve conditions and any other system that needs to react to battle events.

The FSM emits signals as it executes. Conditions subscribe to the signals they care about when they are applied to an actor, and unsubscribe when they expire or are removed. The FSM has no direct knowledge that conditions exist — it emits signals and moves on.

Core signal vocabulary:

6.5 Condition Triggers
A condition trigger is a subscription to one or more EventBus signals. All trigger types are unified under this model:

The filter field scopes the subscription. "self" means only fire when the event involves the actor carrying this condition. Without a filter, the condition responds to that event for any actor on the field.

6.6 Condition Interaction with StatResolver
Conditions that apply persistent stat modifiers (Burn halving attack, Paralysis halving speed) do not directly mutate the monster's stored stat values. Instead, they register a modifier entry on the monster instance's active condition list. StatResolver reads this list when building its pipe chain and folds in each active modifier.

The FSM never directly reads conditions. It calls StatResolver to get a stat value and receives the fully resolved number. The condition's influence is invisible to the FSM — it is already baked into the number StatResolver returns.

This gives the system two clean seams through which conditions interact with the battle, and only two:

The FSM remains unaware of conditions entirely.

1. Open Questions and Deferred Decisions
The following items were identified during design but deliberately deferred. They should be addressed once a working move resolver prototype exists:

FSM implementation details — how nodes are represented in GDScript (scripts, callables, inner classes), and how a move references an override node at runtime. This is an implementation question, not an architectural one.
StatBlock field declaration — whether StatBlock should explicitly mark which exported fields are stats vs. other metadata, rather than treating all serialize() keys as stats.
Multi-effect stacking order — when two conditions both modify the same stat, what is the pipe ordering? Which wins? Can they stack additively?
Generator implementation — the generator will expose high-level functions for common move archetypes (damage + elemental type, apply status effect) and one-off functions for complex moves. Generator design is intentionally deferred until the engine runtime is proven.
Extended condition types — Slay the Spire style power conditions, charge state conditions (Solar Beam), streak conditions (Rollout), and multi-phase boss conditions are all valid future extensions. The EventBus and StatResolver seams are designed to support them without FSM changes.
Full custom FSM — the ability for a move to define an entirely custom node sequence is out of scope for this implementation. If a genuinely novel move type requires it, the architecture will be revisited.

1. System Interaction Summary
The diagram below shows how the major systems interact at runtime during a move resolution:

Generator
  └─ writes MoveConfig.tres to content/moves/
       └─ loaded by engine at startup, Expression fields compiled + cached

Battle FSM (default pipeline)
  DECLARE → TARGET_RESOLVE → ACCURACY_CHECK → CRIT_CHECK
    → APPLY_PRE_EFFECTS → DAMAGE_CALC → APPLY_DAMAGE
    → APPLY_POST_EFFECTS → RESOLVE

  Each node:
    1. Reads pipeline context (hit flag, crit flag, damage_value, etc.)
    2. Calls StatResolver for any stat values needed
    3. Executes Expression if a formula string is present
    4. Writes results back to pipeline context
    5. Emits relevant EventBus signals

StatResolver (called by FSM nodes and Expression context builder)
  base_stat | level_scale | condition_modifiers | battle_modifiers | clamp
  -> returns single resolved float

EventBus (signals emitted by FSM, subscribed to by Conditions)
  actor_turn_started → Burn/Poison periodic damage fires
  actor_turn_started → Sleep/Paralysis turn denial rolls
  move_hit(type=FIRE) → Freeze removal trigger fires

Conditions (applied to monster_instance.active_conditions)
  → Stat modifiers: read by StatResolver pipe chain
  → Triggered behaviors: fired by EventBus subscriptions

End of Document
