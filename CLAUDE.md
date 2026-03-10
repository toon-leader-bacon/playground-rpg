# JRPG Project

This file describes the project, the separation of concerns therein, and instructions for inter-library design and development.
This, and all other CLAUDE.md files are 'living' documents. After major development efforts, suggest changes to a relevant CLAUDE.md file(s) to ensure they are up to date.
CLAUDE.md files capture the "How to build" this project.
The DESIGN_BIBLE.md, along with the user's direct instruction/ messages captures "What to build" and "Why to build it".

In project management speak, the DESIGN_BIBLE.md document represents a static product owner. Only I (a human) should update it. The DESIGN_BIBLE (along with the initial human prompt) answers the question of "What to build" and "why to build it", where as the claude.md and rules answer the questions of "how to build it".

---

## Project Summary

This project contains two distinct development parts:

- Configurable JRPG **engine** built in Godot 4 with GDScript.
- A content **generator** that builds the configurations that will be loaded into the engine.

The engine and generator are strictly separate systems; The engine has zero direct awareness of the generator, only indirectly coupling via the "content" `.tres` configuration files created by the generator (or other sources).
The engine and generator may both import from `schema/`, but it only contains data models. Engine and Generator must not import from each other.

There is a third, parallel region related to **tests** for the above two parts.
The tests directory must match the exact structure of the engine and generator directories to stay organized.

---

## Project Structure

- Engine and Generator are in separate top level directories.
- Configurations (created by the generator, consumed by the engine) should live in the `content/` directory
- `schema/` defines Resource class shapes. `content/` contains `.tres` instances of those classes.
- The `tests/` directory is a parallel tree that must mirror the `engine/` and `generator/` directories exactly.

An example directory structure is as follows (this example is for illustration, and may not be the actual current implementation)

```
res://
├── engine/       # Scripts related to actually running a game
│   ├── core/     
│   ├── battle/
│   ├── world/
│   ├── entities/
│   ├── etc...
│   └── ui/
│
├── generator/     # Entirely separate — engine has zero awareness of this
│   ├── zones/
│   ├── monsters/
│   ├── moves/
│   └── etc.../
│
├── schema/        # Engine and generator may import from schema. Schema must not import from any other directory
│   ├── battle/
│   ├── monsters/
│   ├── world/
│   └── moves/
│
├── content/       # All .tres config files live here (the particular implementations for the schema objects)
│   ├── monsters/
│   ├── moves/
│   ├── world/
│   └── etc.../
|
├── tests/          # tests directory matches the engine and generator directory exactly
│   ├── engine/
|   |   ├── core/
|   |   ├── battle/
|   |   ├── world/
|   |   └── etc.../
│   └── generator/
|       ├── zones/
|       ├── monster/
|       ├── moves/
|       └── etc.../
│
└── assets/        # Will be populated by a human at the relevant time
    ├── sprites/
    ├── audio/
    └── fonts/
```

---

## Other Rules

- The `engine/` directory must never import from or reference `generator/`. The generator produces `.tres` files into `content/`; the engine reads from `content/`. That is the only connection between them.
- The `generator/` may use ONLY data model objects from `engine/`, but only data model objects. Engine logic (controller scripts) should NOT be used in the generator
- All game content is defined in `.tres` Godot Resource files in `content/` (typically created by the generator)

---

## What NOT to Do

- Do not add story, dialogue systems, or narrative content — out of scope. Just focus on building the engine with configurable mechanics, and the generator which creates configurable controls for that dynamic engine.

## Godot Conventions

### `.tres` files for custom Resource classes

Always use `type="Resource"` with an explicit `script = ExtResource(...)` reference — never `type="ClassName"`. Using the class name requires Godot's global class cache to be populated, which is unreliable outside the editor (headless runs, fresh clones,
etc.).

Correct pattern:

```.tres
[ext_resource type="Script" path="res://schema/monsters/MyClass.gd" id="1_id"]

[resource]
script = ExtResource("1_id")
```

### Headless class cache

Any time you add a new class_name script, run godot --headless --import once before running .tscn files directly. gdUnit4 tests work without this; scene runs need the cache.

### Running tests headlessly

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add "res://tests/"
```

Use `--add "res://tests/path/to/TestFile.gd"` to run a single suite.
