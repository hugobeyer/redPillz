@tool
extends CharacterBody3D

enum LookState {
    FORWARD,
    SPOT,
    TRANSITIONING,
    PLAYER,
    RANDOM
}

# Movement - All used
@export var base_speed: float = 4.0          # Used in apply_movement()
@export var hover_radius: float = 12.0       # Used in wander()
@export var max_distance_from_player: float = 16.0  # Used in wander()

# Height - All used
@export var min_height: float = 2.0          # Used in enforce_height_limits()
@export var max_height: float = 4.0          # Used in enforce_height_limits()
@export var preferred_height: float = 3.0     # Used in wander() and _ready()
@export var height_wobble_amount: float = 0.3 # Used in wander()

# Noise Movement - All used
@export var noise_influence: float = 0.25     # Used in wander()
@export var noise_speed: float = 0.15         # Used in wander()
@export var second_noise_influence: float = 0.15  # Used in wander()

# Smoothing - All used
@export var position_smoothing: float = 0.08  # Used in wander() and apply_movement()
@export var rotation_smoothing: float = 4.0   # Used in face_direction()
@export var time_scale: float = 0.5          # Used in _physics_process()

# Looking Behavior - All used
@export var head_turn_speed: float = 1.8     # Used in update_looking_behavior()
@export var max_head_angle: float = 0.7      # Used in calculate_look_rotation()
@export var min_look_time: float = 2.2       # Used in choose_new_look_target()
@export var max_look_time: float = 4.5       # Used in choose_new_look_target()
@export var look_forward_chance: float = 0.35 # Used in choose_new_look_target()
@export var look_player_chance: float = 0.25  # Used in choose_new_look_target()
@export var look_random_chance: float = 0.20  # Used in choose_new_look_target()
@export var look_ahead_strength: float = 5.0  # Used in update_looking_behavior()

# Internal variables
var player: Node3D
var noise: FastNoiseLite
var second_noise: FastNoiseLite
var noise_position: Vector2 = Vector2.ZERO
var second_noise_position: Vector2 = Vector2.ZERO
var current_velocity: Vector3
var target_position: Vector3
var is_initialized: bool = false

# Looking variables
var current_look_state: LookState = LookState.FORWARD
var current_look_point: Vector3
var look_timer: float = 0.0
var target_look_rotation: Vector3
var current_look_rotation: Vector3
var is_looking_forward: bool = true
var time_in_state: float = 0.0
var time_passed: float = 0.0

@onready var head: Node3D = $BuddyHead

func _ready():
    if Engine.is_editor_hint():
        return
        
    # Initialize noise first
    noise = FastNoiseLite.new()
    noise.seed = randi()
    noise.frequency = 0.5
    noise.fractal_octaves = 2
    
    second_noise = FastNoiseLite.new()
    second_noise.seed = randi() + 100
    second_noise.frequency = 0.3
    second_noise.fractal_octaves = 1
    
    # Wait for scene tree to be ready
    await get_tree().process_frame
    await get_tree().process_frame
    
    # Get player reference
    player = get_parent().get_node("Player")
    if not player:
        push_warning("Player node not found!")
        return
        
    # Initialize position
    if is_inside_tree():
        global_position = player.global_position + Vector3(0, preferred_height, 0)
        target_position = global_position
        is_initialized = true

func _physics_process(delta):
    if Engine.is_editor_hint() or not player or not is_initialized:
        return

    time_passed += delta * time_scale
    wander(delta)
    update_looking_behavior(delta)
    face_direction(delta)
    enforce_height_limits()

func wander(delta):
    # Update noise positions
    noise_position += Vector2(delta * noise_speed, delta * noise_speed * 0.8)
    second_noise_position += Vector2(delta * noise_speed * 0.3, delta * noise_speed * 0.25)
    
    # Get noise values and clamp them for more controlled movement
    var noise_x = clamp(noise.get_noise_2d(noise_position.x, 0.0), -0.7, 0.7)
    var noise_z = clamp(noise.get_noise_2d(0.0, noise_position.y), -0.7, 0.7)
    var second_x = clamp(second_noise.get_noise_2d(second_noise_position.x, 0.0), -0.7, 0.7)
    var second_z = clamp(second_noise.get_noise_2d(0.0, second_noise_position.y), -0.7, 0.7)
    
    # Combine noises with reduced influence
    var combined_x = noise_x * noise_influence + second_x * second_noise_influence
    var combined_z = noise_z * noise_influence + second_z * second_noise_influence
    
    # Calculate target position relative to player with smoother interpolation
    var target_offset = Vector3(combined_x * hover_radius, 0, combined_z * hover_radius)
    var ideal_position = player.global_position + target_offset
    ideal_position.y = preferred_height + noise.get_noise_2d(noise_position.x * 0.3, noise_position.y * 0.3) * height_wobble_amount
    
    # Smooth target position update
    target_position = target_position.lerp(ideal_position, position_smoothing)
    
    # If too far from player, smoothly return
    var distance_to_player = global_position.distance_to(player.global_position)
    if distance_to_player > max_distance_from_player:
        var return_position = player.global_position + target_offset.normalized() * max_distance_from_player
        return_position.y = preferred_height
        target_position = target_position.lerp(return_position, 0.1)
    
    apply_movement()

