extends RigidBody3D

# @export var enemy_type: EnemyType:
#     set(value):
#         enemy_type = value
#         update_properties()
#         notify_property_list_changed()

# Export Groups
@export_group("General Enemy Parameters")
@export var enable_general_features: bool = true
@export var max_health: float = 125.0
@export var movement_speed: float = 3.0
@export var initial_max_speed: float = 5.0  # This can be set in the inspector
@export var knockback_resistance: float = 32.0
@export var turn_speed: float = 3.0
@export var detection_range: float = 65.0
@export var damage: float = 10.0
@export var use_shield: bool = false
@export var use_melee: bool = false

@export_group("Flocking Parameters")
@export var enable_flocking: bool = true
@export var flock_separation_weight: float = 32
@export var flock_alignment_weight: float = 12
@export var flock_cohesion_weight: float = 4.0
@export var flock_neighbor_distance: float = 5
@export var max_flock_neighbors: int = 5
@export var flock_weight_change_rate: float = 1.2
@export var max_flock_weight_multiplier: float = 2.0

@export_group("Death Effect Parameters")
@export var enable_death_effect: bool = true
@export var death_effect_scene: PackedScene
@export var death_effect_duration: float = 2.0

@export_group("Berserk Parameters")
@export var enable_berserk: bool = true
@export var berserk_chance: float = 0.25
@export var berserk_speed_multiplier: float = 2.0
@export var berserk_duration: float = 2.0

@export_group("Wander Parameters")
@export var enable_wander: bool = true
@export var wander_radius: float = 1.0
@export var wander_interval: float = 1.0

@export_group("Wobble Effect Parameters")
@export var enable_wobble: bool = true
@export var wobble_strength: float = 1.0
@export var wobble_decay: float = 5.0
@export_range(0, 1) var wobble_damping: float = 0.98
var _initial_mesh_transform: Transform3D

# Onready Variables
@onready var shield: EnemyShield = $EnemyShield if has_node("EnemyShield") else null
@onready var mesh = $mesh_pivot/MeshInstance3D
@onready var mesh_instance = $mesh_pivot/MeshInstance3D
@onready var mesh_pivot = $mesh_pivot
@onready var effects: EnemyEffects = $EnemyEffects
@onready var health_bar: Sprite3D = $HealthBar
@onready var melee_weapon = $MeleeWeapon if has_node("MeleeWeapon") else null
@onready var max_speed: float = initial_max_speed

# State Variables (hidden from Inspector)
var _health: float
var _is_berserk: bool = false
var _time_alive: float = 0
var _wander_time: float = 0
var _wander_direction: Vector3 = Vector3.ZERO

# Physics Variables (hidden from Inspector)
var _knockback_velocity: Vector3 = Vector3.ZERO
var _wobble_velocity: Vector3 = Vector3.ZERO

# Reference Variables (hidden from Inspector)
var _player: Node3D = null
# var _formation_manager: Node3D
# var _ai_director: Node
# var _spawner: Node

# Transform Variables (hidden from Inspector)


# Signals
signal enemy_killed(enemy)

# var _formation_target: Vector3

# At the top of your script, with other @export variables


# Add this near your other @onready variables


# var _formation_target: Vector3

var is_invulnerable = false
var invulnerability_duration = 0.05  # Adjust this value as needed

func _ready():
	if Engine.is_editor_hint():
		return
        
	# Wait for scene tree to be ready
	await get_tree().process_frame
	await get_tree().process_frame
    
	if not is_inside_tree():
		push_error("Enemy not inside scene tree!")
		return
    
	# Initialize basic components
	mesh_pivot = get_node("mesh_pivot")
	mesh_instance = get_node("mesh_pivot/MeshInstance3D")
    
	if not mesh_pivot:
		push_error("Pivot not found on enemy!")
		return
        
	# Initialize health and groups
	_health = max_health
	update_health_bar()
	add_to_group("enemies")
	max_speed = initial_max_speed
    
	# Get player reference with retry
	for i in range(3):  # Try 3 times
		_player = get_tree().get_first_node_in_group("player")
		if _player:
			break
		await get_tree().process_frame
    
	if not _player:
		# Fallback to direct path if needed
		_player = get_node("/root/GameRoot/Main/Player")
    
	if not _player:
		push_error("Player node not found! Make sure Player node is in 'player' group")
		return
        
	# Store initial transform after everything is initialized
	if is_inside_tree() and mesh_pivot.is_inside_tree():
		_initial_mesh_transform = mesh_pivot.transform

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if not _player or not is_instance_valid(_player) or not is_inside_tree():
		return
        
	if not state.linear_velocity.is_finite():
		state.linear_velocity = Vector3.ZERO

	if not global_transform.origin.is_finite():
		global_transform.origin = Vector3.ZERO

	apply_distance_to_player_limit(state)
	apply_knockback(state)
    
	# Enforce max speed
	state.linear_velocity = state.linear_velocity.limit_length(max_speed)
    
	# Apply wobble effect
	if enable_wobble:
		apply_wobble(state.step)
    
	orient_to_movement(state.step)

