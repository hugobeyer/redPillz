# This script is for movement (attached to the Player (CharacterBody3D))
extends CharacterBody3D

@export var health: float = 1000.0
@export var SPEED: float = 6.0
@export var ROTATION_SPEED: float = 10.0
@export_range(0.1, 1.0) var SHOOTING_THRESHOLD: float = 0.8
@export var camera: Camera3D = null
@onready var machine_gun = get_node("MachineGun")
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Damage handling variables
@export var invulnerability_time: float = 0.5  # Time in seconds of invulnerability after being hit
var is_invulnerable: bool = false
var current_health: float

var thumbstick: Node = null
var input_vector: Vector2 = Vector2.ZERO
var is_shooting: bool = false
var has_left_deadzone: bool = false

@export var acceleration: float = 15.0  # How quickly the player reaches max speed
@export var deceleration: float = 10.0  # How quickly the player comes to a stop
@export var air_control: float = 0.3    # How much control the player has while in the air

# Current movement velocity (separate from gravity)
var movement_velocity: Vector3 = Vector3.ZERO

@export var use_mouse_aim: bool = true
@export var knockback_resistance: float = 0.3  # Reduced from 0.5 to 0.3 for more knockback impact
@export var knockback_recovery_speed: float = 8.0  # Reduced from 15.0 to 8.0 for longer knockback effect

var knockback_velocity: Vector3 = Vector3.ZERO

@onready var wobble_mesh = $WobbleEffect/PlayerMesh
@onready var wobble = $WobbleEffect

@onready var dash_trail_scene = preload("res://_scenes/dash_particles.tscn")

@export_group("Dash Settings")
@export var dash_enabled: bool = true
@export var dash_force: float = 30.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export var dash_input_buffer_time: float = 0.2  # Time window to buffer dash input
@export_range(0.0, 1.0) var dash_air_control: float = 0.3  # How much control during dash
@export var dash_trail_enabled: bool = true

# Add to your variables
var can_dash: bool = true
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var dash_input_buffer_timer: float = 0.0

var dash_trail: Node3D = null
var trail_points: Array[Vector3] = []
const MAX_TRAIL_POINTS = 20

func _ready():
    # Test dash trail scene loading
    if dash_trail_scene:
        print("Dash trail scene loaded successfully")
    else:
        push_error("Failed to load dash trail scene")
    
    current_health = health
    thumbstick = get_node("../../MainHUD/ControllerCanvas/MovementJoystick")
    if not thumbstick:
        push_error("Thumbstick not found. Make sure it's properly added to the scene.")
    else:
        thumbstick.connect("on_trigger", Callable(self, "_on_thumbstick_trigger"))
        thumbstick.connect("on_pressed", Callable(self, "_on_thumbstick_pressed"))
        thumbstick.connect("on_released", Callable(self, "_on_thumbstick_released"))

    if machine_gun:
        if not machine_gun.is_connected("weapon_fired", Callable(self, "_on_machine_gun_fired")):
            machine_gun.connect("weapon_fired", Callable(self, "_on_machine_gun_fired"))
        if not machine_gun.is_connected("recoil_reset", Callable(self, "_on_machine_gun_recoil_reset")):
            machine_gun.connect("recoil_reset", Callable(self, "_on_machine_gun_recoil_reset"))

func _physics_process(delta):
    # Update dash timers
    if dash_cooldown_timer > 0:
        dash_cooldown_timer -= delta
        if dash_cooldown_timer <= 0:
            dash_cooldown_timer = 0
            can_dash = true
    
    if dash_input_buffer_timer > 0:
        dash_input_buffer_timer -= delta
    
    # Handle dash state
    if is_dashing:
        dash_timer -= delta
        if dash_timer <= 0:
            end_dash()
        else:
            # Apply additional dash force during dash
            movement_velocity += dash_direction * (dash_force * delta)
    
    # Check for dash input
    if Input.is_action_just_pressed("dash"):
        dash_input_buffer_timer = dash_input_buffer_time
    
    if dash_input_buffer_timer > 0 and can_dash and dash_enabled and not is_dashing:
        start_dash()
    
    # Normal movement when not dashing
    handle_movement(delta)
    handle_rotation(delta)
    
    # Apply gravity
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif velocity.y < 0:
        velocity.y = 0
    
    # Handle knockback recovery
    if knockback_velocity.length() > 0:
        # Apply knockback directly to movement_velocity instead of velocity
        movement_velocity += knockback_velocity * delta
        knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, knockback_recovery_speed * delta * knockback_velocity.length())
        if knockback_velocity.length() < 0.1:
            knockback_velocity = Vector3.ZERO
    
    # Apply movement velocity to actual velocity
    velocity.x = movement_velocity.x
    velocity.z = movement_velocity.z
    
    move_and_slide()

