## Stateless utility that computes the filtered action space for a monster.
## Reads active_conditions directly — MonsterInstance is not modified.
##
## Algorithm:
##   1. Start with monster.config.move_ids.
##   2. Scan active_conditions for injected moves; lazy-load into move_library.
##   3. If any condition has action_lock_move_id != "": return [locked_id] (first wins).
##   4. Build union of all action_denied_tags across all active conditions.
##   5. Remove moves whose move_tags intersect the denied set.
##   6. Return remaining Array[String].
##
## Auto-pass: if the result is empty, the caller should skip the actor's decision slot
## and emit EventBus.battle_turn_denied for UI feedback.

const _ConditionConfig = preload("res://schema/battle/ConditionConfig.gd")
const _ConfigLoader = preload("res://engine/core/ConfigLoader.gd")


static func build_available(
	monster: MonsterInstance,
	move_library: Dictionary[String, MoveConfig]
) -> Array[String]:
	# Step 1: seed candidates from the monster's known move list
	var candidates: Array[String] = []
	candidates.assign(monster.config.move_ids)

	# Step 2: scan conditions for injected moves and lock-in flags
	var lock_move_id: String = ""
	var denied_tags: Array[String] = []

	for inst: Object in monster.active_conditions:
		var cfg: ConditionConfig = inst.get("config") as ConditionConfig
		if cfg == null:
			continue

		# Injected move: add to pool (lazy-load into library)
		if cfg.action_injected_move_id != "":
			var injected_id: String = cfg.action_injected_move_id
			if not candidates.has(injected_id):
				candidates.append(injected_id)
			if not move_library.has(injected_id):
				var loaded: MoveConfig = ConfigLoader.load_move(injected_id)
				if loaded != null:
					move_library[injected_id] = loaded

		# Lock-in: first match wins
		if lock_move_id == "" and cfg.action_lock_move_id != "":
			lock_move_id = cfg.action_lock_move_id

		# Denied tags: accumulate union
		for tag: String in cfg.action_denied_tags:
			if not denied_tags.has(tag):
				denied_tags.append(tag)

	# Step 3: lock-in overrides everything
	if lock_move_id != "":
		var locked: Array[String] = []
		locked.append(lock_move_id)
		return locked

	# Step 4-5: filter out moves with denied tags
	if denied_tags.is_empty():
		return candidates

	var result: Array[String] = []
	for move_id: String in candidates:
		var move: MoveConfig = move_library.get(move_id, null) as MoveConfig
		if move == null:
			result.append(move_id)
			continue
		var blocked: bool = false
		for tag: String in move.move_tags:
			if denied_tags.has(tag):
				blocked = true
				break
		if not blocked:
			result.append(move_id)

	return result
