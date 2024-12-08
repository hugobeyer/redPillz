# extends Node3D

# @export var enemy_scenes: Dictionary = {}
# @export var min_spawn_radius: float = 15.0
# @export var max_spawn_radius: float = 25.0
# @export var spawn_height: float = 1.0
# @export var below_ground_offset: float = 5.0
# @export var rise_duration: float = 1.0
# @export var max_enemies: int = 50
# @export var min_spawn_interval: float = 0.5
# @export var max_spawn_interval: float = 2.0
# @export var min_cluster_points: int = 1
# @export var max_cluster_points: int = 3
# @export var min_enemies_per_cluster: int = 2
# @export var max_enemies_per_cluster: int = 5
# @export var cluster_radius: float = 5.0

# var player: Node3D
# var active_enemies: int = 0
# var spawn_timer: Timer
# var spawn_points: Array = []
# var ai_director: Node
# @onready var formation_manager = $FormationManager
# var spawn_queue: Array = []

# var _preloaded_enemy_scenes: Dictionary = {}

# func set_ai_director(director: Node):
#     ai_director = director

# func _ready():
#     ai_director = get_node("../AIDirector")
#     player = get_parent().get_node("Player")
#     if not player:
#         push_error("Player not found at path: 'parent'/Player")
#         return    
#     setup_spawn_timer()
#     setup_gradual_spawn_timer()
    
#     # Preload assigned enemy resources
#     for key in enemy_scenes:
#         if enemy_scenes[key] is String and enemy_scenes[key].ends_with(".tres"):
#             var resource = load(enemy_scenes[key])
#             if resource is EnemyType:
#                 _preloaded_enemy_scenes[key] = resource
#             else:
#                 push_warning("Invalid resource type for enemy: " + key)
#         else:
#             push_warning("Invalid resource path for enemy type: " + key)
    
#     SignalBus.connect("enemy_killed", Callable(self, "_on_enemy_killed"))

# func setup_spawn_timer():
#     spawn_timer = Timer.new()
#     spawn_timer.timeout.connect(generate_spawn_points)
#     add_child(spawn_timer)
#     set_next_spawn_interval()

# func set_next_spawn_interval():
#     var next_interval = randf_range(min_spawn_interval, max_spawn_interval)
#     spawn_timer.set_wait_time(next_interval)
#     spawn_timer.start()

# func generate_spawn_points():
#     var num_clusters = randi_range(min_cluster_points, max_cluster_points)
    
#     for _i in range(num_clusters):
#         var cluster_center_radius = randf_range(min_spawn_radius, max_spawn_radius)
#         var cluster_center_angle = randf() * 2 * PI
#         var cluster_center = get_spawn_position(cluster_center_radius, cluster_center_angle)
        
#         generate_cluster_points(cluster_center)
    
#     replace_points_with_enemies()
#     set_next_spawn_interval()

# func generate_cluster_points(cluster_center: Vector3):
#     var points_in_cluster = randi_range(min_enemies_per_cluster, max_enemies_per_cluster)
    
#     for _i in range(points_in_cluster):
#         if active_enemies + spawn_points.size() >= max_enemies:
#             break
        
#         var angle = randf() * 2 * PI
#         var radius = randf() * cluster_radius
#         var spawn_position = cluster_center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
        
#         spawn_points.append(spawn_position)

# func replace_points_with_enemies():
#     spawn_queue = spawn_points.duplicate()
#     spawn_points.clear()
#     start_gradual_spawning()

# func start_gradual_spawning():
#     if not spawn_queue.is_empty() and active_enemies < max_enemies:
#         var delay = randf_range(0.1, 0.5)  # Random delay between 0.1 and 0.5 seconds
#         spawn_timer.start(delay)

# func spawn_next_enemy():
#     if not spawn_queue.is_empty() and active_enemies < max_enemies:
#         var spawn_position = spawn_queue.pop_front()
#         spawn_enemy(spawn_position)
#         start_gradual_spawning()  # Continue spawning

# func spawn_enemy(spawn_position: Vector3):
#     var enemy_type = ai_director.get_enemy_type()
#     if enemy_type not in _preloaded_enemy_scenes:
#         push_error("Enemy type not found: " + enemy_type)
#         return
    
#     var enemy_scene = _preloaded_enemy_scenes[enemy_type]
#     var enemy_instance = enemy_scene.instantiate()
    
#     # Calculate the below-ground position
#     var below_position = spawn_position - Vector3(0, below_ground_offset, 0)
    
#     # Check if the position is valid
#     if not below_position.is_finite():
#         push_error("Invalid spawn position: " + str(below_position))
#         below_position = Vector3.ZERO  # Fallback to a safe position
    
#     # Set the initial position
#     enemy_instance.position = below_position
    
#     # Get enemy parameters from AI Director
#     var enemy_params = ai_director.get_enemy_parameters(enemy_type)
#     var flocking_params = ai_director.get_flocking_parameters()
    
#     # Combine all parameters into a single dictionary
#     var init_params = {
#         "enemy_params": enemy_params,
#         "flocking_params": flocking_params,
#         "ai_director": ai_director,
#         "spawner": self
#     }
    
#     # Now add the enemy to the scene
#     add_child(enemy_instance)
    
#     if enemy_instance.has_method("initialize"):
#         enemy_instance.initialize(init_params)
    
#     # Ensure spawn_position is finite
#     if not spawn_position.is_finite():
#         push_error("Invalid final spawn position: " + str(spawn_position))
#         spawn_position = Vector3(below_position.x, 0, below_position.z)  # Use a safe height
    
#     # Create the rising animation
#     var tween = create_tween()
#     tween.tween_property(enemy_instance, "position", spawn_position, rise_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

#     # Wait for the rising animation to complete
#     await tween.finished

#     # If there's a custom physics enable method, call it
#     if enemy_instance.has_method("set_physics_enabled"):
#         enemy_instance.set_physics_enabled(true)

#     enemy_instance.connect("enemy_killed", Callable(SignalBus, "emit_signal").bind("enemy_killed"))

#     # After spawning
#     active_enemies += 1
    
#     # If there are more enemies to spawn, continue the process
#     if not spawn_queue.is_empty():
#         start_gradual_spawning()

#     # Add the enemy to the formation
#     formation_manager.add_enemy(enemy_instance)

# func get_spawn_position(radius: float, angle: float) -> Vector3:
#     var player_pos = get_player_position()
#     var x = cos(angle) * radius
#     var z = sin(angle) * radius
#     var spawn_pos = Vector3(x, spawn_height, z) + player_pos
    
#     if not spawn_pos.is_finite():
#         push_error("Invalid spawn position calculated: " + str(spawn_pos))
#         return Vector3.ZERO  # Fallback to a safe position
    
#     return spawn_pos

# func get_player_position() -> Vector3:
#     if player:
#         return player.global_position
#     else:
#         push_error("Player reference is null in get_player_position")
#         return Vector3.ZERO

# func _on_enemy_killed():
#     active_enemies -= 1

# func setup_gradual_spawn_timer():
#     spawn_timer = Timer.new()
#     spawn_timer.one_shot = true
#     add_child(spawn_timer)
#     spawn_timer.timeout.connect(spawn_next_enemy)
