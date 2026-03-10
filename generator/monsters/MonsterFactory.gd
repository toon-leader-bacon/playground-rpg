class_name MonsterFactory
extends RefCounted
## Factory for producing MonsterConfig resources.
## Accepts an optional RNG for deterministic generation in tests.

var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator = null) -> void:
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()


## Build a MonsterConfig with explicit parameters.
## Use this when you know exactly what you want (e.g. hand-authored monsters).
func build(
	id: String,
	display_name: String,
	type_tags: Array[int],
	base_stats: StatBlock,
	move_ids: Array[String],
	ai_style: MonsterConfig.AIStyle = MonsterConfig.AIStyle.RANDOM,
	base_xp_yield: int = 10,
	encounter_weight: float = 1.0,
	sprite_path: String = ""
) -> MonsterConfig:
	var config := MonsterConfig.new()
	config.id = id
	config.display_name = display_name
	config.type_tags = type_tags
	config.base_stats = base_stats
	config.move_ids = move_ids
	config.ai_style = ai_style
	config.base_xp_yield = base_xp_yield
	config.encounter_weight = encounter_weight
	config.sprite_path = sprite_path
	return config


## Build a StatBlock with explicit values.
func build_stats(max_hp: int, attack: int, defense: int, speed: int) -> StatBlock:
	var stats := StatBlock.new()
	stats.max_hp = max_hp
	stats.attack = attack
	stats.defense = defense
	stats.speed = speed
	return stats
