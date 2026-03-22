# Combat Moves — Design Space

This is a living design document. Its purpose is to map the problem space of combat moves in RPG battle systems — not to specify an implementation. The goal right now is clarity of thinking: what is a move, what can a move do, and where are the interesting edges?

See [MOVES_EXAMPLES.md](./MOVES_EXAMPLES.md) for a catalog of specific moves that probe these edges.

---

## What Is a Move?

A **move** is a discrete, intentional action taken by a combatant during battle. It has a defined moment of initiation and a defined moment of resolution. It is not an ongoing condition — it fires, it resolves, and it is done.

Three things define a move:

1. **A source** — the combatant (or combatants) initiating the action. Usually a single actor, but not always.
2. **A target** — the entity or entities the move acts on. This could be another combatant, the source themselves, a group, the environment, or something more abstract like a rule of the battle.
3. **An effect** — what the move actually does when it resolves. This could be direct and immediate, or it could set something in motion that plays out over time.

That last distinction — *immediate vs. setting something in motion* — is worth dwelling on.

### Moves vs. Ongoing Conditions

Some moves do their work entirely at the moment of resolution: deal damage, restore HP, raise a stat. Others accomplish their goal by installing a **persistent condition** on a combatant or on the battle itself — a burn that ticks each turn, a protective barrier, a stance that changes what moves are available, a delayed countdown to a devastating effect. The move fires once; the condition does the ongoing work.

This distinction matters because it keeps moves simple and composable. A move that causes a character to retaliate against the next hit doesn't need to know anything about future hits — it just installs a condition that does. A move that changes the weather doesn't change how every subsequent move resolves directly — it modifies the battlefield state that those moves read.

The richest and most interesting move designs often come from this combination: a simple, clean move that installs a condition, and a condition with a non-obvious trigger or expiry that creates emergent behavior.

---

## What Can a Move Act On?

The scope of what a move can affect is wider than it might first appear. Organized roughly from most concrete to most abstract:

**Combatant stats and resources**
The most familiar territory: damage, healing, draining HP, modifying attack or defense or speed. But this also includes less-obvious resources like a combatant's remaining action count for this turn, their position on a grid, or the charges remaining on one of their own moves.

**Combatant state and conditions**
Installing or removing persistent conditions: status ailments (poison, burn, sleep), stat modifications (attack up, evasion down), stances, transformation into a new form, or flags that alter how future moves resolve (focus, enrage, protect).

**The combatant's action space**
What moves are available to a combatant is itself a target. A move can lock a combatant into repeating a specific action (Encore in Pokémon), prevent an entire category of moves (Taunt blocks non-damaging moves, Silence blocks magic), copy an opponent's moveset (Transform), or force the use of a random move (Metronome). The space of *what you can do* is as targetable as your HP.

**Other moves and conditions**
Conditions on the field are not inert data — they can be stolen (Snatch), transferred (Psycho Shift), extended, shortened, or removed wholesale (Dispel). A move can also interact with a specific ongoing condition by reading it, disrupting it, or hijacking its trigger. Baton Pass transfers the caster's own conditions to a replacement ally; Spite reduces the PP of whatever move the opponent just used.

**The battlefield / shared state**
Some moves alter rules that apply globally for the remainder of the encounter or for a duration: weather systems (Rain Dance, Sandstorm), gravity (Gravity prevents moves that require flight), spatial inversion (Trick Room reverses speed order), or terrain that interacts with specific move types (Electric Terrain, Psychic Terrain). These moves don't target a combatant — they rewrite the context that all subsequent moves resolve within.

**The structure of the encounter itself**
Moves that change *who is participating* (Roar forces an opponent to swap; Baton Pass lets the user pass their buffs to an ally mid-battle), how turns are ordered, or what victory conditions look like.

---

## Does a Move Reach Its Target?

Not all moves reach their targets the same way, and the nature of *if* a move connects (or fails to) is itself design space.

### Does it connect?

