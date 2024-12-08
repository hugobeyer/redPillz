extends Node3D

@export var flocking_enabled: bool = true
@export var flocking_agent: PackedScene
@export var spawn_effect_scene: PackedScene
@export var target_node_path: NodePath
@export_range(1.0, 256.0, 0.1, "or_greater") var target_detection_range: float = 128.0
@export_range(0.1, 200.0, 0.1, "or_greater") var target_weight: float = 100.0
@export_range(0.1, 5.0, 0.1, "or_greater") var point_radius: float = 1.0
@export_range(1.0, 50.0, 0.1, "or_greater") var max_force: float = 80.0
@export_range(0.1, 10.0, 0.1, "or_greater") var turn_speed: float = 2.0
@export var fixed_y_position: float = 0.0

@export_group("Speed Randomization")
@export var min_speed: float = 4.0
@export var max_speed: float = 12.0
@export var min_turn_speed: float = 1.5
@export var max_turn_speed: float = 6.0

@export_group("Flocking Parameters")
@export_range(0.1, 10.0, 0.1, "or_greater") var flock_min_distance_between_points: float = 2.0
@export_range(0.1, 10.0, 0.1, "or_greater") var flock_min_distance_to_target: float = 1.5
@export_range(1.0, 50.0, 0.1, "or_greater") var flock_neighbor_distance: float = 12.0
@export_range(1, 20, 1) var flock_max_neighbors: int = 7
@export_range(0.1, 250.0, 0.1, "or_greater") var flock_separation_weight: float = 128.0
@export_range(0.1, 50.0, 0.1, "or_greater") var flock_alignment_weight: float = 2.0
@export_range(0.1, 50.0, 0.1, "or_greater") var flock_cohesion_weight: float = 3.0

@export_group("Flocking Force Range")
@export var inner_radius: float = 5.0  # Full stop radius
@export var outer_radius: float = 15.0  # Normal movement radius
@export_range(0.0, 1.0) var min_force_multiplier: float = 0.0  # No new forces when close

@export_group("Spawn Settings")
@export var spawn_interval: float = 0.2  # Time between spawns
@export var initial_spawn_delay: float = 3.0  # Delay before first spawn
@export var spawn_effect_duration: float = 0.6  # Duration of spawn effect animation

@export_group("Respawn Settings")
@export var enable_respawn: bool = true
@export var respawn_cooldown: float = 2.0  # Time between respawn cycles
@export var max_respawn_cycles: int = 3  # Maximum number of respawn cycles
@export var points_per_respawn: int = 100  # How many points to spawn each cycle


@export_group("Performance Tuning")
@export var update_frequency: int = 30
@export var force_cache_time: float = 0.2
@export var neighbor_cache_time: float = 0.2




var target_node: Node3D

var scattered_points: Array
var velocities = {}
var point_speeds = {}

# Spatial grid variables
@export var grid_size: float = 20.0
var spatial_grid = {}
var update_counter: int = 0

# Precomputed values
var neighbor_distance_squared: float
var min_distance_squared: float
var initial_positions = {}
var noise: FastNoiseLite
var point_ids = {}
var point_knockback_velocities: Dictionary = {}
var cached_forces = {}
var _force_cache_timer: float = 0.0
var _neighbor_cache_timer: float = 0.0
var _delta_time: float
var _inv_grid_size: float
var _cached_neighbors := {}
var _pending_points: Array = []
var _points_ready: Array = []

var _respawn_timer: float = 0.0
var _original_points: Array = []  # Store original points for respawning

# Update the constants to match your collision layers
const FLOCK_COLLISION_LAYER = 2  # Layer 2 is "enemies"
const FLOCK_COLLISION_MASK = 1 | 2 | 3  # Collide with player, enemies, and environment

# Add near the top with other variables
var _editor_gizmos: Array[Node3D] = []

# Add this variable with other class variables
var _respawn_cycles_remaining: int = 0

# Wave system variables
var current_wave: int = 1
var active_enemies: int = 0
var spawn_timer: Timer  #KEEP

# Add these exports at the top with your other variables
@export var spawn_radius: float = 20.0  # Radius of spawn area
@export var min_spawn_distance: float = 5.0  # Minimum distance from center

var remaining_spawns: int = 0

signal wave_started(wave_number: int, total_waves: int)
signal wave_completed(wave_number: int)
signal all_waves_completed()
signal enemy_count_changed(active: int, total: int)

