class_name TileDefinitionResource
extends Resource
## Defines all properties of a single tile type.
##
## Passability bitmask (passability_mask) uses 8 bits:
##   ENTER_N = 1<<0  enter this tile from its north face (player moving south)
##   ENTER_S = 1<<1  enter this tile from its south face (player moving north)
##   ENTER_E = 1<<2  enter this tile from its east face  (player moving west)
##   ENTER_W = 1<<3  enter this tile from its west face  (player moving east)
##   EXIT_N  = 1<<4  exit this tile to north (player moving north)
##   EXIT_S  = 1<<5  exit this tile to south (player moving south)
##   EXIT_E  = 1<<6  exit this tile to east  (player moving east)
##   EXIT_W  = 1<<7  exit this tile to west  (player moving west)
##
## Common combinations:
##   PASSABLE_ALL = 0xFF  — walkable in all directions
##   IMPASSABLE   = 0x00  — solid wall
##   LEDGE_SOUTH  = 0x21  — enter from north (ENTER_N) + exit to south (EXIT_S)

const ENTER_N: int = 1 << 0
const ENTER_S: int = 1 << 1
const ENTER_E: int = 1 << 2
const ENTER_W: int = 1 << 3
const EXIT_N: int = 1 << 4
const EXIT_S: int = 1 << 5
const EXIT_E: int = 1 << 6
const EXIT_W: int = 1 << 7
const PASSABLE_ALL: int = 0xFF
const IMPASSABLE: int = 0x00

@export var tags: Array = []                                          # Array[String]
@export var passability_mask: int = PASSABLE_ALL
@export var passability_conditions: Array = []                         # Array[PassabilityConditionEntry]
@export var on_enter_effect: TileEffectResource = null
@export var on_exit_effect: TileEffectResource = null
@export var encounter_table_override: EncounterTableResource = null


func serialize() -> Dictionary:
	var cond_data: Array = []
	for c: PassabilityConditionEntry in passability_conditions:
		cond_data.append(c.serialize())
	return {
		"tags": tags.duplicate(),
		"passability_mask": passability_mask,
		"passability_conditions": cond_data,
		"on_enter_effect": on_enter_effect.serialize() if on_enter_effect else null,
		"on_exit_effect": on_exit_effect.serialize() if on_exit_effect else null,
	}


static func deserialize(data: Dictionary) -> TileDefinitionResource:
	var r := TileDefinitionResource.new()
	r.deserialize_update(data)
	return r


func deserialize_update(data: Dictionary) -> void:
	tags = data.get("tags", []).duplicate()
	passability_mask = data.get("passability_mask", PASSABLE_ALL)
	passability_conditions = []
	for c: Dictionary in data.get("passability_conditions", []):
		passability_conditions.append(PassabilityConditionEntry.deserialize(c))
	var enter_data: Variant = data.get("on_enter_effect", null)
	on_enter_effect = TileEffectResource.deserialize(enter_data) if enter_data else null
	var exit_data: Variant = data.get("on_exit_effect", null)
	on_exit_effect = TileEffectResource.deserialize(exit_data) if exit_data else null


func deep_copy() -> TileDefinitionResource:
	return TileDefinitionResource.deserialize(serialize())
