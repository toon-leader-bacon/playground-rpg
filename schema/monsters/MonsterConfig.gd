class_name MonsterConfig
extends Resource

## AIStyle determines which strategy MonsterAI uses when selecting a move.
## Add new strategies here and handle them in MonsterAI.choose_action().
enum AIStyle {
	RANDOM,
	# Future: AGGRESSIVE, DEFENSIVE, STATUS_HEAVY, MIRROR
}

@export var id: String = ""
@export var display_name: String = ""
@export var base_stats: StatBlock
@export var type_tags: Array[int] = []        # Array of TypeTag.Type values
@export var move_ids: Array[String] = []       # Resolved at runtime via ConfigLoader
@export var ai_style: AIStyle = AIStyle.RANDOM
@export var base_xp_yield: int = 10
@export var encounter_weight: float = 1.0
@export var sprite_path: String = ""
