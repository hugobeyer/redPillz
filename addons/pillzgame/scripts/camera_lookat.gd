extends Camera3D

@export var target: Node3D  # The parent node containing target children
@export var smooth_speed: float = 2.0  # Smoothing factor for camera movement
@export var offset: Vector3 = Vector3(0, 5, 10)  # Camera offset from target
@export var look_ahead_factor: float = 0.5  # How much the camera looks ahead of the target's movement
@export var target_switch_interval: float = 5.0  # Time in seconds before switching to the next target
@export var use_average_target: bool = false  # Toggle to use average of all targets
@export var average_update_interval: float = 0.5  # How often to update the average target position

var velocity: Vector3 = Vector3.ZERO
var current_target: Node3D
var target_children: Array = []  # Untyped array
var current_target_index: int = 0
var time_since_last_switch: float = 0.0
var transition_progress: float = 1.0  # Progress of transition between targets
var previous_position: Vector3 = Vector3.ZERO
var previous_look_at: Vector3 = Vector3.ZERO
var average_target_position: Vector3 = Vector3.ZERO
var time_since_last_average_update: float = 0.0

func _ready():
    if target:
        update_target_children()
    previous_position = global_transform.origin
    previous_look_at = global_transform.origin + Vector3.FORWARD
    update_average_target_position()

func update_target_children():
    target_children.clear()
    for child in target.get_children():
        if child is Node3D:
            target_children.append(child as Node3D)  # Explicit cast
    if not target_children.is_empty():
        current_target = target_children[0]

func _physics_process(delta):
    time_since_last_switch += delta
    time_since_last_average_update += delta
    
    if use_average_target and time_since_last_average_update >= average_update_interval:
        update_average_target_position()
        time_since_last_average_update = 0.0
    elif not use_average_target and time_since_last_switch >= target_switch_interval:
        switch_to_next_target()
    
    update_camera_position(delta)

func switch_to_next_target():
    if not target_children.is_empty():
        current_target_index = (current_target_index + 1) % target_children.size()
        current_target = target_children[current_target_index]
        time_since_last_switch = 0.0
        transition_progress = 0.0
        previous_position = global_transform.origin
        previous_look_at = global_transform.basis.z * -10 + global_transform.origin

func update_average_target_position():
    if target_children.is_empty():
        return
    var sum_position = Vector3.ZERO
    var valid_targets = 0
    for child in target_children:
        if is_instance_valid(child):
            sum_position += child.global_position
            valid_targets += 1
    if valid_targets > 0:
        average_target_position = sum_position / valid_targets

func update_camera_position(delta):
    var target_pos = average_target_position if use_average_target else current_target.global_position
    var desired_position = target_pos + offset
    
    if current_target is CharacterBody3D:
        velocity = velocity.lerp(current_target.velocity, delta * smooth_speed)
        desired_position += velocity * look_ahead_factor
    
    var look_target = target_pos + velocity * look_ahead_factor
    
    transition_progress = min(transition_progress + delta * smooth_speed, 1.0)
    
    var interpolated_position = previous_position.lerp(desired_position, transition_progress)
    var interpolated_look_at = previous_look_at.lerp(look_target, transition_progress)
    
    global_transform.origin = interpolated_position
    look_at(interpolated_look_at, Vector3.UP)
    
    previous_position = global_transform.origin
    previous_look_at = interpolated_look_at

func set_new_target(new_target: Node3D):
    target = new_target
    update_target_children()
    current_target_index = 0
    time_since_last_switch = 0.0
    transition_progress = 0.0
    update_average_target_position()
