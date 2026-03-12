# JRPG Project: Generator

This file describes the content/ configuration generator, and instructions for inter-file design and development.
The generator module is responsible for making configurations for the engine, and developing content to load into the engine.

Examples:

- **Engine Configuration**: The engine may offer multiple different battle styles, while the generator can create a config file that selects one (Pokemon battle style) and any settings (2v2, each side has a bench of 4 monsters, initial weather settings)
- **Content Creating**: The generator also can create content to be used by the engine (Generate monster archetypes, along with possible moves, selecting an archetype and moves to create specific monsters for the opponent to feature)

---

## Engine CLI

The generator is operable as a standalone headless CLI. Recipes encode specific, named generation configurations. The CLI is intentionally simple: `--recipe`, `--count`, `--seed`, `--out-dir`. The recipe layer (not the CLI) is where design intent lives. This CLI tool is for developer iteration, not end-user interaction.

---

## Project Structure

- The `generator/` dir contains folders for developing configurations/ content that will be loaded into the engine.
- A `.tscn` scene and its primary `.gd` script always live in the same folder.

An example directory structure is as follows (this example is for illustration, and may not be the actual current implementation)

```
res://
├── generator/
│   ├── shared/        # Common utilities that are useful for across many factories
│   ├── maps/          # Family of factories that are creating content for a specific mechanic(s)
│   │   ├── dungeons/  # Factory for a specific use case/ design strategy
│   │   ├── cities/
│   │   └── world/
│   ├── monsters/
│   │   └── etc..
│   ├── moves/
│   └── etc.../
├── content/           # All .tres config files live here
│  ├── monsters/
│  ├── moves/
│  ├── maps/
│  └── etc.../
└── schema/            # Generator may import from schema. Schema must not import from generator
    ├── battle/
    ├── monsters/
    ├── world/
    └── moves/
```

---

## Architecture Rules

- The generator uses schema data objects to produce `.tres` files into `content/` directory
- The `.tres` files either configure certain mechanics in the engine, or define new content variants (like multiple different monsters, moves, maps etc.)
- Follow the factory class design pattern
- Most factories should accept an optional RNG instance (This helps with unit testing). For example:

```gdscript
func _init(rng: RandomNumberGenerator = null) -> void:
    self.rng = rng if rng != null else RandomNumberGenerator.new()
```

- Avoid hard coding values, prefer to make things configurable/ dynamic
