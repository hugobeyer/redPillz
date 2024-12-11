class_name EnemyShield
extends Node3D

signal shield_depleted

@export var effect_duration: float = 1.0  # Duration of the effect in seconds
@export var max_shield_strength: float = 100.0  # Maximum shield strength

var current_shield_strength: float
var shield_mesh: MeshInstance3D
var is_effect_active: bool = false

func _ready():
	shield_mesh = $ShieldMesh
	if not shield_mesh:
		push_warning("Shield mesh not found! Make sure there's a MeshInstance3D named 'ShieldMesh' as a child of the shield.")
		return
		
	# Initialize shader parameters
	_safe_set_shader_params(0.0)
	current_shield_strength = max_shield_strength

func _safe_set_shader_params(value: float) -> void:
	if not is_instance_valid(shield_mesh):
		return
		
	# Wrap shader parameter setting in try-catch to handle potential errors
	if shield_mesh.get_instance_shader_parameter("lerp_wave") != null:
		shield_mesh.set_instance_shader_parameter("lerp_wave", value)
	if shield_mesh.get_instance_shader_parameter("lerp_displace_normal") != null:
		shield_mesh.set_instance_shader_parameter("lerp_displace_normal", value * 0.5)

func shield_fx():
	if not is_instance_valid(shield_mesh) or is_effect_active:
		return
		
	is_effect_active = true
	
	# Create new tween
	var tween = create_tween()
	tween.finished.connect(func(): is_effect_active = false)
	
	# Animate the shield effect
	tween.tween_method(func(v): _safe_set_shader_params(v), 0.0, 1.0, effect_duration * 0.5)
	tween.tween_method(func(v): _safe_set_shader_params(v), 1.0, 0.0, effect_duration * 0.5)

func apply_shield_effect(damage: Vector3):
	shield_fx()
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
