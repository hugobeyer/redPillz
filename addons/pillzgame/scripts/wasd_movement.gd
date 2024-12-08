@tool
extends Node3D

@export_group("Movement Settings")
@export var wander_speed: float = 8.0
@export var flee_speed: float = 24.0
@export var turn_speed: float = 3.0
@export var min_turn_angle: float = 0.1
@export var max_turn_angle: float = PI / 4

@export_group("Flocking Behavior")
@export var flee_distance: float = 10.0
@export var max_flee_points: int = 3

@export_group("World Boundaries")
@export var min_radius: float = 20.0
@export var max_radius: float = 100.0
@export var turn_around_zone: float = 10.0

@export_group("Noise Settings")
@export var world_noise_strength: float = 2.5
@export var noise_speed: float = 0.5
@export var noise_frequency: float = 0.5
@export_range(1, 5) var noise_octaves: int = 2
@export_range(0.0, 1.0) var noise_persistence: float = 0.5
@export_range(0.5, 4.0) var noise_lacunarity: float = 2.0

@export_group("References")
@export var flock_node_path: NodePath

@export_group("Debug")
@export var wander_enabled: bool = true
@export var debug_lines_enabled: bool = true

# @export_group("Editor Controls")
# @export var wander_enabled: bool = true:
# 	set(value):
# 		wander_enabled = value
# 		if Engine.is_editor_hint():
# 			if toggle_wander:
# 				# print("Wander enabled in editor")
# 				wander_enabled = true
# 			else:
# 				print("Wander disabled in editor")
# 				wander_enabled = true

var noise: FastNoiseLite
var noise_offset: float = 0.0

var current_direction: Vector3 = Vector3.FORWARD


var flock_node: Node3D

var debug_mesh_instance: MeshInstance3D
var debug_immediate_mesh: ImmediateMesh
var debug_closest_points: Array = []
var debug_flee_direction: Vector3 = Vector3.ZERO
var debug_desired_direction: Vector3 = Vector3.ZERO

var initial_position: Vector3
var initial_rotation: Quaternion

func _ready():
	initialize_noise()
	
	if not Engine.is_editor_hint():
		randomize()
		flock_node = get_node(flock_node_path)
		
		initial_position = global_position
		initial_rotation = global_transform.basis.get_rotation_quaternion()
		
		if debug_lines_enabled:
			setup_debug_lines()

func initialize_noise():
	noise = FastNoiseLite.new()
	noise.seed = 0 if Engine.is_editor_hint() else randi()
	update_noise_settings()

func update_noise_settings():
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves
	noise.fractal_lacunarity = noise_lacunarity
	noise.fractal_gain = noise_persistence

func _process(delta):
	if Engine.is_editor_hint():
		if wander_enabled:
			# Simplified wander for editor preview
			editor_wander(delta)
	else:
		# Normal game logic
		update_noise_settings()
		
		if wander_enabled:
			wander_and_flee(delta)
		else:
			wasd_movement(delta)

		if Input.is_action_just_pressed("toggle_wander"):
			wander_enabled = wander_enabled
		
		if debug_lines_enabled:
			update_debug_lines()

func editor_wander(delta):
	# Simplified wander logic for editor preview
	noise_offset += noise_speed * delta
	var noise_angle = noise.get_noise_1d(noise_offset) * PI * world_noise_strength
	var wander_direction = Vector3.FORWARD.rotated(Vector3.UP, noise_angle)
	global_position += wander_direction * wander_speed * delta
	look_at(global_position + wander_direction, Vector3.UP)
	global_position.y = 0  # Keep on the ground

