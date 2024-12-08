extends Node

var scene_cache = {}

func get_scene(path: String) -> PackedScene:
	if path in scene_cache:
		return scene_cache[path]
	
	var scene = load(path)
	if scene is PackedScene:
		scene_cache[path] = scene
		return scene
	else:
		push_error("Failed to load scene: " + path)
		return null

func instantiate_scene(path: String) -> Node:
	var scene = get_scene(path)
	if scene:
		return scene.instantiate()
	else:
		push_error("Failed to instantiate scene: " + path)
		return null

func create_script_instance(script_path: String, parent_class: String = "Node") -> Node:
	var script = load(script_path)
	if script:
		print("IM ALIVE!")
		var parent_node = ClassDB.instantiate(parent_class)
		if parent_node:
			parent_node.set_script(script)
			return parent_node
		else:
			push_error("Failed to instantiate parent node: " + parent_class)
	else:
		push_error("Failed to load script: " + script_path)
	return null
