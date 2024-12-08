class_name EnemyShield
extends Node3D

signal shield_depleted

@export var effect_duration: float = 1.0  # Duration of the effect in seconds
@export var max_shield_strength: float = 100.0  # Maximum shield strength

var current_shield_strength: float

@onready var shield_mesh: MeshInstance3D

func _ready():
	# shield_mesh = get_node("ShieldMesh")
	# shield_mesh.set_instance_shader_parameter("lerp_wave", 0)
	# shield_mesh.set_instance_shader_parameter("lerp_displace_normal", 0)
	current_shield_strength = max_shield_strength

# func shield_fx():
# 	if shield_mesh:
# 		var local_tween = create_tween()
# 		local_tween.tween_method(set_shield_fx_intensity, 0.0, 0.5, effect_duration / 2)
# 		local_tween.tween_method(set_shield_fx_intensity, 0.5, 0.0, effect_duration /  2)

# func set_shield_fx_intensity(value: float):
# 	shield_mesh.set_instance_shader_parameter("lerp_wave", value)
# 	shield_mesh.set_instance_shader_parameter("lerp_displace_normal", value)

func apply_shield_effect(damage: Vector3):
	# shield_fx()
	take_damage(damage.length())

func take_damage(damage: float) -> float:
	var remaining_damage = 0.0
	if current_shield_strength > 0:
		current_shield_strength -= damage
		if current_shield_strength <= 0:
			remaining_damage = abs(current_shield_strength)
			current_shield_strength = 0
			emit_signal("shield_depleted")
	else:
		remaining_damage = damage
	
	return remaining_damage

func get_shield_strength() -> float:
	return current_shield_strength
