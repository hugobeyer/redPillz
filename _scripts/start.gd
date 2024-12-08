extends Control

func _ready():
	$ButtonEdit.connect("pressed", self._on_edit_pressed)
	$ButtonPlay.connect("pressed", self._on_play_pressed)

func _on_edit_pressed():
	get_tree().change_scene_to_file("res://_scenes/edit.tscn")

func _on_play_pressed():
	get_tree().change_scene_to_file("res://_scenes/main.tscn")
