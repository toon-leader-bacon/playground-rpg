class_name StatBlock
extends Resource

@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 5
@export var speed: int = 5
@export var special_attack: int = 5
@export var special_defense: int = 5


func serialize() -> Dictionary:
	return {
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"special_attack": special_attack,
		"special_defense": special_defense,
	}


static func deserialize(data: Dictionary) -> StatBlock:
	var s := StatBlock.new()
	s.max_hp = data.get("max_hp", 10)
	s.attack = data.get("attack", 5)
	s.defense = data.get("defense", 5)
	s.speed = data.get("speed", 5)
	s.special_attack = data.get("special_attack", 5)
	s.special_defense = data.get("special_defense", 5)
	return s
