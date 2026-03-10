class_name StatName
extends RefCounted
## String constants for stat names used as keys in GenericStatBlock.
## Using these constants avoids typos and keeps naming consistent
## across schema, generator, and engine code.

# Core combat
const HP: String = "hp"
const MP: String = "mp"
const ATTACK: String = "attack"
const DEFENSE: String = "defense"
const SPEED: String = "speed"

# Physical attributes
const STRENGTH: String = "strength"
const AGILITY: String = "agility"
const DEXTERITY: String = "dexterity"
const STAMINA: String = "stamina"
const VITALITY: String = "vitality"
const ENDURANCE: String = "endurance"

# Magic / elemental
const MAGIC: String = "magic"
const MAGIC_DEFENSE: String = "magic_defense"
const SPIRIT: String = "spirit"
const INTELLIGENCE: String = "intelligence"
const WISDOM: String = "wisdom"

# Secondary combat
const ACCURACY: String = "accuracy"
const EVASION: String = "evasion"
const LUCK: String = "luck"
const CRITICAL: String = "critical"
const RESISTANCE: String = "resistance"

# Pokemon-style split specials
const SPECIAL_ATTACK: String = "special_attack"
const SPECIAL_DEFENSE: String = "special_defense"

# Social / misc
const CHARISMA: String = "charisma"
const PERCEPTION: String = "perception"
