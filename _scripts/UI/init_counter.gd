extends Label

@export var animation_name := "init_counter"
@export var animation_duration := 5.0

func _ready():
	# Get AnimationPlayer from child node
	var anim_player = $AnimationPlayer
	if anim_player:
		print("Found AnimationPlayer, playing animation")
		anim_player.play("init_counter")  # Using exact name from your screenshot
		await get_tree().create_timer(animation_duration).timeout
		queue_free()
	else:
		push_error("Could not find AnimationPlayer!")
