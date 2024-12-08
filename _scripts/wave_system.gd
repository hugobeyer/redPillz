# wave_system.gd
extends Node3D

class_name WaveSystem

#signal wave_completed  # Add this line to define the signal

# @export var player_path: NodePath  # Commented out if not immediately necessary

# Comment out or remove any references to wave_resource

# Add a basic enemy scene
@export var enemy_scene: PackedScene

var current_wave_index = -1
var active_enemies = 0
var player: CharacterBody3D
var main_scene: Node  # Reference to the main scene
var waves = []  # Add this line at the beginning of your script

const WaveResourceScript = preload("res://_scripts/wave_resource.gd")

# @export var wave_resource: Node = WaveResourceScript.new()
func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("Player node not found in 'player' group!")
		return
	main_scene = get_tree().current_scene

	if waves.is_empty():
		#push_error("No waves defined!")
		return

	start_waves()

func start_waves():
	current_wave_index = -1
	start_next_wave()

func start_next_wave():
	current_wave_index += 1
	if current_wave_index < waves.size():
		var wave = waves[current_wave_index]
		if wave is WaveResourceScript:
			_start_wave(wave)
		else:
			push_error("Invalid wave resource at index " + str(current_wave_index))
	else:
		emit_signal("all_waves_completed")

func _start_wave(wave: WaveResourceScript):
	for i in range(wave.enemy_scenes.size()):
		for j in range(wave.enemy_counts[i]):
			await get_tree().create_timer(wave.spawn_interval).timeout
			var spawn_point = _get_spawn_point_around_player(wave.min_spawn_distance, wave.max_spawn_distance)
			spawn_enemy(wave.enemy_scenes[i], spawn_point, wave.resource)

func _get_spawn_point_around_player(min_distance: float, max_distance: float) -> Vector3:
	var random_angle = randf() * TAU  # Random angle in radians
	var random_distance = randf_range(min_distance, max_distance)
	var offset = Vector3(
		cos(random_angle) * random_distance,
		0,  # Assuming you want enemies to spawn at the same Y level as the player
		sin(random_angle) * random_distance
	)
	return player.global_position + offset

# Place the spawn_enemy function here
func spawn_enemy(new_enemy_scene: PackedScene, spawn_point: Vector3, wave: WaveResourceScript):  # Changed Resource to WaveResource
	var enemy = new_enemy_scene.instantiate()
	main_scene.add_child(enemy)  # Add to the main scene
	enemy.global_position = spawn_point
	
	# Add the enemy to the "enemies" group
	enemy.add_to_group("enemies")
	
	# Apply wave-specific customizations
	if enemy.has_method("set_health"):
		enemy.set_health(enemy.health * wave.enemy_health_multiplier)
	
	if wave.has("enemy_size_multiplier"):
		enemy.scale *= wave.enemy_size_multiplier
	
	if enemy.has_method("set_knockback_resistance"):
		enemy.set_knockback_resistance(wave.enemy_knockback_resistance)
	if wave.enemy_material_overlay:
		# Assume the enemy has a MeshInstance child named "Mesh"
		enemy.get_node("Mesh").material_overlay = wave.enemy_material_overlay
	
	if wave.enemy_can_swing_sword and enemy.has_method("enable_sword_swing"):
		enemy.enable_sword_swing(wave.enemy_swing_speed)
	
	if enemy.has_method("set_target"):
		enemy.set_target(player)
	
	active_enemies += 1

func on_enemy_defeated():
	active_enemies -= 1
	if active_enemies == 0 and current_wave_index < waves.size():
		emit_signal("wave_completed")
		var current_wave = waves[current_wave_index]
		if current_wave is WaveResourceScript:
			await get_tree().create_timer(current_wave.wave_interval).timeout
		start_next_wave()

signal wave_completed
signal all_waves_completed
