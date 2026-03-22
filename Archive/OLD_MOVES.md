# Move System Design

This is a first draft of a design document. Kept for legacy and reference only. Please see MOVES_DESIGN.md for the latest discussion.

This document captures the design thinking behind how moves (actions taken by combatants during battle) should be architected. It is a living design document — not a final spec.

---

## Working Vision: What a Move Is

A move is an action initiated by a caster against one or more targets. The caster and targets are both known at the moment of resolution, though *how* targets are selected varies — some moves let the player choose, some auto-select (all enemies, random, lowest HP), and some derive their target from context (Counter targets whoever just attacked the caster).

Once caster and targets are known, the move computes a **potency** — a number derived from a formula that may draw on the caster's stats, each target's stats, the current battle state, and intrinsic move parameters. This number flows through a modifier pipeline before being applied.

The move then produces one or more **outcomes** against each target. The most common outcome is "modify a stat" — HP up or down, attack raised, speed lowered, typically based on the computed potency post modifier pipeline. Outcomes can also install or remove **effects** on the target, modify battle-level state, or execute arbitrary logic for cases that can't be expressed declaratively (Metronome, boss-specific behaviors). Outcomes can carry **conditions** evaluated at resolution time — "only apply this if the target has burn," or "only if weather is rain" — which handles state-conditional behavior without requiring a separate move class.

### Moves vs. Effects

**A move is a one-time action. An effect is a persistent condition on an entity.**

Moves fire, resolve, and are done. Effects exist on a target for a duration and participate in future resolutions. Moves can create effects as part of their outcome; effects do the ongoing work from there. This is the key architectural policy of the system.

The payoff: most "complex" move categories (see Design Space discussion below) collapse into this model.

- **Multi-turn moves** — a move that installs a "charging" effect on the caster. The effect handles the duration; when it completes, it triggers the actual resolution.
- **Reactive moves** (Counter, Protect, Destiny Bond) — a move that installs a reactive effect. The effect owns the trigger logic and the response action.
- **Field/rule-altering moves** (Rain Dance, Trick Room) — a move that installs an effect on the battle state rather than a combatant. Same concept, different attachment point.

This is analogous to Slay the Spire's card/power model. Cards that say "gain +1 energy on your next turn" apply an effect with a trigger "at the start of this creature's turn." Power cards apply persistent modifiers with triggers like "whenever a card of type X is played" or "whenever you are hit." The most interesting effects have non-trivial triggers — and that complexity lives in the effect system, not the move system. Moves stay simple; effects own the richness.

The escape hatch for Metronome-style arbitrary code belongs in the move's *outcome*, not by collapsing moves and effects back together.

---

## Design Space: Six Categories and Four Axes

This section describes the problem/ design space and attempts to outline the edges of what may be possible. This section is more of a guidelines, than a strict limiting list. This sections adds vocabulary to describe moves, think about edge cases, and attempt to organize/ categorize the possibilities. This design discussion should influence the software architecture, not the other way around.

### The Six Categories

These categories map the edges of the JRPG move design space. They are **not mutually exclusive** — Solar Beam is both category 2 and category 4. Think of them as named examples that probe different corners of the space, not as a filing taxonomy.

| # | Category | Defining trait | Examples |
|---|---|---|---|
| 1 | **Parametric** | Fully data-driven: formula + type + target selector. No engine code needed beyond the formula runner. | Fire Blast, Slash, Heal |
| 2 | **State-conditional** | Effect or magnitude depends on current battle state at resolution time. Handled via conditional outcomes. | Reversal (scales with caster HP%), Solar Beam (instant in sun), Fusion spell (ally must have cast first) |
| 3 | **Rule-altering / Field** | Mutates the battle context for N turns. In this model: a move that installs a field-scoped effect on the battle state. | Trick Room, Rain Dance, Reflect, Haste/Slow |
| 4 | **Multi-turn / Staged** | Move spans multiple turns or schedules a future event. In this model: a move that installs a duration effect on the caster, which triggers the real resolution when it expires. | Solar Beam (charge turn), Doom (countdown), Perish Song, Reraise |
| 5 | **Reactive / Triggered** | "If event E happens, do X." In this model: a move that installs a reactive effect that listens for a future battle event. | Counter (2x damage if hit physically), Destiny Bond, Protect |
| 6 | **Battle-style mechanic** | Only meaningful in one specific combat model. Handled by the specific battle controller, not the shared resolution layer. | Priority moves (turn-based), ATB gauge manipulation (ATB only) |

