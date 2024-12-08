extends Node3D

@export_group("Spring Wobble Parameters")
@export var enable_wobble: bool = true
@export var spring_stiffness: float = 10.0    # How quickly it wants to return
@export var spring_damping: float = 1.0       # How much it resists oscillation
@export_range(0, 90) var max_rotation_degrees: float = 45.0
@export var hit_force: float = 5.0            # Added to control hit strength

var _angular_velocity: float = 0.0
var _target_rotation: float = 0.0
var _initial_transform: Transform3D

func _ready():
    _initial_transform = transform

func apply_hit_wobble(_direction: Vector3):
    if not enable_wobble:
        return
    
    _angular_velocity = hit_force
    _target_rotation = 0.0

func _physics_process(delta):
    if not enable_wobble:
        return
    
    var angle_displacement = rotation.x - _target_rotation
    var spring_force = -spring_stiffness * angle_displacement
    var damping_force = -spring_damping * _angular_velocity
    var total_force = spring_force + damping_force
    
    _angular_velocity += total_force * delta
    
    var new_rotation = rotation
    new_rotation.x += _angular_velocity * delta
    
    new_rotation.x = clamp(new_rotation.x, 
        _initial_transform.basis.get_euler().x - deg_to_rad(max_rotation_degrees),
        _initial_transform.basis.get_euler().x + deg_to_rad(max_rotation_degrees)
    )
    
    rotation = new_rotation