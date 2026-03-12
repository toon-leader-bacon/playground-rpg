class_name ActionResolver
extends RefCounted
## Stateless resolver that applies a single Action's effect to BattleState.
## Returns an ActionResult — does NOT emit any signals.

const _Action = preload("res://engine/battle/model/Action.gd")
const _BattleState = preload("res://engine/battle/model/BattleState.gd")
const _ActionResult = preload("res://engine/battle/model/ActionResult.gd")


static func apply(
	action: Action,
	state: BattleState,
	rng: RandomNumberGenerator
) -> ActionResult:
	var result := ActionResult.new()

	var move: MoveConfig = action.move
	if move == null:
		_log(state, "  %s has no move available!" % action.actor.config.display_name)
		return result

	_log(state, "  %s used %s on %s" % [
		action.actor.config.display_name,
		move.display_name,
		action.target.config.display_name,
	])

	# Accuracy check
	if rng.randf() > move.accuracy:
		_log(state, "  %s used %s — but it missed!" % [
			action.actor.config.display_name, move.display_name
		])
		return result

	result.hit = true

	match move.effect:
		MoveConfig.Effect.NONE:
			if move.power > 0:
				var dmg: int = _calculate_damage(action.actor, move, action.target)
				action.target.apply_damage(dmg)
				result.damage = dmg
				result.fainted = action.target.is_fainted()
				_log(state, "  → %d damage to %s (%d/%d HP left)" % [
					dmg,
					action.target.config.display_name,
					action.target.current_hp,
					action.target.max_hp(),
				])
				if action.target.is_fainted():
					_log(state, "  %s fainted!" % action.target.config.display_name)
			else:
				_log(state, "  (no effect)")
		MoveConfig.Effect.HEAL:
			var before: int = action.actor.current_hp
			action.actor.restore_hp(move.power)
			var healed: int = action.actor.current_hp - before
			result.healed = healed
			_log(state, "  → restored %d HP to %s (%d/%d HP)" % [
				healed,
				action.actor.config.display_name,
				action.actor.current_hp,
				action.actor.max_hp(),
			])
		MoveConfig.Effect.BUFF_SPEED_SELF:
			action.actor.modify_stat_stage("speed", 1)
			result.stat_name = "speed"
			result.stat_delta = 1
			_log(state, "  → %s's speed rose! (stage %+d)" % [
				action.actor.config.display_name,
				action.actor.get_stat_stage("speed"),
			])
		MoveConfig.Effect.DEBUFF_SPEED_TARGET:
			action.target.modify_stat_stage("speed", -1)
			result.stat_name = "speed"
			result.stat_delta = -1
			_log(state, "  → %s's speed fell! (stage %+d)" % [
				action.target.config.display_name,
				action.target.get_stat_stage("speed"),
			])

	return result


## Damage formula: max(1, (power * atk) / (20 + def))
static func _calculate_damage(
	attacker: MonsterInstance,
	move: MoveConfig,
	defender: MonsterInstance
) -> int:
	var numerator: int = move.power * attacker.attack()
	var denominator: int = 20 + defender.defense()
	return max(1, numerator / denominator)


static func _log(state: BattleState, message: String) -> void:
	state.combat_log.append(message)