func handle_movement(delta: float):
    # Get input and normalize immediately to ensure consistent speed
    var move_vector = Vector2.ZERO
    if Input.is_action_pressed("move_forward"):
        move_vector.y -= 1
    if Input.is_action_pressed("move_backward"):
        move_vector.y += 1
    if Input.is_action_pressed("move_left"):
        move_vector.x -= 1
    if Input.is_action_pressed("move_right"):
        move_vector.x += 1
    
    # Get the desired direction relative to the camera
    var cam_basis = camera.global_transform.basis
    var direction = Vector3.ZERO
    
    if move_vector.length() > 0:
        # Normalize input vector first
        move_vector = move_vector.normalized()
        
        # Convert to 3D space relative to camera
        direction = (cam_basis * Vector3(move_vector.x, 0, move_vector.y))
        # Ensure movement is horizontal and normalized
        direction.y = 0
        direction = direction.normalized()
    
    # Calculate target velocity
    var target_velocity = direction * SPEED
    
    # Calculate acceleration rate based on whether we're on the ground
    var current_acceleration = acceleration
    if not is_on_floor():
        current_acceleration *= air_control
    
    if direction.length() > 0:
        # Accelerate towards target velocity
        movement_velocity = movement_velocity.move_toward(target_velocity, current_acceleration * delta)
    else:
        # Decelerate when no input
        movement_velocity = movement_velocity.move_toward(Vector3.ZERO, deceleration * delta)
    
    # Apply movement velocity
    velocity.x = movement_velocity.x
    velocity.z = movement_velocity.z

