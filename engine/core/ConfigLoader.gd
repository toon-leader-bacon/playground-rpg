extends Node
## The only place in the engine allowed to call load().
## All .tres config files are accessed through these helpers.

const MONSTERS_PATH := "res://content/monsters/"
const MOVES_PATH := "res://content/moves/"
const ZONES_PATH := "res://content/zones/"
const STATS_PATH := "res://content/stats/"


func load_monster(id: String) -> MonsterConfig:
	return load(MONSTERS_PATH + id + ".tres") as MonsterConfig


func load_move(id: String) -> MoveConfig:
	return load(MOVES_PATH + id + ".tres") as MoveConfig


func load_stat_block(id: String) -> GenericStatBlock:
	return load(STATS_PATH + id + ".tres") as GenericStatBlock