func _ready():
    initialize_noise()
    
    if Engine.is_editor_hint():
        # Store initial positions for all points
        for point in get_children():
            if point is Node3D:
                var point_id = point.get_instance_id()
                initial_positions[point_id] = point.global_position
        return
    
    _inv_grid_size = 1.0 / grid_size    
    var all_points = get_children().filter(func(child): return child is Node3D) as Array[Node3D]
    
    # Store the original points and their positions
    _original_points = []
    for point in all_points:
        _original_points.append({
            "position": point.global_position,  # Store the initial position
            "node": point
        })
    
    for point in all_points:
        # First disable everything
        point.visible = false
        if point is CollisionObject3D:
            for i in range(1, 33):
                point.set_collision_layer_value(i, false)
                point.set_collision_mask_value(i, false)
            if point is RigidBody3D:
                point.freeze = true
                point.gravity_scale = 0
        
        _pending_points.append(point)
    
    scattered_points.clear()
    _respawn_timer = respawn_cooldown
    _respawn_cycles_remaining = max_respawn_cycles  # Initialize respawn cycles
    
    initialize_target()
    
    neighbor_distance_squared = flock_neighbor_distance * flock_neighbor_distance
    min_distance_squared = flock_min_distance_between_points * flock_min_distance_between_points
    
    # Get spawn points that are already in the scene
    scattered_points = get_children().filter(func(node): return node is Node3D) as Array[Node3D]
    
    spawn_timer = Timer.new()
    add_child(spawn_timer)
    spawn_timer.wait_time = spawn_interval
    spawn_timer.connect("timeout", _on_spawn_timer_timeout)
    
    if enable_respawn:
        setup_wave_spawning()

func setup_wave_spawning():
    await get_tree().create_timer(initial_spawn_delay).timeout
    start_wave()

func start_wave():
    emit_signal("wave_started", current_wave, max_respawn_cycles)
    active_enemies = points_per_respawn
    remaining_spawns = points_per_respawn
    
    # Clear existing enemies
    for child in get_children():
        if child is Node3D and child.get_child_count() > 0:
            var enemy = child.get_child(0)
            if enemy and enemy.is_in_group("enemies"):
                child.queue_free()
    
    # Clear all tracking
    velocities.clear()
    point_speeds.clear()
    point_knockback_velocities.clear()
    cached_forces.clear()
    scattered_points.clear()
    
    spawn_timer.start()

func _on_spawn_timer_timeout():
    if remaining_spawns > 0:
        spawn_enemy()
        remaining_spawns -= 1
    else:
        print("All enemies spawned. Stopping spawn timer.")
        spawn_timer.stop()

func spawn_enemy() -> bool:
    # Get spawn position
    var random_angle = randf() * TAU
    var random_distance = randf_range(min_spawn_distance, spawn_radius)
    var spawn_position = Vector3(
        cos(random_angle) * random_distance,
        fixed_y_position,
        sin(random_angle) * random_distance
    ) + global_position
    
    # Create the enemy point
    var point = Node3D.new()
    add_child(point)
    point.global_position = spawn_position
    scattered_points.append(point)
    
    # Add spawn effect as child of point
    if spawn_effect_scene:
        var effect = spawn_effect_scene.instantiate()
        point.add_child(effect)
        effect.position = Vector3.ZERO
        
        if effect.has_node("AnimationPlayer"):
            var anim_player = effect.get_node("AnimationPlayer")
            anim_player.play("spawn")
            # Create timer and check if effect still exists
            get_tree().create_timer(spawn_effect_duration).timeout.connect(
                func(): 
                    if is_instance_valid(effect):
                        effect.queue_free()
            )
    
    # Add the enemy as a child
    var enemy = flocking_agent.instantiate()
    point.add_child(enemy)
    
    # Setup enemy properties
    var point_id = point.get_instance_id()
    velocities[point_id] = Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU) * max_speed * 0.5
    randomize_point_speeds(point)
    
    if enemy.has_signal("enemy_killed"):
        enemy.enemy_killed.connect(_on_enemy_killed.bind(point))
    
    return true

