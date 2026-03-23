# Move Examples Catalog

This catalog documents specific moves — from existing games or invented to illustrate a design idea — that probe interesting corners of the design space. Each entry notes what makes it worth thinking about. This is a living reference, not a complete taxonomy.

Moves are loosely grouped by the design idea they best illustrate, but many entries belong to multiple groups.

---

## Direct Damage and Healing (The Baseline)

**Fire Blast** *(Pokémon)*
Standard magic damage. Formula: caster magic * move power / target defense. Can miss, can crit, has a small chance to inflict Burn as a secondary outcome. The baseline case every system must handle trivially.

**Slash** *(many games)*
Physical damage with an elevated critical hit rate compared to baseline. Same structure as Fire Blast. Interesting because it establishes that crit rate is a per-move property.

**Heal / Cure** *(many games)*
Restores HP proportional to max HP. Self or ally targeted. Never misses, immune to crits. Interesting because it establishes guaranteed-hit as a first-class property — some moves simply bypass accuracy resolution entirely.

**Brave Bird / Double-Edge** *(Pokémon)*
Deals damage to the target and a percentage of that damage as recoil to the caster. Two outcomes on one move — one targeting the enemy, one targeting the caster. Establishes that recoil is not a special mechanic; it's a self-targeting outcome.

---

## Accuracy and Miss Behavior

**Swift** *(Pokémon)*
Always hits. Bypasses accuracy and evasion entirely, including stat modifications that would otherwise affect either side. Interesting because it distinguishes "never misses" from "ignores evasion modifiers" — these are different properties.

**Aerial Ace** *(Pokémon)*
Also always hits, but in some game entries it does not bypass field-level evasion effects. A nuance case: "cannot miss" can mean at least two distinct things depending on what it bypasses.

**Sand Attack / Flash** *(Pokémon)*
The primary outcome isn't damage — it's installing a debuff effect on the target that reduces their accuracy on future moves. The move itself still goes through a normal accuracy check to connect. Interesting because hit-rate manipulation is expressed as an installed condition, not a direct stat mutation.

**Blizzard** *(Pokémon)*
Normally has imperfect accuracy, but becomes guaranteed to hit during hail weather. Same move; availability and behavior change with field state. Illustrates that accuracy can be state-conditional.

---

## Critical Hits and Critical Defense

**Focus Energy** *(Pokémon)*
Installs a condition on the caster that raises their critical hit rate for future moves. Establishes that crit rate is a readable, modifiable value — not a fixed move property only.

**Lucky Chant** *(Pokémon)*
Installs a field effect preventing the opposing team from landing critical hits. Crit immunity at a team/field scope rather than per-combatant.

**Frost Nova** *(hypothetical)*
Deals ice damage. On a normal hit: applies Slow. On a critical hit: applies Freeze instead of Slow. The critical hit flag changes which status is installed, not just the damage magnitude. Establishes that crits can be behavior-changing, not just potency-scaling.

**Sheer Force / Tough Claws** *(Pokémon abilities, not moves)*
Included because these interact with crit resolution from the outside — abilities that modify how moves calculate their crit multiplier or bypass certain defenses. Worth noting that crit behavior can be altered by the caster's passive state, not just the move itself.

**Counter-Crit** *(hypothetical)*
A passive condition: "when this combatant is critically hit, immediately deal the attacker a percentage of the damage received." A defensive critical hit triggers a reactive outcome. Establishes that critical defense can be an event with its own consequences.

---

## State-Conditional Magnitude

**Reversal / Flail** *(Pokémon)*
Physical / Normal damage that scales inversely with the user's remaining HP. The lower the user's HP, the higher the damage output. The formula variable is `caster_hp / caster_max_hp` — this ratio directly scales move power.

**Stored Power** *(Pokémon)*
Magic damage that scales with the number of positive stat stages the user has accumulated. The formula variable is `caster_buff_count`. Establishes that the caster's effect list (not just their raw stats) can be a formula input.

**Acrobatics** *(Pokémon)*
Physical damage that doubles in power if the user is not holding an item. The formula condition is a flag on the caster's equipment state.

**Magnitude** *(Pokémon)*
Deals damage to all combatants on the field (including allies). The power is randomly drawn from a weighted distribution — low power outcomes are possible but rare; high power outcomes are rare but devastating. The magnitude is random, not derived from stats.

**Solar Beam** *(Pokémon)*
Normally requires a charge turn before firing. In sunny weather: fires immediately with no charge delay. Interesting because field state changes the *structure* of the move (eliminating the staged mechanic), not just a number in the formula.

---

## Multi-Turn and Staged Moves

