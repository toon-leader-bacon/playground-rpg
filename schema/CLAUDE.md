# JRPG Project: Shared Schema

The schema directory is the shared contract layer between `engine/` and `generator/`.
It contains only Godot Resource class definitions — the data shapes that `.tres` files are built from.
It is owned by neither system.
All classes should have:

- serialize function that saves the object to a `.tres` in the provided file/ directory
- static deserialize function that loads data from a `.tres` into a new data object
- deserialize_update function that loads data from a `.tres` file into this data object
- deep_copy function that creates a new instance of the object (typically using the serialize and deserialize functions)

## What Belongs Here

- `@export`-annotated `Resource` subclasses that define content structure
- Pure data shapes: properties and type declarations only
- Any class that a `.tres` file requires to load correctly

## What Does Not Belong Here

- Game logic of any kind — that lives in `engine/`
- Generation algorithms or game design logic — that lives in `generator/`
- Engine-internal utilities (math helpers, type aliases) — those live in `engine/shared/`
- Any class that extends `Node`
- Any imports to files outside of `schema/`

## Schema Changes Are Design Decisions

Schema changes affect both `engine/` and `generator/` simultaneously.
Do not remove or modify properties here to solve a local problem in one system.