func _on_enemy_killed(enemy: Node3D, point: Node3D):
    if not is_instance_valid(enemy):
        return
        
    active_enemies = max(0, active_enemies - 1)
    emit_signal("enemy_count_changed", active_enemies, points_per_respawn)
    
    # Remove from flocking system
    var point_id = point.get_instance_id()
    velocities.erase(point_id)
    point_speeds.erase(point_id)
    point_knockback_velocities.erase(point_id)
    cached_forces.erase(point_id)
    scattered_points.erase(point)
    
    # Check if wave is complete
    if active_enemies <= 0 and remaining_spawns <= 0:
        emit_signal("wave_completed", current_wave)
        if current_wave < max_respawn_cycles:
            current_wave += 1
            spawn_timer.stop()
            call_deferred("start_next_wave")
        else:
            emit_signal("all_waves_completed")

func start_next_wave():
    await get_tree().create_timer(respawn_cooldown).timeout
    start_wave()

func _process(delta):
    if Engine.is_editor_hint() or not flocking_enabled:
        return
    
    # Update spatial grid less frequently
    update_counter += 1
    if update_counter >= update_frequency:
        update_spatial_grid()
        update_counter = 0

    # Cache force calculations
    _force_cache_timer += delta
    if _force_cache_timer >= force_cache_time:
        cached_forces.clear()
        _force_cache_timer = 0.0

    # Process respawn timer
    if enable_respawn and _pending_points.size() == 0:
        _respawn_timer -= delta
        if _respawn_timer <= 0:
            _start_respawn_cycle()

    if _neighbor_cache_timer >= neighbor_cache_time:
        _cached_neighbors.clear()
        _neighbor_cache_timer = 0.0
    
    # Optimization 5: Filter invalid points once per frame
    scattered_points = scattered_points.filter(func(p): return is_instance_valid(p))

func _physics_process(delta):
    if Engine.is_editor_hint() or not flocking_enabled:
        return
    
    # Process knockback velocities first
    var valid_points = scattered_points.filter(func(p): return is_instance_valid(p)) as Array[Node3D]
    scattered_points = valid_points  # Update the scattered_points array
    
    for point in valid_points:
        if not is_instance_valid(point):  # Double-check validity
            continue
            
        var point_id = point.get_instance_id()
        if point_id in point_knockback_velocities:
            var knockback_vel = point_knockback_velocities[point_id]
            point.global_position += knockback_vel * delta
            # Dampen knockback
            point_knockback_velocities[point_id] *= pow(0.1, delta)
            if knockback_vel.length() < 0.01:
                point_knockback_velocities.erase(point_id)
    

    
    # Then process regular flocking forces
    _delta_time = delta
    _neighbor_cache_timer += delta
    
    # Clear force cache periodically
    if _force_cache_timer >= force_cache_time:
        cached_forces.clear()
        _force_cache_timer = 0.0
    
    # Clear neighbor cache periodically
    if _neighbor_cache_timer >= neighbor_cache_time:
        _cached_neighbors.clear()
        _neighbor_cache_timer = 0.0
    
    # Optimization 8: Calculate and apply forces in a single loop
    for point in scattered_points:
        if is_instance_valid(point):
            var force = calculate_forces(point)
            apply_force(point, force, delta)
            enforce_minimum_distances(point)

func update_spatial_grid():
    spatial_grid.clear()
    
    for point in scattered_points:
        if not is_instance_valid(point):
            continue
            
        var point_pos = point.global_position
        var grid_pos = Vector3(
            int(floor(point_pos.x * _inv_grid_size)),
            int(floor(point_pos.y * _inv_grid_size)),
            int(floor(point_pos.z * _inv_grid_size))
        )
        
        if not grid_pos in spatial_grid:
            spatial_grid[grid_pos] = []
        spatial_grid[grid_pos].append(point)

func get_nearby_points(point: Node3D) -> Array:
    var point_pos: Vector3 = point.global_position
    var grid_x: int = int(floor(point_pos.x * _inv_grid_size))
    var grid_y: int = int(floor(point_pos.y * _inv_grid_size))
    var grid_z: int = int(floor(point_pos.z * _inv_grid_size))
    
    var nearby: Array = []
    
    # Check only relevant cells based on neighbor_distance
    var cell_radius: int = int(ceil(flock_neighbor_distance * _inv_grid_size))
    for x in range(max(-cell_radius, -1), min(cell_radius, 2)):
        for z in range(max(-cell_radius, -1), min(cell_radius, 2)):
            var check_pos: Vector3 = Vector3(grid_x + x, grid_y, grid_z + z)
            if spatial_grid.has(check_pos):
                nearby.append_array(spatial_grid[check_pos])
    
    return nearby

