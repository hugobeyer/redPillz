extends Node3D

@export var grenade_scene: PackedScene
@export var toss_strength: float = 20.0
@export var cooldown_time: float = 1.0

var can_toss: bool = true

func _input(event):
	if event.is_action_pressed("toss_grenade") and can_toss:
		toss_grenade()
		start_cooldown()

func toss_grenade():
	if not grenade_scene or not is_inside_tree():
		return
	
	var grenade = grenade_scene.instantiate()
	var spawn_pos = global_position
	
	grenade.transform = Transform3D(Basis(), spawn_pos)
	
	get_tree().root.call_deferred("add_child", grenade)
	
	await grenade.ready
	
	var toss_direction = -global_transform.basis.z.normalized()
	grenade.apply_impulse(toss_direction * toss_strength)

func start_cooldown():
	can_toss = false
	await get_tree().create_timer(cooldown_time).timeout
	can_toss = true