Most offensive moves ask a probabilistic question before doing anything: did it hit? This can be a simple binary (hit or miss), or it can produce a richer result — a glancing blow that deals reduced damage, a near-miss that still procs some minor effect, a dodge that opens a counter-opportunity, a parry or block that deflects and triggers a different response entirely. Some moves bypass this question entirely — heals, self-targeting moves, and certain "never-miss" attacks (Swift, Aerial Ace in Pokémon).

### Was it especially effective?

A secondary question: was the contact particularly effective or particularly resisted? Critical hits are the most common expression of this — typically multiplying damage — but the design space extends further. A critical could change the *type* of outcome, not just its magnitude: applying a different status effect, adding splash damage to nearby targets, granting the attacker a free buff. Critical defense (a "perfect block") is the mirror: a defense so complete that it triggers a counter-reaction, damages the attacker, or nullifies the move entirely.

### Target selection

Who the move acts on, and when that is determined, is surprisingly varied:

- **Chosen at cast time** — the player selects a target before the move fires.
- **Re-evaluated at resolution time** — in systems where time passes between declaring an action and executing it (ATB, initiative-based systems), a target chosen at cast time might be dead or gone by resolution. Some moves re-evaluate the target at resolution.
- **Context-derived** — the target isn't chosen at all; it's implied by the situation. Counter targets whoever just attacked the user. Grudge targets the move that just killed the user. Follow Me redirects all incoming fire to the user.
- **Emergent / stolen** — a reactive condition on one combatant intercepts and redirects a move aimed somewhere else.

---

## How Does a Move's Strength Scale?

Most moves have some sense of *magnitude* — how much damage, how much healing, how large a stat change. Where that number comes from is its own design space:

- **Fixed** — the move always does the same thing, regardless of who's casting or what the situation is.
- **Stat-derived** — the caster's attack, magic, or speed; the target's defense; some ratio of current to maximum HP.
- **State-contingent** — the formula changes based on what's true right now. Reversal (Pokémon) does more damage the lower the user's HP. Stored Power scales with the number of buffs the user has accumulated. Magnitude randomizes from a distribution. A hypothetical synergy move might double in power if a specific ally used a compatible move last turn.
- **Accumulated** — power builds over a sequence: Rollout doubles in power each consecutive use; Fury Cutter does the same; Bide stores up received damage to release it. The move's history is part of its formula.
- **Emergent from interaction** — the power of a move is modified by field conditions, active weather, the target's current status, or the presence of other effects. Rain Dance doesn't change a water move directly — it changes the context the water move resolves in.

---

## When Does a Move Happen?

Resolution timing is more flexible than "this turn":

- **Immediate** — the most common case. Move fires, resolves, done.
- **Delayed** — the move schedules a future event. Future Sight (Pokémon) strikes two turns later regardless of what happens in between. Doom (Final Fantasy) counts down to a KO. The interesting design tension: can the target escape the delayed hit? Can the timer be manipulated?
- **Multi-turn / staged** — the move locks the caster in for a sequence. A charging turn followed by a release (Solar Beam, Geomancy). A multi-turn commitment with escalating power (Rollout, Outrage). The availability cost — giving up action for one or more turns — is part of the move's design.
- **Reactive / triggered** — the move arms a condition that waits for a future event before resolving. Counter fires when the user is next hit physically. Destiny Bond fires when the user faints. Protect fires when the user would be hit. The trigger is part of the move's identity, not just its delivery.

---

## What Does a Move Cost?

A move isn't free. Costs are as much design space as effects:

**Direct resource costs**
MP or mana drawn from a shared pool; PP or charges counting down toward depletion; HP paid to cast (desperate, powerful moves); an item consumed. Resource scarcity creates decision-making.

**Temporal costs**
Time spent charging or winding up. Being locked into a move or sequence for multiple turns. A cooldown period before the move can be used again. Any of these trade present flexibility for future power.

**Risk costs**
Recoil damage (Brave Bird, Double-Edge — the user is hurt by the force of their own attack). Stat drops applied to the caster after use (Close Combat, Overheat). Confusion after overexertion. A move that is powerful but self-destructive carries inherent risk-reward design.

