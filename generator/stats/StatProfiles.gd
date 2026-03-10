class_name StatProfiles
extends RefCounted
## Named collections of stat name arrays representing different JRPG game families.
## Pass these to StatBlockFactory to build blocks pre-keyed for a given style.
## Values are not set here — use StatBlockFactory to populate them.

## Pokemon: split physical/special, no MP.
const POKEMON: Array[String] = [
	StatName.HP,
	StatName.ATTACK,
	StatName.DEFENSE,
	StatName.SPECIAL_ATTACK,
	StatName.SPECIAL_DEFENSE,
	StatName.SPEED,
]

## Chrono Trigger: slim physical/magic split with evasion and stamina.
const CHRONO_TRIGGER: Array[String] = [
	StatName.STRENGTH,
	StatName.ACCURACY,
	StatName.SPEED,
	StatName.MAGIC,
	StatName.EVASION,
	StatName.STAMINA,
	StatName.MAGIC_DEFENSE,
]

## Final Fantasy (simplified): classic HP/MP + eight attributes.
const FF_SIMPLE: Array[String] = [
	StatName.HP,
	StatName.MP,
	StatName.STRENGTH,
	StatName.AGILITY,
	StatName.VITALITY,
	StatName.MAGIC,
	StatName.SPIRIT,
	StatName.LUCK,
]

## Fire Emblem (Three Houses base stats): movement, physical, magic, and charm.
const FIRE_EMBLEM: Array[String] = [
	StatName.HP,
	StatName.STRENGTH,
	StatName.MAGIC,
	StatName.DEXTERITY,
	StatName.SPEED,
	StatName.LUCK,
	StatName.DEFENSE,
	StatName.RESISTANCE,
]

## Secret of Mana: full physical + magic split with dual accuracy/evasion.
const SECRET_OF_MANA: Array[String] = [
	StatName.STRENGTH,
	StatName.AGILITY,
	StatName.STAMINA,
	StatName.INTELLIGENCE,
	StatName.WISDOM,
	StatName.ATTACK,
	StatName.ACCURACY,
	StatName.DEFENSE,
	StatName.EVASION,
	StatName.MAGIC_DEFENSE,
]

## Diablo primary stats (core four).
const DIABLO_PRIMARY: Array[String] = [
	StatName.STRENGTH,
	StatName.DEXTERITY,
	StatName.VITALITY,
	StatName.INTELLIGENCE,
]