func handle_rotation(delta: float):
    if use_mouse_aim:
        _handle_mouse_aim()
    else:
        # Original thumbstick rotation
        if input_vector.length() > 0:
            var cam_basis = camera.global_transform.basis
            var aim_direction = (cam_basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
            var target_rotation = atan2(aim_direction.x, aim_direction.z)
            var new_rotation = lerp_angle(rotation.y, target_rotation, ROTATION_SPEED * delta)
            rotation.y = new_rotation

func _handle_mouse_aim():
    var mouse_pos = get_viewport().get_mouse_position()
    
    if camera:
        var from = camera.project_ray_origin(mouse_pos)
        var to = from + camera.project_ray_normal(mouse_pos) * 1000
        
        # Create space state for raycasting
        var space_state = get_world_3d().direct_space_state
        var query = PhysicsRayQueryParameters3D.create(from, to)
        query.collide_with_areas = false
        query.collide_with_bodies = true
        
        var result = space_state.intersect_ray(query)
        var hit_point
        
        if result:
            hit_point = result.position
        else:
            # Fallback to plane intersection if no collision
            var plane = Plane(Vector3.UP, global_position.y)
            hit_point = plane.intersects_ray(from, to)
        
        if hit_point:
            # Calculate direction to target
            var direction = (hit_point - global_position).normalized()
            # Calculate the angle in the XZ plane
            var target_rotation = atan2(direction.x, direction.z)
            # Smoothly rotate to the target angle
            rotation.y = lerp_angle(rotation.y, target_rotation, ROTATION_SPEED * get_process_delta_time())

func start_shooting():
    if not is_shooting and machine_gun:
        is_shooting = true
        var direction = get_shoot_direction()
        machine_gun.trigger_pressed(direction)

func stop_shooting():
    if is_shooting and machine_gun:
        is_shooting = false
        machine_gun.trigger_released()

func _on_thumbstick_trigger(stick_vector: Vector2, _elapsed: float):
    # Skip thumbstick shooting logic if using mouse
    if use_mouse_aim:
        return
        
    input_vector = stick_vector
    if input_vector.length() > thumbstick.deadzone_radius_percentage:
        has_left_deadzone = true
        if input_vector.length() > SHOOTING_THRESHOLD:
            start_shooting()
        else:
            stop_shooting()
    elif has_left_deadzone and input_vector.length() <= thumbstick.deadzone_radius_percentage:
        has_left_deadzone = false
        stop_shooting()

func _on_thumbstick_pressed(_event):
    if use_mouse_aim:
        return
    has_left_deadzone = false

func _on_thumbstick_released(_position: Vector2, _elapsed: float) -> void:
    if use_mouse_aim:
        return
    input_vector = Vector2.ZERO
    stop_shooting()
    has_left_deadzone = false

func _input(event):
    if use_mouse_aim:
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                start_shooting()
            else:
                stop_shooting()
    
    # Keep your existing fire action
    if event.is_action_pressed("fire"):
        if machine_gun and machine_gun.has_method("shoot2"):
            machine_gun.shoot2()

func _on_machine_gun_fired(recoil_force_forward: Vector3) -> void:
    velocity += recoil_force_forward * machine_gun.get_recoil_value()

func _on_machine_gun_recoil_reset() -> void:
    pass  # Add recoil reset handling if needed

func get_shoot_direction() -> Vector2:
    if use_mouse_aim:
        # Get forward direction when using mouse
        return Vector2(-global_transform.basis.z.x, -global_transform.basis.z.z).normalized()
    else:
        # Original thumbstick direction
        return input_vector.normalized()

func handle_recoil(delta: float):
    if machine_gun:
        machine_gun.handle_recoil(delta)

func start_recoil_recovery():
    if machine_gun:
        machine_gun.start_recoil_recovery()

func apply_knockback(knockback: Vector3) -> void:
    # print("Player received knockback: ", knockback)
    
    # Reduce knockback based on resistance
    knockback *= (1.0 - knockback_resistance)
    
    # Set the initial knockback (make it stronger initially)
    knockback_velocity = knockback * 2.0  # Multiply for stronger initial impulse

func take_damage(amount: float, attacker_position: Vector3 = Vector3.ZERO) -> void:
    if is_invulnerable:
        return
        
    current_health -= amount
    
    # Update health circle
    var health_percent = current_health / health
    if $HealthCircle:
        $HealthCircle.set_progress(health_percent)
    
    # Calculate knockback direction from attacker
    if attacker_position != Vector3.ZERO:
        var knockback_direction = (global_position - attacker_position).normalized()
        knockback_direction.y = 0.2  # Add slight upward component
        apply_knockback(knockback_direction * 10.0)  # Adjust multiplier for desired knockback strength
    
    # Start invulnerability period
    is_invulnerable = true
    
    # Visual feedback
    modulate_player(true)
    
    # Create timer for invulnerability duration
    get_tree().create_timer(invulnerability_time).connect("timeout", Callable(self, "_on_invulnerability_end"))
    
    if current_health <= 0:
        die()

func _on_invulnerability_end() -> void:
    is_invulnerable = false
    modulate_player(false)

func modulate_player(is_hit: bool) -> void:
    if is_hit:
        # Create a new tween for shader effect
        var tween = create_tween()
        tween.tween_method(set_hit_effect, 0.0, 1.0, 0.5)
        tween.tween_method(set_hit_effect, 1.0, 0.0, 0.2)
        
        # Apply wobble effect
        if wobble:
            wobble.apply_hit_wobble(Vector3.FORWARD)

func set_hit_effect(value: float) -> void:
    if wobble_mesh:
        wobble_mesh.set_instance_shader_parameter("lerp_wave", value)

func die() -> void:
    # Implement death behavior
    # For example:
    # - Play death animation
    # - Show game over screen
    # - Restart level
    # - etc.
    pass

func get_movement_input() -> Vector3:
    var cam_basis = camera.global_transform.basis
    var move_vector = Vector2.ZERO
    
    # Get input
    if Input.is_action_pressed("move_forward"): move_vector.y -= 1
    if Input.is_action_pressed("move_backward"): move_vector.y += 1
    if Input.is_action_pressed("move_left"): move_vector.x -= 1
    if Input.is_action_pressed("move_right"): move_vector.x += 1
    
    if move_vector.length() > 0:
        move_vector = move_vector.normalized()
        var direction = (cam_basis * Vector3(move_vector.x, 0, move_vector.y))
        direction.y = 0
        return direction.normalized()
    return Vector3.ZERO

func start_dash():
    print("Starting dash...")
    is_dashing = true
    can_dash = false
    dash_timer = dash_duration
    dash_cooldown_timer = dash_cooldown
    dash_input_buffer_timer = 0
    
    # Get current movement direction
    var input_dir = get_movement_input()
    if input_dir.length() > 0:
        dash_direction = input_dir.normalized()
        # Add dash velocity to current movement instead of replacing
        movement_velocity += dash_direction * dash_force
    else:
        # Use facing direction if no movement input
        dash_direction = -transform.basis.z.normalized()
        # Add dash velocity to current movement
        movement_velocity += dash_direction * dash_force
    
    # Create dash effect
    if dash_trail_enabled:
        create_dash_trail()

func end_dash():
    print("Ending dash...")
    is_dashing = false
    # Don't reset can_dash here, let the cooldown timer handle it
    if dash_trail and dash_trail.has_method("stop_trail"):
        print("Stopping dash trail...")
        dash_trail.stop_trail()

func create_dash_trail():
    print("Creating dash trail...")
    # Create new trail if none exists
    if not dash_trail:
        dash_trail = dash_trail_scene.instantiate()
        if dash_trail.has_method("set_player"):
            print("Setting player for dash trail...")
            dash_trail.set_player(self)
        else:
            push_error("Dash trail missing set_player method")
    
    # Start the trail
    if dash_trail.has_method("start_trail"):
        print("Starting dash trail...")
        dash_trail.start_trail()
    else:
        push_error("Dash trail missing start_trail method")