Most moves in any JRPG fall into category 1. Categories 3–5 are where the effect system earns its keep. Category 6 is a policy question, not a resolution question.

### Four Axes

A complementary way to place any move in the design space. A move is a point along these four axes:

| Axis | Options |
|---|---|
| **Resolution timing** | Immediate / Delayed (effect-driven) / Reactive (event-triggered) |
| **Effect target(s)** | Self / Single combatant / Team / Field / Battle-global / Move lists / individual PP pools / the resolution pipeline itself |
| **Target certainty** | Known at cast time / Known at resolution time / Known at trigger time |
| **Outcome type** | Stat modification / Effect install or remove / Battle state write / Arbitrary code |
| **Spatial / positional** | Grid position, range, adjacency, front line or back line |
| **Turn queue scope** | Manipulating action order, granting/stealing turns |

Example: Solar Beam sits at — Immediate timing (the move fires now; the charging effect handles the delay) → single combatant scope → target known at cast → stat modification. The axes make its dual-category nature readable without contradiction.

---

### Accuracy and Hit Resolution

Before potency is ever computed, the system must answer: did the move connect at all? This is a probabilistic gate with its own formula and modifier pipeline, analogous to potency but producing a **hit outcome** rather than a number.

The simplest model is binary — hit or miss — derived from the move's base accuracy and the caster/target accuracy/evasion stats. But many games support richer outcome buckets:

| Hit outcome | What it means |
|---|---|
| **True hit** | Full connection; resolve normally |
| **Glancing blow** | Partial contact; potency reduced, secondary effects may not trigger |
| **Near-miss** | Barely failed; may still trigger graze effects or dust-in-eyes-style results |
| **Dodge** | Target actively evaded; may open a counter-opportunity or trigger a reactive effect |
| **Parry / Block** | Target deflected with weapon or shield; different trigger conditions than a dodge, may have unique follow-up rules |

The result of accuracy resolution is a named bucket, not a boolean. Downstream stages (potency, outcomes) can read this bucket and branch on it — a "glancing blow" could reduce potency by 50% via a pipeline pipe, or a "parry" could trigger a reactive effect on the target.

Some moves bypass accuracy resolution entirely and always produce **True Hit**: heals, item usage, self-targeting moves, and "never-miss" moves (Swift, Aerial Ace). This is a property declared on the move config, not a formula result.

---

### Critical Hits and Critical Defence

After (or intertwined with) accuracy resolution, the system may ask a second probabilistic question: was this hit especially effective, or was the defence especially solid? Critical hit detection and accuracy are related — in some systems a crit guarantees a hit; in others they are fully independent rolls.

**Critical hit variations:**

- **Simple scaling** — a crit multiplies or adds to potency (1.5×, 2×). This is the most common model and can be expressed as a pipeline multiplier pipe.
- **Crit overrides miss** — in some systems, a critical hit cannot miss regardless of accuracy roll. This is a design choice about stage ordering, not a given.
- **Behavior-changing crits** — a crit may do more than scale potency. It could change the outcome list entirely: add splash damage to adjacent targets, apply a bonus buff to the caster, inflict a different status effect. This means the **crit flag must be visible to outcomes and conditions**, not just silently consumed by the damage pipeline.
- **Crit rate modification** — moves and effects can raise or lower crit chance. High-crit-ratio moves, Focus Energy, and Lucky Chant (reduces foe crits) all modify this layer.
- **Crit immunity** — heals, items, and certain move types or targets cannot trigger a crit. This is a property of the move or the target, checked before the roll.

**Critical defence variations:**