func move_towards_player(state: PhysicsDirectBodyState3D):
	if not is_instance_valid(_player):
		return

	var distance_to_player = global_position.distance_to(_player.global_position)
	
	if distance_to_player < 0.01:
		return

	var aggression_factor = clamp(1.0 - (distance_to_player / detection_range), 0.0, 1.0)
	var current_speed = lerp(movement_speed * 0.5, movement_speed * 1.5, aggression_factor)
	current_speed = min(current_speed, max_speed)
	
	var direction_to_player = (_player.global_position - global_position).normalized()
	direction_to_player.y = 0

	var force = direction_to_player * current_speed * 12
	
	var flocking_force = calculate_flocking_force()
	if flocking_force != Vector3.ZERO:
		force += flocking_force * current_speed * 3
	
	state.apply_central_force(force)

func wander(state: PhysicsDirectBodyState3D):
	if not enable_wander:
		return
	
	_wander_time += state.step
	if _wander_time >= wander_interval:
		_wander_time = 0
		_wander_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	
	var wander_target = global_position + _wander_direction * wander_radius
	var direction = (wander_target - global_position).normalized()
	var wander_speed = min(movement_speed * 0.5, max_speed)
	state.linear_velocity = direction * wander_speed
	state.linear_velocity = state.linear_velocity.limit_length(max_speed)
	
	orient_to_movement(state.step)

func apply_knockback(state: PhysicsDirectBodyState3D):
	state.linear_velocity += _knockback_velocity
	state.linear_velocity = state.linear_velocity.limit_length(max_speed)
	_knockback_velocity = _knockback_velocity.lerp(Vector3.ZERO, state.step * 5)

func orient_to_movement(delta: float):
	var move_direction = linear_velocity.normalized()
	if move_direction.length() > 0.1:
		var target_transform = transform.looking_at(global_position + move_direction, Vector3.UP)
		if target_transform.origin.is_finite() and target_transform.basis.is_finite():
			global_transform = global_transform.interpolate_with(target_transform, turn_speed * delta)
		else:
			print("Non-finite target_transform detected in orient_to_movement")

func hit(direction: Vector3, hit_damage: float, impulse: float):
	if is_invulnerable:
		#print("Enemy is invulnerable, ignoring hit")
		return

	is_invulnerable = true
	get_tree().create_timer(invulnerability_duration).connect("timeout", Callable(self, "_end_invulnerability"))

	#print("Enemy hit: Damage =", hit_damage, ", Health before =", _health)
	
	var remaining_damage = hit_damage

	if use_shield and shield and shield.get_shield_strength() > 0:
		remaining_damage = shield.take_damage(hit_damage)
		
		if shield.has_method("apply_shield_effect"):
			shield.apply_shield_effect(direction * hit_damage)
		
		if shield.get_shield_strength() <= 0:
			_on_shield_depleted()
	else:
		shield = null  # Ensure shield is set to null if depleted

	if remaining_damage > 0:
		_health -= remaining_damage
		#print("Enemy health after hit:", _health)
		update_health_bar()
		if _health <= 0:
			#print("Enemy health <= 0, calling die()")
			die()
		else:
			apply_hit_wobble(direction * impulse)
			if effects:
				effects.apply_damage_effect(direction)
	
	# Apply impulse for knockback
	var knockback_impulse = direction * impulse
	knockback_impulse = knockback_impulse.limit_length(max_speed)
	apply_central_impulse(knockback_impulse)

	# Visual feedback for hit
	if mesh_instance:
		var material = mesh_instance.get_surface_override_material(0)
		if material:
			var original_color = material.albedo_color
			material.albedo_color = Color.RED
			get_tree().create_timer(0.1).connect("timeout", Callable(self, "_reset_color").bind(original_color))
		else:
			print("No material found on mesh_instance")
	else:
		print("No mesh_instance found on enemy")

	print("Enemy hit processed. Current health:", _health)

func update_health_bar():
	if health_bar:
		var health_percent = _health / max_health
		var shielded = is_instance_valid(shield) and shield.get_shield_strength() > 0
		health_bar.set_progress(health_percent, shielded)
		# Show the health bar only when necessary
		health_bar.visible = health_percent < 1.0 or shielded
	else:
		push_warning("Health bar is null or not assigned.")

func _process(delta):
	if Engine.is_editor_hint():
		return
        
	_time_alive += delta
    
	if enable_berserk and not _is_berserk and randf() < berserk_chance * delta:
		enter_berserk_mode()
    
	# Only modify flocking weights during berserk mode changes
	# Remove the continuous weight multiplication here

func apply_distance_to_player_limit(state: PhysicsDirectBodyState3D):
	if _player:
		var previous_player_position = _player.global_position
		var distance_to_player = global_position.distance_to(_player.global_position)
		if distance_to_player > 32:
			_player.global_position = previous_player_position
			wander(state)
		else:
			move_towards_player(state)