**Solar Beam (charge variant)** *(Pokémon)*
See above. The caster is committed (locked into the move) during the charge turn. If the weather changes between charge and fire, the power may be reduced. Establishes that delayed resolution interacts with changing field state.

**Rollout** *(Pokémon)*
The caster commits to this move for up to 5 consecutive turns. Power doubles each turn. If the caster is hit during the sequence, the chain breaks (in some games). Establishes accumulated-power formulas and the concept of a commitment penalty.

**Bide** *(Pokémon)*
The caster takes no action for 2 turns, accumulating all damage received, then releases it as double-damage against the last attacker. The "power" of the move isn't known until resolution. The stored value is received damage, not a stat or a counter.

**Future Sight / Doom Desire** *(Pokémon)*
The move is declared now, but strikes the target two turns later — whether or not the caster is still alive, whether or not the target has changed. The delayed hit cannot be redirected after it is placed. Interesting because it decouples the declaration from the resolution almost completely.

**Doom** *(Final Fantasy)*
Installs a visible countdown timer on the target. When the timer reaches zero, the target is instantly KO'd regardless of HP. The timer is explicit, visible, and creates a different kind of tension than a damage-over-time effect. Other moves might interact with the timer. Distinguishes "countdown to a binary outcome" from "damage accumulation over time."

---

## Reactive and Triggered Moves

**Counter / Mirror Coat** *(Pokémon)*
Returns 2× the damage received from the last physical (Counter) or special (Mirror Coat) hit. The move arms a condition after being used. The condition's trigger is "was just hit by a physical / special move." The target is context-derived: whoever just struck the user.

**Destiny Bond** *(Pokémon)*
Arms a condition on the caster: "if this combatant faints before their next move, the attacker that caused it also faints." The move does nothing visible on the turn it's used. Its entire effect is a reactive threat.

**Protect / Detect** *(Pokémon)*
Installs a condition: "block the next incoming move this turn." Success probability decreases with consecutive uses — using it repeatedly becomes unreliable. Interesting because the availability and effectiveness of the move depend on its own recent usage history.