- **Fortify / Block** — the target resists more effectively than normal; potency is further reduced beyond normal defences.
- **Counter-crit** — a perfect defence triggers a reaction (thorns-style recoil to the attacker, or a free counter-move).
- **Crit defence bypass** — some moves or abilities ignore the target's ability to critically defend (armor-piercing, Mold Breaker-style).

Because crits can change behavior beyond potency, the resolution context passed to outcome evaluation must carry the crit flag and crit-defence flag, not just the final potency number.

---

### Move Cost and Availability

Before a move can be selected or executed, the system must answer: is this move currently available to this caster? Availability is checked before the player commits — unavailable moves should not be selectable (or should appear greyed out with a reason). Several independent axes govern availability:

**Resource costs:**

- **PP / Charges** — a fixed number of uses per battle or session; reaching 0 makes the move unavailable (Pokémon PP, Fire Emblem weapon durability).
- **Mana / MP** — a shared pool depleted per use; recovered by other moves, items, or resting.
- **HP cost** — the move costs the caster a portion of their own HP (dark magic tropes, desperation moves).
- **Level / rank gating** — the move is unlocked at a threshold and unavailable below it.

**Cooldowns and timing locks:**

- **Turn cooldown** — the move cannot be used again for N turns after firing.
- **Prior-move lock** — using this move commits the caster to it for multiple consecutive turns; other moves are unavailable until it completes (Rollout, Bide, Outrage).
- **Sequence requirement** — a move is only available if a specific move was used last turn (a combo finisher requiring a setup move, Fury Cutter building power on consecutive use).

**Conditional availability:**

- **Environmental requirement** — the move requires specific field conditions (Surf needs water terrain, a fire-type move may be boosted or restricted by weather).
- **Multi-caster requirement** — the move requires specific allies to be present and actively participating. This is a special availability check: not just the caster's state, but the combined state of multiple combatants (Chrono Trigger dual techs, combined limit breaks).
- **Arbitrary code** — for cases that cannot be expressed declaratively, an availability check can run custom logic (boss-specific restrictions, puzzle-gated abilities).

Availability is a move property evaluated before the player confirms selection. Move configs must carry enough data for the UI layer to display availability state cheaply without running the full resolution pipeline.

---

## The Generator / Engine Boundary

Moves are authored as `.tres` data files (by the generator or by hand). The engine executes them. These two sides must stay decoupled.

The bridge is a **tag vocabulary**: the engine ships a set of named behaviors (formula types, pipe tags, effect tags, outcome types). Designers reference these tags in move configs. The engine maps tags to implementations.

### Workflow for adding a new move behavior

1. **Engine dev** — implement the new behavior (formula variable, pipe, effect handler, or outcome type)
2. **Schema dev** — add the new tag to the valid vocabulary in `schema/`
3. **Designer** — author `.tres` files referencing that tag; no code needed

A designer working only with existing tags never touches engine code. Adding a new *behavior* requires an engine PR first; adding new *content* using existing behaviors does not. The tag vocabulary should be documented as a self-service reference for designers.

---

## Move Resolution: Five Stages

This section starts to discuss proposed architecture/ implementation/ psudo code for building a system that supports the above design discussions. Consider this section a proposal, not a prescribed task.

### Stage 1 — Target Selection

Targets are resolved before potency is computed. The move config declares a target selector:

- Player-chosen (single, or multi-select)
- Auto-select (all enemies, all allies, all combatants, random, lowest HP)
- Context-derived ("the last entity that attacked the caster" — used by Counter)

Target certainty matters: some moves lock targets at cast time; others re-evaluate at the moment of resolution (important for ATB where time passes between cast and firing).

### Stage 2 — Accuracy Resolution

For each target, the system evaluates whether the move connects at all. The move config declares one of:

- **Guaranteed hit** — skip this stage entirely; produce True Hit unconditionally (heals, items, Swift-style moves).
- **Formula-based** — evaluate an accuracy formula against a variable namespace (caster accuracy stat, target evasion stat, field modifiers, move base accuracy) to produce a hit outcome bucket.

