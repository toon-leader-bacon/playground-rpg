extends Node
## Holds all mutable runtime game state.
## Only controller scripts may write to these properties.

var player_party: Array[Resource] = []
var current_zone_id: String = ""
var flags: Dictionary = {}
## Typed as Resource to avoid class-name resolution issues during autoload parsing.
## At runtime this holds a BattleState instance.
var last_battle_state: Resource = null
