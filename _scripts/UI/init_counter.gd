extends Label

@export var final_text: String = "GO!"
@export var start_scale: float = 2.0
@export var end_scale: float = 0.5
@export var start_color: Color = Color(1, 1, 1, 1)  # White
@export var end_color: Color = Color(1, 0, 0, 1)    # Red
@export var tween_curve: Curve

var current_count: int = 3

func _ready() -> void:
	# Set initial properties
	scale = Vector2(start_scale, start_scale)
	modulate = start_color
	update_count()

func update_count() -> void:
	if current_count > 0:
		text = str(current_count)
		animate_count()
		current_count -= 1
	else:
		text = final_text
		animate_count()
		# After the final text, queue removal of both labels
		var tween = create_tween()
		tween.tween_interval(1.0)  # Wait for the "GO!" animation to complete
		tween.tween_callback(cleanup_labels)

func animate_count() -> void:
	var tween = create_tween()
	
	# Reset scale and color at the start of each count
	scale = Vector2(start_scale, start_scale)
	modulate = start_color
	
	# If we have a curve, use it for both scale and color animation
	if tween_curve:
		tween.parallel().tween_method(set_custom_scale, 0.0, 1.0, 1.0)
		tween.parallel().tween_method(set_custom_color, 0.0, 1.0, 1.0)
	else:
		# Simple linear scale and color tween if no curve is set
		tween.parallel().tween_property(self, "scale", Vector2(end_scale, end_scale), 1.0)
		tween.parallel().tween_property(self, "modulate", end_color, 1.0)
	
	# Wait for animation to complete before next number
	if current_count >= 0:  # Include 0 for final text
		tween.tween_callback(update_count).set_delay(0.1)

func set_custom_scale(progress: float) -> void:
	var scale_value = start_scale
	if tween_curve:
		# Interpolate between start and end scale using the curve
		scale_value = lerp(start_scale, end_scale, tween_curve.sample(progress))
	scale = Vector2(scale_value, scale_value)

func set_custom_color(progress: float) -> void:
	if tween_curve:
		# Interpolate between start and end color using the curve
		modulate = start_color.lerp(end_color, tween_curve.sample(progress))
	else:
		modulate = start_color.lerp(end_color, progress)

func cleanup_labels() -> void:
	# Find and remove the "Incoming" label sibling
	var incoming_label = get_node_or_null("../Incoming")
	if incoming_label:
		incoming_label.queue_free()
	
	# Remove self
	queue_free()