func calculate_forces(point: Node3D) -> Vector3:
    var point_id = point.get_instance_id()
    if point_id in cached_forces and _force_cache_timer < force_cache_time:
        return cached_forces[point_id]
    
    var flocking_forces = calculate_flocking_forces(point)
    var target_force = calculate_target_force(point)
    
    var total_force = flocking_forces + target_force
    cached_forces[point_id] = total_force
    return total_force

func calculate_flocking_forces(point: Node3D) -> Vector3:
    var point_id: int = point.get_instance_id()
    
    if not is_instance_valid(point):
        scattered_points.erase(point)
        return Vector3.ZERO
    
    var separation: Vector3 = Vector3.ZERO
    var alignment: Vector3 = Vector3.ZERO
    var cohesion: Vector3 = Vector3.ZERO
    var neighbor_count: int = 0
    
    # Calculate force multiplier based on distance to target
    var force_multiplier: float = 1.0
    var velocity_multiplier: float = 1.0  # New multiplier for velocity
    
    if target_node:
        var distance_to_target: float = point.global_position.distance_to(target_node.global_position)
        
        if distance_to_target <= inner_radius:
            # Inside inner radius - almost no movement
            force_multiplier = 0.0  # No new forces
            velocity_multiplier = 0.1  # Slow existing velocity
        elif distance_to_target < outer_radius:
            # Smooth transition between inner and outer radius
            var t: float = (distance_to_target - inner_radius) / (outer_radius - inner_radius)
            force_multiplier = smoothstep(0.0, 1.0, t)
            velocity_multiplier = smoothstep(0.1, 1.0, t)
        
        # Apply velocity damping
        if point_id in velocities:
            velocities[point_id] *= velocity_multiplier
    
    # Use cached neighbors if available
    var nearby_points: Array
    if point_id in _cached_neighbors and _neighbor_cache_timer < neighbor_cache_time:
        nearby_points = _cached_neighbors[point_id]
    else:
        nearby_points = get_nearby_points(point)
        _cached_neighbors[point_id] = nearby_points
    
    var point_pos: Vector3 = point.global_position
    
    for other in nearby_points:
        if other == point or not is_instance_valid(other):
            continue
            
        var other_id: int = other.get_instance_id()
        if not other_id in velocities:
            continue
            
        var offset: Vector3 = point_pos - other.global_position
        var distance_squared: float = offset.length_squared()
        
        if distance_squared < neighbor_distance_squared and neighbor_count < flock_max_neighbors:
            var inv_dist: float = 1.0 / sqrt(distance_squared)
            separation += offset * inv_dist
            alignment += velocities[other_id]
            cohesion += other.global_position
            neighbor_count += 1
    
    var total_force: Vector3 = Vector3.ZERO
    if neighbor_count > 0:
        var inv_count: float = 1.0 / float(neighbor_count)
        # Scale ALL forces by the multiplier
        alignment = (alignment * inv_count - velocities[point_id]) * flock_alignment_weight * force_multiplier
        cohesion = ((cohesion * inv_count) - point_pos) * flock_cohesion_weight * force_multiplier
        separation = separation * inv_count * flock_separation_weight * force_multiplier
        total_force = separation + alignment + cohesion
    
    return total_force

func calculate_target_force(point: Node3D) -> Vector3:
    if not target_node:
        return Vector3.ZERO
    
    var to_target = target_node.global_position - point.global_position
    var distance = to_target.length()
    
    if distance < flock_min_distance_to_target:
        return -to_target.normalized() * target_weight
    elif distance > target_detection_range:
        return Vector3.ZERO
    else:
        return to_target.normalized() * target_weight

func apply_force(point: Node3D, force: Vector3, delta: float):
    var point_id = point.get_instance_id()
    
    # Initialize dictionaries if they don't exist
    if not point_id in velocities:
        velocities[point_id] = Vector3.ZERO
    if not point_id in point_speeds:
        randomize_point_speeds(point)
    
    var velocity = velocities[point_id]
    var point_speed_data = point_speeds.get(point_id, {"max_speed": max_speed, "turn_speed": turn_speed})
    var max_speed_for_point = point_speed_data["max_speed"]
    var turn_speed_for_point = point_speed_data["turn_speed"]
    
    # Apply force to velocity (zero out Y component)
    force.y = 0
    velocity += force * delta
    velocity.y = 0
    
    # Limit speed
    if velocity.length() > max_speed_for_point:
        velocity = velocity.normalized() * max_speed_for_point
    
    # Update position (maintain fixed Y)
    var new_position = point.global_position + velocity * delta
    new_position.y = fixed_y_position
    point.global_position = new_position
    
    # Update rotation (only around Y axis)
    if velocity.length() > 0.1:
        var look_dir = velocity.normalized()
        var angle = atan2(look_dir.x, look_dir.z)
        point.rotation = Vector3(0, angle, 0)
    
    # Store velocity
    velocities[point_id] = velocity

