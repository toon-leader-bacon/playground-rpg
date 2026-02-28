# JRPG Engine — Design Bible

> **Project Motto:** "A button I can press to create a new JRPG."
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

## 3. Architecture Philosophy

### 3.1 The Config-Driven Engine

The engine is a **generic host** for mechanics. All content (monsters, moves, maps, stats, encounter tables) is defined in external configuration files, not hardcoded. The engine reads configs at startup and at runtime.

**Key principle:** Adding new *content* must never require changing engine code. Adding new *mechanic types* (new combat systems, new movement modes) requires engine code, but should be structured as an enumerated, switch-driven extension point.

### 3.2 MVC Separation

The project must follow Model-View-Controller discipline:

- **Model:** Game state, entity stats, battle state. No rendering logic. Fully serializable.
- **View:** Godot scenes/nodes responsible for display only. No game logic.
- **Controller:** Systems (BattleManager, WorldManager, etc.) that mediate between model and view.

All Model objects must be serializable to and deserializable from config files. This supports both saving/loading and content generation.

### 3.3 Config File Format

Config files use **Godot `.tres` (Resource) format** as the primary format. This provides native Godot editor integration, type safety, and serialization support.

**Note on XML:** If a future content generator or external tooling requires a human-readable format with comment support, XML is the preferred alternative. LLMs reason over XML well, and inline comments allow game design intent to be documented directly in the data. This decision is deferred until the generator phase.

### 3.4 Engine vs. Generator Boundary

```
[Content Generator] --> produces --> [.tres config files] --> consumed by --> [Engine]
```

The engine has zero awareness of how configs were created. The generator has zero game logic. They communicate only through the config file schema.

---

## 4. Configurability Axes

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

## 5. MVP Scope (Vertical Slice)

The MVP must prove the architecture works, not deliver a complete game. Success means:

- [ ] At least **2 zones** exist, each with distinct enemy pools and visual identity
- [ ] At least **2 combat system modes** are implemented and swappable via config (e.g., standard 1v1 and ATB 1v1)
- [ ] A monster can be **fully defined by a `.tres` config** (stats, moves, type, encounter weight)
- [ ] A map zone can be **fully defined by config** (tileset, encounter table, connections to other zones)
- [ ] The player can: enter a zone, trigger an encounter, battle, win/lose, return to the world, reach a simple end condition
- [ ] Game state can be **saved and loaded** via serialization of the Model layer
- [ ] Swapping which combat system is active requires **only a config change**, no code change

---

## 6. Entity Model

All game entities (monsters, players, NPCs) share a base model. The base is generic; configs load specific values in.

### 6.1 Base Entity Properties (MVP)
- `id: String` — unique identifier
- `display_name: String`
- `stats: Dictionary` — keyed by stat name (HP, ATK, DEF, SPD, etc.)
- `moves: Array[MoveResource]`
- `type_tags: Array[String]` — e.g., ["fire", "flying"]
- `level: int`
- `sprite_path: String`

### 6.2 Move Properties (MVP)
- `id: String`
- `display_name: String`
- `type_tag: String`
- `power: int` — 0 for non-damaging
- `accuracy: float`
- `effect: String` — enum key into the engine's effect registry
- `effect_params: Dictionary` — parameters passed to the effect handler

**Design note:** `effect` + `effect_params` is how interesting moves are expressed. A move is not interesting if it's just `{power: 80, type: fire}`. It becomes interesting when `effect: "multi_hit"` or `effect: "stat_change"` or `effect: "self_destruct"` is applied. The engine maintains a registry of named effects; configs reference them by key.

---

## 7. What Makes Content Interesting (Generator Design Principles)

This section captures game design intent for future encoding into the content generator. These are not engine requirements — they are creative principles.

### 7.1 Interesting Monsters
- **Clear stat identity:** Glass cannon, slow tank, fast frail, support-only — not balanced generalists
- **Niche enemies:** Metal Slime (low catch rate, huge XP), Bomb (self-destructs for massive damage), Shield (redirects damage from allies), Status-only (no direct damage, only debuffs)
- **Regional theming:** Enemies in a zone should share a thematic identity (poison swamp enemies are all slimy/venomous; ice cave enemies are all slow/high-defense)

### 7.2 Interesting Moves
Moves beyond `{damage, type}` that the generator should be able to produce:
- Multi-hit moves
- Stat modifiers (self-buff, self-debuff, enemy debuff)
- Status effects (poison, sleep, paralysis, burn, freeze)
- Delayed/charging moves
- Self-sacrifice moves
- Random/chaotic moves (Metronome equivalent)
- Counter/reactive moves

### 7.3 Interesting Zone Design
- **Environmental hazard + weak boss:** The challenge is the journey, not the fight
- **Rare side-boss:** High reward, optional, telegraphed by environment
- **Pacing variety:** Not all zones should have the same encounter density
- **Progression gates:** New zones unlock when a prior zone's challenge is cleared

### 7.4 Interesting World Progression
Content novelty drives play. Each zone should feel distinct from the last:
- New enemy types not seen before
- New move effects introduced via enemies
- New environmental challenges
- Escalating difficulty in stat terms, but with mechanical surprises

---

## 8. Autoload / Global Systems

These Godot Autoloads form the backbone of the engine. They must be scaffolded before any feature development begins.

| Autoload | Responsibility |
|---|---|
| `GameState` | Mutable global data: player party, inventory, current zone, flags |
| `EventBus` | Signal declarations only. All inter-system communication routes through here |
| `ConfigLoader` | Reads `.tres` files and validates them against expected schemas |
| `BattleManager` | Orchestrates battle flow; delegates to combat system implementation |
| `WorldManager` | Manages zone transitions, encounter triggering, map state |

**EventBus signals to define first (not exhaustive):**
- `battle_started(enemy_data)`
- `battle_ended(result: String)` — "win", "lose", "flee"
- `entity_fainted(entity_id)`
- `xp_gained(amount)`
- `zone_transition_requested(zone_id)`
- `save_requested()`
- `load_requested()`

---

## 9. Development Loop

The intended workflow for adding new mechanics:

1. **Brainstorm** — Interview/discuss the mechanic's game design goals. Reference existing games.
2. **Design** — Define the mechanic in terms of the entity model and config schema. Add signals to EventBus if needed.
3. **Implement** — Give Claude Code a well-scoped task: "Implement X mechanic as a new branch in the combat system switch. Here is the interface it must conform to."
4. **Configure** — Ask Claude Code to produce a minimal example `.tres` config that exercises the new mechanic.
5. **Test & Refine** — Play test. Adjust config. Refine engine if needed.
6. **Generalize** — Once mechanic is stable, encode game design principles for it into the content generator.

---

## 10. Roguelike Meta-Progression (Future Goal)

Once the engine and generator are functional, a roguelike wrapper is a natural evolution:

- First run: Player uses a default generated JRPG with locked parameters
- On completion: Generator parameters unlock (larger world, alternate combat mode, etc.)
- Meta-game items: Player can earn in-game items that modify generator parameters mid-run
  - Example: "Design Document" item lets player reroll the current zone's encounter table
  - Example: "Game Jam" item unlocks ATB mode for the rest of the run
  - Example: "Debug Mode" item reveals enemy stat blocks

This is a distant goal. It is noted here to ensure the engine's config system is designed with runtime parameter mutation in mind.

---

## 11. Open Questions (To Be Resolved at Implementation Time)

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
