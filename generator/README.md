# Content Generator

CLI tool for generating `.tres` resource files from named **recipes**. Each recipe is a pre-configured, repeatable factory call that produces one type of content.

---

## Prerequisites

- Godot 4 installed and accessible on your PATH (or use the full path to the binary)
- Run from the project root (where `project.godot` lives)

The generator runs entirely headless — no window opens.

---

## Quick Start

```bash
# List all available recipes
godot --headless -s res://generator/GeneratorMain.gd -- --list-recipes

# Generate one stat block
godot --headless -s res://generator/GeneratorMain.gd -- --recipe stat_pokemon_tank

# Output goes to res://content/generated/ by default
```

---

## CLI Reference

```
godot --headless -s res://generator/GeneratorMain.gd -- [options]
```

| Option | Default | Description |
|---|---|---|
| `--recipe <name>` | *(required)* | Recipe to run. See `--list-recipes`. |
| `--count <n>` | `1` | Number of resources to generate. |
| `--out-dir <path>` | `res://content/generated/` | Output directory as a `res://` path. |
| `--out-prefix <name>` | *(recipe name)* | Filename prefix. |
| `--seed <n>` | *(timestamp)* | Integer RNG seed for reproducible output. |
| `--list-recipes` | | Print all recipes with descriptions, then exit. |
| `--help`, `-h` | | Print this usage summary, then exit. |

> **Note:** The `--` separator between Godot's own flags and your arguments is required.

---

## Examples

```bash
# List all available recipes
godot --headless -s res://generator/GeneratorMain.gd -- --list-recipes

# Generate one Pokemon-style balanced stat block (output: content/generated/stat_pokemon_balanced.tres)
godot --headless -s res://generator/GeneratorMain.gd -- --recipe stat_pokemon_balanced

# Generate 5 tank stat blocks into content/stats/ with a custom prefix
godot --headless -s res://generator/GeneratorMain.gd -- \
    --recipe stat_pokemon_tank --count 5 \
    --out-dir res://content/stats/ --out-prefix tank

# Reproduce a specific run exactly using a fixed seed
godot --headless -s res://generator/GeneratorMain.gd -- --recipe stat_ff_tank --seed 12345

# Generate 10 accented blocks (each gets a random secondary strength)
godot --headless -s res://generator/GeneratorMain.gd -- \
    --recipe stat_pokemon_accented --count 10 --out-prefix accented
```

---

## Available Recipes

Run `--list-recipes` to see the current list. As of initial setup:

| Recipe | Description |
|---|---|
| `stat_pokemon_balanced` | Pokemon stats, Gaussian distribution (500 pts) |
| `stat_pokemon_tank` | Pokemon stats, tank archetype (high HP + DEF, low SPD) |
| `stat_pokemon_glass_cannon` | Pokemon stats, glass cannon (high ATK, low DEF and HP) |
| `stat_pokemon_speedster` | Pokemon stats, speedster (high SPD + ATK, low DEF) |
| `stat_pokemon_support` | Pokemon stats, support (high MDEF + SPIRIT, low ATK) |
| `stat_pokemon_accented` | Pokemon stats, tank base with one random secondary strength |
| `stat_ff_balanced` | FF-simple stats, Gaussian distribution (600 pts) |
| `stat_ff_tank` | FF-simple stats, tank archetype |
| `stat_fire_emblem_balanced` | Fire Emblem stats, Gaussian distribution (350 pts) |
| `stat_diablo_balanced` | Diablo primary stats, Gaussian distribution (100 pts) |

---

## Adding a New Recipe

Recipes are registered in two places:

### 1. Write the recipe function

Open (or create) a file in `generator/recipes/` that matches your content type, e.g. `StatBlockRecipes.gd` for stat blocks, `MonsterRecipes.gd` for monsters.

Add a static function with this exact signature:

```gdscript
static func my_recipe_name(rng: RandomNumberGenerator) -> Resource:
    var factory := _SomeFactory.new(rng)
    return factory.build_something(...)
```

Hard-coded parameters are intentional — the recipe is a named, repeatable configuration. If you need a variation, add a second recipe.

### 2. Register the recipe

Open `generator/GeneratorRegistry.gd` and add an entry to the dictionary in `get_all()`:

```gdscript
"my_recipe_name": {
    "func": func(rng: RandomNumberGenerator) -> Resource:
        return _StatBlockRecipes.my_recipe_name(rng),
    "description": "One-line description shown in --list-recipes.",
},
```

If you created a new Recipes file (e.g. `MonsterRecipes.gd`), also add a preload at the top of `get_all()`:

```gdscript
const _MonsterRecipes = preload("res://generator/recipes/MonsterRecipes.gd")
```

That's it. Run `--list-recipes` to verify your recipe appears.

---

## Output Format

Generated files are standard Godot `.tres` resource files. They can be loaded by the engine via `ConfigLoader` or inspected directly in the Godot editor.

**Filename convention:**

- Single file: `<prefix_or_recipe_name>.tres`
- Multiple files: `<prefix_or_recipe_name>_0.tres`, `_1.tres`, etc.

The default output directory `res://content/generated/` is created automatically if it does not exist. You may want to add it to `.gitignore` if you don't want generated test files committed.

---

## Reproducibility

Every run prints the seed used. To reproduce a result exactly:

```
Seed: 1741234567890 (time-based)
```

```bash
godot --headless -s res://generator/GeneratorMain.gd -- --recipe stat_pokemon_tank --seed 1741234567890
```

The same seed + same recipe always produces identical output.

---

## Architecture Notes

- **Entrypoint:** `generator/GeneratorMain.gd` — parses CLI args, drives the run
- **Registry:** `generator/GeneratorRegistry.gd` — maps recipe names to functions
- **Recipes:** `generator/recipes/*.gd` — static functions, one per recipe
- **Future direction:** Recipes are currently hard-coded functions. The intended evolution is to make them `.tres` config files (a `GeneratorRecipe` schema object), enabling editor-side authoring and automated pipelines without changing the CLI surface.
