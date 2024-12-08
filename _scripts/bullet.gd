extends Area3D

@export var damage: float = 10.0
@export var lifetime: float = 2.0
@export var knockback: float = 1.0
@export var max_speed: float = 50.0
@export_range(0.0, 1.0) var damping: float = 0.02
@export var hit_effect: HitEffect

var bullet_owner: Node3D = null
var time_alive: float = 0.0
var last_print_time: float = 0.0

var velocity: Vector3 = Vector3.ZERO
var direction: Vector3
var speed: float = 30.0

@onready var hit_effect_instance = get_tree().get_root().find_child("HitEffect", true, false)

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))
	
	add_to_group("player_projectiles")
	
	time_alive = 0.0

func _physics_process(delta: float) -> void:
	time_alive += delta
	
	if time_alive >= lifetime:
		get_parent().remove_child(self)
		queue_free()
		return
	
	if not is_position_finite():
		queue_free()
		return
	
	velocity = velocity * (1.0 - damping)
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	global_position += velocity * delta
	perform_raycast()
	
	if time_alive - last_print_time >= 0.5:
		last_print_time = time_alive

func is_position_finite() -> bool:
	return global_transform.origin.is_finite() and velocity.is_finite()

func perform_raycast():
	if not is_position_finite():
		queue_free()
		return
	
	var space_state = get_world_3d().direct_space_state
	if space_state:
		var query = PhysicsPointQueryParameters3D.new()
		query.position = global_transform.origin
		query.exclude = [self]
		query.collision_mask = 1
		
		var results = space_state.intersect_point(query)
		for result in results:
			var collider = result["collider"]
			var enemy = find_enemy_node(collider)
			if enemy:
				apply_hit_to_enemy(enemy)
				queue_free()
				break

func find_enemy_node(node: Node) -> Node:
	if node.is_in_group("enemies"):
		return node
	
	var parent = node.get_parent()
	while parent:
		if parent.is_in_group("enemies"):
			return parent
		parent = parent.get_parent()
	
	return null

func apply_hit_to_enemy(enemy: Node):
	var hit_direction = velocity.normalized()
	hit_direction.y = 0
	
	if hit_effect_instance:
		hit_effect_instance.spawn_from_hit(global_position, hit_direction)
	
	# Calculate knockback force based on velocity and knockback multiplier
	var knockback_force = velocity.length() * knockback
	
	# Apply hit with damage and knockback through flocking manager
	if enemy.has_method("hit"):
		enemy.hit(hit_direction, damage)
		
		# Get the parent point and flocking manager to apply knockback
		var parent_point = enemy.get_parent()
		if parent_point and is_instance_valid(parent_point):
			var flocking_manager = parent_point.get_parent()
			if flocking_manager and flocking_manager.has_method("apply_point_knockback"):
				flocking_manager.apply_point_knockback(parent_point, hit_direction, knockback_force)

func _on_body_entered(body: Node3D) -> void:
	if body == bullet_owner:
		return
	
	var enemy = find_enemy_node(body)
	if enemy:
		apply_hit_to_enemy(enemy)
	
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("enemies"):
		apply_hit_to_enemy(area)
		queue_free()

func set_velocity(new_velocity: Vector3) -> void:
	if new_velocity.is_finite():
		velocity = new_velocity.limit_length(max_speed)
	else:
		queue_free()

func set_damage(value: float):
	damage = value

func set_lifetime(value: float):
	lifetime = value
	time_alive = 0.0

func set_knockback(value: float):
	knockback = value

func set_bullet_owner(new_owner: Node3D):
	bullet_owner = new_owner

func shoot(initial_position: Vector3, shoot_direction: Vector3):
	if initial_position.is_finite() and shoot_direction.is_finite():
		global_transform.origin = initial_position
		velocity = (shoot_direction.normalized() * max_speed).limit_length(max_speed)
	else:
		queue_free()
