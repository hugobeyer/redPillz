class_name Enemy
extends CharacterBody3D

@export var speed: float = 5.0
@export var turn_speed: float = 2.0

var player: Node3D
var nav_ready = false

# Remove the flock property if it's not being used
# var flock: Array[Node3D]

func _ready():
	$NavigationAgent3D.path_desired_distance = 0.5
	$NavigationAgent3D.target_desired_distance = 0.5
	
	# Find the player using the correct path
	player = get_tree().get_root().get_node("Main/Player")
	print("Enemy ready, player: ", player)
	print("Initial enemy position: ", global_position)

	# Wait for the navigation map to be ready
	get_tree().create_timer(0.5).timeout.connect(func(): nav_ready = true)

func _physics_process(delta):
	if not nav_ready or not is_instance_valid(player):
		return
	
	var player_position = player.global_position
	var enemy_position = global_position
	print("Player position: ", player_position)
	print("Enemy position: ", enemy_position)
	
	$NavigationAgent3D.set_target_position(player_position)
	
	var next_path_position: Vector3 = $NavigationAgent3D.get_next_path_position()
	print("Next path position: ", next_path_position)
	
	var direction = (next_path_position - enemy_position).normalized()
	print("Direction to player: ", direction)
	
	var desired_velocity = direction * speed
	velocity = velocity.lerp(desired_velocity, turn_speed * delta)
	print("Current velocity: ", velocity)
	
	move_and_slide()
	
	if velocity.length() > 0.1:
		var look_at_position = enemy_position + velocity.normalized()
		look_at(look_at_position, Vector3.UP)
		print("Looking at: ", look_at_position)