**Grudge** *(Pokémon)*
Arms a condition: "if the user faints before their next action, the move that caused it loses all remaining PP." Cross-entity outcome (writes to the attacker's move resource, not the attacker's HP). Cross-event (triggered by the user's own fainting). One of the most unusual trigger structures in the design space.

**Perish Song** *(Pokémon)*
All combatants currently on the field (including the user) receive a Perish countdown condition. After 3 turns, any combatant still with the condition faints. The trigger is duration-based, but the interaction — every combatant affected, but switching out removes the condition in some games — creates emergent scenarios.

---

## Field and Rule-Altering Moves

**Rain Dance / Sunny Day / Sandstorm / Hail** *(Pokémon)*
Installs a weather condition on the battle state for a fixed duration. This condition modifies formula evaluation for specific move types (water moves boosted in rain, fire moves weakened), causes periodic damage to certain combatant types (Sandstorm damages non-rock/ground/steel types), and changes the availability or behavior of other moves (Blizzard never misses in hail, Solar Beam charges faster in sun). One move; many downstream interactions.

**Trick Room** *(Pokémon)*
Inverts the speed ordering of all combatants for 5 turns. Slower combatants now act first. Interesting because it is a complete rule reversal, not a buff or debuff. Especially interesting because using it again while active cancels it early.

**Gravity** *(Pokémon)*
Prevents moves that require flight or levitation for all combatants for 5 turns. Grounds all levitating combatants, making them susceptible to ground-type moves. Also increases accuracy of all moves during this time. A single field effect that modifies availability, targeting, and magnitude simultaneously.

**Electric Terrain / Psychic Terrain / Grassy Terrain / Misty Terrain** *(Pokémon)*
Terrain effects that modify formula results for specific move types and add or remove secondary effects (Psychic Terrain prevents moves that require priority from hitting grounded targets). These interact with weather and other field conditions.

**Reflect / Light Screen** *(Pokémon)*
Installs a team-level condition that reduces incoming physical or special damage for all allies for several turns. Field-scoped damage reduction, not individual combatant protection.

---

## Moves That Target the Action Space

**Taunt** *(Pokémon)*
Installs a condition on the target: for the next several turns, they can only use damaging moves. Non-damaging moves (status moves, field moves, healing) become unavailable. Targets the opponent's action space.

**Encore** *(Pokémon)*
Forces the target to repeat the last move they used for several consecutive turns. The target loses access to all other moves. Particularly powerful when used after the opponent uses a setup move on themselves.

**Disable** *(Pokémon)*
Makes one specific move — the last one the target used — unusable for several turns. More surgical than Taunt; targets a particular slot in the opponent's action space.

**Silence / Seal** *(many RPGs)*
Prevents the use of magic or skill moves. Usually expressed as a condition that checks move category at availability resolution.

**Mimic** *(Pokémon)*
Permanently replaces one of the user's moves (the Mimic slot) with the last move the target used, for the duration of the battle. Writes to the user's own move list.

**Transform** *(Pokémon / many games)*
The user completely copies the target's current stats, type, and moveset. Writes to multiple combatant properties simultaneously. One of the broadest outcome scopes of any single move.

**Sketch** *(Pokémon — Smeargle)*
Like Mimic, but the acquired move is permanent — it persists beyond the battle. Establishes that some move outcomes write to data that outlasts the encounter entirely.

---

## Moves That Target Other Conditions

**Dispel / Purge** *(many RPGs)*
Removes all buff conditions from a target in a single outcome. Requires querying the target's effect list by tag ("remove all effects tagged as buff") rather than naming a specific effect.

**Snatch** *(Pokémon)*
Arms a reactive condition: "if any combatant uses a self-targeting beneficial move before the user's next action, steal the effect — apply it to the user instead and prevent it from applying to its original target." Intercepts and redirects another move's outcome.

**Psycho Shift** *(Pokémon)*
Transfers the user's own primary status condition (burn, poison, paralysis, etc.) to the target. The source loses the condition; the target gains it. Moves the condition across entities rather than creating or destroying it.

**Baton Pass** *(Pokémon)*
Switches the user out and sends in a replacement ally, but passes all stat modifications and installed conditions to the incoming ally. Transfers the accumulated results of multiple prior moves to a new combatant.

**Spite** *(Pokémon)*
Targets a specific move in the opponent's moveset and reduces its remaining PP. Writes to a resource belonging to a specific move, not a general stat.

**Effect Extension / Reduction** *(hypothetical)*
A support move that extends the duration of all beneficial conditions on an ally by 2 turns. Requires iterating the ally's effect list and modifying duration values. Establishes that effect duration itself is mutable data.

---

## Multi-Source Moves (Combined Actions)

**Dual Tech — Aura Whirl** *(Chrono Trigger — Lucca + Marle)*
Requires both Lucca and Marle to be alive and participating. Neither can act independently on this turn. Both casters contribute; a single combined resolution occurs. Availability check is multi-entity. The combined stats of both casters may factor into the formula.

**Delta Attack** *(Chrono Trigger — all three characters)*
Requires all three active party members to be available. Multi-source extreme: three combatants, one resolution.

**Cross Limit Break** *(hypothetical — two characters both at limit)*
Only available when two specific characters both have a full limit gauge simultaneously. Each character's limit gauge is consumed. The combined move is more powerful than either individual limit break. Availability is a joint condition on two separate resource pools.

---

## Multi-Hit Moves

**Fury Swipes / Bullet Seed / Arm Thrust** *(Pokémon)*
Strikes the target 2–5 times in a single turn. Each hit is a fully independent resolution: its own accuracy check, its own crit check, its own damage calculation. A hit that faints the target mid-chain stops the remaining hits. Per-hit trigger effects (contact abilities, held item effects) fire on each hit individually. The number of strikes is determined once before the chain begins.

**Triple Kick** *(Pokémon)*
Hits three times with escalating power on each successive hit. But each hit has its own accuracy check — if the first miss, the chain ends. Power escalation and per-hit accuracy create a different risk profile than a fixed multi-hit move.

---

## Position and Turn-Order Manipulation

**Roar / Whirlwind** *(Pokémon)*
Forces the target to switch out, replaced by a random member of their reserve. In multi-battle contexts, affects who is participating. Writes to the encounter participant list.

**Quick Attack / Extreme Speed** *(Pokémon)*
Moves with elevated priority that act before other moves in the same turn, even from slower combatants. Priority is a move property that interacts with the turn ordering system.

**Extra Turn** *(Persona series)*
Knocking down or stunning an enemy under certain conditions grants the player an additional action this turn. Turn count is mutable data, and certain move outcomes can write to it.

**Haste / Slow** *(many RPGs)*
Installs a condition that modifies the combatant's speed stat, which feeds into turn ordering. In ATB systems, this affects how quickly the gauge fills.

---

## The Escape Hatch

**Metronome** *(Pokémon)*
Randomly selects any other move and executes it. No formula. No standard outcome. There is no clean declarative way to express "pick a random item from the universe of all moves." This is a custom handler — not everything can or should be expressed as data.

**Boss-Specific Scripted Behaviors** *(many JRPGs)*
Behaviors that only make sense in one encounter: a boss that uses a specific move only when the player has a specific item in their inventory; an enemy that transforms into a new form at exactly 50% HP; a multi-phase encounter where the ruleset itself changes between phases. These belong to the encounter design, not the shared move system.
