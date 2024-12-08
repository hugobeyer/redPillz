class_name EnemyDash
extends Node

signal dash_completed

@export var dash_distance: float = 5.0  # Distance of each dash
@export var dash_speed: float = 10.0  # Speed of the dash
@export var pause_time: float = 1.5  # Time to pause between dashes

var is_dashing: bool = false
var dash_timer: float = 0.0
var pause_timer: float = 0.0
var initial_position: Vector3
# var dash_direction: Vector3

# # func start_dash(start_position: Vector3, direction: Vector3):
# 	dash_direction = direction.normalized()
# 	is_dashing = true
# 	dash_timer = 0.0

# func process(delta: float, current_position: Vector3) -> Vector3:
	# # if is_dashing:
	# # 	return perform_dash(delta)
	# else:
	# 	return pause_between_dashes(delta)

# func perform_dash(delta: float) -> Vector3:
# 	dash_timer += delta
# 	var t = dash_timer / (dash_distance / dash_speed)
	
# 	if t <= 1.0:
# 		return dash_direction * dash_speed
# 	else:
# 		stop_dash()
# 		return Vector3.ZERO

# func pause_between_dashes(delta: float) -> Vector3:
# 	pause_timer += delta
# 	if pause_timer >= pause_time:
# 		emit_signal("dash_completed")
# 	return Vector3.ZERO

# func get_current_direction() -> Vector3:
# 	return dash_direction if is_dashing else Vector3.ZERO

func stop_dash():
	is_dashing = false
	pause_timer = 0.0
	emit_signal("dash_completed")