The hit outcome (True Hit, Glancing Blow, Near-Miss, Dodge, Parry, etc.) is stored on the resolution context and forwarded to all subsequent stages. Downstream stages can condition on it — a Glancing Blow outcome might install a reduced-potency pipe, a Parry might skip the potency stage entirely and instead install a reactive effect on the target.

### Stage 2.1 — Critical Hit / Critical Defence Detection

The system makes a secondary probabilistic roll (unless the hit outcome was a full miss or the move is crit-immune). This stage is separate because crits can interact with accuracy (in some systems a crit overrides a miss) — the ordering between Stage 2 and 2.1 is a design choice that may need to be configurable per battle style.

Some games determine the critical hit rate first, and if it crits it automatically hits (skips accuracy resolution), so a Crit may be considered a special type of hit outcome. The title "Stage 2.1" suggests this happens after accuracy, which is true in some games. But other games check crits before critical hits (old pokemon games I believe), and some games check at the same time (D&D for example).

The outputs of this stage are two flags on the resolution context:

- `is_critical_hit` — the attack was especially effective
- `is_critical_defence` — the target defended especially well

Both flags are forwarded to the potency pipeline and the outcome list. Their effect is not determined here — this stage only determines whether they occurred. What a crit *does* is up to the pipeline pipes and outcome conditions that read the flag.

> **Open:** How exactly does a crit change behavior? Options include: a temporary pipe injected into the potency pipeline, a separate outcome list that executes in addition to or instead of the normal list, a flag passed into the formula namespace, or a custom handler. This is unresolved and warrants its own design discussion before implementation.

> **Open:** How exactly does a "defense crit" get computed

### Stage 3 — Potency (Expression Evaluator + Modifier Pipeline)

`MoveConfig` stores a formula string evaluated against a flat variable namespace:

```
caster_attack, caster_magic, caster_spirit, caster_speed, caster_hp, caster_max_hp
target_attack, target_defense, target_hp, target_max_hp
move_power
battle_turn
battle_weather   # integer/enum value
etc...
```

Example formulas:

```
caster_attack * move_power / target_defense
caster_max_hp * 0.25
move_power * (battle_weather == 2 ? 2.0 : 1.0) * caster_magic / target_defense
```

Ternary expressions are permitted (they remain pure functions from inputs to a number). Full if/else blocks or side effects are not. Adding a new variable to the namespace costs one line in the resolver.

The base value then flows through a **modifier pipeline** assembled fresh at resolution time from serializable state. Pipes are ephemeral — they are instantiated from tags and enums on `BattleState` and `MonsterInstance`, applied, and discarded.

Pipeline phases (order defined in `BattleConfig`, making phase order itself serializable and configurable per battle style):

```
PHASE_ADDITIVE    # flat bonuses (+10 damage, etc.)
PHASE_MULTIPLY    # multipliers (type effectiveness, weather, debuffs)
PHASE_CAP         # clamps, minimums, maximums
```

The core principle: **state stores data, behavior is assembled from data.** `BattleState` and `MonsterInstance` hold tags, enums, and values — always serializable. Pipes are instantiated from those tags at resolution time, never persisted.

### Stage 4 — Outcomes

The modified potency value is handed to each outcome declared by the move. Each outcome is a discrete, independently conditional instruction:

| Outcome type | What it does |
|---|---|
| **Stat delta** | Add or subtract potency from a stat (HP damage, HP healing, stat stage change). The most common outcome. |
| **Stat set** | Set a stat to an absolute value rather than applying a delta. Used by moves like Endeavor (set target HP equal to caster HP) or OHKO moves (set HP to 0). Distinct from delta because it bypasses the potency value entirely or uses it as a direct target value. |
| **Effect install** | Add an effect (with trigger and expiry config) to caster, target, or battle state |
| **Effect remove** | Remove a named effect from caster, target, or battle state |
| **Battle state write** | Write to a field on `BattleState` (weather enum, field flags, etc.) |
| **Custom handler** | Run arbitrary code — the escape hatch for Metronome, boss specials, etc. |