func wasd_movement(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		global_position += direction * wander_speed * delta
		look_at(global_position + direction, Vector3.UP)

	if wander_enabled == true:
		wander_enabled = false
	else:
		wander_enabled = true

func action_toggle_wander(event):
	if event.is_action_pressed("toggle_wander"):
		wander_enabled = !wander_enabled

func wander_and_flee(delta):
	noise_offset += noise_speed * delta

	var to_world_center = -global_position
	var distance_to_center = to_world_center.length()

	var center_force = clamp(inverse_lerp(min_radius, max_radius, distance_to_center), 0.0, 1.0)
	
	var closest_points = []
	for flock_member in flock_node.get_children():
		var distance = global_position.distance_to(flock_member.global_position)
		if distance < flee_distance:
			closest_points.append({"point": flock_member, "distance": distance})
	
	closest_points.sort_custom(func(a, b): return a.distance < b.distance)
	closest_points = closest_points.slice(0, max_flee_points)

	var flee_direction = Vector3.ZERO
	var total_flee_influence = 0.0
	for point_data in closest_points:
		var distance = point_data.distance
		var flee_influence = 1.0 - (distance / flee_distance)
		flee_direction += (global_position - point_data.point.global_position).normalized() * flee_influence
		total_flee_influence += flee_influence

	if total_flee_influence > 0:
		flee_direction = (flee_direction / total_flee_influence).normalized()

	to_world_center = to_world_center.normalized()

	var noise_angle = noise.get_noise_1d(noise_offset) * PI * world_noise_strength

	var wander_direction = to_world_center.rotated(Vector3.UP, noise_angle)
	
	var turn_around_strength = clamp(inverse_lerp(max_radius - turn_around_zone, max_radius, distance_to_center), 0.0, 1.0)
	wander_direction = wander_direction.lerp(to_world_center, turn_around_strength)

	var flee_intensity = clamp(total_flee_influence / max_flee_points, 0.0, 1.0)
	var desired_direction: Vector3
	
	if flee_direction != Vector3.ZERO:
		# Lerp between wander direction and flee direction based on flee intensity
		desired_direction = wander_direction.lerp(flee_direction, flee_intensity)
	else:
		desired_direction = wander_direction

	desired_direction = desired_direction.normalized()

	var max_angle_change = lerp(min_turn_angle, max_turn_angle, max(1.0 - center_force, flee_intensity, turn_around_strength))

	var angle_to_desired = current_direction.angle_to(desired_direction)
	var clamped_angle = clamp(angle_to_desired, 0, max_angle_change)

	var new_direction: Vector3
	if angle_to_desired > 0.001:
		var cross_product = current_direction.cross(desired_direction)
		if cross_product.length() > 0.001:
			new_direction = current_direction.rotated(cross_product.normalized(), clamped_angle)
		else:
			new_direction = current_direction
	else:
		new_direction = current_direction

	new_direction = new_direction.normalized()
	current_direction = current_direction.slerp(new_direction, clamp(turn_speed * delta, 0.0, 1.0)).normalized()

	var speed = lerp(wander_speed, flee_speed, flee_intensity)
	var movement = current_direction * speed * delta
	
	var new_position = global_position + movement
	if new_position.length() > max_radius:
		new_position = new_position.normalized() * max_radius

	if is_valid_vector3(new_position):
		global_position = new_position
	else:
		print("Invalid new position: ", new_position)

	var look_target = global_position + current_direction
	if look_target.distance_to(global_position) > 0.001 and is_valid_vector3(look_target):
		var new_transform = global_transform.looking_at(look_target, Vector3.UP)
		if is_valid_transform(new_transform):
			global_transform = new_transform
		else:
			print("Invalid transform when looking at: ", look_target)

	global_position.y = 0

	# Store the calculated values for debug visualization
	self.debug_closest_points = closest_points
	self.debug_flee_direction = flee_direction
	self.debug_desired_direction = desired_direction

func setup_debug_lines():
	debug_immediate_mesh = ImmediateMesh.new()
	debug_mesh_instance = MeshInstance3D.new()
	debug_mesh_instance.mesh = debug_immediate_mesh
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_mesh_instance.material_override = material
	add_child(debug_mesh_instance)
	debug_mesh_instance.top_level = true

func update_debug_lines():
	if not is_instance_valid(debug_immediate_mesh):
		return

	debug_immediate_mesh.clear_surfaces()
	debug_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var inverse_initial_rotation = initial_rotation.inverse()
	var current_offset = global_position - initial_position
	var debug_y_offset = Vector3(0, 0.25, 0)  # 0.25 units above the ground
	
	# Draw lines to closest points
	for point_data in debug_closest_points:
		var point = point_data.point
		var influence = 1.0 - (point_data.distance / flee_distance)
		var color = Color.BLACK.lerp(Color.RED, influence)  # Black to red based on influence
		debug_immediate_mesh.surface_set_color(color)
		debug_immediate_mesh.surface_add_vertex(debug_y_offset)
		debug_immediate_mesh.surface_add_vertex(inverse_initial_rotation * (point.global_position - global_position) + debug_y_offset)
	
	# Draw flee direction
	if debug_flee_direction != Vector3.ZERO:
		var flee_strength = debug_flee_direction.length() / flee_distance
		var color = Color.DARK_BLUE.lerp(Color.BLUE, flee_strength)  # Black to blue based on flee strength
		debug_immediate_mesh.surface_set_color(color)
		debug_immediate_mesh.surface_add_vertex(debug_y_offset)
		debug_immediate_mesh.surface_add_vertex(inverse_initial_rotation * debug_flee_direction.normalized() * flee_distance/8 + debug_y_offset)
	
	# Draw desired direction
	var desired_strength = debug_desired_direction.length() / 2  # Assuming max length is 2
	var color = Color.BLACK.lerp(Color.GREEN, desired_strength)  # Black to green based on desired strength
	debug_immediate_mesh.surface_set_color(color)
	debug_immediate_mesh.surface_add_vertex(debug_y_offset)
	debug_immediate_mesh.surface_add_vertex(inverse_initial_rotation * debug_desired_direction.normalized() * 4 + debug_y_offset)
	
	debug_immediate_mesh.surface_end()

	# Update the debug mesh instance's position and rotation
	debug_mesh_instance.global_position = global_position + Vector3(0, 0.25, 0)
	debug_mesh_instance.global_transform.basis = Basis(initial_rotation)

func is_valid_vector3(vec: Vector3) -> bool:
	return not (is_inf(vec.x) or is_inf(vec.y) or is_inf(vec.z) or
				is_nan(vec.x) or is_nan(vec.y) or is_nan(vec.z))

func is_valid_transform(trans: Transform3D) -> bool:
	return is_valid_vector3(trans.origin) and is_valid_vector3(trans.basis.x) and is_valid_vector3(trans.basis.y) and is_valid_vector3(trans.basis.z)
