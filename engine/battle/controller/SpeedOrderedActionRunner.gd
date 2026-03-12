class_name SpeedOrderedActionRunner
extends RefCounted
## Executes a committed action queue, sorted by actor speed (descending).
## Emits signals after each resolved action. Does NOT modify BattleState.turn.

signal move_used(user_name: String, move_name: String, target_name: String)
signal damage_dealt(target_name: String, amount: int, remaining_hp: int, max_hp: int)
signal hp_restored(target_name: String, amount: int, new_hp: int, max_hp: int)
signal stat_changed(target_name: String, stat: String, delta: int, total_stage: int)
signal monster_fainted(monster_name: String)

const _ActionResolver = preload("res://engine/battle/controller/ActionResolver.gd")
const _ActionResult = preload("res://engine/battle/model/ActionResult.gd")


## Execute all actions in queue, sorted by speed. Stops if a target faints mid-queue.
func run(queue: Array[Action], state: BattleState, rng: RandomNumberGenerator) -> void:
	# Pre-assign random tiebreak values so the comparator is consistent (required by sort_custom).
	var tiebreaks: Array[float] = []
	for i: int in range(queue.size()):
		tiebreaks.append(rng.randf())

	# Sort by index so comparator always sees the same tiebreak for the same element.
	var indices: Array[int] = []
	for i: int in range(queue.size()):
		indices.append(i)
	indices.sort_custom(func(i: int, j: int) -> bool:
		var spd_a: int = queue[i].actor.effective_speed()
		var spd_b: int = queue[j].actor.effective_speed()
		if spd_a != spd_b:
			return spd_a > spd_b
		return tiebreaks[i] > tiebreaks[j]
	)
	var sorted: Array[Action] = []
	for i: int in indices:
		sorted.append(queue[i])

	for action: Action in sorted:
		if action.actor.is_fainted():
			continue

		if action.move != null:
			move_used.emit(
				action.actor.config.display_name,
				action.move.display_name,
				action.target.config.display_name
			)

		var result: ActionResult = _ActionResolver.apply(action, state, rng)

		if result.damage > 0:
			damage_dealt.emit(
				action.target.config.display_name,
				result.damage,
				action.target.current_hp,
				action.target.max_hp()
			)

		if result.healed > 0:
			hp_restored.emit(
				action.actor.config.display_name,
				result.healed,
				action.actor.current_hp,
				action.actor.max_hp()
			)

		if result.stat_name != "":
			var affected: MonsterInstance
			if result.stat_delta > 0:
				affected = action.actor
			else:
				affected = action.target
			stat_changed.emit(
				affected.config.display_name,
				result.stat_name,
				result.stat_delta,
				affected.get_stat_stage(result.stat_name)
			)

		if result.fainted:
			monster_fainted.emit(action.target.config.display_name)
			break