Each outcome can carry an optional condition evaluated at resolution time before it applies. Conditions may read the hit outcome bucket, crit flag, and crit-defence flag from the resolution context — this is how behavior-changing crits are expressed without special-casing the resolution logic.

**Note on self-targeting outcomes:** a move can declare multiple outcomes targeting different entities. A recoil move (Double-Edge, Brave Bird) is a damage outcome targeting the enemy *and* a Stat delta outcome targeting the caster. The two outcomes are independent instructions on the same move — no special recoil mechanic is needed.

---

## Effects (Overview)

Effects are persistent conditions attached to a combatant or to the battle state. They are a separate system from moves — moves can create them, but effects own their lifecycle.

An effect has:

- **An attachment target** — a specific combatant, or the battle globally
- **A trigger** — when does it act? (passive/always, on turn start, on turn end, on a specific battle event)
- **An action** — what happens when triggered? (modify potency in the pipeline, emit a new move resolution, write to a stat, install/remove another effect)
- **An expiry condition** — when does it cease to exist? (N turns elapsed, a specific event fires, manually removed by another move)

Effects with event-based triggers are how categories 3–5 are implemented. The effect system — trigger types, expiry models, stacking rules, event binding and cleanup — is its own design space and will have its own document.

---

## Example Moves

This section catalogs moves that probe different corners of the design space. These serve two purposes: (1) justifying why the design space is drawn where it is, and (2) acting as planning test cases — if an architecture can't cleanly express these moves, it isn't done yet. Each entry notes *why* it is included.

### Common Cases

**Fire Blast** — Category 1 parametric damage. Formula: `caster_magic * move_power / target_defense`. Single enemy target, standard accuracy roll, can crit (1.5× potency pipe). Included as the baseline: the happy path every system must handle trivially.

**Slash** — Physical damage with an elevated crit rate. Identical to Fire Blast in structure except the crit roll probability is higher. Included to confirm that crit rate is a per-move property, not a global constant.

**Heal / Potion** — `caster_max_hp * 0.5` targeting self. Guaranteed hit (bypasses Stage 2 entirely). Crit-immune. No accuracy roll, no crit roll. Included to confirm the guaranteed-hit bypass path exists and that crit immunity is a move property.

---

### Accuracy and Hit Outcome Cases

**Sand Attack / Flash** — a move whose primary outcome is installing a debuff effect that lowers the target's accuracy on future rolls. Included to confirm that hit-rate modification is expressed as an effect on the target, not a direct mutation of a stat.

**Swift** — damage move that cannot miss. Guaranteed hit regardless of evasion modifiers or accuracy debuffs on the caster. Included to confirm the guaranteed-hit property bypasses Stage 2 even when the caster is debuffed.

**Aerial Ace** — similar to Swift: guaranteed hit, but does not bypass evasion-altering field effects in all games. Included as a nuance case — "cannot miss" may mean "ignores target evasion stat" or "bypasses Stage 2 entirely" depending on the game's rules. The distinction must be representable.

---

### Critical Hit Cases

**Focus Energy** — a move that installs an effect on the caster raising their crit rate. The crit roll reads a modified rate. Included to confirm crit rate is a readable/modifiable value in the resolution context.

**Frost Nova (hypothetical)** — deals damage and, *if it crits*, applies a Freeze status instead of the normal Slow status. The crit flag is read by a conditional outcome. Included to confirm that behavior-changing crits are expressed via outcome conditions reading the crit flag — not special-cased in the resolution logic.

**Sacred Sword** — damage that ignores the target's defensive stat stage buffs. Crits often ignore the attacker's offensive debuffs and/or the target's defensive buffs, or use a different potency equation entirely in some games.

**Lucky Chant** — installs a field effect that prevents the opposing team from landing critical hits. Included to confirm crit immunity can be attached to a field-level effect, not just individual combatants.

---

### Move Cost and Availability Cases

**PP-limited move** — a standard damage move with 8 PP. After 8 uses it becomes unavailable. Included as the baseline resource cost case.

**Surf (terrain-gated)** — conditionally available based on field state (water terrain). Included to confirm environmental availability checks are a first-class move property.