func die():
	print("Enemy dying, emitting signal...")
	GameEvents.enemy_killed.emit(self)  # Use GameEvents instead of SignalBus
	
	# Instantiate death effect
	if enable_death_effect and death_effect_scene:
		var death_effect = death_effect_scene.instantiate()
		get_parent().add_child(death_effect)
		
		# Ensure the particle system starts emitting
		if death_effect is GPUParticles3D:
			death_effect.emitting = true
		
		# Set up a timer to remove the effect after the specified duration
		var timer = get_tree().create_timer(death_effect_duration)
		timer.connect("timeout", Callable(death_effect, "queue_free"))
	
	print("Enemy about to be freed")
	queue_free()

func _on_shield_depleted():
	if is_instance_valid(shield):
		shield.queue_free()
		shield = null
	update_health_bar()

func calculate_flocking_force():
	if not enable_flocking:
		return Vector3.ZERO
	
	var separation_force = Vector3.ZERO
	var alignment_force = Vector3.ZERO
	var cohesion_force = Vector3.ZERO
	var neighbor_count = 0

	var neighbors = []
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self:
			continue
		var offset = enemy.global_position - global_position
		var distance = offset.length()
		if distance < flock_neighbor_distance and distance > 0.001:
			neighbors.append([distance, enemy])

	neighbors.sort()
	var max_neighbors = min(max_flock_neighbors, neighbors.size())
	
	for i in range(max_neighbors):
		var neighbor_info = neighbors[i]
		var distance = neighbor_info[0]
		var neighbor = neighbor_info[1]
		
		# Separation: stronger when closer
		separation_force += (global_position - neighbor.global_position).normalized() * (flock_neighbor_distance / distance)
		
		# Alignment: match velocity
		alignment_force += neighbor.linear_velocity
		
		# Cohesion: move toward center
		cohesion_force += neighbor.global_position
		neighbor_count += 1

	if neighbor_count > 0:
		# Calculate final forces without early normalization
		separation_force = separation_force * flock_separation_weight
		alignment_force = (alignment_force / neighbor_count - linear_velocity) * flock_alignment_weight
		
		var center = cohesion_force / neighbor_count
		cohesion_force = (center - global_position) * flock_cohesion_weight
		
		# Combine forces
		var final_force = separation_force + alignment_force + cohesion_force
		
		# Only normalize at the very end
		return final_force.normalized()

	return Vector3.ZERO

func set_physics_enabled(enabled: bool):
	set_physics_process(enabled)
	# Do NOT disable the collider here
	# $CollisionShape3D.disabled = !enabled  # Remove this line if it exists

func enter_berserk_mode():
	if not enable_berserk:
		return
	
	_is_berserk = true
	movement_speed *= berserk_speed_multiplier
	max_speed *= berserk_speed_multiplier
	flock_separation_weight *= 0.5
	mesh_instance.set_instance_shader_parameter("lerp_wave", 0.5)
	mesh_instance.set_instance_shader_parameter("lerp_color", Color(1.5, 0.1, 0.1, 1.0))

	await get_tree().create_timer(berserk_duration).timeout
	exit_berserk_mode()

func exit_berserk_mode():
	var default_hit_color = mesh.get_instance_shader_parameter("lerp_color")
	_is_berserk = false
	movement_speed /= berserk_speed_multiplier
	max_speed /= berserk_speed_multiplier
	flock_separation_weight *= 2
	mesh_instance.set_instance_shader_parameter("lerp_wave", 0.0)
	mesh_instance.set_instance_shader_parameter("lerp_color", default_hit_color)

# func _exit_tree():
# 	if _formation_manager:
# 		_formation_manager.remove_enemy(self)

func apply_hit_wobble(force: Vector3):
	if not enable_wobble:
		return
	_wobble_velocity += force * wobble_strength

func apply_wobble(delta: float):
	if not enable_wobble or not mesh_pivot:
		return
	
	# Calculate wobble rotation
	var wobble_rotation = Quaternion(Vector3(1, 0, 0), _wobble_velocity.z * delta) * Quaternion(Vector3(0, 0, 1), -_wobble_velocity.x * delta)
	
	# Apply wobble to mesh transform
	mesh_pivot.transform = _initial_mesh_transform * Transform3D(wobble_rotation)
	# Decay wobble
	_wobble_velocity = _wobble_velocity.lerp(Vector3.ZERO, wobble_decay * delta)
	_wobble_velocity *= wobble_damping  # Additional damping

func calculate_direction_to_player():
	var offset = _player.global_position - global_position
	var distance = offset.length()
	if distance > 0.001:  # Avoid division by zero
		return offset / distance
	else:
		return Vector3.ZERO

func _physics_process(_delta):
	if not global_transform.origin.is_finite():
		print("Resetting non-finite position in _physics_process")
		global_transform.origin = Vector3.ZERO
	if not linear_velocity.is_finite():
		print("Resetting non-finite linear_velocity in _physics_process")
		linear_velocity = Vector3.ZERO

func _end_invulnerability():
	is_invulnerable = false
	print("Enemy invulnerability ended")

# Visual feedback for hit


# func _reset_color(original_color):
# 	if mesh_instance:
# 		var material = mesh_instance.get_surface_override_material(0)
# 		if material:
# 			material.albedo_color = original_color
# 		else:
# 			print("No material found on mesh_instance when resetting color")
# 	else:
# 		print("No mesh_instance found on enemy when resetting color")
