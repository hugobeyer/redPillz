@tool
extends Node3D

@export var point_count: int = 10:
    set(value):
        point_count = value
        call_deferred("scatter_points")

@export var min_radius: float = 5.0:
    set(value):
        min_radius = value
        call_deferred("scatter_points")

@export var max_radius: float = 10.0:
    set(value):
        max_radius = value
        call_deferred("scatter_points")

@export var y_offset: float = 0.0:
    set(value):
        y_offset = value
        call_deferred("update_y_positions")

@export var relaxation_iterations: int = 10:
    set(value):
        relaxation_iterations = value
        call_deferred("scatter_points")

var points_container: Node3D

func _ready():
    if Engine.is_editor_hint():
        call_deferred("initialize_points_container")

func initialize_points_container():
    if not points_container:
        points_container = Node3D.new()
        points_container.name = "ScatteredPoints"
        add_child(points_container)
        points_container.set_owner(get_tree().edited_scene_root)
    call_deferred("scatter_points")

func scatter_points():
    if not points_container:
        call_deferred("initialize_points_container")
        return

    # Clear existing points
    for child in points_container.get_children():
        child.queue_free()

    # Initial scatter within the radius range
    for i in range(point_count):
        var point = Node3D.new()
        point.name = "ScatteredPoint_" + str(i)
        points_container.add_child(point)
        point.set_owner(get_tree().edited_scene_root)
        
        var angle = randf() * 2 * PI
        var radius = randf_range(min_radius, max_radius)
        var pos = Vector3(
            cos(angle) * radius,
            0,
            sin(angle) * radius
        )
        
        point.global_position = global_position + pos
        
        # Create a sphere as a child of the point for visualization
        var sphere = CSGSphere3D.new()
        sphere.name = "VisualizationSphere"
        sphere.radius = 0.5
        point.add_child(sphere)
        sphere.set_owner(get_tree().edited_scene_root)

    # Defer the relaxation process
    call_deferred("relax_points")

func relax_points():
    var avg_radius = (min_radius + max_radius) / 2
    var target_distance = (2 * PI * avg_radius) / point_count
    
    for iteration in range(relaxation_iterations):
        var points = points_container.get_children()
        for point in points:
            # Find nearest neighbors
            var neighbors = find_nearest_neighbors(point, 2)
            
            var adjustment = Vector3.ZERO
            for neighbor in neighbors:
                var to_neighbor = neighbor.global_position - point.global_position
                adjustment += to_neighbor.normalized() * (to_neighbor.length() - target_distance)
            
            adjustment /= neighbors.size()
            
            point.global_position += adjustment * 0.5
            
            # Ensure point stays within the radius range
            var to_center = point.global_position - global_position
            to_center.y = 0
            var current_radius = to_center.length()
            if current_radius < min_radius:
                point.global_position = global_position + to_center.normalized() * min_radius
            elif current_radius > max_radius:
                point.global_position = global_position + to_center.normalized() * max_radius

    call_deferred("update_y_positions")

func find_nearest_neighbors(point: Node3D, count: int) -> Array:
    var points = points_container.get_children()
    var distances = []
    for other_point in points:
        if other_point != point:
            var distance = point.global_position.distance_to(other_point.global_position)
            distances.append({"point": other_point, "distance": distance})
    
    distances.sort_custom(func(a, b): return a["distance"] < b["distance"])
    
    var neighbors = []
    for i in range(min(count, distances.size())):
        neighbors.append(distances[i]["point"])
    
    return neighbors

func update_y_positions():
    var floor_nodes = get_tree().get_nodes_in_group("floor")
    var points = points_container.get_children()
    
    for point in points:
        if floor_nodes.size() > 0:
            var closest_floor = find_closest_floor(point.global_position, floor_nodes)
            if closest_floor:
                var hit = closest_floor.intersect_ray(point.global_position + Vector3.UP * 1000, point.global_position - Vector3.UP * 1000)
                if hit:
                    point.global_position.y = hit.position.y + y_offset
        else:
            point.global_position.y = global_position.y + y_offset

func find_closest_floor(position: Vector3, floor_nodes: Array) -> StaticBody3D:
    var closest_floor = null
    var closest_distance = INF
    
    for floor_node in floor_nodes:
        if floor_node is StaticBody3D:
            var distance = position.distance_to(floor_node.global_position)
            if distance < closest_distance:
                closest_distance = distance
                closest_floor = floor_node
    
    return closest_floor

func _notification(what):
    if what == NOTIFICATION_EDITOR_POST_SAVE:
        call_deferred("scatter_points")
