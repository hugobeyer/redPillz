# This script is for movement (attached to the Player (CharacterBody3D))
extends CharacterBody3D

@export var health: float = 1000.0
@export var SPEED: float = 6.0
@export var ROTATION_SPEED: float = 10.0
@export_range(0.1, 1.0) var SHOOTING_THRESHOLD: float = 0.8
@export var camera: Camera3D = null
@onready var Weapon = get_node("Weapon")
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
@export var knockback_resistance: float = 0.5
@export var knockback_recovery_speed: float = 15.0  # Increased recovery speed

var knockback_velocity: Vector3 = Vector3.ZERO

func _ready():
    current_health = health
    thumbstick = get_node("../../MainHUD/ControllerCanvas/MovementJoystick")
    if not thumbstick:
        push_error("Thumbstick not found. Make sure it's properly added to the scene.")
    else:
        thumbstick.connect("on_trigger", Callable(self, "_on_thumbstick_trigger"))
        thumbstick.connect("on_pressed", Callable(self, "_on_thumbstick_pressed"))
        thumbstick.connect("on_released", Callable(self, "_on_thumbstick_released"))

    if Weapon:
        if not Weapon.is_connected("Weapon_fired", Callable(self, "_on_Weapon_fired")):
            Weapon.connect("Weapon_fired", Callable(self, "_on_Weapon_fired"))
        if not Weapon.is_connected("recoil_reset", Callable(self, "_on_Weapon_recoil_reset")):
            Weapon.connect("recoil_reset", Callable(self, "_on_Weapon_recoil_reset"))

func _physics_process(delta):
    handle_movement(delta)
    handle_rotation(delta)
    
    # Apply gravity
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif velocity.y < 0:
        velocity.y = 0
    
    # Handle knockback recovery
    if knockback_velocity.length() > 0:
        # Add knockback to movement instead of overriding
        velocity += knockback_velocity * delta  # Multiply by delta for frame-rate independence
        # Gradually reduce knockback (faster reduction)
        knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, knockback_recovery_speed * delta * knockback_velocity.length())
        
        # If knockback is very small, clear it
        if knockback_velocity.length() < 0.1:
            knockback_velocity = Vector3.ZERO
    
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
    
    # Normalize before applying any movement
    # This ensures diagonal movement isn't faster
    move_vector = move_vector.normalized()

    # Get the desired direction relative to the camera
    var cam_basis = camera.global_transform.basis
    var direction = Vector3.ZERO
    
    if move_vector.length() > 0:
        direction = (cam_basis * Vector3(move_vector.x, 0, move_vector.y)).normalized()
        direction.y = 0  # Ensure movement is horizontal
    
    # Calculate target velocity
    # Since direction is normalized, this will maintain consistent speed
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
        
        var plane = Plane(Vector3.UP, global_position.y)
        var hit_point = plane.intersects_ray(from, to)
        
        if hit_point:
            # Calculate direction to target
            var direction = (hit_point - global_position).normalized()
            # Calculate the angle in the XZ plane
            var target_rotation = atan2(direction.x, direction.z)
            # Smoothly rotate to the target angle
            rotation.y = lerp_angle(rotation.y, target_rotation, ROTATION_SPEED * get_process_delta_time())

func start_shooting():
    if not is_shooting and Weapon:
        is_shooting = true
        var direction = get_shoot_direction()
        Weapon.trigger_pressed(direction)

func stop_shooting():
    if is_shooting and Weapon:
        is_shooting = false
        Weapon.trigger_released()

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
        if Weapon and Weapon.has_method("shoot2"):
            Weapon.shoot2()

func _on_Weapon_fired(recoil_force_forward: Vector3) -> void:
    # Handle recoil by adjusting velocity or another method
    velocity += recoil_force_forward * Weapon.get_recoil_value()

func get_shoot_direction() -> Vector2:
    if use_mouse_aim:
        # Get forward direction when using mouse
        return Vector2(-global_transform.basis.z.x, -global_transform.basis.z.z).normalized()
    else:
        # Original thumbstick direction
        return input_vector.normalized()

func handle_recoil(delta: float):
    if Weapon:
        Weapon.handle_recoil(delta)

func start_recoil_recovery():
    if Weapon:
        Weapon.start_recoil_recovery()

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
    # You can implement visual feedback here
    # For example, changing the material's albedo color or transparency
    # This is just a placeholder - implement actual visual feedback based on your setup
    pass

func die() -> void:
    # Implement death behavior
    # For example:
    # - Play death animation
    # - Show game over screen
    # - Restart level
    # - etc.
    pass
