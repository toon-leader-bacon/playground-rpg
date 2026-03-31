class_name TileDefinitionResource
extends Resource
## Defines a single tile type. Reusable definition — not a placed tile instance.
##
## Passability bitmask:
##   Bit 0 = enter from North  Bit 4 = exit to North
##   Bit 1 = enter from South  Bit 5 = exit to South
##   Bit 2 = enter from East   Bit 6 = exit to East
##   Bit 3 = enter from West   Bit 7 = exit to West
##   0xFF (255) = fully passable   0x00 (0) = fully blocked
##   0x20 (32)  = ledge south (exit S only)

const PASSABLE_ALL: int = 0xFF
const IMPASSABLE: int = 0x00
const LEDGE_SOUTH: int = 0x22  # enter N (bit 0) | exit S (bit 5)

@export var id: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var texture: Texture2D = null
@export var atlas_coords: Vector2i = Vector2i(0, 0)
@export var passability_mask: int = 255
## Array[PassabilityConditionResource] — untyped for .tres compatibility.
@export var conditions: Array = []
@export var on_enter: TileEffectResource = null
@export var on_exit: TileEffectResource = null
@export var encounter_table_override: EncounterTableResource = null
## 0 = no collision, 1 = world_static, 2 = water, 3 = entities
@export var physics_layer: int = 0