func apply_movement():
    # More stable velocity calculation
    var desired_velocity = (target_position - global_position)
    var speed_factor = clamp(desired_velocity.length() / 2.0, 0.0, 1.0)
    desired_velocity = desired_velocity.normalized() * base_speed * speed_factor
    
    # Smoother velocity interpolation
    current_velocity = current_velocity.lerp(desired_velocity, position_smoothing)
    
    # Use move_and_slide for physics-based movement
    velocity = current_velocity
    move_and_slide()

func update_looking_behavior(delta):
    look_timer -= delta
    time_in_state += delta
    
    if look_timer <= 0:
        choose_new_look_target()
    
    var desired_rotation = Vector3.ZERO
    
    match current_look_state:
        LookState.FORWARD:
            if current_velocity.length() > 0.1:
                var forward_point = global_position + current_velocity.normalized() * look_ahead_strength
                desired_rotation = calculate_look_rotation(forward_point)
        
        LookState.SPOT:
            desired_rotation = calculate_look_rotation(current_look_point)
        
        LookState.PLAYER:
            if player:
                desired_rotation = calculate_look_rotation(player.global_position)
        
        LookState.RANDOM:
            desired_rotation = calculate_look_rotation(current_look_point)
        
        LookState.TRANSITIONING:
            desired_rotation = calculate_look_rotation(current_look_point)
            if is_rotation_close_enough(current_look_rotation, desired_rotation):
                current_look_state = LookState.SPOT
    
    # Smooth head movement (only X and Y)
    current_look_rotation.x = lerp(current_look_rotation.x, desired_rotation.x, delta * head_turn_speed)
    current_look_rotation.y = lerp(current_look_rotation.y, desired_rotation.y, delta * head_turn_speed)
    
    if head:
        head.rotation.x = current_look_rotation.x
        head.rotation.y = current_look_rotation.y
        head.rotation.z = 0

func choose_new_look_target():
    time_in_state = 0.0
    var random_val = randf()
    
    if random_val < look_forward_chance:
        current_look_state = LookState.FORWARD
    elif random_val < look_forward_chance + look_player_chance:
        current_look_state = LookState.PLAYER
    elif random_val < look_forward_chance + look_player_chance + look_random_chance:
        current_look_state = LookState.RANDOM
        var random_radius = randf_range(8.0, 20.0)
        var random_angle = randf_range(-PI, PI)
        var random_height = randf_range(-2.0, 5.0)
        
        current_look_point = global_position + Vector3(
            cos(random_angle) * random_radius,
            random_height,
            sin(random_angle) * random_radius
        )
    else:
        var spot_radius = randf_range(10.0, 25.0)
        var spot_angle = randf_range(-PI, PI)
        var spot_height = randf_range(-1.0, 4.0)
        
        current_look_point = global_position + Vector3(
            cos(spot_angle) * spot_radius,
            spot_height,
            sin(spot_angle) * spot_radius
        )
        current_look_state = LookState.TRANSITIONING
    
    look_timer = randf_range(min_look_time, max_look_time)

func calculate_look_rotation(look_point: Vector3) -> Vector3:
    var to_target = look_point - global_position
    var rotation_vec = Vector3.ZERO
    
    rotation_vec.y = wrapf(
        atan2(-to_target.x, -to_target.z) - rotation.y,
        -PI,
        PI
    )
    
    rotation_vec.x = clamp(
        atan2(to_target.y, sqrt(to_target.x * to_target.x + to_target.z * to_target.z)),
        -max_head_angle,
        max_head_angle
    )
    
    return rotation_vec

func is_rotation_close_enough(current: Vector3, target: Vector3) -> bool:
    return (
        abs(current.x - target.x) < 0.1 and
        abs(current.y - target.y) < 0.1
    )

func face_direction(delta):
    if current_velocity.length() > 0.1:
        var target_rotation = atan2(-current_velocity.z, current_velocity.x)
        rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_smoothing)

func enforce_height_limits():
    var current_height = global_position.y
    if current_height < min_height:
        global_position.y = lerp(current_height, min_height, position_smoothing)
    elif current_height > max_height:
        global_position.y = lerp(current_height, max_height, position_smoothing)