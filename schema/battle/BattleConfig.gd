class_name BattleConfig
extends Resource
## Configuration resource that fully describes a battle to start.
## Content authors create .tres instances of this in content/battles/.
## BattleScene reads the config and starts the appropriate battle mode.

## User-facing battle mode. Maps to BattleManager.CombatStyle internally.
enum CombatStyle {
	TURN_BASED_NVM = 0,  ## Pokemon-style: all submit, execute speed-ordered.
	ATB_NVM = 1,          ## FF-style: independent gauges, act when full.
}

## Which battle system to use.
@export var style: CombatStyle = CombatStyle.TURN_BASED_NVM

## Monster IDs to load for each team (matched by index to team slot).
@export var player_monster_ids: Array[String] = []
@export var enemy_monster_ids: Array[String] = []

## Level used when instantiating all monsters in this battle.
@export var monster_level: int = 5

## ATB fill rate multiplier. 1.0 = normal, 2.0 = double speed.
## Not yet wired through to the scheduler — reserved for future tuning.
@export var atb_speed_multiplier: float = 1.0
