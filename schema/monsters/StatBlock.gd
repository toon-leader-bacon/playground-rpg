class_name StatBlock
extends Resource

@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 5
@export var speed: int = 5


func serialize() -> Dictionary:
	return {
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
	}


static func deserialize(data: Dictionary) -> StatBlock:
	var s := StatBlock.new()
	s.max_hp = data.get("max_hp", 10)
	s.attack = data.get("attack", 5)
	s.defense = data.get("defense", 5)
	s.speed = data.get("speed", 5)
	return s
