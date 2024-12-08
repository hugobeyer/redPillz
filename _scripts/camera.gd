extends Camera3D

@export var camera_offset: Vector3 = Vector3(55, 75, 44)
@export var max_offset: float = 20.0
@export_range(0, 1, 0.01) var attraction_strength: float = 0.6
@export_range(0, 1, 0.01) var damping: float = 0.5
@export_range(0, 1, 0.01) var blend_factor: float = 0.5
@export_range(0, 1, 0.01) var look_adjust_strength: float = 0.25
@export_range(0, 1, 0.01) var enemies_average_smoothing: float = 0.5
@export var player_y_offset: float = -15.0

# Camera Shake Parameters
@export_group("Camera Shake")
@export var shake_decay: float = 0.95
@export var shake_max_offset: float = 0.5
@export var shake_max_roll: float = 3.0
@export_range(0, 5) var recoil_shake_intensity: float = 0.3
@export_range(0.1, 5.0) var shake_falloff_time: float = 0.3

var camera_velocity: Vector3 = Vector3.ZERO
var smoothed_enemies_average: Vector3 = Vector3.ZERO
@onready var player_pos: CharacterBody3D = get_parent()

var shake_strength: float = 0.0
var shake_offset: Vector3 = Vector3.ZERO
var shake_rotation: float = 0.0
var noise = FastNoiseLite.new()
var noise_pos: float = 0.0

var current_velocity := Vector3.ZERO

var target_shake_strength: float = 0.0
var shake_lerp_speed: float = 5.0  # Adjust this to control lerp speed

@export_range(0.0, 1.0) var smoothness: float = 0.9

func _ready():
	smoothed_enemies_average = player_pos.global_position
	
	if not player_pos:
		player_pos = get_parent()
		if not player_pos:
			push_error("Player node not found. Please assign it in the editor or ensure the path is correct.")

	# Initialize noise for camera shake
	noise.seed = randi()
	noise.frequency = 0.5

func _process(delta):
	if player_pos:
		update_camera_position(delta)
		apply_camera_shake(delta)

func update_camera_position(delta):
	var adjusted_player_pos = player_pos.global_position + Vector3(0, player_y_offset, 0)
	var player_target_position = adjusted_player_pos + camera_offset
	
	var enemies_average = calculate_enemies_average(delta)
	smoothed_enemies_average = smoothed_enemies_average.lerp(enemies_average, delta * (enemies_average_smoothing * 20.0))
	var blended_target_position = player_target_position.lerp(smoothed_enemies_average + camera_offset, blend_factor)
	apply_camera_movement(blended_target_position, delta)
	
	var look_blend = blend_factor * look_adjust_strength
	var look_target = adjusted_player_pos.lerp(smoothed_enemies_average, look_blend)
	look_at(look_target, Vector3.UP)

func calculate_enemies_average(_delta: float) -> Vector3:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return player_pos.global_position
	
	var sum = Vector3.ZERO
	for enemy in enemies:
		sum += enemy.global_position
	return sum / enemies.size()

func apply_camera_movement(target_position: Vector3, delta: float):
	var direction_to_target = target_position - global_position
	var distance_to_target = direction_to_target.length()
	
	if distance_to_target > max_offset:
		direction_to_target = direction_to_target.normalized() * max_offset * delta
		target_position = global_position + direction_to_target
	
	var force = direction_to_target * (attraction_strength * 16)
	camera_velocity += force * delta
	camera_velocity = camera_velocity.lerp(Vector3.ZERO, (damping * 4.0) * delta)
	global_position += camera_velocity * delta

func add_shake(strength: float):
	# Only add shake if strength is significant
	if strength > 0.001:  # Add minimum threshold
		target_shake_strength = min(target_shake_strength + strength, 1.0)

func apply_camera_shake(delta: float):
	# Only process shake if it's significant
	if target_shake_strength > 0.001:  # Add minimum threshold
		shake_strength = lerp(shake_strength, target_shake_strength, shake_lerp_speed * delta)
		
		if shake_strength > 0.001:  # Check if shake is still significant
			noise_pos += delta * 100.0
			
			# Calculate shake offset
			var shake_x = noise.get_noise_2d(noise_pos, 0.0) * shake_strength * shake_max_offset
			var shake_y = noise.get_noise_2d(noise_pos, 100.0) * shake_strength * shake_max_offset
			shake_offset = Vector3(shake_x, shake_y, 0)
			
			# Calculate shake rotation
			shake_rotation = noise.get_noise_2d(noise_pos, 200.0) * shake_strength * shake_max_roll
			
			# Apply shake
			h_offset = shake_offset.x
			v_offset = shake_offset.y
			rotation_degrees.z = shake_rotation
			
			# Use falloff_time to calculate decay rate
			var decay_rate = 1.0 / shake_falloff_time
			target_shake_strength = lerp(target_shake_strength, 0.0, decay_rate * delta)
			
			# Force reset when very small
			if target_shake_strength < 0.001:
				reset_shake()
		else:
			reset_shake()
	else:
		reset_shake()

func reset_shake():
	target_shake_strength = 0.0
	shake_strength = 0.0
	h_offset = 0.0
	v_offset = 0.0
	rotation_degrees.z = 0.0

func _physics_process(delta):
	var target_pos = global_position
	var new_pos = global_position.lerp(target_pos, 1.0 - pow(smoothness, delta * 50))
	global_position = new_pos
