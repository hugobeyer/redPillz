extends Node3D

@export var movement_speed: float = 4.0
@export var turn_speed: float = 1.0
@export var enable_flocking: bool = true
@export var flock_separation_weight: float = 12.0
@export var flock_alignment_weight: float = 4.0
@export var flock_cohesion_weight: float = 2.0
@export var flock_neighbor_distance: float = 12.0
@export var max_flock_neighbors: int = 12
@export var detection_range: float = 32.0
@export var point_radius: float = 0.5

@export var target: Node3D = null

var velocity: Vector3 = Vector3.ZERO
var debug_mesh: MeshInstance3D
var immediate_mesh: ImmediateMesh

func _ready():
	# Create a sphere mesh for the point
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = point_radius
	sphere_mesh.height = point_radius * 2
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = sphere_mesh
	add_child(mesh_instance)

	# Setup debug line mesh
	immediate_mesh = ImmediateMesh.new()
	debug_mesh = MeshInstance3D.new()
	debug_mesh.mesh = immediate_mesh
	add_child(debug_mesh)

	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	debug_mesh.material_override = material

	# Ensure the current node is in the "points_of_interest" group
	add_to_group("points_of_interest")

func _process(delta):
	if enable_flocking:
		var flocking_force = calculate_flocking_force()
		
		# Debug visualization
		draw_debug_line(global_position, global_position + flocking_force * 5, Color.RED)
		
		if target and global_position.distance_to(target.global_position) <= detection_range:
			move_towards_target(delta, flocking_force)
		else:
			apply_flocking(delta, flocking_force)
		
		orient_to_movement(delta)

func move_towards_target(delta, flocking_force: Vector3):
	var direction_to_target = (target.global_position - global_position).normalized()
	
	var desired_direction = (direction_to_target * 0.5 + flocking_force * 0.5).normalized()
	var desired_velocity = desired_direction * movement_speed
	
	velocity = velocity.move_toward(desired_velocity, movement_speed * delta)
	global_position += velocity * delta

func apply_flocking(delta, flocking_force: Vector3):
	var desired_velocity = flocking_force * movement_speed
	
	velocity = velocity.move_toward(desired_velocity, movement_speed * delta)
	global_position += velocity * delta

func orient_to_movement(delta: float):
	if velocity.length() > 0.1:
		var target_transform = global_transform.looking_at(global_position + velocity, Vector3.UP)
		global_transform = global_transform.interpolate_with(target_transform, turn_speed * delta)

func calculate_flocking_force() -> Vector3:
	var separation_force = Vector3.ZERO
	var alignment_force = Vector3.ZERO
	var cohesion_force = Vector3.ZERO
	var neighbor_count = 0
	var points_of_interest = get_tree().get_nodes_in_group("points_of_interest")

	for point in points_of_interest:
		if point == self:
			continue
		var offset = point.global_position - global_position
		var distance = offset.length()
		if distance < flock_neighbor_distance and distance > 0.001:
			# Separation
			separation_force -= offset.normalized() / distance
			
			# Alignment
			var neighbor_flocking = point.get_node(".")
			if neighbor_flocking:
				alignment_force += neighbor_flocking.velocity
			
			# Cohesion
			cohesion_force += point.global_position
			
			neighbor_count += 1

	if neighbor_count > 0:
		separation_force = separation_force.normalized() * flock_separation_weight
		alignment_force = (alignment_force / neighbor_count - velocity).normalized() * flock_alignment_weight
		cohesion_force = ((cohesion_force / neighbor_count) - global_position).normalized() * flock_cohesion_weight

	return (separation_force + alignment_force + cohesion_force).normalized()

func draw_debug_line(start: Vector3, end: Vector3, color: Color):
	immediate_mesh.clear_surfaces()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate_mesh.surface_set_color(color)
	immediate_mesh.surface_add_vertex(start)
	immediate_mesh.surface_add_vertex(end)
	immediate_mesh.surface_end()
