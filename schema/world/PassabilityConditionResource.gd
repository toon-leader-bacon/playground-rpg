class_name PassabilityConditionResource
extends Resource
## Encodes a single conditional passability rule.
## A tile may have zero or more of these evaluated before the base passability bitmask.
##
## Direction bitmask encoding:
##   Bit 0 = can enter from North (0,-1)
##   Bit 1 = can enter from South (0,+1)
##   Bit 2 = can enter from East  (+1,0)
##   Bit 3 = can enter from West  (-1,0)
##   Bit 4 = can exit to North
##   Bit 5 = can exit to South
##   Bit 6 = can exit to East
##   Bit 7 = can exit to West

@export var direction_mask: int = 0
@export var condition_tag: String = ""
@export var condition_args: Dictionary = {}
