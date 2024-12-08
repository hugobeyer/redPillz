@tool
extends Resource
class_name CurveSettings

@export var amplitude: float = 1.0
@export var primary_frequency: float = 1.0
@export var secondary_frequency: float = 2.0
@export var tertiary_frequency: float = 0.5
@export var phase_shift: float = 0.0
@export var blend_factor: float = 0.5
@export var distortion: float = 0.0
@export var draw_color: Color = Color.WHITE
@export var draw_resolution: int = 100
@export var curve_scale: float = 1.0
@export_enum("None", "Pow", "Atan2", "Bias", "SoftClip", "Remainder") var distortion_type: int = 0
