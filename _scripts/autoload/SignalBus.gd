extends Node

# Enemy signals
signal enemy_killed(enemy: Node)
# signal enemy_spawned(enemy: Node)
# signal enemy_damaged(enemy: Node, damage: float)

# # Player signals
# signal player_damaged(damage: float)
# signal player_healed(amount: float)
# signal player_died
# signal player_respawned

# # Weapon signals
# signal weapon_fired(weapon: Node)
# signal weapon_reloaded(weapon: Node)
# signal ammo_changed(current: int, max: int)

# # Game state signals
# signal wave_started(wave_number: int)
# signal wave_completed(wave_number: int)
# signal game_paused
# signal game_resumed
# signal game_over
# signal game_restarted

# # UI signals
# signal score_changed(new_score: int)
# signal health_changed(current: float, max: float) 