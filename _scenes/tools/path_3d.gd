@tool
extends Resource
class_name DebugCurve

@export var curve: Curve3D = Curve3D.new()
@export var amplitude: float = 1.0
@export var primary_frequency: float = 1.0
@export var secondary_frequency: float = 2.0
@export var phase_shift: float = 0.0
@export var time_scale: float = 1.0
@export var blend_factor: float = 0.5

var original_positions: Array = []

func _init():
    if curve.point_count == 0:
        curve.add_point(Vector3(0, 0, 0))
        curve.add_point(Vector3(1, 0, 0))
    
    # Store the original positions
    for i in range(curve.point_count):
        original_positions.append(curve.get_point_position(i))

func trigon_signed(t: float) -> float:
    var time = Time.get_ticks_msec() / 1000.0 * time_scale
    
    # Primary wave
    var primary_wave = sin(2 * PI * primary_frequency * t + phase_shift + time)
    
    # Secondary wave
    var secondary_wave = cos(2 * PI * secondary_frequency * t + phase_shift + time)
    
    # Blend the two waves
    var blended_wave = lerp(primary_wave, secondary_wave, blend_factor)
    
    return amplitude * blended_wave

func update_curve():
    for i in range(curve.point_count):
        var t = float(i) / max(1, curve.point_count - 1)
        var original_position = original_positions[i]
        var new_position = original_position + Vector3(0, trigon_signed(t), 0)
        if new_position.length() > 0:
            curve.set_point_position(i, new_position)
        else:
            curve.set_point_position(i, Vector3(0.001, 0.001, 0.001))

    # Notify that the resource has changed
    emit_changed()
