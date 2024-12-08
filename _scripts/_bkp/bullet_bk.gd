# extends RigidBody3D

# @export var damage: float = 0.01
# @export var lifetime: float = 1.0
# @export var knockback: float = 1.0

# var bullet_owner: Node3D = null
# var time_alive: float = 0.0
# var last_print_time: float = 0.0

# func _ready():
#     body_entered.connect(_on_body_entered)
#     contact_monitor = true
#     max_contacts_reported = 1
	
#     # Check if the bullet is spawned inside another object
#     var space_state = get_world_3d().direct_space_state
#     var query = PhysicsRayQueryParameters3D.create(global_transform.origin, global_transform.origin)
#     var result = space_state.intersect_ray(query)

#     if result:
#         print("Warning: Bullet spawned inside or very close to an object")
#         # Optionally, you could move the bullet slightly:
#         # global_transform.origin += Vector3.UP * 0.125

#     # print("Bullet spawned at position: ", global_transform.origin)
#     # print("Bullet initial velocity: ", linear_velocity)

# func _physics_process(delta: float) -> void:
#     time_alive += delta
#     if time_alive >= lifetime:
#         queue_free()
	
#     # Print debug info every 0.5 seconds
#     if time_alive - last_print_time >= 0.5:
#         # print("Bullet position: ", global_transform.origin, " Velocity: ", linear_velocity)
#         last_print_time = time_alive

# func _on_body_entered(body: Node3D) -> void:
#     if body == bullet_owner:
#         return
#     if body.has_method("hit"):
#         body.hit(-linear_velocity.normalized(), damage, linear_velocity.length())
#     # print("Bullet hit: ", body.name)
#     queue_free()

# func set_velocity(new_velocity: Vector3) -> void:
#     linear_velocity = new_velocity
#     print("Bullet velocity set to: ", linear_velocity)

# func set_damage(value: float):
#     damage = value

# func set_lifetime(value: float):
#     lifetime = value

# func set_knockback(value: float):
#     knockback = value

# func set_bullet_owner(new_owner: Node3D):
#     bullet_owner = new_owner