**Availability costs**
Some moves require conditions to be met before they can be used at all: a specific ally must be alive and uncommitted (Dual Techs from Chrono Trigger); a terrain or weather condition must be active; a prior move must have been used last turn; the combatant must be below a certain HP threshold. Availability constraints can transform a move's tactical meaning completely.

---

## Annotated Combat Walkthroughs

These walkthroughs illustrate how the above design elements interact during an actual encounter. They are descriptive examples, not engine specifications.

---

### Walkthrough 1 — A Simple Exchange

*Two combatants. No field conditions. A straightforward offensive trade.*

**Setup:** Ryn (player character, mage archetype) faces a Stone Golem. Ryn has Fire Blast, Haste, and Heal available. The Golem has Crush (slow, high-damage physical) and Rock Throw (ranged, moderate damage).

---

**Turn 1 — Ryn acts first (higher speed)**

> Ryn uses **Haste** on herself.

- Source: Ryn. Target: Ryn (self). Cost: 20 MP.
- No accuracy question — self-targeting moves connect unconditionally.
- No magnitude question — the outcome is installing a condition ("Haste"), not a number.
- *Haste* is a persistent condition now on Ryn. It will modify her speed stat (and therefore turn order) for the next several turns. The move is done; the condition does the ongoing work.

**Golem acts (slower, acts after Ryn)**

> Golem uses **Rock Throw** targeting Ryn.

- Accuracy check: Rock Throw has moderate accuracy. Ryn's evasion is baseline. The roll succeeds — the move connects.
- Magnitude: derived from Golem's physical attack vs. Ryn's defense. A number is calculated.
- Critical check: The roll does not produce a crit this time.
- Ryn takes damage. Her HP decreases.

*Nothing unusual so far. But Haste is now on the field, and it will change turn ordering next turn.*

---

**Turn 2 — Haste is now active**

> Ryn acts first again — and with Haste, her effective speed is high enough that she might act twice before the Golem, depending on the battle system.

> Ryn uses **Fire Blast** targeting Golem.

- Accuracy check: Fire Blast has high but not perfect accuracy. It connects.
- Type/resistance check (if applicable): Does the Golem have resistance to fire? Suppose it does — this modifies the magnitude via a multiplier applied after the base calculation.
- Magnitude: Ryn's magic stat * Fire Blast power / Golem's magic defense, then multiplied by the resistance modifier. The Golem takes reduced damage.
- Secondary effect: Fire Blast has a chance to inflict Burn. The system checks a separate probability. It triggers — a *Burn* condition is now installed on the Golem.

*Two things happened here: direct damage (immediate outcome) and a condition install (persistent outcome). From here, Burn will deal damage to the Golem at the start of each of its turns — without Ryn doing anything else.*

---

**Turn 3 — The Burn condition acts**

Before the Golem takes its action, the Burn condition triggers on its turn start. The Golem takes periodic damage — not from any move Ryn cast this turn, but from a condition left behind by a move two turns ago.

> Golem uses **Crush** — its slow, powerful physical attack.

- This is a slower move. If the turn order system uses a speed threshold or ATB gauge, Crush might have delayed resolution even within the same turn.
- Accuracy check: Connects.
- Magnitude: High physical power, calculated against Ryn's defense. Ryn takes significant damage.

*Ryn's Haste is still running. The Burn is ticking. The battlefield is more complex than turn 1, and it got there through accumulated move outcomes.*

---

### Walkthrough 2 — A Reactive Exchange

*Illustrating moves that arm triggers, redirect incoming attacks, and create non-obvious timing.*

**Setup:** Two player characters — Aiden (physical striker) and Sela (support/disruption) — face the Duel Specter boss. The Specter has a telegraphed heavy attack (Reave) and a reactive punish (Ghoststrike — fires immediately after being hit by a physical move).

---

**Turn 1 — Sela acts**

> Sela uses **Veilward** on Aiden.

