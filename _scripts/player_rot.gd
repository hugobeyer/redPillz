# extends Node3D

# var camera: Camera3D  
# @export var rotation_speed: float = 10.0  # Increased rotation speed
# @export var min_rotation_speed: float = 0.1  # Minimum rotation speed to prevent very slow rotations

# var target_rotation: float = 0.0

# func _ready():
# 	if not camera:
# 		camera = get_node("/root/Main/GameCamera")
# 	if not camera:
# 		push_error("Camera3D not found in the scene tree.")

# func _process(delta):
# 	rotate_player_to_mouse(delta)

# func rotate_player_to_mouse(delta):
# 	if not camera:
# 		return

# 	var mouse_position = get_viewport().get_mouse_position()
	
# 	# Project a ray from the camera to a plane at the player's height
# 	var from = camera.project_ray_origin(mouse_position)
# 	var to = from + camera.project_ray_normal(mouse_position) * 1000
# 	var player_plane = Plane(Vector3.UP, global_position.y)
	
# 	var cursor_pos = player_plane.intersects_ray(from, to)
	
# 	if cursor_pos:
# 		var direction = global_position - cursor_pos  # Changed this line
# 		direction.y = 0  # Ensure we only rotate on the Y axis
		
# 		if direction.length_squared() > 0.001:  # Avoid division by zero
# 			target_rotation = atan2(direction.x, direction.z)
			
# 			# Calculate the shortest rotation difference
# 			var rotation_difference = fmod((target_rotation - rotation.y + PI), (PI * 2)) - PI
			
# 			# Apply a minimum rotation speed
# 			var rotation_step = sign(rotation_difference) * max(abs(rotation_difference) * rotation_speed * delta, min_rotation_speed * delta)
			
# 			# Clamp the rotation step to prevent overshooting
# 			rotation_step = clamp(rotation_step, -abs(rotation_difference), abs(rotation_difference))
			
# 			# Apply the rotation
# 			rotation.y += rotation_step