**Rollout** — the caster is locked into this move for up to 5 consecutive turns; power doubles each turn. Move is unavailable for other selections while active. Power scaling is a formula variable (`consecutive_uses`). Included to confirm prior-move lock and formula-accessible turn counters are both supported.

**Dual Tech — Fire + Wind (Chrono Trigger-style)** — requires two specific party members to both be alive, un-locked, and participating. Neither member can act independently that turn; both contribute to a single combined resolution. Included to confirm the multi-caster availability check and joint resolution path are in scope, even if the architecture for this is unresolved.

---

### Edge Cases

**Endeavor** — sets the target's HP to equal the caster's current HP. Uses Stat set (absolute), not Stat delta. Accuracy roll applies (can miss). Crit does not apply (HP is set, not increased — though this is a design choice). Included to confirm the Stat set outcome type exists.

**Guillotine / Fissure / Sheer Cold** — OHKO: sets the target's HP to 0 if it connects, regardless of potency. Accuracy is lower for targets at higher level than the caster (formula-based). Crit-immune. Included to confirm that "bypass potency, set HP to 0" is expressible via Stat set with a constant value rather than requiring a special OHKO outcome type.

**Double-Edge** — deals damage to the target and 25% recoil to the caster. Expressed as two outcomes: Stat delta targeting the enemy (normal damage), Stat delta targeting the caster (`potency * 0.25` with the `self` target selector). Included to confirm recoil requires no special mechanic — just a self-targeting outcome.

**Counter** — deals 2× the physical damage the caster received on the previous turn. Target is context-derived ("the last entity that attacked the caster physically"). Potency formula reads `last_physical_damage_received * 2`. Included to confirm context-derived targets and effects that store their own temporary variables are supported.

**Metronome** — randomly selects and executes another move. No formula, no standard outcome. The escape hatch: Custom handler. Included to confirm the custom handler outcome type exists and that not everything must be expressed declaratively.

**Rain Dance** — installs a weather effect on the battle state lasting 5 turns. The weather enum affects potency formulas of water/fire moves via a pipeline pipe. Included to confirm field-scoped effect installation and formula variable exposure of battle state are both supported.

**Fury Swipes** — strikes the target 2–5 times in a single turn. Each hit is a full independent resolution of Stages 2–4: its own accuracy roll, its own crit roll, its own potency computation. A hit that faints the target mid-chain stops the remaining hits. The number of strikes is determined once before the chain begins (random, weighted toward 2–3 hits). Included as the canonical multi-hit example — it makes explicit that multi-hit is a *loop* around the resolution stages, not a potency multiplier, and that early-exit on faint must be handled between iterations. On hit/ attack trigger effects happen multiple times (if applicable)

**Transform / Mimic (Pokémon)** — the caster copies the target's moveset, stats, or appearance. Mimic permanently replaces one of the caster's moves with the last move the target used.

**Sketch (Smeargle)** — permanently learns the last move used. This persists beyond the battle.

**Disable / Encore / Taunt (Pokémon)** — force or restrict move selection. Taunt prevents non-damaging moves; Encore locks the target into repeating the last move used; Disable makes one specific move unavailable

**Silence / Seal (FF, many JRPGs)** — prevents a category of moves (magic, skills) from being selected.

---

- **Effect system design** — trigger types, expiry models, stacking/conflict policy, and interaction ordering are all unresolved. This is the largest remaining design surface.
- **Battle-style validity (category 6)** — how does a move declare which battle styles it is valid in? Does the controller silently skip invalid moves, or does the schema enforce it at load time?
- **Formula validation** — expression strings are hard to validate at content-authoring time. A linter or dry-run validator in the generator tooling is worth considering.
- **Tag vocabulary home** — where does the canonical list of valid pipe tags, effect tags, and outcome types live? `schema/battle/` is the likely home.
- **Chemistry / emergence** — the most interesting effects interact with each other (rain + thunder, fire + oil surface). This is a much larger design surface (cf. Breath of the Wild, Divinity: Original Sin 2, weather effects in Pokémon) and is explicitly out of scope for now. The effect attachment model should not architecturally preclude it.
