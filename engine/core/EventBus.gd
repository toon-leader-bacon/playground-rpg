extends Node
## Central signal bus. Append-only — never rename or remove a signal.
## All cross-system communication goes through here.

# --- Battle signals ---
signal battle_started(player_name: String, enemy_name: String)
signal battle_turn_started(turn_num: int, player_name: String, player_hp: int, enemy_name: String, enemy_hp: int)
signal battle_move_used(user_name: String, move_name: String, target_name: String)
signal battle_damage_dealt(target_name: String, amount: int, remaining_hp: int, max_hp: int)
signal battle_hp_restored(target_name: String, amount: int, new_hp: int, max_hp: int)
signal battle_stat_changed(target_name: String, stat: String, delta: int, total_stage: int)
signal battle_monster_fainted(monster_name: String)
signal battle_ended(winner_name: String, loser_name: String, turn_count: int)
signal battle_waiting_for_input(actor_id: String, available_moves: Array)
signal battle_combatants_initialized(player_name: String, player_max_hp: int, enemy_name: String, enemy_max_hp: int)
signal battle_2v2_initialized(p0_name: String, p0_max_hp: int, p1_name: String, p1_max_hp: int, e0_name: String, e0_max_hp: int, e1_name: String, e1_max_hp: int)
signal battle_turn_advanced(turn_num: int)
signal battle_needs_target(actor_id: String, valid_target_ids: Array[String])
signal battle_damage_dealt_keyed(actor_id: String, amount: int, remaining_hp: int, max_hp: int)
signal battle_hp_restored_keyed(actor_id: String, amount: int, new_hp: int, max_hp: int)
signal battle_nvm_initialized(player_names: Array, player_max_hps: Array, enemy_names: Array, enemy_max_hps: Array)
signal battle_gauge_updated(actor_id: String, value: float)
signal battle_action_started(actor_id: String)
