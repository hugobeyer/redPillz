extends Control  # or CanvasLayer, depending on your setup

@onready var kill_label: Label = $KillLabel  # Adjust this path to match your scene structure

func _ready():
	SignalBus.connect("enemy_killed", Callable(self, "_on_enemy_killed"))

func _on_enemy_killed(_enemy):
	var current_kills = int(kill_label.text.split(": ")[1])
	current_kills += 1
	kill_label.text = "Kills: " + str(current_kills)
