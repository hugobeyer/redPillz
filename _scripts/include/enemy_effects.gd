class_name EnemyEffects
extends Node3D

@export var flash_duration: float = 0.1
@export var flash_offset: float = 16.0
@export var flash_color: Color = Color(1.0, 0.417, 0.0, 1)
@export var flash_off_color: Color = Color(0, 0, 0, 0)

var mesh_instance: MeshInstance3D

func _ready():
	mesh_instance = get_parent().get_node("WobbleEffect/CharacterMesh")
	_init_shader_parameters()

func _init_shader_parameters():
	RenderingServer.call_on_render_thread(func():
		if is_instance_valid(mesh_instance):
			mesh_instance.set_instance_shader_parameter("lerp_wave", 0)
			mesh_instance.set_instance_shader_parameter("lerp_wave_offset", 0)
	)

func flash_red():
	if not is_instance_valid(mesh_instance):
		return
		
	var local_tween = create_tween()
	local_tween.set_parallel(false)
	
	# First sequence: Flash in
	local_tween.set_parallel(true)
	local_tween.tween_method(set_flash_intensity, 0.0, 1.0, flash_duration / 2)
	local_tween.tween_method(set_flash_color, flash_off_color, flash_color, flash_duration / 2)
	
	# Second sequence: Flash out
	local_tween.set_parallel(true)
	local_tween.tween_method(set_flash_intensity, 1.0, 0.0, flash_duration / 2)
	local_tween.tween_method(set_flash_color, flash_color, flash_off_color, flash_duration / 2)
	
	# Make sure values are reset at the end
	local_tween.tween_callback(reset_flash_parameters)

func reset_flash_parameters():
	RenderingServer.call_on_render_thread(func():
		if is_instance_valid(mesh_instance):
			mesh_instance.set_instance_shader_parameter("lerp_wave", 0.0)
			mesh_instance.set_instance_shader_parameter("lerp_color", flash_off_color)
	)

func set_flash_intensity(value: float):
	RenderingServer.call_on_render_thread(func():
		if is_instance_valid(mesh_instance):
			mesh_instance.set_instance_shader_parameter("lerp_wave", value)
			mesh_instance.set_instance_shader_parameter("lerp_wave_offset", value * flash_offset)
	)

func set_flash_color(color: Color):
	RenderingServer.call_on_render_thread(func():
		if is_instance_valid(mesh_instance):
			mesh_instance.set_instance_shader_parameter("lerp_color", color)
	)

func apply_damage_effect(_damage: Vector3):
	flash_red()

func _on_property_changed():
	RenderingServer.call_on_render_thread(func():
		if is_instance_valid(mesh_instance):
			mesh_instance.set_instance_shader_parameter("lerp_color", flash_color)
			mesh_instance.set_instance_shader_parameter("lerp_wave", 1.0)
			mesh_instance.set_instance_shader_parameter("lerp_wave_offset", flash_offset)
	)