- Source: Sela. Target: Aiden. A self-targeting move on an ally.
- No accuracy check. No magnitude. Outcome: installs a *Veilward* condition on Aiden.
- *Veilward* is a reactive condition: "the next time Aiden would receive damage, reduce it by 60% and remove this condition." It is now armed and waiting.

*Sela spent her turn doing nothing visible to a casual observer. But Aiden is now protected once.*

**Aiden acts**

> Aiden uses **Heavy Strike** targeting the Specter.

- Physical move — this will trigger the Specter's *Ghoststrike* reactive condition.
- Accuracy check: Connects.
- Magnitude: Normal physical calculation. Specter takes damage.
- **Ghoststrike fires** — the Specter's reactive condition detects "was hit by physical move" and immediately resolves a retaliatory strike back at Aiden.
  - This is a triggered move, not the Specter's action for the turn. It fires as a consequence of the Ghoststrike condition, not as a separate choice.
  - Ghoststrike connects. Normally Aiden would take heavy damage — but *Veilward* is armed.
  - *Veilward* intercepts: damage is reduced 60%. The Veilward condition is consumed and removed from Aiden.

*In one chain of resolution: Aiden's attack triggered a reactive punish, which triggered a defensive condition Sela had pre-installed. Three effects resolving in sequence, all set in motion by Aiden swinging once.*

---

**Turn 2 — The Specter telegraphs Reave**

> The Specter begins **charging Reave** — a multi-turn heavy attack. A visual indicator shows it will fire next turn.

- This is a staged/multi-turn move. The Specter's action this turn is "enter Reave charge state." A condition is installed on the Specter: "on your next turn, resolve Reave."
- The Specter loses action flexibility this turn in exchange for a powerful upcoming strike.

> Sela uses **Disruption** targeting the Specter.

- *Disruption* is designed specifically to interact with charging states: "if target is currently charging a move, cancel the charge and deal moderate magic damage."
- The Specter's Reave charge condition is detected and removed. The Specter takes moderate damage.
- Reave never fires.

*Sela used the charge window — the Specter's intentional vulnerability — to cancel the threat. This is a move that targets another move. The charge state being a readable, removable condition is what makes this interaction possible.*

---

**Turn 3 — Aiden tries a finishing sequence**

> Aiden uses **Expose** targeting the Specter — a setup move that installs a condition: "the next hit against this target ignores 50% of its defense."

> Aiden immediately uses **Rending Strike** — a finisher with a built-in availability check: only available if the target has an *Expose* condition.

- Availability check passes. Rending Strike becomes available after Expose resolved.
- Rending Strike resolves: standard physical calculation, but the potency pipeline reads the Expose condition on the Specter and applies the defense-reduction modifier.
- The Expose condition is consumed on use — it was a single-hit amplifier.

*This is a two-move combo with a conditional availability gate. Rending Strike exists in the move list but can't be used unless Expose is active. The payoff is a hit significantly stronger than either move alone.*

---

## What This Space Doesn't Settle

This document draws the *edges* of the design space but intentionally leaves several things open:

**How do multiple effects interact?** When two conditions that both modify the same thing are active simultaneously — two attack buffs, a buff and a debuff, conflicting weather effects — what is the resolution order? Which wins? Can they stack? This is its own large design surface.

**What does a "turn" mean?** The walkthroughs above assume a rough turn structure, but different battle systems (pure turn-based, ATB, real-time with pause, initiative-based) give "turn" very different meanings. The move design space described here mostly holds across all of them — but the specifics of ordering, timing, and simultaneity depend heavily on the battle system model.

**What context does a move have access to?** Several move types (state-conditional, context-derived targeting, accumulated power) depend on the move being able to read battle history. What is stored? For how long? How far back can a move look? These are both design and engineering questions.

**How do multi-caster moves work at the architecture level?** Dual Techs and combined limit breaks (multiple source combatants contributing to a single resolution) are named as part of the space but their internal mechanics — who "owns" the resolution, how their stats are combined, what happens if one contributor is interrupted mid-charge — are unresolved.
