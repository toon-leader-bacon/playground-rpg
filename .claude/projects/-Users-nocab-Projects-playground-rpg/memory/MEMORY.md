# Project Memory — JRPG Engine

## Status
- Five core autoloads scaffolded and registered in project.godot (stubs only, no logic)
- Engine directory structure exists but is otherwise empty

## Key File Locations
- Autoloads: `engine/core/` — EventBus.gd, GameState.gd, ConfigLoader.gd, BattleManager.gd, WorldManager.gd
- Content configs: `content/` (empty)
- Design reference: `DESIGN_BIBLE.md`, `CLAUDE.md`

## Conventions (confirmed)
- Typed GDScript everywhere — no untyped vars
- All loading via ConfigLoader (never call load() directly)
- All inter-system signals via EventBus (append-only)
- GameState is the only source of mutable global data
- MVC: model = pure data, view = display only, controller = logic/state mutation
- No game logic in _ready() or _process()