func enforce_minimum_distances(point: Node3D):
    if target_node:
        var offset_to_target = target_node.global_position - point.global_position
        var distance_to_target = offset_to_target.length()
        if distance_to_target < flock_min_distance_to_target:
            var correction = offset_to_target.normalized() * (flock_min_distance_to_target - distance_to_target)
            point.global_position -= correction

    for other in scattered_points:
        if other == point:
            continue
        var offset = other.global_position - point.global_position
        var distance = offset.length()
        if distance < flock_min_distance_between_points:
            var correction = offset.normalized() * (flock_min_distance_between_points - distance) * 0.5
            point.global_position -= correction
            other.global_position += correction

func _activate_point(point: Node3D):
    if point is CollisionObject3D:
        point.set_collision_layer_value(FLOCK_COLLISION_LAYER, true)
        point.set_collision_mask_value(1, true)  # player
        point.set_collision_mask_value(2, true)  # enemies
        point.set_collision_mask_value(3, true)  # environment
        
        # Connect to enemy death signal if it exists
        var enemy = point.get_child(0)
        if enemy and enemy.has_signal("enemy_killed"):
            enemy.enemy_killed.connect(self._on_enemy_killed.bind(point))
    
    scattered_points.append(point)
    _initialize_point(point)

func _initialize_point(point: Node3D):
    var point_id = point.get_instance_id()
    point_ids[point_id] = point
    velocities[point_id] = Vector3.ZERO
    randomize_point_speeds(point)
    initial_positions[point_id] = point.global_position
    
    if flocking_agent:
        var agent_instance = flocking_agent.instantiate()
        point.add_child(agent_instance)
        agent_instance.name = "FlockingAgent"

func _start_respawn_cycle():
    for point in get_children():
        if point is Node3D and not point in scattered_points:
            point.visible = false
            # Ensure only Node3D objects are processed
            if point.has_method("global_position"):
                point.global_position = Vector3.ZERO  # Example reset or logic

func initialize_target():
    if not target_node_path.is_empty():
        target_node = get_node(target_node_path)

func initialize_noise():
    noise = FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    noise.seed = randi()
    noise.frequency = 0.01

func randomize_point_speeds(point: Node3D):
    var point_id = point.get_instance_id()
    point_speeds[point_id] = {
        "max_speed": randf_range(min_speed, max_speed),
        "turn_speed": randf_range(min_turn_speed, max_turn_speed)
    }

func reset_to_initial_positions():
    if not Engine.is_editor_hint():
        return
        
    for point in get_children():
        if point is Node3D:
            var point_id = point.get_instance_id()
            if point_id in initial_positions:
                point.global_position = initial_positions[point_id]
                if point_id in velocities:
                    velocities[point_id] = Vector3.ZERO


# Add this helper function for smoother interpolation
func smoothstep(edge0: float, edge1: float, x: float) -> float:
    var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

# Add this function to manually trigger respawn
func trigger_respawn():
    if enable_respawn and _pending_points.size() == 0 and _respawn_cycles_remaining > 0:
        _start_respawn_cycle()

# Add this function to reset respawn cycles
func reset_respawn_cycles():
    _respawn_cycles_remaining = max_respawn_cycles

func apply_knockback(point: Node3D, knockback_velocity: Vector3):
    var point_id = point.get_instance_id()
    if point_id in point_knockback_velocities:
        point_knockback_velocities[point_id] += knockback_velocity
    else:
        point_knockback_velocities[point_id] = knockback_velocity



func apply_point_knockback(point: Node3D, direction: Vector3, force: float):
    if not is_instance_valid(point):  # Check if point is valid
        return
        
    var point_id = point.get_instance_id()
    direction.y = 0
    direction = direction.normalized()
    # Store raw velocity for physics_process to handle
    point_knockback_velocities[point_id] = direction * force




