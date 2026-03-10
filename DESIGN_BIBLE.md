# JRPG Engine — Design Bible

> **Project vision:** "A button I can press to create a new JRPG."
> **Nature of Project:** Personal learning project. Not intended for release. Fun over polish.

---

## 1. Project Vision

This project has two distinct, layered goals:

1. **Build a configurable JRPG engine** in Godot — a generic, data-driven game engine capable of expressing a wide variety of classic JRPG mechanics through configuration rather than code changes.
2. **Build a content generator on top of that engine** — a system that can author valid, interesting game configurations automatically, encoding game design principles as code.

The engine is the foundation. The generator is the long-term creative goal. These two systems must remain architecturally separate. The engine must never depend on the generator. The generator only produces config files that the engine consumes.

The ultimate vision: press a button, receive a playable JRPG. Each run produces a new world, new monsters, new moves, new zones. The game is the engine; the content is disposable and regenerable.

---

## 2. Inspirations & Design Compass

| Game | What to Borrow |
|---|---|
| **Pokémon** | 1v1 combat skeleton, world-as-linked-zones, monster collection feel, exploration reward loop |
| **Final Fantasy VI/VII** | ATB combat system (stretch), party-based NvN (stretch), overworld map structure (stretch) |
| **Chrono Trigger** | Smooth non-tile movement on tile maps, encounter design philosophy |
| **Skies of Arcadia** | 2D map-based positional combat (distant stretch goal) |
| **Fire Emblem** | Positioning as a core decision (distant stretch goal) |

**Core appeal to optimize for:** Exploration novelty and mechanical depth — not narrative. Players engage because they want to discover new zones and encounter interesting monsters, not to follow a story. Story is out of scope.

---

## 3. Configurability Axes

These are the known "dials" the engine must support. Each is a toggleable/tunable parameter. The MVP implements the simplest option for each; others are built incrementally.

| Axis | MVP Default | Future Options |
|---|---|---|
| **Combat style** | 1v1 turn-based (Pokémon) | ATB 1v1, NvN turn-based, NvN ATB |
| **Map movement** | Tile-locked | Free/smooth (Chrono Trigger style) |
| **World structure** | Linked tile zones | Overworld + embedded sub-zones |
| **Stat system** | Fixed set (HP, ATK, DEF, SPD) | Configurable stat list per run |
| **Encounter style** | Random encounters | Fixed encounters, visible enemies |
| **Party size** | 1 | N (configurable) |
| **World size** | Small (few zones) | Configurable at generation time |

**Implementation rule:** Each axis is an enum in engine code. A switch/match statement routes to the correct implementation. New options are added by extending the enum and adding a new branch — never by modifying existing branches.

---

## 4. MVP Scope (Vertical Slice)

The MVP must prove the architecture works, not deliver a complete game. Success means:

- [ ] At least **2 zones** exist, each with distinct enemy pools and visual identity
- [ ] At least **2 combat system modes** are implemented and swappable via config (e.g., standard 1v1 and ATB 1v1)
- [ ] A monster can be **fully defined by a `.tres` config** (stats, moves, type, encounter weight)
- [ ] A map zone can be **fully defined by config** (tileset, encounter table, connections to other zones)
- [ ] The player can: enter a zone, trigger an encounter, battle, win/lose, return to the world, reach a simple end condition
- [ ] Game state can be **saved and loaded** via serialization of the Model layer
- [ ] Swapping which combat system is active requires **only a config change**, no code change

---

## 5. Entity Model

All game entities (monsters, players, NPCs) share a base model. The base is generic; configs load specific values in.

### 5.1 Base Entity Properties (MVP)

- `id: String` — unique identifier
- `display_name: String`
- `stats: Dictionary[StatEnum, int]` — keyed by stat name (HP, ATK, DEF, SPD, etc.)
- `moves: Array[MoveResource]`
- `type_tags: Array[TypeEnum]` — e.g., ["fire", "flying"]
- `level: int`
- `sprite_path: String`

### 5.2 Move Properties (MVP)

- `id: String`
- `display_name: String`
- `type_tag: String`
- `power: int` — 0 for non-damaging
- `accuracy: float`
- `effect: EffectEnum` — enum key into the engine's effect registry

---

## 6. What Makes Content Interesting (Generator Design Principles)

This section captures game design intent for future encoding into the content generator. These are not engine requirements — they are creative principles.

### 6.1 Interesting Monsters

- **Clear stat identity:** Glass cannon, slow tank, fast frail, support-only — not balanced generalists
- **Niche enemies:** Metal Slime (low catch rate, huge XP), Bomb (self-destructs for massive damage), Shield (redirects damage from allies), Status-only (no direct damage, only debuffs)
- **Regional theming:** Enemies in a zone should share a thematic identity (poison swamp enemies are all slimy/venomous; ice cave enemies are all slow/high-defense)

### 6.2 Interesting Moves

Moves beyond `{damage, type}` that the generator should be able to produce:

- Multi-hit moves
- Stat modifiers (self-buff, self-debuff, enemy debuff)
- Status effects (poison, sleep, paralysis, burn, freeze)
- Delayed/charging moves
- Self-sacrifice moves
- Random/chaotic moves (Metronome equivalent)
- Counter/reactive moves

### 6.3 Interesting Zone Design

- **Environmental hazard + weak boss:** The challenge is the journey, not the fight
- **Rare side-boss:** High reward, optional, telegraphed by environment
- **Pacing variety:** Not all zones should have the same encounter density
- **Progression gates:** New zones unlock when a prior zone's challenge is cleared

### 6.4 Interesting World Progression

Content novelty drives play. Each zone should feel distinct from the last:

- New enemy types not seen before
- New move effects introduced via enemies
- New environmental challenges
- Escalating difficulty in stat terms, but with mechanical surprises

---

## 7. Open Questions (To Be Resolved at Implementation Time)

- [ ] How does leveling work? Fixed XP thresholds? Scaling curve?
- [ ] What is the "end condition" of a generated run? Defeat a final boss? Reach a certain zone depth?
- [ ] How is type effectiveness calculated? Fixed 2x/0.5x table? Configurable per run?
- [ ] Does the player have a persistent character, or is the player entity also generated per run?
- [ ] How are move PP / resource limits handled (or are they)?
- [ ] What does "flee" look like mechanically in 1v1 vs NvN?
- [ ] How are zone connections defined — directional graph? Free placement?
- [ ] What is the save/load granularity? Per-zone checkpoints? Anywhere?

---

*This document is a living design bible. Update it as decisions are made and open questions are resolved. Do not let it become stale.*
