extends RefCounted
## State object created at DECLARE and passed through every FSM node.
## Nodes read from and write to this object as move resolution proceeds.

var actor_id: String = ""
var target_id: String = ""
var actor: MonsterInstance
var target: MonsterInstance
var move: MoveConfig
var battle_state: BattleStateNvM
var rng: RandomNumberGenerator

# Accumulated state:
var hit: bool = false
var crit: bool = false
var damage_value: int = 0
var healed_value: int = 0
var turn_denied: bool = false
var fainted: bool = false
