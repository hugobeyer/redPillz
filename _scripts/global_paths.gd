extends Node

var player: Node3D
var shield: Node3D

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	call_deferred("_initialize_references")

func _initialize_references():
	await get_tree().root.ready
	
	if not is_inside_tree():
		await get_tree().process_frame
	
	player = get_tree().get_first_node_in_group("player")
	shield = get_tree().get_first_node_in_group("shield")
	
	if not player:
		push_warning("Player not found in scene tree")
	if not shield:
		push_warning("Shield not found in scene tree")

func get_player() -> Node3D:
	return player

func get_shield() -> Node3D:
	return shield
