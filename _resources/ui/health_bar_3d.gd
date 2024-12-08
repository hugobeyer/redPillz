extends MeshInstance3D

var progress: float = 1.0
var health_material = material_override


func _ready():
    # Initial setup
    if health_material:
        update_bar()

func set_progress(value: float, _shielded: bool = false):
    progress = clamp(value, 0.0, 1.0)
    update_bar()

func update_bar():
    
    # For HealthCircle shader, 1.0 = full, 0.0 = empty
    self.set_instance_shader_parameter("health_parm", progress)