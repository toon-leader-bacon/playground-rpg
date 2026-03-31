class_name GlobalTileRegistry
extends Resource
## Shared tile definitions available across all zones.
## Effective palette = global tiles (0..N-1) + zone.local_tile_palette (N..M).
## Prototype: global registry is empty; all palette indices map to local tiles.

## Array[TileDefinitionResource] — untyped for .tres compatibility.
@export var tiles: Array = []
