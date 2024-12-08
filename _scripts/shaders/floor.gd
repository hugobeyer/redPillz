extends MeshInstance3D

@export var max_radius: float = 10.0 : set = set_max_radius
@export var falloff_start: float = 8.0 : set = set_falloff_start

@onready var material: ShaderMaterial

func set_max_radius(value: float):
    max_radius = value
    if material:
        RenderingServer.call_on_render_thread(func():
            material.set_shader_parameter("max_radius", value)
        )

func set_falloff_start(value: float):
    falloff_start = value
    if material:
        RenderingServer.call_on_render_thread(func():
            material.set_shader_parameter("falloff_start", value)
        )

func _ready():
    material = get_surface_override_material(0)
    if not material:
        return
        
    # Initial setup
    set_max_radius(max_radius)
    set_falloff_start(falloff_start)
