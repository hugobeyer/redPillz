#wave_resource.gd
@tool
extends Node

class Wave:
	var enemy_count: int = 1
	var size_multiplier: float = 1.0
	var spawn_interval: float = 1.0
	var _difficulty: int = 0
	var enemy_scenes: Array[PackedScene] = []
	var enemy_counts: Array[int] = []

	func _init(p_enemy_count = 1, p_size_multiplier = 1.0, p_difficulty = 0, p_spawn_interval = 1.0):
		enemy_count = p_enemy_count
		size_multiplier = p_size_multiplier
		_difficulty = p_difficulty
		spawn_interval = p_spawn_interval

	func get_difficulty():
		return _difficulty

	func set_difficulty(value):
		_difficulty = value

@export var enemy_scene: PackedScene  # Temporary: Use a single enemy scene

# func add_wave(wave: Wave):
#     if wave is Wave:
#         waves.append(wave)

# func remove_wave(index: int):
#     if index >= 0 and index < waves.size():
#         waves.remove_at(index)

# func get_wave(index: int) -> Wave:
#     if index >= 0 and index < waves.size():
#         return waves[index]
#     return null
