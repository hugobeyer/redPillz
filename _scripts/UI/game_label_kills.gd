extends Label

var kills: int = 0

func _ready():
	# print("Kill counter ready")  # Debug
	text = "0"
	
	# Connect to GameEvents
	GameEvents.enemy_killed.connect(_on_enemy_killed)

func _on_enemy_killed(_enemy = null):
	# print("Previous kills: ", kills)  # Debug
	kills += 1
	# print("New kills: ", kills)  # Debug
	text = str(kills)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
